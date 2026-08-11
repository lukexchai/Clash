#!/usr/bin/env pwsh
# ═══════════════════════════════════════════════════════════
#   Mihomo Kernel Manager — Windows
#   clash.ps1 <command>   |   clash.ps1 (交互菜单)   |   clash.ps1 help
# ═══════════════════════════════════════════════════════════

# ─── 路径变量 ───
$ConfigDir  = "$env:USERPROFILE\.config\mihomo"
$ConfigFile = "$ConfigDir\config.yaml"
$PidFile    = "$ConfigDir\mihomo.pid"
$LogFile    = "$ConfigDir\mihomo.log"
$ErrLogFile = "$ConfigDir\mihomo.err.log"
$LinkFile   = "$ConfigDir\source.txt"
$SourceDir  = "$env:USERPROFILE\Mihomo"
$MixedPort  = 7890
$ApiPort    = 9090

if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }

# ─── 颜色 ───
$e = [char]27
$Bold       = "$e[1m";   $Dim        = "$e[2m"
$Green      = "$e[0;32m"; $BoldGreen  = "$e[1;32m"
$Red        = "$e[0;31m"; $BoldRed    = "$e[1;31m"
$Yellow     = "$e[0;33m"; $BoldYellow = "$e[1;33m"
$Blue       = "$e[0;34m"; $BoldBlue   = "$e[1;34m"
$Purple     = "$e[0;35m"; $BoldPurple = "$e[1;35m"
$Cyan       = "$e[0;36m"; $BoldCyan   = "$e[1;36m"
$NC         = "$e[0m"
$SEP        = "$Dim$('─' * 42)$NC"

# ─── 输出辅助 ───
function W-Info  { Write-Host "  ${Cyan}ℹ${NC} $args" }
function W-Ok    { Write-Host "  ${Green}✓${NC} $args" }
function W-Warn  { Write-Host "  ${Yellow}⚠${NC} $args" }
function W-Err   { Write-Host "  ${Red}✗${NC} $args" }
function W-Dim   { Write-Host "  ${Dim}$args${NC}" }
function W-Section { Write-Host ""; Write-Host "  ${Bold}── $args ──${NC}" }

# ─── mihomo 二进制查找 ───
function Get-MihomoBin {
    $cmd = Get-Command mihomo -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $paths = @(
        "$env:USERPROFILE\scoop\apps\mihomo\current\mihomo.exe",
        "$env:USERPROFILE\Mihomo\mihomo.exe",
        "$env:LOCALAPPDATA\Programs\mihomo\mihomo.exe",
        "$env:ProgramFiles\mihomo\mihomo.exe"
    )
    foreach ($p in $paths) { if (Test-Path $p) { return $p } }
    return $null
}

$Script:MihomoBin = Get-MihomoBin

# ─── wintun.dll 检测 ───
function Test-Wintun {
    if (-not $Script:MihomoBin) { return $false }
    $dir = Split-Path $Script:MihomoBin -Parent
    return (Test-Path (Join-Path $dir "wintun.dll"))
}

# ─── 管理员检测 ───
function Test-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($current)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ─── 运行状态 ───
function Test-Running {
    if (-not (Test-Path $PidFile)) { return $false }
    $procId = [System.IO.File]::ReadAllText($PidFile).Trim()
    if (-not $procId) { return $false }
    $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
    return ($null -ne $proc)
}

