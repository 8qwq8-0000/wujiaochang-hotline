param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [switch]$ExportWindows
)
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot
if (!(Test-Path $GodotPath -PathType Leaf)) { throw "GodotPath 必须是已解压的 Godot .NET 可执行文件" }
$version = (& $GodotPath --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.7\.2\.stable\.mono\.') { throw "引擎版本不符合要求：$version" }
Write-Host "Godot: $version"
$sdkList = (& dotnet --list-sdks | Out-String)
if ($LASTEXITCODE -ne 0 -or $sdkList -notmatch '(?m)^8\.0\.') { throw "请安装 .NET 8 SDK" }
& dotnet build WujiaochangHotline.csproj --nologo
if ($LASTEXITCODE -ne 0) { throw ".NET 编译失败" }
New-Item -ItemType Directory -Force builds/checks | Out-Null
function Invoke-GodotCheck([string[]]$GodotArgs, [string]$LogName) {
    $logPath = Join-Path $projectRoot "builds/checks/$LogName.log"
    & $GodotPath @GodotArgs 2>&1 | Out-File -Encoding utf8 $logPath
    $result = $LASTEXITCODE
    if ($result -ne 0 -or (Select-String -Path $logPath -Pattern 'SCRIPT ERROR:|(^|\s)ERROR:' -Quiet)) {
        Get-Content $logPath
        throw "Godot 检查失败：$LogName；详见 $logPath"
    }
    Write-Host "通过：$LogName（日志 $logPath）"
}
Invoke-GodotCheck -GodotArgs @('--headless','--editor','--path',$projectRoot,'--import') -LogName 'import'
Invoke-GodotCheck -GodotArgs @('--headless','--path',$projectRoot,'--quit-after','10') -LogName 'startup'
if ($ExportWindows) {
    New-Item -ItemType Directory -Force builds/windows | Out-Null
    Invoke-GodotCheck -GodotArgs @('--headless','--path',$projectRoot,'--export-debug','Windows Desktop','builds/windows/wujiaochang-hotline.exe') -LogName 'export'
}
Write-Host "自动检查结束。仍需人工测试窗口比例、按键，以及 Windows 编辑器外运行。"
