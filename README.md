# delphi-tree-sitter

<img src="Docs\Delphi-tree-sitter-512.avif" alt="Delphi-tree-sitter.avif" style="zoom:50%; float:right;" />
Delphi (and potentially Free Pascal) bindings for consuming [tree-sitter](https://github.com/tree-sitter/tree-sitter) grammar. Not to be confused with [tree-sitter-pascal](https://github.com/jimmckeeth/tree-sitter-pascal), the grammar allowing tree-sitter to understand Delphi's Object Pascal, Free Pascal, and similar Pascal dialects.

## Status

Windows only for now and only tested with Delphi, but expanding to other platforms.

| API section             | Status          |
| ----------------------- | --------------- |
| Parser                  | Basics covered  |
| Language                | Mostly complete |
| Tree                    | Mostly complete |
| TreeCursor              | Mostly complete |
| Node                    | Mostly complete |
| Query                   | Mostly complete |
| QueryCursor             | Mostly complete |
| LookAheadIterator       | Missing         |
| WebAssembly Integration | Missing         |

## Prerequisites

### Delphi

The demos and tests require **Embarcadero Delphi** (tested with Delphi 12 Alexandria / BDS 23.0 and Delphi 13 / BDS 37.0). No design-time packages or third-party components are required.

### Native DLLs

The library loads `tree-sitter.dll` and grammar DLLs (e.g. `tree-sitter-pascal.dll`) at runtime. The DLLs must be placed alongside the compiled executable before running. You can obtain them by:

1. **Building from source** using the [`Examples/BuildLibs.ps1`](#building-the-native-libraries) script (recommended — see below).
2. **Downloading** pre-built binaries from the [GitHub Releases](https://github.com/jimmckeeth/delphi-tree-sitter/releases) page, where the CI workflow publishes DLLs for each supported platform.

### Git Submodules

The repository uses submodules for the tree-sitter core library and the Pascal grammar. Initialize them before building:

```powershell
git submodule update --init --recursive
```

### Zig (for building DLLs)

The build script uses [Zig](https://ziglang.org) as a cross-compiler to produce DLLs for all target platforms from a single machine. Install the latest stable release and ensure `zig` is on your `PATH`. Alternatively, run the helper script which will download Zig automatically:

```powershell
cd Examples
.\Prerequisites.ps1 -Install
```

## Building the Native Libraries

All native DLLs are built by `Examples/BuildLibs.ps1`. It compiles the tree-sitter core library and the Pascal grammar for every requested platform using Zig.

```powershell
# Build for Win32 and Win64 only (most common)
cd Examples
.\BuildLibs.ps1 -Platforms Win32,Win64

# Build for all supported platforms (excludes iOSDevice64 by default)
.\BuildLibs.ps1

# Clean previous outputs first
.\BuildLibs.ps1 -Clean -Platforms Win32,Win64
```

Output is written to `Libs/<platform>/`, e.g. `Libs/Win32/tree-sitter.dll` and `Libs/Win32/tree-sitter-pascal.dll`.

After building, copy the DLLs for your target platform into the output directory of the executable you want to run:

```powershell
# Tests (Win32 Debug)
cp Libs\Win32\tree-sitter*.dll Tests\Win32\Debug\

# VCL / FMX demos (Win32 Debug)
cp Libs\Win32\tree-sitter*.dll Examples\bin\Win32\Debug\
```

### Additional Grammar DLLs

The demos support multiple languages (C, Python, TypeScript, JavaScript, JSON). Their grammar DLLs must also be present. The CI workflow builds and publishes them automatically for each release. To build them locally, clone the individual grammar repositories and compile `src/parser.c` against the tree-sitter core headers using Zig:

```powershell
# Example: build tree-sitter-c for Win32
$TsCoreInclude = "tree-sitter-pascal\tree-sitter\lib\include"
zig cc -shared -o Libs\Win32\tree-sitter-c.dll `
    path\to\tree-sitter-c\src\parser.c `
    -Ipath\to\tree-sitter-c\src `
    -I$TsCoreInclude `
    -target x86-windows-gnu -O2
```

## Installation

No design-time packages etc. necessary. The demos with GUI - as of yet - do not require any additional 3rd party packages.

To run the demos, you need to have `tree-sitter.dll` (of the right architecture) somewhere, where the EXE will be able to find it (it won't even start without).

For the different parsers (sometimes called grammars) you need a DLL too, e.g. [tree-sitter-c][]

If you don't have a C compiler setup at hand to compile the tree-sitter DLLs, I can highly recommend [zig][].

Tree-sitter itself already comes with a `build.zig` file, so running `zig build` in the root directory of tree-sitter will work.
This might build a .lib instead of a `.dll`, so in `build.zig` you would need to change `b.addStaticLibrary` into `b.addSharedLibrary`.

Most parsers do not seem to come with zig-support out of the box, but it should be straightforward to create a `build.zig` and use the one from tree-sitter itself as a template.

[tree-sitter-c]: https://github.com/tree-sitter/tree-sitter-c
[zig]: https://ziglang.org

## Building the Delphi Projects

All Delphi projects are built with the `DelphiBuildDPROJ.ps1` helper script at the repo root, which auto-detects the installed Delphi version via the Windows registry. **Default platform is Win32.**

```powershell
# Test suite
.\DelphiBuildDPROJ.ps1 -ProjectFile Tests\TreeSitterTests.dproj

# VCL demo
.\DelphiBuildDPROJ.ps1 -ProjectFile Examples\VCL\DelphiTreeSitterVCLDemo.dproj

# FMX demo
.\DelphiBuildDPROJ.ps1 -ProjectFile Examples\FMX\DelphiTreeSitterFMXDemo.dproj

# Console demo
.\DelphiBuildDPROJ.ps1 -ProjectFile Examples\Console\ConsoleReadPasFile.dproj
```

## Running the Tests

The test binary requires the core and Pascal grammar DLLs in the same directory:

```powershell
cp Libs\Win32\tree-sitter*.dll Tests\Win32\Debug\
.\Tests\Win32\Debug\TreeSitterTests.exe --exit:continue
```

All 109 tests across 11 fixtures should pass. Run a single fixture with:

```powershell
.\Tests\Win32\Debug\TreeSitterTests.exe --fixture:TParserTests --exit:continue
```

## VCL demo project

Instead of demoing a typical use-case, the VCL demo is intended to allow exploring the API and functionality that tree-sitter supplies.
![image](https://github.com/modersohn/delphi-tree-sitter/assets/44807458/27319bec-f3b6-4a67-8329-f67cc7d9d079)

Currently supports a handful of languages out of the box and a treeview of nodes with field name and ID where applicable. Selects the corresponding code part in the memo when a node gets selected.

Inspector-like grid with node properties. Navigation via popup menu of the tree. Lists field names of the language and allows finding child node by field ID.

Now with secondary form listing symbols, fields and version of the language:
![image](https://github.com/modersohn/delphi-tree-sitter/assets/44807458/1243f2fe-ca26-4658-a24e-55ab11c5c153)

New query form, showing info about the query and allowing iterating over matches and listing their captures. Selecting a capture, selects the captured node in the main form and selects the corresponding code section:
![image](https://github.com/modersohn/delphi-tree-sitter/assets/44807458/ac2cba4f-06b2-4a02-8bb4-d02f5adac857)

## Console demo project loading .pas

[Simple console project](ConsoleReadPasFile.dpr) which demonstrates TTSParser.Parse called with an anonymous method for reading the text to parse.
