<#
.SYNOPSIS
    Builds all Tree-Sitter Delphi examples for all supported platforms and configurations.

.DESCRIPTION
    1. Cross-compiles native libraries (tree-sitter and tree-sitter-pascal) using zig.
    2. Builds all Delphi projects (.dproj) in the Examples directory using MSBuild.
    3. Copies native libraries to the executable output folders.

.PARAMETER Platforms
    Platforms to build. Defaults to Win32, Win64, Linux64.
    Others (macOS, Android, iOS) are currently disabled/commented out.

.PARAMETER Configs
    Configurations to build. Defaults to Debug, Release.
#>
param(
    [string[]]$Platforms = @('Win32', 'Win64', 'Linux64'),
    [string[]]$Configs = @('Debug', 'Release')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Ensure we have absolute paths regardless of where the script is called from
$ScriptDir = Get-Item $PSScriptRoot | Select-Object -ExpandProperty FullName
$RepoRoot = Get-Item "$ScriptDir\.." | Select-Object -ExpandProperty FullName
$BuildDproj = Join-Path $RepoRoot 'DelphiBuildDPROJ.ps1'
$BuildLibs = Join-Path $ScriptDir 'BuildLibs.ps1'
$LibsRoot = Join-Path $RepoRoot 'Libs'
$BinRoot = Join-Path $ScriptDir 'bin'

# All possible platforms (for reference and future enabling)
$AvailablePlatforms = @(
    'Win32',
    'Win64',
    'Linux64'
    # 'macOS-x64',
    # 'macOS-arm64',
    # 'Android',
    # 'Android64',
    # 'iOSDevice64'
)

# Projects to build
$Projects = Get-ChildItem -Path $RepoRoot -Filter "*.dproj" -Recurse | Where-Object { $_.FullName -notmatch '__history' }

Write-Host "=== Tree-Sitter Delphi: Build All ===" -ForegroundColor Cyan
Write-Host "Repo Root: $RepoRoot"
Write-Host "Platforms: $($Platforms -join ', ')"
Write-Host "Configs:   $($Configs -join ', ')"
Write-Host "Projects:  $($Projects.Count)"
Write-Host ""

# Change to repo root to ensure consistent environment for sub-scripts
Push-Location $RepoRoot
try {
    foreach ($Platform in $Platforms) {
        Write-Host "--- Processing Platform: $Platform ---" -ForegroundColor Yellow
        
        # 1. Build Native Libs for this platform
        Write-Host "Building native libraries..."
        & $BuildLibs -Platforms $Platform
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to build native libraries for $Platform"
            continue
        }

        $SourceLibsDir = Join-Path $LibsRoot $Platform
        if (-not (Test-Path $SourceLibsDir)) {
            Write-Warning "Source libraries directory not found: $SourceLibsDir"
            continue
        }
        $LibFiles = Get-ChildItem -Path $SourceLibsDir -File

        foreach ($Config in $Configs) {
            Write-Host "`nConfig: $Config" -ForegroundColor Gray
            
            foreach ($Project in $Projects) {
                # Skip VCL projects on non-Windows platforms
                if ($Platform -ne 'Win32' -and $Platform -ne 'Win64') {
                    if ($Project.Name -match 'VCL') {
                        Write-Host "Skipping Windows-only project: $($Project.Name)" -ForegroundColor Gray
                        continue
                    }
                }

                Write-Host "Building project: $($Project.Name)..."
                # 2. Build Delphi Project
                # Spawn a child process so rsvars.bat PATH additions don't accumulate
                # in our process on each iteration.
                pwsh -NoProfile -File $BuildDproj `
                    -ProjectFile $Project.FullName -Platform $Platform -Config $Config

                if ($LASTEXITCODE -eq 0) {
                    # 3. Copy Native Libs to output folder
                    # Try several common output locations
                    $ProjDir = Split-Path $Project.FullName -Parent
                    $PossibleOutDirs = @(
                        (Join-Path $BinRoot "$Platform\$Config"),
                        (Join-Path $ProjDir "bin\$Platform\$Config"),
                        (Join-Path $ProjDir "$Platform\$Config"),
                        (Join-Path $ProjDir "..\bin\$Platform\$Config"),
                        (Join-Path $RepoRoot "bin\$Platform\$Config")
                    )

                    $FoundOutDir = $null
                    foreach ($Dir in $PossibleOutDirs) {
                        if (Test-Path $Dir) {
                            $FoundOutDir = $Dir
                            Break
                        }
                    }

                    if ($FoundOutDir) {
                        Write-Host "  Copying native libraries to: $FoundOutDir"
                        foreach ($Lib in $LibFiles) {
                            Copy-Item -Path $Lib.FullName -Destination $FoundOutDir -Force
                        }
                    } else {
                        Write-Warning "  No output directory found for $($Project.Name). Skipping library copy."
                    }
                } else {
                    Write-Host "  FAILED to build project $($Project.Name)" -ForegroundColor Red
                }
            }
        }
        Write-Host ""
    }
}
finally {
    Pop-Location
}

Write-Host "Build All process finished." -ForegroundColor Green