# ─── 源文件自动检测 ───
function Get-AutoDetectSource {
    if (Test-Path $LinkFile) {
        $linked = [System.IO.File]::ReadAllText($LinkFile).Trim()
        if (Test-Path $linked) { return $linked }
        W-Warn "链接文件不存在: $linked，尝试自动检测..."
    }
    if (Test-Path $SourceDir) {
        $latest = Get-ChildItem -Path $SourceDir -File |
            Where-Object { $_.Extension -in '.yaml', '.yml' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($latest) { return $latest.FullName }
    }
    return $null
}

# ─── Windows 配置适配（不改源文件）───
function Invoke-WinAdaptConfig {
    param([string]$Src)

    if (-not $Src) { $Src = Get-AutoDetectSource }
    if (-not $Src -or -not (Test-Path $Src)) {
        W-Err "未找到 YAML 配置文件"
        W-Dim "请把 .yaml 放到 $SourceDir，或用: clash.ps1 link C:\path\to\file.yaml"
        return $false
    }

    Write-Host -NoNewline "  适配 Windows 配置 ... "
    Copy-Item $Src $ConfigFile -Force
    $content = [System.IO.File]::ReadAllText($ConfigFile)

    # Windows 兼容修复（与 macOS 版逻辑一致）
    $content = $content -replace '(?m)^\s*device:\s*nikki\s*\r?\n', ''
    $content = $content -replace '(?m)^\s*auto-redirect:\s*true\s*\r?\n', ''
    $content = $content -replace '(?m)^(\s*stack:)\s*system', '$1 gvisor'
    $content = $content -replace '  - tcp://', '  - '
    $content = $content -replace '  - udp://', '  - '

    [System.IO.File]::WriteAllText($ConfigFile, $content, [System.Text.UTF8Encoding]::new($false))

    Write-Host "${Green}✓${NC}"
    W-Dim "源文件   $Src"
    W-Dim "适配后   $ConfigFile"
    return $true
}

# ─── 管理面板 ───
function Get-UiUrl {
    $uiDir = "$ConfigDir\ui"
    if (Test-Path $uiDir) {
        $dash = Get-ChildItem $uiDir -Directory | Sort-Object Name | Select-Object -First 1
        if ($dash) { return "http://127.0.0.1:$ApiPort/ui/$($dash.Name)/" }
    }
    return "http://127.0.0.1:$ApiPort/ui"
}

function Update-UiIndex {
    $uiDir = "$ConfigDir\ui"
    if (-not (Test-Path $uiDir)) { return }
    $dash = Get-ChildItem $uiDir -Directory | Sort-Object Name | Select-Object -First 1
    if (-not $dash) { return }
    $indexFile = "$uiDir\index.html"
    if (-not (Test-Path $indexFile)) {
        $html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=./$($dash.Name)/">
<title>Mihomo Dashboard</title>
</head>
<body>
<p>正在打开面板 <a href="./$($dash.Name)/">$($dash.Name)</a> ...</p>
</body>
</html>
"@
        [System.IO.File]::WriteAllText($indexFile, $html, [System.Text.UTF8Encoding]::new($false))
        W-Info "已生成面板首页跳转: $indexFile"
    }
}

# ─── 残留网络状态检测 ───
function Test-NetworkLeftovers {
    # 1. 残留 mihomo 进程
    if (Get-Process -Name mihomo -ErrorAction SilentlyContinue) { return $true }

    # 2. 残留 wintun 网卡
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -like "*Wintun*" -or $_.InterfaceDescription -like "*Mihomo*" }
    if ($adapters) { return $true }

    # 3. 残留路由（网关落在 198.18.x fake-IP 段）
    $routes = Get-NetRoute -ErrorAction SilentlyContinue | Where-Object { $_.NextHop -match '^198\.18\.' }
    if ($routes) { return $true }

    # 4. DNS 劫持（指向 127.0.0.1 或 198.18.x）
    $dns = Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Where-Object {
        $_.ServerAddresses -contains "127.0.0.1" -or
        ($_.ServerAddresses | Where-Object { $_ -match "^198\.18\." })
    }
    if ($dns) { return $true }

    return $false
}

