# Video Compression Script for Rec Room Creator Portfolio
# Prerequisites: Install FFmpeg (https://ffmpeg.org/download.html)
#   - Download from https://www.gyan.dev/ffmpeg/builds/ (Windows builds)
#   - Or install via: winget install Gyan.FFmpeg
#
# Usage: Run this script from the project root directory
#   powershell -ExecutionPolicy Bypass -File compress-videos.ps1
#
# This will compress all .mp4 files in assets/images/ to 720p with CRF 28
# Original files are backed up to assets/images-original/

$assetsDir = "assets\images"
$backupDir = "assets\images-original"

# Create backup directory
if (!(Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

# Find all mp4 files
$videos = Get-ChildItem -Path $assetsDir -Recurse -Filter "*.mp4"

Write-Host "Found $($videos.Count) video files to compress..." -ForegroundColor Cyan
Write-Host ""

foreach ($video in $videos) {
    $relativePath = $video.FullName.Substring((Resolve-Path $assetsDir).Path.Length + 1)
    $backupPath = Join-Path $backupDir $relativePath
    $backupFolder = Split-Path $backupPath -Parent
    
    # Create backup subdirectory if needed
    if (!(Test-Path $backupFolder)) {
        New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
    }
    
    # Backup original
    Copy-Item $video.FullName $backupPath -Force
    
    $originalSize = [math]::Round($video.Length / 1MB, 2)
    $tempOutput = $video.FullName + ".tmp.mp4"
    
    Write-Host "Compressing: $relativePath ($originalSize MB)" -ForegroundColor Yellow
    
    # Compress: 720p, CRF 28, no audio (these are muted carousel videos)
    & ffmpeg -i $video.FullName -vcodec libx264 -crf 28 -preset slow -vf "scale=1280:-2" -an -movflags +faststart -y $tempOutput 2>$null
    
    if ($LASTEXITCODE -eq 0 -and (Test-Path $tempOutput)) {
        $newSize = [math]::Round((Get-Item $tempOutput).Length / 1MB, 2)
        Remove-Item $video.FullName -Force
        Move-Item $tempOutput $video.FullName
        $savings = [math]::Round((1 - $newSize / $originalSize) * 100, 1)
        Write-Host "  Done: $originalSize MB -> $newSize MB (saved $savings%)" -ForegroundColor Green
    } else {
        Write-Host "  FAILED - keeping original" -ForegroundColor Red
        if (Test-Path $tempOutput) { Remove-Item $tempOutput -Force }
    }
    
    Write-Host ""
}

$totalOriginal = ($videos | Measure-Object -Property Length -Sum).Sum / 1MB
$totalNew = (Get-ChildItem -Path $assetsDir -Recurse -Filter "*.mp4" | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total: $([math]::Round($totalOriginal, 1)) MB -> $([math]::Round($totalNew, 1)) MB" -ForegroundColor Cyan
Write-Host "Originals backed up to: $backupDir" -ForegroundColor Cyan
