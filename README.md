# delphi-tree-sitter

<img src="Docs\Delphi-tree-sitter-512.avif" alt="Delphi-tree-sitter.avif" style="zoom:50%; float:right;" />

[Delphi](https://www.embarcadero.com/products/delphi) (and potentially [Free Pascal](https://www.freepascal.org/)) bindings for consuming [tree-sitter](https://github.com/tree-sitter/tree-sitter) grammars. Not to be confused with [tree-sitter-pascal](https://github.com/jimmckeeth/tree-sitter-pascal), the grammar allowing tree-sitter to understand Delphi's Object Pascal, Free Pascal, and similar Pascal dialects.

## Status

Actively developed and tested on **Win32**, **Win64**, and **Linux64** (via FmxLinux or console). Expansion to other Delphi-supported platforms is ongoing.

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

## Repository Organization

- [`/Source`](Source/): The core Delphi bindings and high-level wrapper classes (`TTSParser`, `TTSTree`, etc.).
- [`/Tests`](Tests/): Comprehensive DUnitX test suite for validating the bindings across platforms.
- [`/Examples`](Examples/): Interactive demo applications (VCL, FMX, Console) and automation scripts.
- [`/Libs`](Libs/): Destination for native shared libraries (`.dll`, `.so`) compiled from C/C++ grammar sources.
- [`/Packages`](Packages/): Delphi package files (`.dpk`) for installing the library into the IDE.

## Architecture & Building

This project involves two distinct build processes:

1.  **Delphi Bindings:** The code in this repository is written in Object Pascal. It is compiled using **Embarcadero Delphi** compilers to target Windows, Linux, and other platforms.
2.  **Native Libraries:** Tree-sitter core and its grammars (like `tree-sitter-pascal`) are C/C++ codebases. These must be compiled into native shared libraries (`.dll` on Windows, `.so` on Linux) that the Delphi code loads at runtime.

### Prerequisites

#### Delphi

The demos and tests require **Embarcadero Delphi** (tested with Delphi 12 Alexandria and Delphi 13).

#### Native Libraries

The library requires `tree-sitter.dll` and grammar DLLs (e.g., `tree-sitter-pascal.dll`) at runtime. You can:

1.  **Download** pre-built binaries for all supported platforms from the [GitHub Releases](https://github.com/jimmckeeth/delphi-tree-sitter/releases) page. These are compiled using our CI pipeline.
2.  **Build from source** using the [`Examples/BuildLibs.ps1`](Examples/BuildLibs.ps1) script (requires Zig).

#### Git Submodules

The repository uses submodules for the native grammar sources. Initialize them before building:

```powershell
git submodule update --init --recursive
```

#### Zig (for building native libraries)

The native libraries are cross-compiled using [Zig](https://ziglang.org). It produces optimized binaries for all target platforms from a single Windows machine.

```powershell
cd Examples
.\Prerequisites.ps1 -Install
```

## Building & Running

### 1. Build Native Libraries (Zig)

Compile the C/C++ core and grammars into shared libraries for your target platform:

```powershell
cd Examples
.\BuildLibs.ps1 -Platforms Win32,Win64,Linux64
```

### 2. Build Delphi Projects (MSBuild)

Compile the Delphi applications. The helper script auto-detects your Delphi version:

```powershell
# Build everything (Native Libs + Delphi Projects)
cd Examples
.\BuildAll.ps1

# Or build individual projects
.\Examples\DelphiBuildDPROJ.ps1 -ProjectFile Tests\TreeSitterTests.dproj
```

## Examples & Demos

Detailed information, including screenshots and usage guides for the VCL, FMX, and Console demos, can be found in the **[Examples Documentation](Examples/examples.md)**.

- **VCL Demo:** Full API explorer with treeview, node inspector, and query tester.
- **FMX Demo:** Multi-platform FireMonkey version of the tree explorer.
- **Console Demo:** Simple example of parsing `.pas` files via stream callbacks.

## Running the Tests

The test binary requires the core and Pascal grammar native libraries in its output directory:

```powershell
# Copy libs then run (Win32 example)
.\Examples\BuildLibs.ps1 -Platforms Win32
cp Libs\Win32\tree-sitter*.dll Tests\Win32\Debug\
.\Tests\Win32\Debug\TreeSitterTests.exe
```

## License

I've migrated my updates to [AGPL](license). I'm a big fan of open source. Unfortunately, I've seen too many companies take advantage of permissive licenses and turn an open source project into a closed source one. This is why I prefer AGPL. At the same time, I'm also a big fan of commercial software, which might seem incompatible. That is why I'm happy to provide a dual license. I'll set up a pricing structure later, but I just want to announce it is an option. Let me know if you are interested.
