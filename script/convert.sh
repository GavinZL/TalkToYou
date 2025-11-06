#!/bin/bash
# SenseVoice 模型转换一键脚本

set -e  # 遇到错误立即退出

echo "======================================="
echo "SenseVoice 模型转换工具"
echo "======================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 Python 版本
echo "📋 检查 Python 环境..."
if ! command -v python3.11 &> /dev/null; then
    echo -e "${RED}❌ 未找到 Python 3，请先安装 Python 3.8+${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3.11 --version | awk '{print $2}')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

echo -e "${GREEN}✅ Python 版本: $PYTHON_VERSION${NC}"

# 检查 Python 版本是否兼容
if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 13 ]; then
    echo -e "${YELLOW}⚠️  警告: Python 3.13+ 可能与 coremltools 不兼容${NC}"
    echo -e "${YELLOW}建议使用 Python 3.10 或 3.11${NC}"
    echo ""
    echo "您可以:"
    echo "  1. 安装 Python 3.11: brew install python@3.11"
    echo "  2. 使用 pyenv 管理版本: pyenv install 3.11"
    echo "  3. 或者继续尝试 (可能失败)"
    echo ""
    read -p "是否继续? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 1
    fi
fi
echo ""

# 检查是否在 script 目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 创建虚拟环境（可选）
if [ ! -d "venv" ]; then
    echo "🔧 创建 Python 虚拟环境..."
    python3.11 -m venv venv
    echo -e "${GREEN}✅ 虚拟环境创建成功${NC}"
    echo ""
fi

# 激活虚拟环境
echo "🔌 激活虚拟环境..."
source venv/bin/activate
echo ""

# 安装依赖
echo "📦 安装 Python 依赖包..."
echo -e "${YELLOW}这可能需要几分钟时间...${NC}"
pip install --upgrade pip
pip install -r requirements.txt
echo -e "${GREEN}✅ 依赖安装完成${NC}"
echo ""

# 运行转换脚本
echo "🚀 开始转换模型..."
echo ""
python3.11 convert_sensevoice_to_coreml.py

# 检查转换结果
if [ -d "coreml_models" ]; then
    echo ""
    echo "======================================="
    echo -e "${GREEN}✅ 转换完成！${NC}"
    echo "======================================="
    echo ""
    echo "生成的文件："
    ls -lh coreml_models/
    echo ""
    echo "📱 下一步："
    echo "  1. 打开 Xcode 项目"
    echo "  2. 将 coreml_models/SenseVoice.mlmodel 拖入项目"
    echo "  3. 确保文件在 'Copy Bundle Resources' 中"
    echo ""
else
    echo ""
    echo -e "${RED}❌ 转换失败，请查看上方错误信息${NC}"
    exit 1
fi