# ─── 网络恢复（TUN/路由/DNS 全面清理）───
function Invoke-NetworkRestore {
    param([bool]$ShowProgress = $true)

    if ($ShowProgress) { W-Section "网络恢复" }

    # 1. 清理残留 mihomo 进程
    $procs = Get-Process -Name mihomo -ErrorAction SilentlyContinue
    if ($procs) {
        if ($ShowProgress) { W-Warn "发现残留进程，正在清理..." }
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }

    # 2. 清理残留 wintun 网卡 + 其上的全部路由
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -like "*Wintun*" -or $_.InterfaceDescription -like "*Mihomo*" }
    foreach ($adapter in $adapters) {
        if ($ShowProgress) { Write-Host -NoNewline "  清理残留 TUN $($adapter.Name) ... " }
        # 删除该网卡上的所有路由（不限网段），避免黑洞残留
        Get-NetRoute -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue |
            Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
        netsh interface set interface "$($adapter.Name)" admin=disable 2>$null | Out-Null
        if ($ShowProgress) { Write-Host "${Green}✓${NC}" }
    }

    # 3. 清理残留路由（网关落在 198.18.x fake-IP 段的，无条件删除）
    $mihomoRoutes = Get-NetRoute -ErrorAction SilentlyContinue |
        Where-Object { $_.NextHop -match '^198\.18\.' }
    foreach ($route in $mihomoRoutes) {
        Remove-NetRoute -DestinationPrefix $route.DestinationPrefix -NextHop $route.NextHop -Confirm:$false -ErrorAction SilentlyContinue
    }

    # 4. 刷新 DNS 缓存
    if ($ShowProgress) { Write-Host -NoNewline "  刷新 DNS 缓存 ... " }
    ipconfig /flushdns 2>$null | Out-Null
    if ($ShowProgress) { Write-Host "${Green}✓${NC}" }

    # 5. 还原系统 DNS（如果被 mihomo 指到 127.0.0.1 / 198.18.x）
    $dnsHijacked = Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Where-Object {
        $_.ServerAddresses -contains "127.0.0.1" -or
        ($_.ServerAddresses | Where-Object { $_ -match "^198\.18\." })
    }
    if ($dnsHijacked) {
        if ($ShowProgress) { Write-Host -NoNewline "  还原系统 DNS ... " }
        foreach ($adapter in $dnsHijacked) {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
        }
        ipconfig /flushdns 2>$null | Out-Null
        if ($ShowProgress) { Write-Host "${Green}✓${NC}" }
    }

    if ($ShowProgress) {
        Write-Host ""
        W-Ok "网络已恢复"
    }
}

# ─── 网络诊断 ───
function Invoke-NetworkHealthCheck {
    $issues = $false
    W-Section "网络诊断"

    # DNS 解析
    try {
        $null = Resolve-DnsName baidu.com -ErrorAction Stop
        W-Ok "DNS 解析正常 (baidu.com)"
    } catch {
        W-Err "DNS 解析失败"
        $issues = $true
    }

    # 外网连通
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send("8.8.8.8", 2000)
        if ($reply.Status -eq 'Success') {
            W-Ok "外网连通 (8.8.8.8)"
        } else {
            W-Err "外网不可达"
            $issues = $true
        }
    } catch {
        W-Err "外网不可达"
        $issues = $true
    }

    # TUN 接口检查
    $wintunAdapters = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -like "*Wintun*" -or $_.InterfaceDescription -like "*Mihomo*" }
    if (-not $wintunAdapters) {
        W-Ok "无残留 TUN 接口"
    } else {
        W-Warn "发现 $($wintunAdapters.Count) 个残留 TUN 接口"
        $issues = $true
    }

    if ($issues) {
        W-Warn "网络可能有异常，试试: clash.ps1 cleanup"
    } else {
        W-Ok "网络一切正常"
    }
}

