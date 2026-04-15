<#
.SYNOPSIS
    Builds tree-sitter and grammar shared libraries for all Delphi-supported
    platforms using the Zig cross-compiler, then deploys them to the Delphi
    output directories so projects can be run immediately after building.

.DESCRIPTION
    1. Compiles tree-sitter core and tree-sitter-pascal from submodule sources.
    2. Optionally builds extra grammar DLLs (C, Python, TypeScript, JavaScript,
       JSON) by cloning their repos into GrammarsCache/.
    3. Copies all built libraries to:
         Libs/<platform>/              - canonical output (used for releases)
         Examples/bin/<platform>/Debug/
         Examples/bin/<platform>/Release/
         Tests/<platform>/Debug/       (Win32 and Win64 only)

.PARAMETER Platforms
    One or more platform names to build. Defaults to all desktop platforms.
    Valid: Win32, Win64, Linux64, macOS-x64, macOS-arm64, Android, Android64,
           iOSDevice64

.PARAMETER Clean
    Remove Libs/<platform>/ output directories before building.

.PARAMETER Grammars
    Also build extra language grammar DLLs (C, Python, TypeScript, JavaScript,
    JSON). Clones repos into GrammarsCache/ on first run.

.PARAMETER GrammarsCache
    Directory where grammar repos are cloned/cached.
    Defaults to <RepoRoot>/GrammarsCache.

