#!/bin/bash
# Gummy WebSocket API 测试启动脚本

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
source venv/bin/activate

# 安装依赖
echo "检查依赖..."
pip install -q websockets==11.0.3

# 检查 API Key
if [ -z "$DASHSCOPE_API_KEY" ]; then
    echo "⚠️  警告: 未设置 DASHSCOPE_API_KEY 环境变量"
    echo "请运行: export DASHSCOPE_API_KEY='your_api_key'"
    echo ""
fi

# 运行测试
echo "启动测试程序..."
python test_gummy_websocket.py
