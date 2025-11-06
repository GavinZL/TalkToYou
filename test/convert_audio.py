#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音频格式转换工具
将音频转换为 Gummy API 要求的格式：单声道, 16kHz, 16-bit WAV
"""

import wave
import sys
import os
import struct


def convert_to_mono(input_file: str, output_file: str = None):
    """
    将立体声音频转换为单声道
    
    Args:
        input_file: 输入的 WAV 文件路径
        output_file: 输出的 WAV 文件路径（可选）
    """
    if output_file is None:
        name, ext = os.path.splitext(input_file)
        output_file = f"{name}_mono{ext}"
    
    print(f"正在转换: {input_file}")
    
    with wave.open(input_file, 'rb') as wf_in:
        # 获取音频参数
        channels = wf_in.getnchannels()
        sample_width = wf_in.getsampwidth()
        framerate = wf_in.getframerate()
        nframes = wf_in.getnframes()
        
        print(f"输入格式: {channels}声道, {sample_width*8}bit, {framerate}Hz, {nframes/framerate:.1f}秒")
        
        if channels == 1:
            print("已经是单声道，无需转换")
            return input_file
        
        # 读取所有帧
        frames = wf_in.readframes(nframes)
        
        # 转换为单声道（取平均值）
        if sample_width == 2:  # 16-bit
            # 解包为采样点
            samples = struct.unpack(f'<{nframes * channels}h', frames)
            
            # 平均多个声道
            mono_samples = []
            for i in range(0, len(samples), channels):
                avg = sum(samples[i:i+channels]) // channels
                mono_samples.append(avg)
            
            # 重新打包
            mono_frames = struct.pack(f'<{len(mono_samples)}h', *mono_samples)
        else:
            raise ValueError(f"不支持的采样宽度: {sample_width} 字节")
        
        # 写入单声道文件
        with wave.open(output_file, 'wb') as wf_out:
            wf_out.setnchannels(1)
            wf_out.setsampwidth(sample_width)
            wf_out.setframerate(framerate)
            wf_out.writeframes(mono_frames)
        
        print(f"输出格式: 1声道, {sample_width*8}bit, {framerate}Hz, {len(mono_samples)/framerate:.1f}秒")
        print(f"✅ 转换完成: {output_file}")
        
        return output_file


def resample_audio(input_file: str, target_rate: int = 16000, output_file: str = None):
    """
    重采样音频（简单实现，建议使用 ffmpeg 或 librosa）
    
    Args:
        input_file: 输入文件
        target_rate: 目标采样率
        output_file: 输出文件
    """
    if output_file is None:
        name, ext = os.path.splitext(input_file)
        output_file = f"{name}_{target_rate}hz{ext}"
    
    try:
        import numpy as np
        from scipy import signal
        
        print(f"正在重采样: {input_file} -> {target_rate}Hz")
        
        with wave.open(input_file, 'rb') as wf_in:
            channels = wf_in.getnchannels()
            sample_width = wf_in.getsampwidth()
            framerate = wf_in.getframerate()
            nframes = wf_in.getnframes()
            
            if framerate == target_rate:
                print(f"采样率已经是 {target_rate}Hz，无需重采样")
                return input_file
            
            # 读取音频数据
            frames = wf_in.readframes(nframes)
            
            if sample_width == 2:
                samples = np.frombuffer(frames, dtype=np.int16)
            else:
                raise ValueError(f"不支持的采样宽度: {sample_width}")
            
            # 如果是多声道，reshape
            if channels > 1:
                samples = samples.reshape(-1, channels)
            
            # 重采样
            num_samples = int(len(samples) * target_rate / framerate)
            resampled = signal.resample(samples, num_samples)
            
            # 转换回 int16
            resampled = resampled.astype(np.int16)
            
            # 写入文件
            with wave.open(output_file, 'wb') as wf_out:
                wf_out.setnchannels(channels)
                wf_out.setsampwidth(sample_width)
                wf_out.setframerate(target_rate)
                wf_out.writeframes(resampled.tobytes())
            
            print(f"✅ 重采样完成: {output_file}")
            return output_file
            
    except ImportError:
        print("⚠️  重采样需要 numpy 和 scipy 库")
        print("   建议使用 ffmpeg 进行转换:")
        print(f"   ffmpeg -i {input_file} -ar {target_rate} -ac 1 {output_file}")
        return None


def main():
    """主函数"""
    if len(sys.argv) < 2:
        print("用法: python convert_audio.py <input_file> [output_file]")
        print()
        print("示例:")
        print("  python convert_audio.py input.wav")
        print("  python convert_audio.py input.wav output_mono.wav")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    if not os.path.exists(input_file):
        print(f"❌ 文件不存在: {input_file}")
        sys.exit(1)
    
    # 转换为单声道
    result = convert_to_mono(input_file, output_file)
    
    print()
    print("转换完成！现在可以使用转换后的文件进行测试了。")


if __name__ == "__main__":
    main()