# ─── 启动 ───
function Invoke-CmdStart {
    param([string]$Src)

    $doAdapt = $true
    if ($Src) {
        $linked = if (Test-Path $LinkFile) { [System.IO.File]::ReadAllText($LinkFile).Trim() } else { "" }
        if ($Src -eq $ConfigFile -or $Src -eq $linked) { $doAdapt = $false }
    }
    if (-not $Src) { $Src = Get-AutoDetectSource }

    if ($doAdapt -and $Src -ne $ConfigFile) {
        $result = Invoke-WinAdaptConfig $Src
        if (-not $result) { return }
    } elseif (-not (Test-Path $ConfigFile)) {
        W-Err "配置文件不存在: $ConfigFile"
        W-Dim "试试: clash.ps1 link C:\path\to\your.yaml"
        return
    }

    if (Test-Running) {
        W-Warn "mihomo 已经在运行了"
        return
    }

    # 检查 mihomo 二进制
    if (-not $Script:MihomoBin) {
        W-Err "未找到 mihomo.exe"
        W-Dim "请先运行 install.ps1 安装，或手动下载 mihomo.exe"
        return
    }

    # 检查 wintun.dll
    if (-not (Test-Wintun)) {
        W-Warn "未找到 wintun.dll（TUN 模式需要）"
        W-Dim "请将 wintun.dll 放在 mihomo.exe 同目录，或运行 install.ps1"
        return
    }

    # 启动前清理残留
    if (Test-NetworkLeftovers) {
        Write-Host ""
        W-Info "检测到上次残留网络状态，先清理 ..."
        Invoke-NetworkRestore $false
    }

    Write-Host ""
    Write-Host -NoNewline "  启动中 ... "

    # 清理旧日志
    Remove-Item $LogFile -Force -ErrorAction SilentlyContinue
    Remove-Item $ErrLogFile -Force -ErrorAction SilentlyContinue

    # 启动 mihomo（隐藏窗口，重定向输出）
    $argStr = "-d `"$ConfigDir`" -f `"$ConfigFile`""
    $proc = Start-Process -FilePath $Script:MihomoBin `
        -ArgumentList $argStr `
        -WindowStyle Hidden `
        -RedirectStandardOutput $LogFile `
        -RedirectStandardError $ErrLogFile `
        -PassThru

    [System.IO.File]::WriteAllText($PidFile, $proc.Id.ToString())
    Start-Sleep -Seconds 1

    if (Test-Running) {
        Write-Host "${Green}✓${NC} 已就绪"
        Update-UiIndex
        Write-Host ""
        Write-Host "  ${Dim}代理端口   ${NC}${Cyan}127.0.0.1:$MixedPort${NC}  ${Dim}(HTTP/SOCKS5)${NC}"
        Write-Host "  ${Dim}API 端口   ${NC}${Cyan}127.0.0.1:$ApiPort${NC}"
        Write-Host "  ${Dim}管理面板   ${NC}${Cyan}$(Get-UiUrl)${NC}"
        Write-Host ""
    } else {
        W-Err "启动失败"
        W-Dim "查看日志: Get-Content $LogFile"
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
}

# ─── 停止 ───
function Invoke-CmdStop {
    if (-not (Test-Running)) {
        W-Warn "mihomo 没有在运行"
        if (Test-NetworkLeftovers) {
            Write-Host ""
            W-Info "检测到残留网络状态，正在清理 ..."
            Invoke-NetworkRestore $true
            Write-Host ""
            Invoke-NetworkHealthCheck
        }
        return
    }

    $procId = [int][System.IO.File]::ReadAllText($PidFile).Trim()
    Write-Host ""
    Write-Host -NoNewline "  停止中 ... "

    Stop-Process -Id $procId -ErrorAction SilentlyContinue

    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Milliseconds 500
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if (-not $proc) {
            Write-Host "${Green}✓${NC} 已停止 (PID: $procId)"
            Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
            Write-Host ""
            Invoke-NetworkRestore $false
            Invoke-NetworkHealthCheck
            return
        }
    }

    Write-Host ""
    W-Warn "超时，强制终止..."
    Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    # 兜底：按进程名强杀，防止 PID 文件不准导致杀不掉
    Get-Process -Name mihomo -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue

    if (Get-Process -Name mihomo -ErrorAction SilentlyContinue) {
        W-Err "停止失败，残留进程仍在运行"
        W-Dim "试试: Stop-Process -Name mihomo -Force"
        return
    }

    W-Warn "已强制停止"
    W-Info "正在恢复网络 ..."
    Invoke-NetworkRestore $true
    Write-Host ""
    Invoke-NetworkHealthCheck
}

# ─── 重启 / 热重载 ───
function Invoke-CmdRestart {
    param([string]$Src)
    Invoke-CmdStop
    Start-Sleep -Seconds 1
    Invoke-CmdStart $Src
}

function Invoke-CmdReload {
    param([string]$Cfg = $ConfigFile)

    if (-not (Test-Running)) {
        W-Warn "mihomo 没在运行，直接启动"
        Invoke-CmdStart $Cfg
        return
    }
    if (-not (Test-Path $Cfg)) {
        W-Err "配置文件不存在: $Cfg"
        return
    }

    Write-Host -NoNewline "  热重载配置 ... "
    try {
        # mihomo API 开启 secret 时必须带 Bearer 鉴权，否则 PUT /configs 会 401
        # BUGFIX: 旧逻辑只处理双引号和裸值，漏了单引号（secret: 'xxx'）
        # 且 fallback 正则会连引号一起捕获导致鉴权失败
        # 现在三级 fallback：双引号 → 单引号 → 裸值，每级精确匹配不吞引号
        $headers = @{}
        if (Test-Path $Cfg) {
            # 匹配双引号: secret: "mysecret"
            $secLine = Select-String -Path $Cfg -Pattern '^\s*secret:\s*"([^"]+)"' | Select-Object -First 1
            if (-not $secLine) {
                # 匹配单引号: secret: 'mysecret'
                $secLine = Select-String -Path $Cfg -Pattern "^\s*secret:\s*'([^']+)'" | Select-Object -First 1
            }
            if (-not $secLine) {
                # 匹配裸值: secret: mysecret
                $secLine = Select-String -Path $Cfg -Pattern '^\s*secret:\s*([^\s#]+)' | Select-Object -First 1
            }
            if ($secLine) { $headers['Authorization'] = "Bearer $($secLine.Matches[0].Groups[1].Value)" }
        }
        $body = @{ path = $Cfg } | ConvertTo-Json -Compress
        $uri = "http://127.0.0.1:$ApiPort/configs"
        $resp = Invoke-WebRequest -Method PUT -Uri $uri -ContentType "application/json" -Body $body -Headers $headers -UseBasicParsing -ErrorAction Stop
        W-Ok "成功"
    } catch {
        W-Err "API 不可达，尝试重启..."
        Invoke-CmdRestart $Cfg
    }
}

# ─── 状态 ───
function Invoke-CmdStatus {
    if (Test-Running) {
        $procId = [System.IO.File]::ReadAllText($PidFile).Trim()
        Write-Host ""
        Write-Host "  ${BoldGreen}● 运行中${NC}  ${Dim}PID: $procId${NC}"
        Write-Host "  $SEP"
        Write-Host "  ${Dim}代理端口   ${NC}${Cyan}127.0.0.1:$MixedPort${NC} (HTTP/SOCKS5)"
        Write-Host "  ${Dim}API 端口   ${NC}${Cyan}127.0.0.1:$ApiPort${NC}"
        Write-Host "  ${Dim}管理面板   ${NC}${Cyan}$(Get-UiUrl)${NC}"
        Write-Host "  ${Dim}配置文件   ${NC}$ConfigFile"
        Write-Host "  ${Dim}日志文件   ${NC}$LogFile"
        $src = if (Test-Path $LinkFile) { [System.IO.File]::ReadAllText($LinkFile).Trim() } else { Get-AutoDetectSource }
        if ($src) { Write-Host "  ${Dim}源文件     ${NC}$src" }
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "  ${BoldRed}○ 已停止${NC}"
        Write-Host "  $SEP"
        W-Dim "mihomo 当前未运行"
        Write-Host ""
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
}

# ─── 链接源配置 ───
function Invoke-CmdLink {
    param([string]$Src)

    if (-not $Src) {
        Write-Host ""
        W-Section "源文件链接"
        if (Test-Path $LinkFile) {
            W-Info "当前链接: $([System.IO.File]::ReadAllText($LinkFile).Trim())"
        } else {
            $detected = Get-AutoDetectSource
            if ($detected) {
                W-Info "自动检测: $detected"
            } else {
                W-Warn "未检测到源文件"
            }
        }
        Write-Host ""
        # BUGFIX: $input 是 PowerShell 自动变量（包含管道输入），不能当普通变量使用
        # 旧代码用 $input 存储用户输入会导致意外行为，改为 $inputPath
        $inputPath = Read-Host "  请输入 YAML 文件路径 (Enter 取消)"
        if (-not $inputPath) { W-Dim "已取消"; return }
        $Src = $inputPath.Trim().Trim('"')
    }

    if (-not (Test-Path $Src)) {
        W-Err "文件不存在: $Src"
        return
    }

    [System.IO.File]::WriteAllText($LinkFile, $Src, [System.Text.UTF8Encoding]::new($false))
    W-Ok "已链接"
    W-Dim "源文件   $Src"
    Write-Host ""
    $ans = Read-Host "  立即适配并启动? (y/n)"
    if ($ans -eq 'y') {
        $result = Invoke-WinAdaptConfig $Src
        if (-not $result) { return }
        if (Test-Running) {
            Invoke-CmdRestart
        } else {
            Invoke-CmdStart
        }
    }
}

# ─── 日志 / 编辑 / 面板 / 修复 / 诊断 ───
function Invoke-CmdLog {
    if (Test-Path $LogFile) {
        Write-Host ""
        W-Section "实时日志  (Ctrl+C 退出)"
        Get-Content $LogFile -Wait
    } else {
        W-Warn "日志文件不存在"
    }
}

function Invoke-CmdEdit {
    W-Info "打开编辑器: $ConfigFile"
    $editor = $env:EDITOR
    if (-not $editor) { $editor = "notepad" }
    Start-Process $editor -ArgumentList "`"$ConfigFile`"" -Wait
}

