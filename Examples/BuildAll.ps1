<#
.SYNOPSIS
    Builds all Tree-Sitter Delphi examples for all supported platforms and configurations.

.DESCRIPTION
    1. Cross-compiles native libraries (tree-sitter and tree-sitter-pascal) using zig.
    2. Builds all Delphi projects (.dproj) in the Examples directory using MSBuild.
    3. Copies native libraries to the executable output folders.
    4. Writes a build.log to the Examples directory with the full output of the run.
    5. Displays a summary table of all build results.

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
$BuildDproj = Join-Path $ScriptDir 'DelphiBuildDPROJ.ps1'
$BuildLibs = Join-Path $ScriptDir 'BuildLibs.ps1'
$LibsRoot = Join-Path $RepoRoot 'Libs'
$BinRoot = Join-Path $ScriptDir 'bin'
$LogFile = Join-Path $ScriptDir 'build.log'

# Track results for summary
$BuildResults = [System.Collections.Generic.List[PSCustomObject]]::new()

# Projects to build — only search our own directories, not submodules
$Projects = @('Examples', 'Tests', 'Packages') | ForEach-Object {
    $dir = Join-Path $RepoRoot $_
    if (Test-Path $dir) {
        Get-ChildItem -Path $dir -Filter '*.dproj' -Recurse |
            Where-Object { $_.FullName -notmatch '__history' }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Logging: write to both console and build.log simultaneously.
# ─────────────────────────────────────────────────────────────────────────────
$LogLines = [System.Collections.Generic.List[string]]::new()

function Write-Log {
    param(
        [string]$Message,
        [System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::White
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
    $script:LogLines.Add($Message)
}

function Add-Result {
    param($Project, $Platform, $Config, $Status)
    $script:BuildResults.Add([PSCustomObject]@{
        Project  = $Project
        Platform = $Platform
        Config   = $Config
        Status   = $Status
    })
}

# Truncate the log at start of each run
Set-Content -Path $LogFile -Value "Build started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Encoding UTF8

Write-Log "=== Tree-Sitter Delphi: Build All ===" -ForegroundColor Cyan
Write-Log "Repo Root: $RepoRoot"
Write-Log "Platforms: $($Platforms -join ', ')"
Write-Log "Configs:   $($Configs -join ', ')"
Write-Log "Projects:  $($Projects.Count)"
Write-Log ""

# Change to repo root to ensure consistent environment for sub-scripts
Push-Location $RepoRoot
try {
    foreach ($Platform in $Platforms) {
        Write-Log "--- Processing Platform: $Platform ---" -ForegroundColor Yellow

        # 1. Build Native Libs for this platform
        Write-Log "Building native libraries..."
        $libOutput = & $BuildLibs -Platforms $Platform 2>&1
        $libExit = $LASTEXITCODE
        foreach ($line in $libOutput) { $text = "$line"; Write-Host $text; $script:LogLines.Add($text) }

        if ($libExit -ne 0) {
            Write-Log "  FAILED: native libraries for $Platform" -ForegroundColor Red
            # Record failure for all projects for this platform
            foreach ($Config in $Configs) {
                foreach ($Project in $Projects) {
                    Add-Result -Project $Project.Name -Platform $Platform -Config $Config -Status "Failed (Native Libs)"
                }
            }
            continue
        }

        $SourceLibsDir = Join-Path $LibsRoot $Platform
        if (-not (Test-Path $SourceLibsDir)) {
            Write-Log "  WARNING: Source libraries directory not found: $SourceLibsDir" -ForegroundColor Yellow
            continue
        }
        $LibFiles = Get-ChildItem -Path $SourceLibsDir -File

        foreach ($Config in $Configs) {
            Write-Log ""
            Write-Log "Config: $Config" -ForegroundColor Gray

            foreach ($Project in $Projects) {
                # Skip VCL projects on non-Windows platforms
                if ($Platform -ne 'Win32' -and $Platform -ne 'Win64') {
                    if ($Project.Name -match 'VCL') {
                        Write-Log "  Skipping Windows-only project: $($Project.Name)" -ForegroundColor Gray
                        continue
                    }
                }

                Write-Log "Building project: $($Project.Name)..."
                # Spawn a child process so rsvars.bat PATH additions don't accumulate
                # in our process on each iteration.
                $projOutput = pwsh -NoProfile -File $BuildDproj `
                    -ProjectFile $Project.FullName -Platform $Platform -Config $Config 2>&1
                $projExit = $LASTEXITCODE
                foreach ($line in $projOutput) { $text = "$line"; Write-Host $text; $script:LogLines.Add($text) }

                if ($projExit -eq 0) {
                    # 3. Copy Native Libs to output folder
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
                        Write-Log "  Copying native libraries to: $FoundOutDir"
                        foreach ($Lib in $LibFiles) {
                            Copy-Item -Path $Lib.FullName -Destination $FoundOutDir -Force
                        }
                    } else {
                        Write-Log "  WARNING: No output directory found for $($Project.Name). Skipping library copy." -ForegroundColor Yellow
                    }
                    Add-Result -Project $Project.Name -Platform $Platform -Config $Config -Status "Success"
                } else {
                    Write-Log "  FAILED: $($Project.Name) [$Platform/$Config]" -ForegroundColor Red
                    Add-Result -Project $Project.Name -Platform $Platform -Config $Config -Status "Failed"
                }
            }
        }
        Write-Log ""
    }
}
finally {
    Pop-Location
}

Write-Log ""
Write-Log "================================================================================" -ForegroundColor Cyan
Write-Log "                                BUILD SUMMARY" -ForegroundColor Cyan
Write-Log "================================================================================" -ForegroundColor Cyan
Write-Log ""
Write-Log ("{0,-30} {1,-10} {2,-10} {3}" -f "Project", "Platform", "Config", "Status") -ForegroundColor Cyan
Write-Log ("{0,-30} {1,-10} {2,-10} {3}" -f ("-" * 29), ("-" * 9), ("-" * 9), ("-" * 10)) -ForegroundColor Cyan

# Display results in a table
foreach ($Row in $BuildResults) {
    $Color = [System.ConsoleColor]::White
    if ($Row.Status -eq "Success") { $Color = [System.ConsoleColor]::Green }
    elseif ($Row.Status -match "Failed") { $Color = [System.ConsoleColor]::Red }

    $msg = "{0,-30} {1,-10} {2,-10} {3}" -f $Row.Project, $Row.Platform, $Row.Config, $Row.Status
    Write-Log $msg -ForegroundColor $Color
}

Write-Log ""
$Total = @($BuildResults).Count
$Succeeded = @($BuildResults | Where-Object { $_.Status -eq "Success" }).Count
$Failed = @($BuildResults | Where-Object { $_.Status -match "Failed" }).Count

Write-Log "Summary: $Total total, $Succeeded succeeded, $Failed failed" -ForegroundColor Cyan
Write-Log ""

Write-Log "Build All process finished: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green

# Flush all captured output to the log file
Add-Content -Path $LogFile -Value ($LogLines -join "`n") -Encoding UTF8
Write-Host ""
Write-Host "Log written to: $LogFile" -ForegroundColor DarkGray
