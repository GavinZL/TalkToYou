#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
直接从 PyTorch 模型转换为 Core ML
使用 coremltools 进行转换
"""

import sys
import os
import argparse
from pathlib import Path


def check_dependencies():
    """检查必要的依赖"""
    required_packages = ['torch', 'coremltools']
    
    missing_packages = []
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing_packages.append(package)
    
    if missing_packages:
        print(f"❌ 缺少以下依赖包: {', '.join(missing_packages)}")
        print(f"\n请运行以下命令安装:")
        print(f"pip install {' '.join(missing_packages)}")
        return False
    
    print("✅ 所有依赖已安装")
    return True


def load_pytorch_model(model_path):
    """加载 PyTorch 模型"""
    import torch
    
    print(f"\n📥 加载 PyTorch 模型: {model_path}")
    
    try:
        # 方式1: 直接加载模型
        model = torch.load(model_path, map_location='cpu')
        print(f"✅ 模型加载成功")
        print(f"模型类型: {type(model)}")
        
        # 检查模型结构
        if isinstance(model, dict):
            print("\n📊 模型包含的键:")
            for key in model.keys():
                print(f"  - {key}")
            
            # 尝试提取实际模型
            if 'model' in model:
                actual_model = model['model']
            elif 'state_dict' in model:
                print("⚠️  这是一个 state_dict，需要模型架构定义")
                return None
            else:
                actual_model = model
        else:
            actual_model = model
        
        return actual_model
        
    except Exception as e:
        print(f"❌ 加载失败: {e}")
        return None


def convert_to_coreml(model, output_path, input_shape=None):
    """转换 PyTorch 模型为 Core ML"""
    import torch
    import coremltools as ct
    
    print(f"\n🔄 开始转换为 Core ML...")
    
    try:
        # 设置模型为评估模式
        if hasattr(model, 'eval'):
            model.eval()
        
        # 准备示例输入
        if input_shape is None:
            # SenseVoice 默认输入: (batch=1, time=3000, features=80)
            # 这里使用简化的输入进行测试
            input_shape = (1, 1000)  # (batch, samples)
        
        print(f"使用输入形状: {input_shape}")
        example_input = torch.randn(*input_shape)
        
        # 追踪模型
        print("📝 追踪模型...")
        traced_model = torch.jit.trace(model, example_input)
        
        # 转换为 Core ML
        print("🔧 转换为 Core ML 格式...")
        
        # 定义输入
        coreml_model = ct.convert(
            traced_model,
            inputs=[ct.TensorType(name="audio", shape=input_shape)],
            minimum_deployment_target=ct.target.iOS15,
            compute_precision=ct.precision.FLOAT32,
        )
        
        # 设置元数据
        coreml_model.author = "FunAudioLLM"
        coreml_model.license = "MIT"
        coreml_model.short_description = "SenseVoice - Multilingual ASR Model"
        coreml_model.version = "1.0.0"
        
        # 保存模型
        coreml_model.save(output_path)
        
        print(f"✅ Core ML 模型转换成功: {output_path}")
        print(f"📱 可以将此文件添加到 iOS 项目")
        
        return True
        
    except Exception as e:
        print(f"❌ 转换失败: {e}")
        print(f"\n详细错误:")
        import traceback
        traceback.print_exc()
        return False


def convert_with_funasr():
    """使用 FunASR 加载模型后转换"""
    print("\n🔄 尝试使用 FunASR 加载模型...")
    
    try:
        from funasr import AutoModel
        import torch
        import coremltools as ct
        
        # 加载 SenseVoice 模型
        print("📥 使用 FunASR 加载 SenseVoice...")
        model = AutoModel(
            model="iic/SenseVoiceSmall",
            trust_remote_code=True,
            device="cpu"
        )
        
        print("✅ 模型加载成功")
        
        # 获取实际的 PyTorch 模型
        pytorch_model = model.model
        pytorch_model.eval()
        
        print(f"模型类型: {type(pytorch_model)}")
        
        # 准备示例输入
        # SenseVoice 需要的输入格式（推理模式只需要 speech 相关参数）
        batch_size = 1
        seq_len = 1000
        feat_dim = 80
        
        dummy_input = {
            'speech': torch.randn(batch_size, seq_len, feat_dim),
            'speech_lengths': torch.tensor([seq_len]),
            'language': torch.tensor([0]),  # 0 = auto
            'text': torch.tensor([[0]]),  # 占位符
            'text_lengths': torch.tensor([1])  # 占位符
        }
        
        print(f"\n输入形状:")
        for key, value in dummy_input.items():
            print(f"  {key}: {value.shape if hasattr(value, 'shape') else value}")
        
        # 尝试简单推理测试（使用 encoder 方法）
        print("\n🧪 测试模型编码器...")
        with torch.no_grad():
            try:
                # SenseVoice 有 encode 方法用于推理
                if hasattr(pytorch_model, 'encode'):
                    encoder_out, encoder_out_lens = pytorch_model.encode(
                        speech=dummy_input['speech'],
                        speech_lengths=dummy_input['speech_lengths']
                    )
                    print(f"✅ 编码器推理成功")
                    print(f"Encoder 输出形状: {encoder_out.shape}")
                    use_encoder_only = True
                else:
                    # 使用完整 forward
                    output = pytorch_model(**dummy_input)
                    print(f"✅ Forward 推理成功")
                    print(f"输出类型: {type(output)}")
                    use_encoder_only = False
            except Exception as e:
                print(f"⚠️  模型测试失败: {e}")
                print("尝试只使用编码器部分...")
                use_encoder_only = True
        
        # 创建包装器以简化输入
        class SenseVoiceEncoderWrapper(torch.nn.Module):
            """SenseVoice Encoder 包装器 - 只使用编码器部分"""
            def __init__(self, model):
                super().__init__()
                self.encoder = model.encoder if hasattr(model, 'encoder') else model
            
            def forward(self, speech):
                # 简化输入：只接受音频
                speech_lengths = torch.tensor([speech.shape[1]])
                # 使用 encoder 直接编码
                if hasattr(self.encoder, '__call__'):
                    encoder_out, encoder_out_lens = self.encoder(speech, speech_lengths)
                else:
                    # 如果 encoder 不可调用，尝试直接返回输入
                    encoder_out = speech
                    encoder_out_lens = speech_lengths
                return encoder_out, encoder_out_lens
        
        wrapped_model = SenseVoiceEncoderWrapper(pytorch_model)
        wrapped_model.eval()
        
        # 准备简化的输入用于追踪
        simple_input = torch.randn(1, seq_len, feat_dim)
        
        print("\n📝 追踪模型...")
        traced_model = torch.jit.trace(wrapped_model, simple_input)
        
        # 转换为 Core ML
        print("🔧 转换为 Core ML...")
        coreml_model = ct.convert(
            traced_model,
            inputs=[ct.TensorType(
                name="speech",
                shape=(1, ct.RangeDim(lower_bound=100, upper_bound=3000), feat_dim)
            )],
            minimum_deployment_target=ct.target.iOS15,
            compute_precision=ct.precision.FLOAT16,  # 使用 FP16 减小模型体积
        )
        
        # 设置元数据
        coreml_model.author = "FunAudioLLM"
        coreml_model.license = "MIT"
        coreml_model.short_description = "SenseVoice Small - Multilingual ASR"
        coreml_model.version = "1.0.0"
        
        # 保存
        output_path = "./coreml_models/SenseVoice.mlmodel"
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        coreml_model.save(output_path)
        
        print(f"\n✅ 转换成功!")
        print(f"模型位置: {output_path}")
        
        return True
        
    except Exception as e:
        print(f"❌ 转换失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='将 PyTorch 模型直接转换为 Core ML'
    )
    parser.add_argument(
        '--model',
        type=str,
        default='/Users/bigo/.cache/modelscope/hub/models/iic/SenseVoiceSmall/model.pt',
        help='PyTorch 模型路径'
    )
    parser.add_argument(
        '--output',
        type=str,
        default='./coreml_models/SenseVoice.mlmodel',
        help='输出的 Core ML 模型路径'
    )
    parser.add_argument(
        '--use-funasr',
        action='store_true',
        help='使用 FunASR 加载模型'
    )
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("PyTorch 转 Core ML 直接转换工具")
    print("=" * 60)
    
    # 检查 Python 版本
    python_version = sys.version_info
    print(f"\n🐍 Python 版本: {python_version.major}.{python_version.minor}.{python_version.micro}")
    
    if python_version >= (3, 13):
        print("\n⚠️  警告: Python 3.13+ 可能与某些依赖包不兼容")
        print("建议使用 Python 3.10 或 3.11")
    
    # 检查依赖
    if not check_dependencies():
        sys.exit(1)
    
    # 创建输出目录
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    
    # 选择转换方式
    if args.use_funasr:
        print("\n使用 FunASR 方式加载模型")
        success = convert_with_funasr()
    else:
        print("\n使用直接加载方式")
        print("⚠️  注意: SenseVoice 模型结构复杂，直接加载可能失败")
        print("建议使用 --use-funasr 参数\n")
        
        # 加载模型
        model = load_pytorch_model(args.model)
        
        if model is None:
            print("\n❌ 模型加载失败，尝试使用 --use-funasr 参数")
            sys.exit(1)
        
        # 转换
        success = convert_to_coreml(model, args.output)
    
    if success:
        print("\n" + "=" * 60)
        print("✅ 转换完成!")
        print("=" * 60)
        print(f"\n生成的文件:")
        print(f"  - {args.output}")
        print(f"\n📱 使用方法:")
        print(f"  1. 将 {os.path.basename(args.output)} 添加到 Xcode 项目")
        print(f"  2. 确保文件在 'Copy Bundle Resources' 中")
        print(f"  3. 在代码中加载并使用模型")
    else:
        print("\n" + "=" * 60)
        print("❌ 转换失败")
        print("=" * 60)
        print("\n可能的原因:")
        print("  1. 模型结构过于复杂")
        print("  2. PyTorch 版本不兼容")
        print("  3. 缺少模型架构定义")
        print("\n建议:")
        print("  1. 尝试使用 --use-funasr 参数")
        print("  2. 使用 ONNX Runtime 方案（推荐）")
        print("  3. 使用云端 ASR API")
        sys.exit(1)


if __name__ == "__main__":
    main()
