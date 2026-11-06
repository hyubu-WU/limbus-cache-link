#requires -Version 5.1
<#
.SYNOPSIS
    把 Limbus Company 的 Unity 缓存目录改成指向别的盘的 junction，并在被冲掉时自动修复。

.DESCRIPTION
    游戏把缓存写在 LocalLow\Unity\ProjectMoon_LimbusCompany。
    这个脚本把那个位置变成 junction，指向你指定的目标目录（比如 D:\LimbusCache）。

    会处理三种情况：
      1. 链接完好           -> 什么都不做
      2. 链接指向错了       -> 拆掉重建
      3. 位置上变成了真目录 -> 把内容搬回目标盘，再重建链接

    任何一步失败都停下、不改动，原因写进日志。

.PARAMETER Quiet
    只写日志，不输出中文提示（给计划任务用）

.EXAMPLE
    .\Fix-LimbusCacheLink.ps1

.EXAMPLE
    .\Fix-LimbusCacheLink.ps1 -Quiet
#>
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'

# ── 读配置 ────────────────────────────────────────────────────────────────
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfgPath = Join-Path $here 'config.json'

$defaultLink = Join-Path $env:USERPROFILE 'AppData\LocalLow\Unity\ProjectMoon_LimbusCompany'
$cfg = @{
    Link        = $defaultLink
    Target      = 'D:\LimbusCache'
    GameProcess = 'LimbusCompany'
}

if (Test-Path -LiteralPath $cfgPath) {
    try {
        $user = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($k in 'Link', 'Target', 'GameProcess') {
            if ($user.PSObject.Properties.Name -contains $k -and $user.$k) {
                $cfg[$k] = [string]$user.$k
            }
        }
    }
    catch {
        Write-Host "  [!!]  config.json 读不了，用默认值：$($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$link   = $cfg.Link
$target = $cfg.Target
$proc   = $cfg.GameProcess

$logDir = Join-Path $env:LOCALAPPDATA 'LimbusCacheLink'
$log    = Join-Path $logDir 'fix-link.log'

# ── 输出 ──────────────────────────────────────────────────────────────────
function Say($msg, $level = 'info') {
    if ($Quiet) { return }
    switch ($level) {
        'ok'    { Write-Host "  [OK]  $msg" -ForegroundColor Green }
        'warn'  { Write-Host "  [!!]  $msg" -ForegroundColor Yellow }
        'err'   { Write-Host "  [XX]  $msg" -ForegroundColor Red }
        default { Write-Host "  ..    $msg" -ForegroundColor Cyan }
    }
}

function Write-Log([string]$msg) {
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    try { Add-Content -LiteralPath $log -Value $line -Encoding UTF8 } catch { }
}

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

if (-not $Quiet) {
    Write-Host ''
    Write-Host '  Limbus 缓存链接 · 守护' -ForegroundColor White
    Write-Host '  ----------------------------------------'
    Write-Host "  链接:   $link"
    Write-Host "  实体:   $target"
    Write-Host ''
}

try {
    # 1) 游戏在跑就不动
    if ($proc -and (Get-Process -Name $proc -ErrorAction SilentlyContinue)) {
        Say '游戏正在运行，这次先跳过（避免抢文件）' 'warn'
        Write-Log 'skip: game is running'
        if (-not $Quiet) { Write-Host ''; Write-Host '  按任意键关闭...' -ForegroundColor DarkGray }
        exit 0
    }

    # 2) 目标目录
    if (-not (Test-Path -LiteralPath $target)) {
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        Say "目标目录不存在，已新建：$target" 'ok'
        Write-Log "created target: $target"
    }
    else {
        Say "缓存实体在：$target" 'ok'
    }

    $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue

    # 3) 链接状态
    if ($null -ne $item -and $item.LinkType -eq 'Junction') {
        if ($item.Target -eq $target) {
            Say '链接完好，指向正确' 'ok'
            Write-Log 'ok: junction intact'
            if (-not $Quiet) { Write-Host ''; Write-Host '  按任意键关闭...' -ForegroundColor DarkGray }
            exit 0
        }
        cmd /c rmdir "$link" | Out-Null
        Say "链接指向了错误位置（原：$($item.Target)），已拆除重建" 'warn'
        Write-Log "removed stale junction: $($item.Target)"
        $item = $null
    }

    # 4) 被重装/修复冲成了真目录 -> 搬回目标盘
    if ($null -ne $item -and $item.PSIsContainer) {
        $sum = (Get-ChildItem -LiteralPath $link -Recurse -File -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum)
        $gb = [math]::Round(($sum.Sum / 1GB), 2)
        Say "发现真目录（可能是重装/修复造成的），大小 $gb GB" 'warn'
        Say '正在把内容搬回目标盘...' 'info'

        & robocopy $link $target /E /MOVE /XJ /R:1 /W:1 /NFL /NDL /NJH /NP | Out-Null
        if ($LASTEXITCODE -ge 8) {
            Say "搬运失败（robocopy $LASTEXITCODE），未做改动" 'err'
            Write-Log "ERROR: robocopy $LASTEXITCODE"
            if (-not $Quiet) { Write-Host ''; Write-Host '  按任意键关闭...' -ForegroundColor DarkGray }
            exit 1
        }

        $left = Get-ChildItem -LiteralPath $link -Recurse -Force -ErrorAction SilentlyContinue
        if ($left) {
            Say "搬运后源目录仍有残留（$($left.Count) 项），已停止" 'err'
            Write-Log "ERROR: source not empty ($($left.Count))"
            if (-not $Quiet) { Write-Host ''; Write-Host '  按任意键关闭...' -ForegroundColor DarkGray }
            exit 1
        }

        if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link -Force }
        Write-Log 'moved real directory content to target'
    }

    if (Test-Path -LiteralPath $link) {
        Say '链接路径状态异常，已停止，未做改动' 'err'
        Write-Log 'ERROR: link path still exists'
        if (-not $Quiet) { Write-Host ''; Write-Host '  按任意键关闭...' -ForegroundColor DarkGray }
        exit 1
    }

    # 5) 建链接
    cmd /c mklink /J "$link" "$target" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Say "创建链接失败（mklink $LASTEXITCODE）" 'err'
        Write-Log "ERROR: mklink $LASTEXITCODE"
        if (-not $Quiet) { Write-Host ''; Write-Host '  按任意键关闭...' -ForegroundColor DarkGray }
        exit 1
    }
    Say "已重建链接：$link" 'ok'
    Say "  -> $target" 'ok'
    Write-Log "recreated junction -> $target"

    if (-not $Quiet) { Write-Host ''; Write-Host '  按任意键关闭...' -ForegroundColor DarkGray }
    exit 0
}
catch {
    Say "出现意外：$($_.Exception.Message)" 'err'
    Write-Log "ERROR: $($_.Exception.Message)"
    if (-not $Quiet) { Write-Host ''; Write-Host '  按任意键关闭...' -ForegroundColor DarkGray }
    exit 1
}
