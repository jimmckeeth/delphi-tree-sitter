<#
.SYNOPSIS
    Builds tree-sitter and tree-sitter-pascal shared libraries for all
    Delphi-supported platforms using the Zig cross-compiler.

.DESCRIPTION
    Compiles the tree-sitter core library and the tree-sitter-pascal grammar
    from their submodule sources. Output goes to Libs/<platform>/.
    Run Prerequisites.ps1 first to ensure zig is available.

.PARAMETER Platforms
    One or more platform names to build. Defaults to all platforms.
    Valid values: Win32, Win64, Linux64, macOS-x64, macOS-arm64, Android, Android64, iOSDevice64

.NOTES
    Requires zig (https://ziglang.org) on PATH.
    iOSDevice64 requires Apple SDK headers and must be built on macOS.

.PARAMETER Clean
    Remove the Libs output directory before building.

.EXAMPLE
    .\BuildLibs.ps1
    .\BuildLibs.ps1 -Platforms Win32,Win64
    .\BuildLibs.ps1 -Clean
#>
param(
    [ValidateSet('Win32','Win64','Linux64','macOS-x64','macOS-arm64','Android','Android64','iOSDevice64')]
    [string[]]$Platforms,
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot      = Split-Path $PSScriptRoot -Parent
$OutRoot       = Join-Path $RepoRoot 'Libs'
$TsPascalDir   = Join-Path $RepoRoot 'tree-sitter-pascal'
$TsCoreDir     = Join-Path $TsPascalDir 'tree-sitter'
$TsCoreSrc     = Join-Path $TsCoreDir 'lib\src\lib.c'
$TsCoreInclude = Join-Path $TsCoreDir 'lib\include'
$TsCoreSrcDir  = Join-Path $TsCoreDir 'lib\src'
$PascalSrc     = Join-Path $TsPascalDir 'src\parser.c'
$PascalInclude = Join-Path $TsPascalDir 'src'

# Verify submodules are initialized
if (-not (Test-Path $TsCoreSrc)) {
    Write-Error "tree-sitter submodule not found. Run: git submodule update --init --recursive"
}
if (-not (Test-Path $PascalSrc)) {
    Write-Error "tree-sitter-pascal submodule not found. Run: git submodule update --init --recursive"
}

# Platform definitions: zig target, output file names
$AllPlatforms = [ordered]@{
    'Win32'        = @{ Target = 'x86-windows-gnu';     Core = 'tree-sitter.dll';           Pascal = 'tree-sitter-pascal.dll' }
    'Win64'        = @{ Target = 'x86_64-windows-gnu';  Core = 'tree-sitter.dll';           Pascal = 'tree-sitter-pascal.dll' }
    'Linux64'      = @{ Target = 'x86_64-linux-gnu';    Core = 'libtree-sitter.so';         Pascal = 'libtree-sitter-pascal.so' }
    'macOS-x64'    = @{ Target = 'x86_64-macos-none';   Core = 'libtree-sitter.dylib';      Pascal = 'libtree-sitter-pascal.dylib' }
    'macOS-arm64'  = @{ Target = 'aarch64-macos-none';  Core = 'libtree-sitter.dylib';      Pascal = 'libtree-sitter-pascal.dylib' }
    'Android'      = @{ Target = 'arm-linux-musleabi';     Core = 'libtree-sitter.so';       Pascal = 'libtree-sitter-pascal.so' }      # 32-bit
    'Android64'    = @{ Target = 'aarch64-linux-musl';    Core = 'libtree-sitter.so';       Pascal = 'libtree-sitter-pascal.so' }
    'iOSDevice64'  = @{ Target = 'aarch64-ios-none';      Core = 'libtree-sitter.dylib';   Pascal = 'libtree-sitter-pascal.dylib' }
}

if (-not $Platforms) {
    # iOSDevice64 excluded by default — requires Apple SDK headers (build on macOS)
    $Platforms = $AllPlatforms.Keys | Where-Object { $_ -ne 'iOSDevice64' }
}

if ($Clean) {
    foreach ($key in $AllPlatforms.Keys) {
        $dir = Join-Path $OutRoot $key
        if (Test-Path $dir) {
            Remove-Item $dir -Recurse -Force
        }
    }
    Write-Host "Cleaned platform output directories"
}

$failed = @()

foreach ($plat in $Platforms) {
    $info = $AllPlatforms[$plat]
    $outDir = Join-Path $OutRoot $plat
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    Write-Host "`n=== Building $plat ($($info.Target)) ===" -ForegroundColor Cyan

    # Build tree-sitter core
    $coreOut = Join-Path $outDir $info.Core
    Write-Host "  tree-sitter -> $($info.Core)"
    $args = @('cc', '-shared', '-o', $coreOut, $TsCoreSrc, "-I$TsCoreInclude", "-I$TsCoreSrcDir", "-target", $info.Target, '-O2')
    & zig @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED: tree-sitter for $plat" -ForegroundColor Red
        $failed += "$plat/core"
        continue
    }

    # Build tree-sitter-pascal
    $pascalOut = Join-Path $outDir $info.Pascal
    Write-Host "  tree-sitter-pascal -> $($info.Pascal)"
    $args = @('cc', '-shared', '-o', $pascalOut, $PascalSrc, "-I$PascalInclude", "-target", $info.Target, '-O2')
    & zig @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED: tree-sitter-pascal for $plat" -ForegroundColor Red
        $failed += "$plat/pascal"
        continue
    }

    Write-Host "  OK" -ForegroundColor Green
}

Write-Host ""
if ($failed.Count -gt 0) {
    Write-Host "Failed builds: $($failed -join ', ')" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All builds completed successfully." -ForegroundColor Green
    Write-Host "Output: $OutRoot"
}
