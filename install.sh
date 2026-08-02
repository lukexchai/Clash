#!/bin/zsh
# ═══════════════════════════════════════════════════════════
#   Mihomo Kernel Manager — macOS 一键部署脚本
#   用法: curl -fsSL https://xxx/install.sh | zsh
#   或本地: zsh install.sh
# ═══════════════════════════════════════════════════════════

set -e

BOLD='\033[1m'
GREEN='\033[0;32m'
BOLD_GREEN='\033[1;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo ""
echo "  ${PURPLE}╭──────────────────────────────────────╮${NC}"
echo "  ${PURPLE}│${NC}  ${BOLD}Mihomo Kernel Manager 部署脚本${NC}     ${PURPLE}│${NC}"
echo "  ${PURPLE}╰──────────────────────────────────────╯${NC}"
echo ""

# ─── 前置检查 ───
echo "  ${BOLD}──  系统检查  ──${NC}"

# Homebrew
echo -n "  ${CYAN}▶${NC} Homebrew ... "
if command -v brew &>/dev/null; then
    echo "${GREEN}已安装${NC}"
else
    echo "${YELLOW}未安装，正在安装...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# mihomo 内核
echo -n "  ${CYAN}▶${NC} mihomo 内核 ... "
if command -v mihomo &>/dev/null; then
    echo "${GREEN}已安装 ($(mihomo -v 2>/dev/null | head -1))${NC}"
else
    echo "${YELLOW}未安装，正在安装...${NC}"
    brew install mihomo
    echo "  ${GREEN}✓ mihomo 安装完成${NC}"
fi

# ─── 部署 clash 管理脚本 ───
echo ""
echo "  ${BOLD}──  部署管理脚本  ──${NC}"

SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)/clash"
SCRIPT_DST="/opt/homebrew/bin/clash"

if [[ -f "$SCRIPT_SRC" ]]; then
    echo -n "  ${CYAN}▶${NC} 安装 clash 脚本 ... "
    sudo cp "$SCRIPT_SRC" "$SCRIPT_DST"
    sudo chmod +x "$SCRIPT_DST"
    echo "${GREEN}已部署 → $SCRIPT_DST${NC}"
else
    echo "  ${RED}✗ 未找到 clash 脚本文件${NC}"
    echo "  ${YELLOW}请确保 install.sh 和 clash 在同一目录${NC}"
    exit 1
fi

# ─── 创建必要目录 ───
echo ""
echo "  ${BOLD}──  初始化目录  ──${NC}"

echo -n "  ${CYAN}▶${NC} 配置目录 (~/.config/mihomo) ... "
mkdir -p "$HOME/.config/mihomo"
echo "${GREEN}已创建${NC}"

echo -n "  ${CYAN}▶${NC} 源文件目录 (~/Mihomo) ... "
mkdir -p "$HOME/Mihomo"
echo "${GREEN}已创建${NC}"

# ─── 完成提示 ───
echo ""
echo "  ${PURPLE}╭──────────────────────────────────────╮${NC}"
echo "  ${PURPLE}│${NC}  ${BOLD_GREEN}✅ 部署完成！${NC}                        ${PURPLE}│${NC}"
echo "  ${PURPLE}╰──────────────────────────────────────╯${NC}"
echo ""
echo "  接下来："
echo "  ${CYAN}  1.${NC} 把你的 .yaml 配置文件放入 ${BOLD}~/Mihomo/${NC}"
echo "  ${CYAN}  2.${NC} 运行 ${BOLD}clash start${NC} 启动"
echo "  ${CYAN}  3.${NC} 运行 ${BOLD}clash${NC} 进入交互菜单"
echo ""
echo "  更多命令: ${BOLD}clash help${NC}"
echo ""