function Invoke-CmdOpen {
    if (Test-Running) {
        Update-UiIndex
        $url = Get-UiUrl
        Start-Process $url
        W-Ok "已打开管理面板"
        W-Dim $url
    } else {
        W-Warn "mihomo 未运行，请先启动"
    }
}

function Invoke-CmdCleanup {
    Invoke-NetworkRestore $true
}

function Invoke-CmdDoctor {
    Invoke-NetworkHealthCheck
}

# ─── 关闭 Clash Verge 后台服务 ───
function Invoke-CmdVergeOff {
    Write-Host ""
    W-Section "关闭 Clash Verge"

    $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like "*clash*verge*" -or $_.Name -like "*clash_verge*"
    }

    if ($svc) {
        W-Info "发现 Clash Verge 服务: $($svc.Name) ($($svc.Status))"
        Write-Host -NoNewline "  正在停止 ... "
        if ($svc.Status -eq 'Running') {
            Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 1
        # 杀残留进程
        Get-Process -Name "clash-verge*", "clash_verge*" -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
        W-Ok "已停止"
    } else {
        $procs = Get-Process -Name "clash-verge*", "clash_verge*" -ErrorAction SilentlyContinue
        if ($procs) {
            W-Info "发现 Clash Verge 进程"
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            W-Ok "已停止"
        } else {
            W-Ok "Clash Verge 服务未运行"
        }
    }

    Write-Host ""
    $ans = Read-Host "  是否同时卸载开机自启? (y/n)"
    if ($ans -eq 'y') {
        if ($svc) {
            sc.exe delete $svc.Name 2>$null | Out-Null
            W-Ok "已卸载开机自启"
        } else {
            W-Dim "未找到注册服务，跳过"
        }
    }
    Write-Host ""
    W-Ok "现在可以纯用 clash.ps1 管理了"
    Write-Host ""
}

