#!/bin/bash
# Python 版本兼容性修复脚本

set -e

echo "======================================="
echo "Python 环境修复工具"
echo "======================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查当前 Python 版本
PYTHON_VERSION=$(python3 --version | awk '{print $2}')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

echo -e "当前 Python 版本: ${BLUE}$PYTHON_VERSION${NC}"
echo ""

# 检查是否需要修复
if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 13 ]; then
    echo -e "${YELLOW}❌ Python 3.13+ 与 coremltools 不兼容${NC}"
    echo ""
    echo "问题: coremltools 7.x 依赖已废弃的 'imp' 模块"
    echo "解决方案: 使用 Python 3.10 或 3.11"
    echo ""
    
    # 检查是否有其他 Python 版本
    echo "📋 检查系统中的 Python 版本..."
    echo ""
    
    # 检查 python3.11
    if command -v python3.11 &> /dev/null; then
        PY311_VERSION=$(python3.11 --version)
        echo -e "${GREEN}✅ 找到 $PY311_VERSION${NC}"
        USE_PYTHON="python3.11"
    # 检查 python3.10
    elif command -v python3.10 &> /dev/null; then
        PY310_VERSION=$(python3.10 --version)
        echo -e "${GREEN}✅ 找到 $PY310_VERSION${NC}"
        USE_PYTHON="python3.10"
    else
        echo -e "${RED}❌ 未找到 Python 3.10 或 3.11${NC}"
        echo ""
        echo "请选择安装方式:"
        echo ""
        echo "方式1: 使用 Homebrew (推荐)"
        echo "  brew install python@3.11"
        echo ""
        echo "方式2: 使用 pyenv"
        echo "  brew install pyenv"
        echo "  pyenv install 3.11"
        echo "  pyenv local 3.11"
        echo ""
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}🔧 将使用 $USE_PYTHON 重新创建虚拟环境${NC}"
    echo ""
    
    # 删除旧的虚拟环境
    if [ -d "venv" ]; then
        echo "🗑️  删除旧的虚拟环境..."
        rm -rf venv
    fi
    
    # 创建新的虚拟环境
    echo "🔨 使用 $USE_PYTHON 创建虚拟环境..."
    $USE_PYTHON -m venv venv
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 升级 pip
    echo "📦 升级 pip..."
    pip install --upgrade pip
    
    # 安装依赖
    echo "📦 安装依赖包..."
    pip install -r requirements.txt
    
    echo ""
    echo -e "${GREEN}✅ 环境修复完成！${NC}"
    echo ""
    echo "下一步:"
    echo "  1. 激活环境: source venv/bin/activate"
    echo "  2. 运行转换: python convert_sensevoice_to_coreml.py"
    echo "  或直接运行: ./convert.sh"
    
else
    echo -e "${GREEN}✅ Python 版本兼容${NC}"
    echo "无需修复，可以直接运行转换脚本"
fi
