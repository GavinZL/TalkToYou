#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
阿里云灵积 Gummy 一句话识别与翻译 WebSocket API 测试
模型: gummy-chat-v1
文档: https://help.aliyun.com/zh/model-studio/sentence-websocket-api
"""

import os
import json
import asyncio
import websockets
import wave
import uuid
from pathlib import Path


class GummyWebSocketClient:
    """Gummy WebSocket 客户端"""
    
    def __init__(self, api_key: str):
        """
        初始化客户端
        
        Args:
            api_key: 阿里云 API Key
        """
        self.api_key = api_key
        self.url = "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
        self.task_id = str(uuid.uuid4())
        self.websocket = None
        
    async def connect(self):
        """建立 WebSocket 连接"""
        headers = {
            "Authorization": f"bearer {self.api_key}",
            "user-agent": "GummyTest/1.0",
            "X-DashScope-DataInspection": "enable"
        }
        
        print(f"🔗 正在连接到服务器...")
        self.websocket = await websockets.connect(self.url, extra_headers=headers)
        print(f"✅ 连接成功! Task ID: {self.task_id}")
        
    async def send_run_task(self, 
                           target_lang: str = "en",
                           source_lang: str = "auto",
                           sample_rate: int = 16000,
                           format: str = "pcm",
                           max_end_silence: int = 5000,
                           enable_inverse_text_normalization: bool = True):
        """
        发送 run-task 指令开启任务
        
        Args:
            target_lang: 翻译目标语言，如 'en', 'ja', 'ko' 等
            source_lang: 源语言，默认 'auto' 自动识别
            sample_rate: 音频采样率，支持 8000/16000
            format: 音频格式，支持 'pcm', 'opus', 'opu'
            max_end_silence: 最大静音时长(ms)，默认5000ms（适用于长音频）
            enable_inverse_text_normalization: 是否启用逆文本正则化
        """
        run_task_message = {
            "header": {
                "task_id": self.task_id,
                "action": "run-task",
                "streaming": "duplex"
            },
            "payload": {
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": "gummy-realtime-v1",
                "input": {
                    "format": format,
                    "sample_rate": sample_rate,
                    "audio_type": "sentence",
                    "translation": {
                        "target_lang": target_lang,
                        "source_lang": source_lang
                    }
                },
                "parameters": {
                    "max_end_silence": max_end_silence,
                    "enable_inverse_text_normalization": enable_inverse_text_normalization
                }
            }
        }
        
        print(f"📤 发送 run-task 指令...")
        print(f"   - 目标语言: {target_lang}")
        print(f"   - 采样率: {sample_rate} Hz")
        print(f"   - 格式: {format}")
        print(f"   - 静音检测时长: {max_end_silence} ms")
        
        await self.websocket.send(json.dumps(run_task_message))
        
    async def send_audio_data(self, audio_file_path: str, chunk_size: int = 3200):
        """
        发送音频数据流
        
        Args:
            audio_file_path: 音频文件路径 (PCM 格式)
            chunk_size: 每次发送的数据块大小 (字节)
        """
        if not os.path.exists(audio_file_path):
            raise FileNotFoundError(f"音频文件不存在: {audio_file_path}")
            
        print(f"🎵 开始发送音频数据: {audio_file_path}")
        
        # 读取音频文件
        if audio_file_path.endswith('.wav'):
            # WAV 文件，提取 PCM 数据
            with wave.open(audio_file_path, 'rb') as wf:
                # 获取音频参数
                channels = wf.getnchannels()
                sample_width = wf.getsampwidth()
                framerate = wf.getframerate()
                total_frames = wf.getnframes()
                
                # 计算音频时长（秒）
                duration = total_frames / framerate
                
                print(f"   音频信息: {channels}通道, {sample_width*8}bit, {framerate}Hz, {duration:.1f}秒")
                
                # 检查时长限制（60秒）
                if duration > 60:
                    raise ValueError(f"音频时长 {duration:.1f} 秒超过限制（最大60秒）")
                
                # 每次读取的帧数
                frames_per_chunk = chunk_size // (sample_width * channels)
                sent_frames = 0
                
                while True:
                    data = wf.readframes(frames_per_chunk)
                    if not data:
                        print(f"   not data..")
                        break
                    
                    await self.websocket.send(data)
                    sent_frames += frames_per_chunk
                    
                    # 模拟实时流式发送，按照实际播放速度
                    await asyncio.sleep(frames_per_chunk / framerate)
                    
                    # 显示进度
                    progress = min((sent_frames / total_frames) * 100, 100)
                    print(f"   发送进度: {progress:.1f}%", end='\r')
                    
        else:
            # 原始 PCM 文件
            file_size = os.path.getsize(audio_file_path)
            
            # 假设 16kHz, 16bit, 单声道
            duration = file_size / (16000 * 2)
            print(f"   音频信息: 1通道, 16bit, 16000Hz, {duration:.1f}秒")
            
            if duration > 60:
                raise ValueError(f"音频时长 {duration:.1f} 秒超过限制（最大60秒）")
            
            with open(audio_file_path, 'rb') as f:
                sent_size = 0
                
                while True:
                    data = f.read(chunk_size)
                    if not data:
                        break
                    
                    await self.websocket.send(data)
                    sent_size += len(data)
                    
                    # 模拟实时流式发送 (16kHz, 16bit)
                    await asyncio.sleep(len(data) / (16000 * 2))
                    
                    # 显示进度
                    progress = min((sent_size / file_size) * 100, 100)
                    print(f"   发送进度: {progress:.1f}%", end='\r')
        
        print(f"\n✅ 音频数据发送完成!")
        
    async def send_finish_task(self):
        """发送 finish-task 指令结束任务"""
        finish_task_message = {
            "header": {
                "task_id": self.task_id,
                "action": "finish-task",
                "streaming": "duplex"
            },
            "payload": {
                "input": {}
            }
        }
        
        print(f"📤 发送 finish-task 指令...")
        await self.websocket.send(json.dumps(finish_task_message))
        
    async def receive_messages(self):
        """接收服务器消息"""
        print(f"👂 开始监听服务器消息...\n")
        
        try:
            async for message in self.websocket:
                try:
                    event = json.loads(message)
                    event_type = event.get("header", {}).get("event")
                    
                    if event_type == "task-started":
                        print(f"✅ 任务已开启 (task-started)\n")
                        
                    elif event_type == "result-generated":
                        self._handle_result(event)
                        
                    elif event_type == "task-finished":
                        print(f"\n✅ 任务已完成 (task-finished)")
                        break
                        
                    elif event_type == "task-failed":
                        error_code = event.get("header", {}).get("error_code", "UNKNOWN")
                        error_message = event.get("header", {}).get("error_message", "")
                        
                        print(f"\n❌ 任务失败 (task-failed)")
                        print(f"错误代码: {error_code}")
                        print(f"错误信息: {error_message}")
                        
                        # 提供友好的错误提示
                        if error_code == "TOO_LONG_SPEECH":
                            print("\n⚠️  提示: 音频时长超过 60 秒限制，请使用较短的音频文件")
                        
                        print(f"\n详细信息: {json.dumps(event, ensure_ascii=False, indent=2)}")
                        break
                        
                except json.JSONDecodeError as e:
                    print(f"⚠️  JSON 解析错误: {e}")
                    
        except websockets.exceptions.ConnectionClosed as e:
            print(f"\n⚠️  连接已关闭: {e}")
            
    def _handle_result(self, event: dict):
        """处理识别/翻译结果"""
        payload = event.get("payload", {})
        output = payload.get("output", {})
        
        print(f"Received result: {event}")
        # 识别结果
        transcription = output.get("transcription", {})
        if transcription:
            text = transcription.get("text", "")
            sentence_end = transcription.get("sentence_end", False)
            begin_time = transcription.get("begin_time", 0)
            end_time = transcription.get("end_time", 0)
            
            status = "✅ 完整" if sentence_end else "⏳ 中间"
            print(f"📝 识别结果 [{status}] ({begin_time}-{end_time}ms):")
            print(f"   {text}")
        
        # 翻译结果
        translations = output.get("translations", [])
        for translation in translations:
            lang = translation.get("lang", "")
            text = translation.get("text", "")
            sentence_end = translation.get("sentence_end", False)
            begin_time = translation.get("begin_time", 0)
            end_time = translation.get("end_time", 0)
            
            status = "✅ 完整" if sentence_end else "⏳ 中间"
            print(f"🌍 翻译结果 [{lang}] [{status}] ({begin_time}-{end_time}ms):")
            print(f"   {text}")
            
        print()  # 空行分隔
        
    async def close(self):
        """关闭连接"""
        if self.websocket:
            await self.websocket.close()
            print(f"🔌 连接已关闭")
            

async def test_with_audio_file(api_key: str, audio_file: str, target_lang: str = "en"):
    """
    测试：使用音频文件进行识别和翻译
    
    Args:
        api_key: API Key
        audio_file: 音频文件路径 (支持 WAV 或原始 PCM)
        target_lang: 目标语言
    """
    client = GummyWebSocketClient(api_key)
    
    try:
        # 1. 建立连接
        await client.connect()
        
        # 2. 启动接收消息的协程
        receive_task = asyncio.create_task(client.receive_messages())
        
        # 等待一小段时间确保连接稳定
        await asyncio.sleep(0.1)
        
        # 3. 发送 run-task 指令（增加静音检测时长以支持长音频）
        await client.send_run_task(
            target_lang=target_lang,
            source_lang="auto",
            sample_rate=16000,
            format="pcm",
            max_end_silence=10000  # 增加到10秒，避免过早结束
        )
        
        # 等待 task-started 事件
        await asyncio.sleep(0.5)
        
        # 4. 发送音频数据
        await client.send_audio_data(audio_file, chunk_size=3200)
        
        # 5. 发送 finish-task 指令
        await client.send_finish_task()
        
        # 6. 等待接收任务完成
        await receive_task
        
    except Exception as e:
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        
    finally:
        # 7. 关闭连接
        await client.close()


async def test_with_microphone(api_key: str, target_lang: str = "en", duration: int = 10):
    """
    测试：使用麦克风实时录音并识别翻译
    
    Args:
        api_key: API Key
        target_lang: 目标语言
        duration: 录音时长 (秒)
    """
    try:
        import pyaudio
    except ImportError:
        print("❌ 需要安装 pyaudio 库: pip install pyaudio")
        return
    
    client = GummyWebSocketClient(api_key)
    
    # 音频参数
    CHUNK = 3200
    FORMAT = pyaudio.paInt16
    CHANNELS = 1
    RATE = 16000
    
    try:
        # 1. 建立连接
        await client.connect()
        
        # 2. 启动接收消息的协程
        receive_task = asyncio.create_task(client.receive_messages())
        
        await asyncio.sleep(0.1)
        
        # 3. 发送 run-task 指令
        await client.send_run_task(
            target_lang=target_lang,
            source_lang="auto",
            sample_rate=RATE,
            format="pcm"
        )
        
        await asyncio.sleep(0.5)
        
        # 4. 录音并发送
        print(f"🎤 开始录音 (时长: {duration}秒)...")
        
        audio = pyaudio.PyAudio()
        stream = audio.open(
            format=FORMAT,
            channels=CHANNELS,
            rate=RATE,
            input=True,
            frames_per_buffer=CHUNK
        )
        
        frames_to_record = int(RATE / CHUNK * duration)
        
        for i in range(frames_to_record):
            data = stream.read(CHUNK)
            await client.websocket.send(data)
            
            # 显示进度
            progress = ((i + 1) / frames_to_record) * 100
            print(f"   录音进度: {progress:.1f}%", end='\r')
        
        print(f"\n✅ 录音完成!")
        
        # 关闭音频流
        stream.stop_stream()
        stream.close()
        audio.terminate()
        
        # 5. 发送 finish-task 指令
        await client.send_finish_task()
        
        # 6. 等待接收任务完成
        await receive_task
        
    except Exception as e:
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        
    finally:
        await client.close()


def main():
    """主函数"""
    print("=" * 60)
    print("  阿里云灵积 Gummy 一句话识别与翻译 WebSocket API 测试")
    print("  模型: gummy-chat-v1")
    print("=" * 60)
    print()
    
    # 从环境变量获取 API Key
    api_key = os.getenv("DASHSCOPE_API_KEY")
    if not api_key:
        print("❌ 请设置环境变量 DASHSCOPE_API_KEY")
        print("   export DASHSCOPE_API_KEY='your_api_key'")
        return
    
    print("请选择测试模式:")
    print("1. 使用音频文件测试")
    print("2. 使用麦克风实时测试")
    
    choice = input("\n请输入选项 (1/2): ").strip()
    
    if choice == "1":
        # 音频文件测试
        audio_file = input("请输入音频文件路径 (WAV 或 PCM): ").strip()
        target_lang = input("请输入目标语言 (en/ja/ko/es/fr/de, 默认 en): ").strip() or "en"
        
        asyncio.run(test_with_audio_file(api_key, audio_file, target_lang))
        
    elif choice == "2":
        # 麦克风测试
        target_lang = input("请输入目标语言 (en/ja/ko/es/fr/de, 默认 en): ").strip() or "en"
        duration = input("请输入录音时长(秒, 默认 10): ").strip()
        duration = int(duration) if duration else 10
        
        asyncio.run(test_with_microphone(api_key, target_lang, duration))
        
    else:
        print("❌ 无效的选项")


if __name__ == "__main__":
    main()