# ─── 帮助 ───
function Show-Help {
    Write-Host ""
    Write-Host "  ${BoldPurple}Mihomo Kernel Manager${NC}  ${Dim}— Windows${NC}"
    Write-Host "  $SEP"
    Write-Host ""
    Write-Host "  ${Bold}用法:${NC}"
    Write-Host "    ${Cyan}clash.ps1 <command>${NC}   执行子命令"
    Write-Host "    ${Cyan}clash.ps1${NC}             进入交互菜单"
    Write-Host "    ${Cyan}clash.ps1 help${NC}        显示本帮助"
    Write-Host ""
    Write-Host "  ${Bold}核心:${NC}"
    Write-Host "    ${Cyan}start [file]${NC}    启动（自动适配 Windows 配置，TUN 模式）"
    Write-Host "    ${Cyan}stop${NC}            停止并恢复网络"
    Write-Host "    ${Cyan}restart${NC}         重启"
    Write-Host "    ${Cyan}status${NC}          查看运行状态"
    Write-Host "    ${Cyan}reload [file]${NC}   热重载配置"
    Write-Host "    ${Cyan}open${NC}            打开管理面板"
    Write-Host "    ${Cyan}log${NC}             实时日志"
    Write-Host ""
    Write-Host "  ${Bold}配置:${NC}"
    Write-Host "    ${Cyan}link [file]${NC}     查看/设置源 YAML"
    Write-Host "    ${Cyan}edit${NC}            编辑当前配置"
    Write-Host ""
    Write-Host "  ${Bold}网络:${NC}"
    Write-Host "    ${Cyan}cleanup${NC}         网络修复（清理残留 TUN/路由/DNS）"
    Write-Host "    ${Cyan}doctor${NC}          网络诊断"
    Write-Host ""
    Write-Host "  ${Bold}系统:${NC}"
    Write-Host "    ${Cyan}verge-off${NC}       关闭 Clash Verge 后台服务"
    Write-Host ""
    Write-Host "  ${Bold}示例:${NC}"
    W-Dim "clash.ps1 start"
    W-Dim 'clash.ps1 link C:\Users\you\Mihomo\config.yaml'
    W-Dim "clash.ps1 cleanup"
    Write-Host ""
}

