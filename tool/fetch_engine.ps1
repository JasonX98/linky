# tool/fetch_engine.ps1 —— 下载 yt-dlp 与 FFmpeg 到 assets/bin/
# 说明：yt-dlp 官方未对每个 exe 发布独立 SHA256 校验源，故用"运行校验"兜底
# （下载后执行 `yt-dlp --version` 且退出码 0、输出非空）；若未来官方提供
# checksum 资产，可在此追加 SHA256 对比。
$ErrorActionPreference = 'Stop'
$binDir = Join-Path $PSScriptRoot '..\assets\bin'
$binDir = [System.IO.Path]::GetFullPath($binDir)
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

# 完整性校验：运行 exe --version，退出码 0 且首行非空
function Test-EngineExe {
    param([string]$exePath, [string]$label)
    if (-not (Test-Path $exePath)) { throw "$label 缺失：$exePath" }
    $output = & $exePath --version 2>&1
    if ($LASTEXITCODE -ne 0 -or -not ($output | Select-Object -First 1)) {
        throw "$label 校验失败（无法运行或输出为空）：$exePath"
    }
}

Write-Host 'Downloading yt-dlp.exe ...'
$ytUrl = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
Invoke-WebRequest -Uri $ytUrl -OutFile (Join-Path $binDir 'yt-dlp.exe')

Write-Host 'Downloading FFmpeg essentials ...'
$tmp = Join-Path $env:TEMP ("ffmpeg_" + [System.Guid]::NewGuid().ToString('N'))
$zip = Join-Path $tmp 'ffmpeg.zip'
try {
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    Invoke-WebRequest -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $tmp -Force

    $ffmpeg = Get-ChildItem $tmp -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1
    if ($null -eq $ffmpeg) { throw '压缩包内未找到 ffmpeg.exe' }
    Copy-Item -LiteralPath $ffmpeg.FullName -Destination (Join-Path $binDir 'ffmpeg.exe') -Force

    $ffprobe = Get-ChildItem $tmp -Recurse -Filter 'ffprobe.exe' | Select-Object -First 1
    if ($null -eq $ffprobe) { throw '压缩包内未找到 ffprobe.exe' }
    Copy-Item -LiteralPath $ffprobe.FullName -Destination (Join-Path $binDir 'ffprobe.exe') -Force
}
finally {
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}

Write-Host "Engine files ready in $binDir"
Test-EngineExe (Join-Path $binDir 'yt-dlp.exe') 'yt-dlp'
& (Join-Path $binDir 'yt-dlp.exe') --version
& (Join-Path $binDir 'ffmpeg.exe') -version | Select-Object -First 1
