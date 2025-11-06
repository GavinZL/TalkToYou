#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
简单的 Gummy WebSocket API 测试示例
仅需要 websockets 库，无需 pyaudio
"""

import os
import sys
import asyncio

# 检查 API Key
api_key = os.getenv("DASHSCOPE_API_KEY")
if not api_key:
    print("❌ 错误: 请设置环境变量 DASHSCOPE_API_KEY")
    print("   export DASHSCOPE_API_KEY='your_api_key'")
    sys.exit(1)

# 导入主测试模块
from test_gummy_websocket import test_with_audio_file

def main():
    """主函数"""
    print("=" * 60)
    print("  Gummy WebSocket API 简单测试")
    print("=" * 60)
    print()
    
    # 提示用户输入音频文件
    print("请提供一个测试音频文件:")
    print("  - 格式: WAV 或 原始 PCM")
    print("  - 采样率: 16000 Hz")
    print("  - 通道数: 单声道 (mono)")
    print("  - 位深度: 16-bit")
    print()
    
    audio_file = input("音频文件路径: ").strip()
    
    if not audio_file:
        print("❌ 未提供音频文件路径")
        sys.exit(1)
    
    if not os.path.exists(audio_file):
        print(f"❌ 文件不存在: {audio_file}")
        sys.exit(1)
    
    # 选择目标语言
    print()
    print("支持的目标语言:")
    print("  en - 英语")
    print("  ja - 日语")
    print("  ko - 韩语")
    print("  es - 西班牙语")
    print("  fr - 法语")
    print("  de - 德语")
    print()
    
    target_lang = input("目标语言 (默认: en): ").strip() or "en"
    
    # 运行测试
    print()
    asyncio.run(test_with_audio_file(api_key, audio_file, target_lang))

if __name__ == "__main__":
    main()