# ─── 交互菜单 ───
function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ${BoldPurple}Mihomo Kernel Manager${NC}  ${Dim}— Windows${NC}"
    Write-Host "  $SEP"

    if (Test-Running) {
        $procId = [System.IO.File]::ReadAllText($PidFile).Trim()
        Write-Host "  ${BoldGreen}● 运行中${NC}  ${Dim}PID: $procId  代理: $MixedPort  API: $ApiPort${NC}"
    } else {
        Write-Host "  ${BoldRed}○ 已停止${NC}"
    }
    Write-Host ""

    Write-Host "  ${Bold}1${NC} 启动        ${Bold}5${NC} 状态"
    Write-Host "  ${Bold}2${NC} 停止        ${Bold}6${NC} 实时日志"
    Write-Host "  ${Bold}3${NC} 打开面板    ${Bold}7${NC} 热重载"
    Write-Host "  ${Bold}4${NC} 重启        ${Bold}8${NC} 网络修复"
    Write-Host "  ${Bold}0${NC} 退出"
    Write-Host ""
    Write-Host -NoNewline "  ${Bold}❯${NC} "
}

function Invoke-InteractiveMenu {
    while ($true) {
        Show-Menu
        $choice = Read-Host
        Write-Host ""
        switch ($choice) {
            '1' { Invoke-CmdStart }
            '2' { Invoke-CmdStop }
            '3' { Invoke-CmdOpen }
            '4' { Invoke-CmdRestart }
            '5' { Invoke-CmdStatus }
            '6' { Invoke-CmdLog }
            '7' { Invoke-CmdReload }
            '8' { Invoke-CmdCleanup }
            { $_ -in '0', 'q', 'Q' } {
                Write-Host "  ${Dim}再见 👋${NC}"
                Write-Host ""
                return
            }
            default { W-Warn "无效选项，请输入 0-8" }
        }
        Write-Host ""
        Write-Host -NoNewline "  按 Enter 返回菜单..."
        Read-Host
    }
}

