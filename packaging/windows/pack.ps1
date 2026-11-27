<#
.SYNOPSIS
    把 Release 编译出的 网狗音乐.exe 做成 Windows 安装包（本机和 GitHub Actions 通用）。

.DESCRIPTION
    步骤：
      1. 导入 Visual Studio 的编译环境（vcvars64），windeployqt 靠它找 Windows SDK；
      2. 把 exe 复制到部署目录，用 windeployqt 收集 Qt DLL、QML 模块和插件；
      3. 补上 MSVC 运行库 DLL（windeployqt 在 Release 下只带 vc_redist.x64.exe，不带这几个 DLL；
          缺了它们，没装过 VC++ 运行库的电脑会打不开）；
      4. 用 Inno Setup 7 编译 packaging/windows/installer.iss，输出 WangGouMusic_<版本>_setup.exe。

.EXAMPLE
    packaging\windows\pack.ps1 -Exe build\Release\网狗音乐.exe -QtBin D:\Qt\6.12.0\msvc2022_64\bin -Version 0.8.4
#>
[CmdletBinding()]
param(
    # Release 编译出的 网狗音乐.exe
    [Parameter(Mandatory = $true)] [string] $Exe,
    # Qt 的 bin 目录（里面有 windeployqt.exe）
    [Parameter(Mandatory = $true)] [string] $QtBin,
    [Parameter(Mandatory = $true)] [ValidatePattern('^\d+\.\d+\.\d+$')] [string] $Version,
    # 输出目录，默认是仓库根目录下的 dist
    [string] $OutDir,
    # Inno Setup 7 的 ISCC.exe；不在 PATH 里时用这个参数指定完整路径
    [string] $Iscc = 'ISCC.exe'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# 运行外部程序：它写到 stderr 的警告不算错误，只看退出码
function Invoke-Native {
    param([string] $FilePath, [string[]] $Arguments)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $FilePath @Arguments
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($code -ne 0) { throw "$FilePath 失败（退出码 $code）" }
}

function Import-VcVars {
    $fallback = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022\BuildTools'
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $installDir = $fallback
    if (Test-Path -LiteralPath $vswhere) {
        $found = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath |
            Select-Object -First 1
        if ($found) { $installDir = $found }
    }
    $vcvars = Join-Path $installDir 'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path -LiteralPath $vcvars)) { throw "找不到 vcvars64.bat（$vcvars）。需要装了 C++ 生成工具的 Visual Studio 2022。" }

    # vcvars64.bat 改的是它自己那个 cmd 进程的环境，这里把改完后的环境变量读出来再设到当前进程
    $lines = & cmd.exe /d /c "`"$vcvars`" >nul 2>&1 && set"
    if ($LASTEXITCODE -ne 0) { throw "执行 vcvars64.bat 失败" }
    foreach ($line in $lines) {
        if ($line -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($matches[1])" -Value $matches[2] }
    }
    if (-not $env:VCINSTALLDIR) { throw "导入 VS 环境后没有 VCINSTALLDIR" }
    Write-Host "VS 环境：$installDir"
}

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$QtBin = (Resolve-Path -LiteralPath $QtBin).Path
$WinDeployQt = Join-Path $QtBin 'windeployqt.exe'
if (-not (Test-Path -LiteralPath $WinDeployQt)) { throw "在 $QtBin 里找不到 windeployqt.exe" }
# windeployqt 会按名字调用 Qt bin 目录里的这几个小工具；Qt 装得不全时它只会报一句
# “Process failed to start: The system cannot find the file specified.”，所以先检查一遍，缺了直接说清楚
# （lconvert.exe 在 qttools 归档里，qtpaths.exe 在 qtbase，qmlimportscanner.exe 在 qtdeclarative；
#   用 aqtinstall 装 Qt 时这几个归档都要带上）
foreach ($tool in 'qtpaths.exe', 'qmlimportscanner.exe', 'lconvert.exe') {
    if (-not (Test-Path -LiteralPath (Join-Path $QtBin $tool))) {
        throw "Qt 不完整：$QtBin 里没有 $tool。请用 Qt 安装器补装对应的组件，或用 aqtinstall 装齐 qttools 等归档"
    }
}
if (-not $OutDir) { $OutDir = Join-Path $RepoRoot 'dist' }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path.TrimEnd('\')

# 1. VS 环境
Import-VcVars

# 2. windeployqt
$Stage = Join-Path $OutDir 'stage'
if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
New-Item -ItemType Directory -Path $Stage | Out-Null
Copy-Item -LiteralPath $Exe -Destination $Stage
$StagedExe = Join-Path $Stage (Split-Path $Exe -Leaf)
Write-Host "部署 Qt 依赖到 $Stage ..."
Invoke-Native $WinDeployQt @('--release', '--qmldir', $RepoRoot, '--dir', $Stage, $StagedExe)

# 3. MSVC 运行库（和已发布的安装包保持同一组文件；vc_redist.x64.exe 由 windeployqt 自己带进来）
$RuntimeNames = @(
    'concrt140', 'msvcp140', 'msvcp140_1', 'msvcp140_2', 'msvcp140_atomic_wait',
    'msvcp140_codecvt_ids', 'vccorlib140', 'vcruntime140', 'vcruntime140_1', 'vcruntime140_threads'
)
$RedistRoot = Join-Path $env:VCINSTALLDIR 'Redist\MSVC'
$CrtDir = Get-ChildItem -Path (Join-Path $RedistRoot '*\x64\Microsoft.VC*.CRT') -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "$($RuntimeNames[0]).dll") } |
    Sort-Object -Property { [version]($_.Parent.Parent.Name) } -Descending |
    Select-Object -First 1
if ($CrtDir) {
    foreach ($name in $RuntimeNames) {
        Copy-Item -LiteralPath (Join-Path $CrtDir.FullName "$name.dll") -Destination $Stage
    }
    Write-Host "MSVC 运行库：$($CrtDir.FullName)"
} else {
    # VS 里没装“VC++ 可再发行组件”这个组件时，退而用系统里已经装好的那一份
    $System32 = Join-Path $env:SystemRoot 'System32'
    foreach ($name in $RuntimeNames) {
        $source = Join-Path $System32 "$name.dll"
        if (-not (Test-Path -LiteralPath $source)) { throw "在 $RedistRoot 下找不到 x64\Microsoft.VC*.CRT，$source 也没有，带不了 MSVC 运行库" }
        Copy-Item -LiteralPath $source -Destination $Stage
    }
    Write-Host "MSVC 运行库：$RedistRoot 下没有找到，改用 $System32 里的"
}

# 4. Inno Setup
$Installer = Join-Path $OutDir "WangGouMusic_${Version}_setup.exe"
if (Test-Path -LiteralPath $Installer) { Remove-Item -LiteralPath $Installer -Force }
Invoke-Native $Iscc @("/DMyAppVersion=$Version", "/DPkgDir=$Stage", "/DOutputDir=$OutDir", "/DSrcDir=$RepoRoot",
    (Join-Path $PSScriptRoot 'installer.iss'))
if (-not (Test-Path -LiteralPath $Installer)) { throw "ISCC 没有生成 $Installer" }

$Size = (Get-Item -LiteralPath $Installer).Length
$Md5 = (Get-FileHash -LiteralPath $Installer -Algorithm MD5).Hash
$Sha256 = (Get-FileHash -LiteralPath $Installer -Algorithm SHA256).Hash.ToLowerInvariant()
"$Sha256  $(Split-Path $Installer -Leaf)" | Set-Content -LiteralPath "$Installer.sha256" -Encoding ascii

Write-Host ''
Write-Host "安装包：$Installer"
Write-Host "大小：$Size 字节"
Write-Host "MD5：$Md5"
Write-Host "SHA256：$Sha256"