.NOTES
    Requires zig (https://ziglang.org) on PATH.
    Run Prerequisites.ps1 first to install Zig if needed.
    iOSDevice64 requires Apple SDK headers; build on macOS only.

.EXAMPLE
    .\BuildLibs.ps1 -Platforms Win32,Win64
    .\BuildLibs.ps1 -Platforms Win32,Win64 -Grammars
    .\BuildLibs.ps1 -Clean -Grammars
#>
param(
    [ValidateSet('Win32','Win64','Linux64','macOS-x64','macOS-arm64','Android','Android64','iOSDevice64')]
    [string[]]$Platforms,
    [switch]$Clean,
    [switch]$Grammars,
    [string]$GrammarsCache = ''
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

if ($GrammarsCache -eq '') {
    $GrammarsCache = Join-Path $RepoRoot 'GrammarsCache'
}

# Verify submodules are initialized
if (-not (Test-Path $TsCoreSrc)) {
    Write-Error "tree-sitter submodule not found. Run: git submodule update --init --recursive"
}
if (-not (Test-Path $PascalSrc)) {
    Write-Error "tree-sitter-pascal submodule not found. Run: git submodule update --init --recursive"
}

# Platform definitions: zig target, output file names
$AllPlatforms = [ordered]@{
    'Win32'       = @{ Target = 'x86-windows-gnu';    Core = 'tree-sitter.dll';         Pascal = 'tree-sitter-pascal.dll'     }
    'Win64'       = @{ Target = 'x86_64-windows-gnu'; Core = 'tree-sitter.dll';         Pascal = 'tree-sitter-pascal.dll'     }
    'Linux64'     = @{ Target = 'x86_64-linux-gnu';   Core = 'libtree-sitter.so';       Pascal = 'libtree-sitter-pascal.so'   }
    'macOS-x64'   = @{ Target = 'x86_64-macos-none';  Core = 'libtree-sitter.dylib';    Pascal = 'libtree-sitter-pascal.dylib'}
    'macOS-arm64' = @{ Target = 'aarch64-macos-none'; Core = 'libtree-sitter.dylib';    Pascal = 'libtree-sitter-pascal.dylib'}
    'Android'     = @{ Target = 'arm-linux-musleabi'; Core = 'libtree-sitter.so';       Pascal = 'libtree-sitter-pascal.so'   }
    'Android64'   = @{ Target = 'aarch64-linux-musl'; Core = 'libtree-sitter.so';       Pascal = 'libtree-sitter-pascal.so'   }
    'iOSDevice64' = @{ Target = 'aarch64-ios-none';   Core = 'libtree-sitter.dylib';    Pascal = 'libtree-sitter-pascal.dylib'}
}

# Extra grammar repos.
# SrcSubDir: subdirectory inside the cloned repo containing parser.c.
# Grammars with scanner.c / scanner.cc have those compiled in automatically.
$ExtraGrammars = [ordered]@{
    'c'          = @{ Repo = 'tree-sitter/tree-sitter-c';          SrcSubDir = 'src'            }
    'python'     = @{ Repo = 'tree-sitter/tree-sitter-python';     SrcSubDir = 'src'            }
    'javascript' = @{ Repo = 'tree-sitter/tree-sitter-javascript'; SrcSubDir = 'src'            }
    'json'       = @{ Repo = 'tree-sitter/tree-sitter-json';       SrcSubDir = 'src'            }
    'typescript' = @{ Repo = 'tree-sitter/tree-sitter-typescript'; SrcSubDir = 'typescript/src' }
}

if (-not $Platforms) {
    $Platforms = $AllPlatforms.Keys | Where-Object { $_ -ne 'iOSDevice64' }
}

if ($Clean) {
    foreach ($key in $AllPlatforms.Keys) {
        $dir = Join-Path $OutRoot $key
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
    }
    Write-Host "Cleaned platform output directories." -ForegroundColor Yellow
}

# ─────────────────────────────────────────────────────────────────────────────
# Get the library filename for a grammar on a given platform.
# Uses the same prefix/extension convention as the core/pascal libs.
# ─────────────────────────────────────────────────────────────────────────────
function Get-GrammarLibName([string]$Lang, [hashtable]$PlatInfo) {
    $core = $PlatInfo.Core
    if ($core -like '*.dll')   { return "tree-sitter-$Lang.dll"          }
    if ($core -like '*.dylib') { return "libtree-sitter-$Lang.dylib"     }
    return "libtree-sitter-$Lang.so"
}

# ─────────────────────────────────────────────────────────────────────────────
# Clone a grammar repo into GrammarsCache (no-op if already present).
# ─────────────────────────────────────────────────────────────────────────────
function Ensure-GrammarRepo([string]$Lang, [string]$Repo) {
    $dest = Join-Path $GrammarsCache $Lang
    if (Test-Path (Join-Path $dest '.git')) {
        Write-Host "    [cached] $Lang" -ForegroundColor DarkGray
        return $true
    }
    Write-Host "    Cloning $Repo ..."
    & git clone --depth 1 "https://github.com/$Repo.git" $dest 2>&1
    return ($LASTEXITCODE -eq 0)
}

# ─────────────────────────────────────────────────────────────────────────────
# Build one extra grammar for one platform.
# Automatically includes scanner.c / scanner.cc alongside parser.c.
# ─────────────────────────────────────────────────────────────────────────────
function Build-Grammar([string]$Lang, [string]$SrcSubDir, [string]$OutDir, [hashtable]$PlatInfo) {
    $repoDir = Join-Path $GrammarsCache $Lang
    $srcDir  = Join-Path $repoDir (($SrcSubDir -replace '/', [System.IO.Path]::DirectorySeparatorChar))
    $parser  = Join-Path $srcDir 'parser.c'
    if (-not (Test-Path $parser)) {
        Write-Warning "    No parser.c at $srcDir — skipping $Lang"
        return $false
    }

    $sources = [System.Collections.Generic.List[string]]::new()
    $sources.Add($parser)

    # Include external scanner if present (C or C++)
    $scannerC  = Join-Path $srcDir 'scanner.c'
    $scannerCC = Join-Path $srcDir 'scanner.cc'
    if (Test-Path $scannerC)  { $sources.Add($scannerC);  Write-Host "      + scanner.c"  -ForegroundColor DarkGray }
    if (Test-Path $scannerCC) { $sources.Add($scannerCC); Write-Host "      + scanner.cc" -ForegroundColor DarkGray }

    $outFile = Get-GrammarLibName $Lang $PlatInfo
    $outPath = Join-Path $OutDir $outFile
    Write-Host "    $Lang -> $outFile"

    $args = @('cc', '-shared', '-o', $outPath) `
          + $sources.ToArray() `
          + @("-I$srcDir", "-I$TsCoreInclude", '-target', $PlatInfo.Target, '-O2')

    & zig @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    FAILED: $Lang ($($PlatInfo.Target))" -ForegroundColor Red
        return $false
    }
    return $true
}

# ─────────────────────────────────────────────────────────────────────────────
# Copy all .dll / .so / .dylib from SrcDir to Delphi output directories.
# Only Win32 and Win64 have corresponding Delphi compiler outputs.
# ─────────────────────────────────────────────────────────────────────────────
function Deploy-Libs([string]$Plat, [string]$SrcDir) {
    $platMap = @{ 'Win32' = 'Win32'; 'Win64' = 'Win64' }
    if (-not $platMap.ContainsKey($Plat)) { return }
    $dp = $platMap[$Plat]

    # Collect the native lib extension for this platform
    $ext = switch -Wildcard ($AllPlatforms[$Plat].Core) {
        '*.dll'   { '*.dll'   }
        '*.dylib' { '*.dylib' }
        default   { '*.so'    }
    }

    $libs = @(Get-ChildItem $SrcDir -Filter $ext -ErrorAction SilentlyContinue)
    if ($libs.Count -eq 0) { return }

    $targets = @(
        "$RepoRoot\Examples\bin\$dp\Debug",
        "$RepoRoot\Examples\bin\$dp\Release",
        "$RepoRoot\Tests\$dp\Debug",
        "$RepoRoot\Tests\$dp\Release"
    )

    foreach ($dir in $targets) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        foreach ($lib in $libs) {
            Copy-Item $lib.FullName (Join-Path $dir $lib.Name) -Force
        }
        Write-Host "  -> $dir" -ForegroundColor DarkGray
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Main build loop
# ─────────────────────────────────────────────────────────────────────────────
$failed = [System.Collections.Generic.List[string]]::new()

foreach ($plat in $Platforms) {
    $info   = $AllPlatforms[$plat]
    $outDir = Join-Path $OutRoot $plat
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    Write-Host "`n=== Building $plat ($($info.Target)) ===" -ForegroundColor Cyan

    # ── tree-sitter core ──────────────────────────────────────────────────────
    $coreOut = Join-Path $outDir $info.Core
    Write-Host "  core -> $($info.Core)"
    $args = @('cc', '-shared', '-o', $coreOut, $TsCoreSrc,
              "-I$TsCoreInclude", "-I$TsCoreSrcDir", '-target', $info.Target, '-O2')
    & zig @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED: core" -ForegroundColor Red
        $failed.Add("$plat/core"); continue
    }

    # ── tree-sitter-pascal ────────────────────────────────────────────────────
    $pascalOut = Join-Path $outDir $info.Pascal
    Write-Host "  pascal -> $($info.Pascal)"
    $args = @('cc', '-shared', '-o', $pascalOut, $PascalSrc,
              "-I$PascalInclude", '-target', $info.Target, '-O2')
    & zig @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED: pascal" -ForegroundColor Red
        $failed.Add("$plat/pascal"); continue
    }

    # ── extra grammars ────────────────────────────────────────────────────────
    if ($Grammars) {
        Write-Host "  Extra grammars:"
        if (-not (Test-Path $GrammarsCache)) {
            New-Item -ItemType Directory -Path $GrammarsCache -Force | Out-Null
        }
        foreach ($lang in $ExtraGrammars.Keys) {
            $g = $ExtraGrammars[$lang]
            if (-not (Ensure-GrammarRepo $lang $g.Repo)) {
                Write-Host "    FAILED to clone $lang" -ForegroundColor Red
                $failed.Add("$plat/$lang-clone"); continue
            }
            if (-not (Build-Grammar $lang $g.SrcSubDir $outDir $info)) {
                $failed.Add("$plat/$lang")
            }
        }
    }

    Write-Host "  OK" -ForegroundColor Green

    # ── deploy to Delphi output directories ───────────────────────────────────
    Deploy-Libs $plat $outDir
}

Write-Host ""
if ($failed.Count -gt 0) {
    Write-Host "Failed builds: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "All builds completed successfully." -ForegroundColor Green
    Write-Host "Output: $OutRoot"
}
