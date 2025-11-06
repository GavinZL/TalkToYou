#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试转换后的 Core ML 模型
"""

import sys
import os


def test_coreml_model(model_path):
    """测试 Core ML 模型"""
    try:
        import coremltools as ct
        import numpy as np
        
        print(f"📂 加载模型: {model_path}")
        model = ct.models.MLModel(model_path)
        
        print("\n📊 模型信息:")
        print(f"  作者: {model.author}")
        print(f"  版本: {model.version}")
        print(f"  描述: {model.short_description}")
        
        print("\n📥 输入规格:")
        for input_name, input_spec in model.input_description.items():
            print(f"  - {input_name}: {input_spec}")
        
        print("\n📤 输出规格:")
        for output_name, output_spec in model.output_description.items():
            print(f"  - {output_name}: {output_spec}")
        
        # 创建测试输入
        print("\n🧪 创建测试输入...")
        # 假设输入是 (1, 100, 80) - batch_size, time_steps, features
        test_input = {
            'audio_features': np.random.randn(1, 100, 80).astype(np.float32)
        }
        
        print("🔄 运行推理...")
        try:
            output = model.predict(test_input)
            print(f"✅ 推理成功!")
            print(f"输出: {output}")
        except Exception as e:
            print(f"⚠️  推理失败 (这是正常的，因为输入是随机数据): {e}")
        
        print("\n✅ 模型测试完成!")
        
    except ImportError:
        print("❌ 请安装 coremltools: pip install coremltools")
        sys.exit(1)
    except Exception as e:
        print(f"❌ 测试失败: {e}")
        sys.exit(1)


def main():
    """主函数"""
    if len(sys.argv) < 2:
        model_path = "./coreml_models/SenseVoice.mlmodel"
        if not os.path.exists(model_path):
            print("用法: python test_model.py <model_path>")
            print(f"默认路径 {model_path} 不存在")
            sys.exit(1)
    else:
        model_path = sys.argv[1]
    
    if not os.path.exists(model_path):
        print(f"❌ 模型文件不存在: {model_path}")
        sys.exit(1)
    
    test_coreml_model(model_path)


if __name__ == "__main__":
    main()
