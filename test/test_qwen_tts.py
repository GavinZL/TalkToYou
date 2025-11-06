#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试阿里云 Qwen3-TTS-Flash API 连接

使用方法:
    python test/test_qwen_tts.py

环境变量:
    DASHSCOPE_API_KEY - 阿里云 API Key
"""

import os
import sys
import json
import requests
from pathlib import Path

# 配置
API_ENDPOINT = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
MODEL = "qwen3-tts-flash"
TEST_TEXT = "你好，我是通义千问语音合成服务。今天天气真不错！"
VOICE = "Cherry"
LANGUAGE_TYPE = "Chinese"

def test_tts_api():
    """测试 TTS API"""
    # 获取 API Key
    api_key = os.getenv("DASHSCOPE_API_KEY")
    if not api_key:
        print("❌ 错误: 未设置 DASHSCOPE_API_KEY 环境变量")
        print("\n设置方法:")
        print("  export DASHSCOPE_API_KEY='sk-your-api-key'")
        return False
    
    print("🔑 API Key:", api_key[:10] + "..." if len(api_key) > 10 else api_key)
    print(f"🎯 测试文本: {TEST_TEXT}")
    print(f"🎙️  音色: {VOICE}")
    print(f"🌐 语言: {LANGUAGE_TYPE}")
    print()
    
    # 构建请求
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "model": MODEL,
        "input": {
            "text": TEST_TEXT,
            "voice": VOICE,
            "language_type": LANGUAGE_TYPE
        }
    }
    
    print("📤 发送 TTS 请求...")
    
    try:
        # 发送请求
        response = requests.post(
            API_ENDPOINT,
            headers=headers,
            json=payload,
            timeout=30
        )
        
        print(f"📥 响应状态码: {response.status_code}")
        
        # 检查状态码
        if response.status_code != 200:
            print(f"❌ 请求失败: {response.status_code}")
            print(f"响应内容: {response.text}")
            return False
        
        # 解析响应
        result = response.json()
        print("✅ 请求成功!")
        print()
        print("📄 响应数据:")
        print(json.dumps(result, indent=2, ensure_ascii=False))
        print()
        
        # 提取音频 URL
        if "output" in result and "audio_url" in result["output"]:
            audio_url = result["output"]["audio_url"]
            print(f"🔗 音频 URL: {audio_url}")
            
            # 下载音频文件
            print("⬇️  下载音频文件...")
            audio_response = requests.get(audio_url, timeout=30)
            
            if audio_response.status_code == 200:
                # 保存音频文件
                output_dir = Path(__file__).parent
                output_file = output_dir / "test_tts_output.mp3"
                
                with open(output_file, "wb") as f:
                    f.write(audio_response.content)
                
                file_size = len(audio_response.content)
                print(f"✅ 音频下载成功!")
                print(f"📦 文件大小: {file_size} bytes")
                print(f"💾 保存路径: {output_file}")
                print()
                print("🎵 你可以播放该文件来测试音频质量:")
                print(f"   open {output_file}")
                return True
            else:
                print(f"❌ 音频下载失败: {audio_response.status_code}")
                return False
        else:
            print("❌ 响应中未找到 audio_url")
            return False
            
    except requests.exceptions.Timeout:
        print("❌ 请求超时")
        return False
    except requests.exceptions.RequestException as e:
        print(f"❌ 请求异常: {e}")
        return False
    except json.JSONDecodeError as e:
        print(f"❌ JSON 解析失败: {e}")
        return False
    except Exception as e:
        print(f"❌ 未知错误: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_english_tts():
    """测试英文 TTS"""
    api_key = os.getenv("DASHSCOPE_API_KEY")
    if not api_key:
        print("❌ 错误: 未设置 DASHSCOPE_API_KEY 环境变量")
        return False
    
    print("\n" + "="*60)
    print("测试英文语音合成")
    print("="*60 + "\n")
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "model": MODEL,
        "input": {
            "text": "Hello! This is Qwen Text to Speech service. How are you today?",
            "voice": "Emily",
            "language_type": "English"
        }
    }
    
    print("📤 发送英文 TTS 请求...")
    
    try:
        response = requests.post(API_ENDPOINT, headers=headers, json=payload, timeout=30)
        print(f"📥 响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            if "output" in result and "audio_url" in result["output"]:
                audio_url = result["output"]["audio_url"]
                print(f"🔗 音频 URL: {audio_url}")
                
                # 下载音频
                audio_response = requests.get(audio_url, timeout=30)
                if audio_response.status_code == 200:
                    output_file = Path(__file__).parent / "test_tts_english.mp3"
                    with open(output_file, "wb") as f:
                        f.write(audio_response.content)
                    print(f"✅ 英文音频下载成功: {output_file}")
                    return True
        
        return False
    except Exception as e:
        print(f"❌ 错误: {e}")
        return False

def main():
    print("="*60)
    print("阿里云 Qwen3-TTS-Flash API 测试")
    print("="*60)
    print()
    
    # 测试中文
    success_cn = test_tts_api()
    
    # 测试英文
    success_en = test_english_tts()
    
    print("\n" + "="*60)
    print("测试总结")
    print("="*60)
    print(f"中文 TTS: {'✅ 通过' if success_cn else '❌ 失败'}")
    print(f"英文 TTS: {'✅ 通过' if success_en else '❌ 失败'}")
    print()
    
    if success_cn and success_en:
        print("🎉 所有测试通过！阿里云 TTS API 工作正常。")
        return 0
    else:
        print("⚠️  部分测试失败，请检查配置。")
        return 1

if __name__ == "__main__":
    sys.exit(main())
