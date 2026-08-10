#!/usr/bin/env pwsh
# ═══════════════════════════════════════════════════════════
#   Mihomo Kernel Manager — Windows 一键部署脚本
#   用法: pwsh install.ps1
# ═══════════════════════════════════════════════════════════

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ─── 版本 ───
$MihomoVersion = "v1.19.15"
$WintunVersion  = "0.14.1"

# ─── 路径 ───
$InstallDir = "$env:LOCALAPPDATA\Programs\mihomo"
$ConfigDir  = "$env:USERPROFILE\.config\mihomo"
$SourceDir  = "$env:USERPROFILE\Mihomo"
$ScriptSrc  = Join-Path $PSScriptRoot "clash.ps1"
$ScriptDst  = Join-Path $InstallDir "clash.ps1"

# ─── 架构检测 ───
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }

# ─── 下载地址 ───
$mihomoAsset = if ($arch -eq "arm64") {
    "mihomo-windows-arm64-$MihomoVersion.zip"
} else {
    "mihomo-windows-amd64-v1-$MihomoVersion.zip"
}
$mihomoUrl = "https://github.com/MetaCubeX/mihomo/releases/download/$MihomoVersion/$mihomoAsset"
$wintunUrl = "https://www.wintun.net/builds/wintun-$WintunVersion.zip"

# ─── 颜色 ───
$e = [char]27
$Bold  = "$e[1m"
$Green = "$e[0;32m"; $BoldGreen = "$e[1;32m"
$Red   = "$e[0;31m"
$Yellow= "$e[0;33m"
$Cyan  = "$e[0;36m"
$Purple= "$e[0;35m"
$NC    = "$e[0m"

function W-Step  { Write-Host "  ${Cyan}▶${NC} $args" }
function W-Done  { Write-Host "  ${Green}✓${NC} $args" }
function W-Fail  { Write-Host "  ${Red}✗${NC} $args" }
function W-Note  { Write-Host "  ${Yellow}⚠${NC} $args" }

# ─── 横幅 ───
Write-Host ""
Write-Host "  ${Purple}╭──────────────────────────────────────╮${NC}"
Write-Host "  ${Purple}│${NC}  ${Bold}Mihomo Kernel Manager 部署脚本${NC}     ${Purple}│${NC}"
Write-Host "  ${Purple}╰──────────────────────────────────────╯${NC}"
Write-Host ""

# ─── 前置检查 ───
Write-Host "  ${Bold}──  系统检查  ──${NC}"
Write-Host ""

# PowerShell 版本
W-Step "PowerShell 版本 ... "
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 7) {
    Write-Host "${Green}已安装 ($psVersion)${NC}"
} else {
    Write-Host "${Yellow}版本过低 ($psVersion)，需要 7.0+${NC}"
    Write-Host "  请运行: winget install Microsoft.PowerShell"
    exit 1
}

# 创建目录
Write-Host ""
Write-Host "  ${Bold}──  初始化目录  ──${NC}"
Write-Host ""

W-Step "安装目录 ($InstallDir) ... "
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
W-Done "已创建"

W-Step "配置目录 ($ConfigDir) ... "
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
W-Done "已创建"

W-Step "源文件目录 ($SourceDir) ... "
New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null
W-Done "已创建"

# ─── 下载 mihomo 内核 ───
Write-Host ""
Write-Host "  ${Bold}──  下载 mihomo 内核  ──${NC}"
Write-Host ""

$mihomoExe = Join-Path $InstallDir "mihomo.exe"
$needDownload = $true
if (Test-Path $mihomoExe) {
    W-Note "mihomo.exe 已存在"
    $ans = Read-Host "  重新下载? (y/n)"
    if ($ans -ne 'y') { $needDownload = $false }
}

