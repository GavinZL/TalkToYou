#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SenseVoice 模型转换脚本
将 SenseVoice 模型转换为 Core ML 格式，用于 iOS ASR

使用步骤：
1. 安装依赖: pip install -r requirements.txt
2. 运行脚本: python convert_sensevoice_to_coreml.py
3. 生成的 .mlmodel 文件可直接用于 iOS 项目
"""

import os
import sys
import shutil
from pathlib import Path

def check_dependencies():
    """检查必要的依赖"""
    required_packages = [
        'torch',
        'onnx',
        'coremltools',
        'funasr',
        'numpy'
    ]
    
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


def download_sensevoice_model(model_dir="./models"):
    """下载 SenseVoice 模型"""
    from funasr import AutoModel
    
    print("\n📥 下载 SenseVoice-Small 模型...")
    
    try:
        model = AutoModel(
            model="iic/SenseVoiceSmall",
            trust_remote_code=True,
            disable_update=False,
        )
        
        model_path = model.model_path
        print(f"✅ 模型下载成功: {model_path}")
        return model_path
    except Exception as e:
        print(f"❌ 模型下载失败: {e}")
        return None


def export_to_onnx(model_path, output_dir="./onnx_models"):
    """导出模型为 ONNX 格式"""
    print("\n🔄 导出模型为 ONNX 格式...")
    
    try:
        from funasr import AutoModel
        import torch
        
        # 创建输出目录
        os.makedirs(output_dir, exist_ok=True)
        
        # 加载模型
        model = AutoModel(
            model=model_path,
            trust_remote_code=True,
            device="cpu"  # 使用 CPU 进行导出
        )
        
        # 准备示例输入
        # SenseVoice 输入: (batch_size, seq_len, feat_dim)
        batch_size = 1
        seq_len = 100  # 示例长度
        feat_dim = 80  # mel 特征维度
        
        dummy_input = torch.randn(batch_size, seq_len, feat_dim)
        
        # 导出为 ONNX
        onnx_path = os.path.join(output_dir, "sensevoice_small.onnx")
        
        # 配置导出参数，统一算子类型
        torch.onnx.export(
            model.model,
            dummy_input,
            onnx_path,
            export_params=True,
            opset_version=14,  # 使用 opset 14，更好的类型支持
            do_constant_folding=True,
            input_names=['audio_features'],
            output_names=['transcription'],
            dynamic_axes={
                'audio_features': {0: 'batch_size', 1: 'seq_len'},
                'transcription': {0: 'batch_size'}
            },
            # 关键: 启用 ONNX 检查和类型推断
            operator_export_type=torch.onnx.OperatorExportTypes.ONNX,
            # 启用训练模式导出（有助于类型推断）
            training=torch.onnx.TrainingMode.EVAL,
        )
        
        print(f"✅ ONNX 模型导出成功: {onnx_path}")
        return onnx_path
        
    except Exception as e:
        print(f"❌ ONNX 导出失败: {e}")
        print("\n建议: 使用 FunASR 提供的官方导出工具")
        print("参考: https://github.com/modelscope/FunASR")
        return None


def use_funasr_onnx_export(model_name="iic/SenseVoiceSmall"):
    """使用 FunASR ONNX 官方导出方式"""
    print("\n🔄 使用 FunASR ONNX 导出...")
    
    try:
        from funasr_onnx import SenseVoiceSmall
        
        # 导出 ONNX (会自动保存在模型目录)
        model = SenseVoiceSmall(
            model_name,
            batch_size=1,
            quantize=False  # 不量化，保持精度
        )
        
        print("✅ ONNX 模型已导出到模型目录")
        
        # 查找生成的 ONNX 文件
        from pathlib import Path
        cache_dir = Path.home() / ".cache" / "modelscope" / "hub" / model_name
        
        onnx_files = list(cache_dir.rglob("*.onnx"))
        if onnx_files:
            print(f"📁 ONNX 文件位置: {onnx_files[0]}")
            return str(onnx_files[0])
        
        return None
        
    except Exception as e:
        print(f"❌ FunASR ONNX 导出失败: {e}")
        return None


def convert_onnx_to_coreml(onnx_path, output_dir="./coreml_models"):
    """将 ONNX 模型转换为 Core ML 格式"""
    print("\n🔄 转换 ONNX 为 Core ML 格式...")
    
    try:
        import coremltools as ct
        from coremltools.converters.onnx import convert
        
        # 创建输出目录
        os.makedirs(output_dir, exist_ok=True)
        
        # 转换为 Core ML
        coreml_model = convert(
            model=onnx_path,
            minimum_deployment_target=ct.target.iOS15,
        )
        
        # 设置模型元数据
        coreml_model.author = "FunAudioLLM"
        coreml_model.license = "MIT"
        coreml_model.short_description = "SenseVoice Small - Multilingual ASR Model"
        coreml_model.version = "1.0.0"
        
        # 保存模型
        output_path = os.path.join(output_dir, "SenseVoice.mlmodel")
        coreml_model.save(output_path)
        
        print(f"✅ Core ML 模型转换成功: {output_path}")
        print(f"\n📱 可以将此文件添加到 iOS 项目的 Resources 目录")
        
        return output_path
        
    except Exception as e:
        print(f"❌ Core ML 转换失败: {e}")
        return None


def compile_coreml_model(mlmodel_path):
    """编译 Core ML 模型为 .mlmodelc 格式"""
    print("\n🔧 编译 Core ML 模型...")
    
    try:
        import coremltools as ct
        
        # 加载模型
        model = ct.models.MLModel(mlmodel_path)
        
        # 编译后的路径
        output_path = mlmodel_path.replace('.mlmodel', '.mlmodelc')
        
        # 编译模型
        model.save(output_path)
        
        print(f"✅ 模型编译成功: {output_path}")
        return output_path
        
    except Exception as e:
        print(f"❌ 模型编译失败: {e}")
        return None


def main():
    """主函数"""
    print("=" * 60)
    print("SenseVoice 模型转换工具 - ONNX to Core ML")
    print("=" * 60)
    
    # 0. 检查 Python 版本
    import sys
    python_version = sys.version_info
    print(f"\n🐍 Python 版本: {python_version.major}.{python_version.minor}.{python_version.micro}")
    
    if python_version >= (3, 13):
        print("\n⚠️  警告: Python 3.13+ 可能与某些依赖包不兼容")
        print("建议使用 Python 3.10 或 3.11 版本")
        print("\n你可以:")
        print("1. 使用 pyenv 安装 Python 3.11: pyenv install 3.11")
        print("2. 创建虚拟环境: python3.11 -m venv venv_py311")
        print("3. 激活并重试: source venv_py311/bin/activate && pip install -r requirements.txt")
        
        response = input("\n是否继续尝试? (y/n): ")
        if response.lower() != 'y':
            print("已取消")
            sys.exit(0)
    
    # 1. 检查依赖
    if not check_dependencies():
        sys.exit(1)
    
    # 2. 下载模型
    model_path = download_sensevoice_model()
    if not model_path:
        print("\n⚠️  模型下载失败，请手动下载后重试")
        sys.exit(1)
    
    # 3. 导出为 ONNX
    print("\n" + "=" * 60)
    print("方式1: 使用 FunASR ONNX 官方导出 (推荐)")
    print("=" * 60)
    
    onnx_path = use_funasr_onnx_export()
    
    if not onnx_path:
        print("\n⚠️  ONNX 导出失败")
        print("请参考 FunASR 官方文档手动导出:")
        print("https://github.com/modelscope/FunASR")
        sys.exit(1)
    
    # 4. 转换为 Core ML
    coreml_path = convert_onnx_to_coreml(onnx_path)
    if not coreml_path:
        sys.exit(1)
    
    # 5. 编译模型
    compiled_path = compile_coreml_model(coreml_path)
    
    # 6. 完成
    print("\n" + "=" * 60)
    print("✅ 转换完成！")
    print("=" * 60)
    print(f"\n生成的文件:")
    print(f"  - ONNX 模型: {onnx_path}")
    print(f"  - Core ML 模型: {coreml_path}")
    if compiled_path:
        print(f"  - 编译后模型: {compiled_path}")
    
    print(f"\n📱 使用方法:")
    print(f"  1. 将 {os.path.basename(coreml_path)} 添加到 Xcode 项目")
    print(f"  2. 确保文件在 'Copy Bundle Resources' 中")
    print(f"  3. 在代码中使用 SenseVoice 模型进行 ASR")
    
    print("\n🎉 转换成功完成！")


if __name__ == "__main__":
    main()
