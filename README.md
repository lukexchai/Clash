# Clash — Mihomo 内核管理脚本

一份 YAML 配置同时在 OpenWRT / macOS / Windows 上使用，启动时自动适配平台。

## macOS

### 使用

| 命令 | 说明 |
|------|------|
| `clash` | 交互菜单 |
| `clash start` | 启动 |
| `clash stop` | 停止 |
| `clash restart` | 重启 |
| `clash reload` | 热重载 |
| `clash status` | 状态 |
| `clash link` | 源文件路径 |
| `clash cleanup` | 网络修复 |

### 部署

```bash
git clone git@github.com:lukeopen/Clash.git
cd Clash && zsh install.sh
cp /path/to/config.yaml ~/Mihomo/
clash start
```

### 依赖

- Homebrew + `brew install mihomo`

## Windows

### 使用

| 命令 | 说明 |
|------|------|
| `clash.ps1` | 交互菜单 |
| `clash.ps1 start` | 启动 (TUN 模式) |
| `clash.ps1 stop` | 停止 |
| `clash.ps1 restart` | 重启 |
| `clash.ps1 reload` | 热重载 |
| `clash.ps1 status` | 状态 |
| `clash.ps1 link` | 源文件路径 |
| `clash.ps1 cleanup` | 网络修复 |

### 部署

```powershell
git clone https://github.com/lukeopen/Clash.git
cd Clash
pwsh install.ps1
# 把 .yaml 配置文件放入 ~/Mihomo/
clash.ps1 start
```

### 要求

- Windows 11 + PowerShell 7 (`winget install Microsoft.PowerShell`)
- TUN 模式需要管理员权限（UAC 关闭时自动提权无感）

### 目录结构

```
Clash/
├── clash           # macOS 管理脚本
├── install.sh      # macOS 部署脚本
├── clash.ps1       # Windows 管理脚本
└── install.ps1     # Windows 部署脚本

~/Mihomo/           ← 放 YAML 配置文件
~/.config/mihomo/   ← 运行时数据（config.yaml / pid / log / ui）
```
