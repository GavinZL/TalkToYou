#!/bin/bash
# Quick test script for Qwen TTS API

echo "=========================================="
echo "Qwen3-TTS-Flash API 快速测试"
echo "=========================================="
echo ""

# 检查 API Key
if [ -z "$DASHSCOPE_API_KEY" ]; then
    echo "❌ 错误: 未设置 DASHSCOPE_API_KEY 环境变量"
    echo ""
    echo "请先设置 API Key:"
    echo "  export DASHSCOPE_API_KEY='sk-your-api-key'"
    echo ""
    echo "或者在当前终端临时设置:"
    read -p "请输入你的 API Key: " api_key
    export DASHSCOPE_API_KEY="$api_key"
fi

echo "🔑 API Key: ${DASHSCOPE_API_KEY:0:10}..."
echo ""

# 检查 Python 依赖
echo "📦 检查依赖..."
if ! python3 -c "import requests" 2>/dev/null; then
    echo "⚠️  缺少 requests 库，正在安装..."
    pip3 install requests
fi

echo "✅ 依赖检查完成"
echo ""

# 运行测试
echo "🚀 开始测试..."
echo ""

cd "$(dirname "$0")"
python3 test/test_qwen_tts.py

echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