# ═══════════════════════════════════════════════════════════
#   入口
# ═══════════════════════════════════════════════════════════

# 检测是否为提权重启
$Script:Elevated = $false
$scriptArgs = $args
if ($args.Count -gt 0 -and $args[0] -eq '--elevated') {
    $Script:Elevated = $true
    $scriptArgs = if ($args.Count -gt 1) { $args[1..($args.Count-1)] } else { @() }
}

$cmd = if ($scriptArgs.Count -gt 0) { $scriptArgs[0] } else { "" }
$cmdArgs = if ($scriptArgs.Count -gt 1) { $scriptArgs[1..($scriptArgs.Count-1)] } else { @() }

# 需要管理员的命令
$adminCmds = @('start', 's', 'stop', 'restart', 'r', 'cleanup', 'c', 'verge-off', '')

# 自动提权（UAC 关闭时无感）
if (-not $Script:Elevated -and ($cmd -in $adminCmds) -and -not (Test-Admin)) {
    $elevateArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath, "--elevated")
    if ($cmd) { $elevateArgs += $cmd }
    foreach ($a in $cmdArgs) { $elevateArgs += $a }
    Start-Process "pwsh.exe" -Verb RunAs -ArgumentList $elevateArgs
    exit
}

# 命令分发
if ($cmd -eq 'start' -or $cmd -eq 's') {
    Invoke-CmdStart ($cmdArgs | Select-Object -First 1)
} elseif ($cmd -eq 'stop') {
    Invoke-CmdStop
} elseif ($cmd -eq 'restart' -or $cmd -eq 'r') {
    Invoke-CmdRestart ($cmdArgs | Select-Object -First 1)
} elseif ($cmd -eq 'reload' -or $cmd -eq 'rl') {
    Invoke-CmdReload ($cmdArgs | Select-Object -First 1)
} elseif ($cmd -eq 'status' -or $cmd -eq 'st') {
    Invoke-CmdStatus
} elseif ($cmd -eq 'log' -or $cmd -eq 'l') {
    Invoke-CmdLog
} elseif ($cmd -eq 'link' -or $cmd -eq 'lk') {
    Invoke-CmdLink ($cmdArgs | Select-Object -First 1)
} elseif ($cmd -eq 'open' -or $cmd -eq 'o') {
    Invoke-CmdOpen
} elseif ($cmd -eq 'edit' -or $cmd -eq 'e') {
    Invoke-CmdEdit
} elseif ($cmd -eq 'cleanup' -or $cmd -eq 'c') {
    Invoke-CmdCleanup
} elseif ($cmd -eq 'doctor' -or $cmd -eq 'd') {
    Invoke-CmdDoctor
} elseif ($cmd -eq 'verge-off') {
    Invoke-CmdVergeOff
} elseif ($cmd -eq 'help' -or $cmd -eq '-h' -or $cmd -eq '--help' -or $cmd -eq 'h') {
    Show-Help
} else {
    Invoke-InteractiveMenu
}

# 提权模式下非交互命令结束时暂停（让用户看到输出）
if ($Script:Elevated -and $cmd -ne '' -and $cmd -ne 'help' -and $cmd -ne '-h' -and $cmd -ne '--help' -and $cmd -ne 'h') {
    Write-Host ""
    Write-Host -NoNewline "  按 Enter 关闭..."
    Read-Host
}
