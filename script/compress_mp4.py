#!/usr/bin/env python3
"""
MP4视频压缩脚本
遍历当前目录，找到所有MP4文件并使用ffmpeg进行压缩
"""

import os
import subprocess
import sys
from pathlib import Path


def compress_mp4(input_file):
    """
    使用ffmpeg压缩MP4文件
    
    Args:
        input_file: 输入的MP4文件路径
    
    Returns:
        bool: 压缩是否成功
    """
    # 生成临时输出文件名
    input_path = Path(input_file)
    temp_output = input_path.parent / f"{input_path.stem}_compressed{input_path.suffix}"
    
    print(f"正在压缩: {input_file}")
    
    # ffmpeg压缩命令（使用默认配置，copy模式快速重封装）
    command = [
        'ffmpeg',
        '-i', str(input_file),
        # '-c', 'copy',        # 直接复制流，不重新编码（最快）
        # '-y',                # 覆盖输出文件
        str(temp_output)
    ]
    
    try:
        # 执行ffmpeg命令
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True
        )
        
        # 检查输出文件是否创建成功
        if temp_output.exists() and temp_output.stat().st_size > 0:
            # 删除原文件
            os.remove(input_file)
            # 重命名压缩后的文件为原文件名
            temp_output.rename(input_file)
            
            print(f"✓ 压缩成功: {input_file}")
            return True
        else:
            print(f"✗ 压缩失败: {input_file} - 输出文件无效")
            if temp_output.exists():
                os.remove(temp_output)
            return False
            
    except subprocess.CalledProcessError as e:
        print(f"✗ 压缩失败: {input_file}")
        print(f"错误信息: {e.stderr.decode('utf-8', errors='ignore')}")
        # 清理临时文件
        if temp_output.exists():
            os.remove(temp_output)
        return False
    except Exception as e:
        print(f"✗ 发生错误: {input_file} - {str(e)}")
        if temp_output.exists():
            os.remove(temp_output)
        return False


def find_and_compress_mp4_files(directory='.'):
    """
    在指定目录中查找并压缩所有MP4文件
    
    Args:
        directory: 要搜索的目录，默认为当前目录
    """
    directory_path = Path(directory)
    
    # 检查ffmpeg是否可用
    try:
        subprocess.run(
            ['ffmpeg', '-version'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("错误: 未找到ffmpeg，请先安装ffmpeg")
        print("macOS安装命令: brew install ffmpeg")
        sys.exit(1)
    
    # 查找所有MP4文件
    mp4_files = list(directory_path.glob('*.mp4'))
    
    if not mp4_files:
        print(f"在目录 {directory} 中未找到MP4文件")
        return
    
    print(f"找到 {len(mp4_files)} 个MP4文件")
    print("-" * 50)
    
    success_count = 0
    fail_count = 0
    
    for mp4_file in mp4_files:
        if compress_mp4(mp4_file):
            success_count += 1
        else:
            fail_count += 1
        print("-" * 50)
    
    # 输出统计信息
    print(f"\n压缩完成!")
    print(f"成功: {success_count} 个文件")
    print(f"失败: {fail_count} 个文件")


if __name__ == '__main__':
    # 可以通过命令行参数指定目录，默认为当前目录
    target_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
    find_and_compress_mp4_files(target_dir)
