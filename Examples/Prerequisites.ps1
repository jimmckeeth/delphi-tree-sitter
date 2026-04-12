<#
.SYNOPSIS
    Validates and optionally installs prerequisites for BuildLibs.ps1.

.DESCRIPTION
    Checks that zig and git are available, and that submodules (tree-sitter-pascal
    and its nested tree-sitter) are initialized. Offers to install zig via winget
    if missing, and initializes submodules if needed.

.PARAMETER Install
    Automatically install missing prerequisites without prompting.

.EXAMPLE
    .\Prerequisites.ps1
    .\Prerequisites.ps1 -Install
#>
param(
    [switch]$Install
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot    = Split-Path $PSScriptRoot -Parent
$TsPascalDir = Join-Path $RepoRoot 'tree-sitter-pascal'
$TsCoreDir   = Join-Path $TsPascalDir 'tree-sitter'
$allGood     = $true

function Write-Status($label, $ok, $detail) {
    if ($ok) {
        Write-Host "  [OK] $label" -ForegroundColor Green -NoNewline
    } else {
        Write-Host "  [--] $label" -ForegroundColor Red -NoNewline
    }
    if ($detail) { Write-Host " — $detail" } else { Write-Host }
}

function Confirm-Action($message) {
    if ($Install) { return $true }
    $response = Read-Host "$message (Y/n)"
    return ($response -eq '' -or $response -match '^[Yy]')
}

Write-Host "Checking prerequisites for BuildLibs..." -ForegroundColor Cyan
Write-Host

# --- Git ---
$gitPath = Get-Command git -ErrorAction SilentlyContinue
if ($gitPath) {
    $gitVersion = & git --version 2>&1
    Write-Status 'git' $true $gitVersion
} else {
    Write-Status 'git' $false 'not found — install from https://git-scm.com'
    $allGood = $false
}

# --- Zig ---
$zigPath = Get-Command zig -ErrorAction SilentlyContinue
if ($zigPath) {
    $zigVersion = & zig version 2>&1
    Write-Status 'zig' $true "v$zigVersion ($($zigPath.Source))"
} else {
    Write-Status 'zig' $false 'not found'
    $allGood = $false

    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetPath) {
        if (Confirm-Action 'Install zig via winget?') {
            Write-Host '  Installing zig...' -ForegroundColor Yellow
            & winget install zig.zig --accept-package-agreements --accept-source-agreements 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host '  Installed. Restart your terminal so zig is on PATH.' -ForegroundColor Yellow
            } else {
                Write-Host '  winget install failed. Install manually from https://ziglang.org/download/' -ForegroundColor Red
            }
        } else {
            Write-Host '  Install manually: winget install zig.zig  or  https://ziglang.org/download/' -ForegroundColor Yellow
        }
    } else {
        Write-Host '  Install from https://ziglang.org/download/ and add to PATH' -ForegroundColor Yellow
    }
}

# --- Submodules ---
Write-Host

$pascalOk = Test-Path (Join-Path $TsPascalDir 'src\parser.c')
if ($pascalOk) {
    Write-Status 'tree-sitter-pascal' $true 'submodule present'
} else {
    Write-Status 'tree-sitter-pascal' $false 'submodule not initialized'
    $allGood = $false
}

$coreOk = Test-Path (Join-Path $TsCoreDir 'lib\src\lib.c')
if ($coreOk) {
    Write-Status 'tree-sitter (nested)' $true 'submodule present'
} else {
    Write-Status 'tree-sitter (nested)' $false 'submodule not initialized'
    $allGood = $false
}

if ((-not $pascalOk -or -not $coreOk) -and $gitPath) {
    if (Confirm-Action 'Initialize submodules?') {
        Write-Host '  Running git submodule update --init --recursive...' -ForegroundColor Yellow
        Push-Location $RepoRoot
        & git submodule update --init --recursive 2>&1
        Pop-Location
        if ($LASTEXITCODE -eq 0) {
            Write-Host '  Submodules initialized.' -ForegroundColor Green
            $allGood = $true  # re-evaluate below
        } else {
            Write-Host '  Failed to initialize submodules.' -ForegroundColor Red
        }
    }
}

# --- Summary ---
Write-Host
if ($allGood) {
    Write-Host 'All prerequisites met. Run .\BuildLibs.ps1 to build.' -ForegroundColor Green
} else {
    Write-Host 'Some prerequisites are missing. Resolve the issues above and re-run.' -ForegroundColor Yellow
    exit 1
}
