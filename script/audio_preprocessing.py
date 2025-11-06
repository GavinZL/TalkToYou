#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音频预处理工具
用于将音频转换为 SenseVoice 模型所需的特征格式
"""

import numpy as np


def load_audio(audio_path, sample_rate=16000):
    """
    加载音频文件
    
    Args:
        audio_path: 音频文件路径
        sample_rate: 采样率
    
    Returns:
        numpy array: 音频数据
    """
    try:
        import librosa
        audio, sr = librosa.load(audio_path, sr=sample_rate)
        return audio
    except ImportError:
        print("请安装 librosa: pip install librosa")
        return None


def compute_fbank(audio, sample_rate=16000, n_mels=80):
    """
    计算 Mel 频谱特征 (FBank)
    
    Args:
        audio: 音频数据 (numpy array)
        sample_rate: 采样率
        n_mels: Mel 滤波器数量
    
    Returns:
        numpy array: FBank 特征 (time_steps, n_mels)
    """
    try:
        import librosa
        
        # 计算 mel spectrogram
        mel_spec = librosa.feature.melspectrogram(
            y=audio,
            sr=sample_rate,
            n_fft=512,
            hop_length=160,  # 10ms at 16kHz
            win_length=400,  # 25ms at 16kHz
            n_mels=n_mels,
            fmin=0,
            fmax=8000
        )
        
        # 转换为 dB
        log_mel = librosa.power_to_db(mel_spec, ref=np.max)
        
        # 转置为 (time, freq)
        fbank = log_mel.T
        
        return fbank
        
    except ImportError:
        print("请安装 librosa: pip install librosa")
        return None


def normalize_fbank(fbank):
    """
    归一化 FBank 特征
    
    Args:
        fbank: FBank 特征
    
    Returns:
        numpy array: 归一化后的特征
    """
    mean = np.mean(fbank, axis=0, keepdims=True)
    std = np.std(fbank, axis=0, keepdims=True)
    normalized = (fbank - mean) / (std + 1e-5)
    return normalized


def preprocess_audio(audio_path, sample_rate=16000, n_mels=80):
    """
    完整的音频预处理流程
    
    Args:
        audio_path: 音频文件路径
        sample_rate: 采样率
        n_mels: Mel 滤波器数量
    
    Returns:
        numpy array: 预处理后的特征
    """
    # 1. 加载音频
    audio = load_audio(audio_path, sample_rate)
    if audio is None:
        return None
    
    # 2. 计算 FBank
    fbank = compute_fbank(audio, sample_rate, n_mels)
    if fbank is None:
        return None
    
    # 3. 归一化
    normalized = normalize_fbank(fbank)
    
    return normalized


def test_preprocessing(audio_path):
    """测试音频预处理"""
    print(f"处理音频: {audio_path}")
    
    features = preprocess_audio(audio_path)
    
    if features is not None:
        print(f"特征维度: {features.shape}")
        print(f"特征范围: [{features.min():.2f}, {features.max():.2f}]")
        print("✅ 预处理成功")
    else:
        print("❌ 预处理失败")


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("用法: python audio_preprocessing.py <audio_file>")
        sys.exit(1)
    
    test_preprocessing(sys.argv[1])