if ($needDownload) {
    W-Step "架构: $arch"
    W-Step "版本: $MihomoVersion"
    Write-Host "  下载中 ..."

    $tempDir = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mihomo-install-$(Get-Random)")) -Force
    $mihomoZip = Join-Path $tempDir.FullName $mihomoAsset

    try {
        Invoke-WebRequest -Uri $mihomoUrl -OutFile $mihomoZip -UseBasicParsing
    } catch {
        W-Fail "下载失败: $_"
        W-Note "手动下载: $mihomoUrl"
        W-Note "解压 mihomo.exe 到: $InstallDir"
        exit 1
    }

    # 解压
    W-Step "解压中 ..."
    Expand-Archive -Path $mihomoZip -DestinationPath $tempDir.FullName -Force

    # 找到 mihomo.exe 并复制
    $extracted = Get-ChildItem $tempDir.FullName -Recurse -Filter "mihomo.exe" | Select-Object -First 1
    if ($extracted) {
        Copy-Item $extracted.FullName $mihomoExe -Force
        W-Done "mihomo.exe 已安装"
    } else {
        W-Fail "未在压缩包中找到 mihomo.exe"
        exit 1
    }

    # 清理临时文件
    Remove-Item $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

# ─── 下载 wintun.dll ───
Write-Host ""
Write-Host "  ${Bold}──  下载 wintun.dll  ──${NC}"
Write-Host ""

$wintunDll = Join-Path $InstallDir "wintun.dll"
$needWintun = $true
if (Test-Path $wintunDll) {
    W-Note "wintun.dll 已存在"
    $ans = Read-Host "  重新下载? (y/n)"
    if ($ans -ne 'y') { $needWintun = $false }
}

if ($needWintun) {
    W-Step "版本: $WintunVersion"
    Write-Host "  下载中 ..."

    $tempDir = New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "wintun-install-$(Get-Random)")) -Force
    $wintunZip = Join-Path $tempDir.FullName "wintun.zip"

    try {
        Invoke-WebRequest -Uri $wintunUrl -OutFile $wintunZip -UseBasicParsing
    } catch {
        W-Fail "下载失败: $_"
        W-Note "手动下载: $wintunUrl"
        W-Note "提取 wintun\bin\$arch\wintun.dll 到: $InstallDir"
        exit 1
    }

    # 解压
    W-Step "解压中 ..."
    Expand-Archive -Path $wintunZip -DestinationPath $tempDir.FullName -Force

    # 找到对应架构的 wintun.dll
    $wintunSrc = Join-Path $tempDir.FullName "wintun\bin\$arch\wintun.dll"
    if (Test-Path $wintunSrc) {
        Copy-Item $wintunSrc $wintunDll -Force
        W-Done "wintun.dll 已安装 ($arch)"
    } else {
        W-Fail "未找到 $arch 架构的 wintun.dll"
        exit 1
    }

    # 清理临时文件
    Remove-Item $tempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

# ─── 部署 clash.ps1 ───
Write-Host ""
Write-Host "  ${Bold}──  部署管理脚本  ──${NC}"
Write-Host ""

if (Test-Path $ScriptSrc) {
    W-Step "安装 clash.ps1 ... "
    Copy-Item $ScriptSrc $ScriptDst -Force
    W-Done "已部署 → $ScriptDst"
} else {
    W-Fail "未找到 clash.ps1（请确保 install.ps1 和 clash.ps1 在同一目录）"
    exit 1
}

# ─── 添加到 PATH ───
Write-Host ""
Write-Host "  ${Bold}──  配置 PATH  ──${NC}"
Write-Host ""

$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -and $userPath.Split(';') -contains $InstallDir) {
    W-Done "PATH 中已存在: $InstallDir"
} else {
    W-Step "添加到用户 PATH ... "
    $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    W-Done "已添加: $InstallDir"
    W-Note "请重新打开终端使 PATH 生效"
}

# ─── 完成 ───
Write-Host ""
Write-Host "  ${Purple}╭──────────────────────────────────────╮${NC}"
Write-Host "  ${Purple}│${NC}  ${BoldGreen}✅ 部署完成！${NC}                        ${Purple}│${NC}"
Write-Host "  ${Purple}╰──────────────────────────────────────╯${NC}"
Write-Host ""
Write-Host "  接下来："
Write-Host "  ${Cyan}  1.${NC} 把你的 .yaml 配置文件放入 ${Bold}$SourceDir${NC}"
Write-Host "  ${Cyan}  2.${NC} 重新打开终端，运行 ${Bold}clash.ps1 start${NC} 启动"
Write-Host "  ${Cyan}  3.${NC} 运行 ${Bold}clash.ps1${NC} 进入交互菜单"
Write-Host ""
Write-Host "  更多命令: ${Bold}clash.ps1 help${NC}"
Write-Host ""
