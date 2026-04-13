# TypeFlow Windows Build Script (PowerShell)
# Produces a single-file, self-contained TypeFlow-1.0.0-Setup.exe in the dist\ folder.
#
# Requirements:
#   - .NET 8 SDK  (https://dotnet.microsoft.com/download/dotnet/8.0)
#   - Windows 10 / 11 x64  (WPF requires Windows build environment)
#
# Usage:
#   Right-click this file -> "Run with PowerShell"
#   -OR- from a terminal:  .\build.ps1

param(
    [string]$Configuration = "Release",
    [string]$RuntimeIdentifier = "win-x64",
    [string]$Version = "1.0.0"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Locate project root ───────────────────────────────────────────────────────
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectFile = Join-Path $ScriptDir "TypeFlow.csproj"
$DistDir     = Join-Path $ScriptDir "dist"
$OutputName  = "TypeFlow-$Version-Setup.exe"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TypeFlow Build  v$Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Check .NET SDK ────────────────────────────────────────────────────────────
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Error ".NET SDK not found. Install it from https://dotnet.microsoft.com/download/dotnet/8.0"
    exit 1
}

$sdkVersion = (dotnet --version 2>&1).Trim()
Write-Host "Using .NET SDK $sdkVersion" -ForegroundColor Green

# ── Clean previous output ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "Cleaning previous build artifacts..." -ForegroundColor Yellow
if (Test-Path $DistDir) { Remove-Item $DistDir -Recurse -Force }
New-Item -ItemType Directory -Path $DistDir | Out-Null

# ── Restore dependencies ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "Restoring NuGet packages..." -ForegroundColor Yellow
dotnet restore $ProjectFile
if ($LASTEXITCODE -ne 0) { Write-Error "Restore failed."; exit 1 }

# ── Publish single-file self-contained EXE ───────────────────────────────────
Write-Host ""
Write-Host "Publishing self-contained single-file EXE..." -ForegroundColor Yellow

dotnet publish $ProjectFile `
    --configuration $Configuration `
    --runtime $RuntimeIdentifier `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    --output "$ScriptDir\build_output"

if ($LASTEXITCODE -ne 0) { Write-Error "Publish failed."; exit 1 }

# ── Copy to dist ──────────────────────────────────────────────────────────────
$BuiltExe = Join-Path $ScriptDir "build_output\TypeFlow.exe"
$DestExe  = Join-Path $DistDir $OutputName

Copy-Item $BuiltExe $DestExe
Remove-Item "$ScriptDir\build_output" -Recurse -Force

$sizeMB = [math]::Round((Get-Item $DestExe).Length / 1MB, 1)

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Build complete!" -ForegroundColor Green
Write-Host "  Output : dist\$OutputName  ($sizeMB MB)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
