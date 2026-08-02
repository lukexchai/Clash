# Clash — macOS 代理管理脚本

一份 YAML 配置同时在 OpenWRT 和 macOS 上使用，启动时自动适配 macOS。

## 使用

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

## 目录

```
Clash/
├── clash          # 管理脚本
└── install.sh     # 部署脚本

~/Mihomo/          ← 放 YAML 配置文件
```

## 新电脑部署

```bash
git clone git@github.com:lukeopen/Clash.git
cd Clash && zsh install.sh
cp /path/to/config.yaml ~/Mihomo/
clash start
```

## 依赖

- Homebrew + `brew install mihomo`
