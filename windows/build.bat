@echo off
:: TypeFlow Windows Build Script (Batch)
:: Produces dist\TypeFlow-1.0.0-Setup.exe  (single-file, self-contained)
::
:: Requirements:
::   .NET 8 SDK  ->  https://dotnet.microsoft.com/download/dotnet/8.0
::   Windows 10 / 11 x64
::
:: Usage:  Double-click this file, or run from Command Prompt / PowerShell terminal.

setlocal EnableDelayedExpansion

set VERSION=1.0.0
set CONFIGURATION=Release
set RUNTIME=win-x64
set OUTPUT_NAME=TypeFlow-%VERSION%-Setup.exe

set SCRIPT_DIR=%~dp0
set DIST_DIR=%SCRIPT_DIR%dist
set BUILD_DIR=%SCRIPT_DIR%build_output

echo.
echo ========================================
echo   TypeFlow Build  v%VERSION%
echo ========================================
echo.

:: ── Check for .NET SDK ──────────────────────────────────────────────────────
where dotnet >nul 2>&1
if errorlevel 1 (
    echo [ERROR] .NET SDK not found.
    echo         Install it from: https://dotnet.microsoft.com/download/dotnet/8.0
    pause
    exit /b 1
)

for /f "tokens=*" %%v in ('dotnet --version 2^>^&1') do set SDK_VER=%%v
echo Using .NET SDK !SDK_VER!

:: ── Clean ───────────────────────────────────────────────────────────────────
echo.
echo Cleaning previous build artifacts...
if exist "%DIST_DIR%"  rmdir /s /q "%DIST_DIR%"
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
mkdir "%DIST_DIR%"

:: ── Restore ─────────────────────────────────────────────────────────────────
echo.
echo Restoring NuGet packages...
dotnet restore "%SCRIPT_DIR%TypeFlow.csproj"
if errorlevel 1 (
    echo [ERROR] NuGet restore failed.
    pause
    exit /b 1
)

:: ── Publish single-file self-contained EXE ──────────────────────────────────
echo.
echo Publishing self-contained single-file EXE...
dotnet publish "%SCRIPT_DIR%TypeFlow.csproj" ^
    --configuration %CONFIGURATION% ^
    --runtime %RUNTIME% ^
    --self-contained true ^
    -p:PublishSingleFile=true ^
    -p:IncludeNativeLibrariesForSelfExtract=true ^
    -p:EnableCompressionInSingleFile=true ^
    -p:DebugType=None ^
    -p:DebugSymbols=false ^
    --output "%BUILD_DIR%"

if errorlevel 1 (
    echo [ERROR] dotnet publish failed.
    pause
    exit /b 1
)

:: ── Copy to dist ─────────────────────────────────────────────────────────────
copy "%BUILD_DIR%\TypeFlow.exe" "%DIST_DIR%\%OUTPUT_NAME%"
if errorlevel 1 (
    echo [ERROR] Could not copy output EXE.
    pause
    exit /b 1
)
rmdir /s /q "%BUILD_DIR%"

echo.
echo ========================================
echo   Build complete!
echo   Output: dist\%OUTPUT_NAME%
echo ========================================
echo.

pause
