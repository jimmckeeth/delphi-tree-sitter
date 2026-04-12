# Examples

Delphi demo projects and build scripts for delphi-tree-sitter.

## Demo Projects

| Project                                                          | Description                                                                                   |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| [Console/ConsoleReadPasFile.dpr](Console/ConsoleReadPasFile.dpr) | Console app that parses a `.pas` file using `TTSParser.Parse` with an anonymous read callback |
| VCL/                                                             | Interactive explorer for the tree-sitter API — treeview, node inspector, query form           |
| FMX/                                                             | FireMonkey version of the explorer                                                            |

## Build Scripts

The demo projects require native shared libraries (`tree-sitter` core + `tree-sitter-pascal` grammar) to run. Two PowerShell scripts automate building these from source using the [Zig](https://ziglang.org) cross-compiler.

### Prerequisites.ps1

Validates that all build requirements are met and offers to install anything missing.

```powershell
# Check prerequisites (interactive — prompts before installing)
.\Prerequisites.ps1

# Auto-install without prompting
.\Prerequisites.ps1 -Install
```

**What it checks:**

- **git** — required for submodule initialization
- **zig** — the C cross-compiler used to build the shared libraries. Offers to install via `winget` if missing
- **Submodules** — `tree-sitter-pascal` and its nested `tree-sitter` submodule. Offers to run `git submodule update --init --recursive` if not initialized

### BuildLibs.ps1

Cross-compiles `tree-sitter` and `tree-sitter-pascal` shared libraries for all Delphi-supported platforms. Output goes to `Libs/<platform>/`.

```powershell
# Build all platforms (excludes iOSDevice64 by default)
.\BuildLibs.ps1

# Build specific platforms only
.\BuildLibs.ps1 -Platforms Win32,Win64

# Clean previous output and rebuild
.\BuildLibs.ps1 -Clean
```

**Supported platforms:**

| Platform    | Zig Target         | Output Files                                          |
| ----------- | ------------------ | ----------------------------------------------------- |
| Win32       | x86-windows-gnu    | `tree-sitter.dll`, `tree-sitter-pascal.dll`           |
| Win64       | x86_64-windows-gnu | `tree-sitter.dll`, `tree-sitter-pascal.dll`           |
| Linux64     | x86_64-linux-gnu   | `libtree-sitter.so`, `libtree-sitter-pascal.so`       |
| macOS-x64   | x86_64-macos-none  | `libtree-sitter.dylib`, `libtree-sitter-pascal.dylib` |
| macOS-arm64 | aarch64-macos-none | `libtree-sitter.dylib`, `libtree-sitter-pascal.dylib` |
| Android     | arm-linux-musleabi | `libtree-sitter.so`, `libtree-sitter-pascal.so`       |
| Android64   | aarch64-linux-musl | `libtree-sitter.so`, `libtree-sitter-pascal.so`       |
| iOSDevice64 | aarch64-ios-none   | `libtree-sitter.dylib`, `libtree-sitter-pascal.dylib` |

> **Note:** iOSDevice64 requires Apple SDK headers and must be built on macOS. It is excluded from the default build.

### Quick Start

```powershell
cd Examples
.\Prerequisites.ps1 -Install
.\BuildLibs.ps1 -Platforms Win32
copy ..\Libs\Win32\*.dll bin\Win32\Release\
```
