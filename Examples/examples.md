# Examples

Delphi demo projects and build scripts for `delphi-tree-sitter`.

## Demo Projects

### [VCL API Explorer](vcl/DelphiTreeSitterVCLDemo.dproj)

The VCL demo is a comprehensive API explorer designed to allow builders to investigate the functionality supplied by the tree-sitter bindings.

![VCL Main Explorer](https://github.com/modersohn/delphi-tree-sitter/assets/44807458/27319bec-f3b6-4a67-8329-f67cc7d9d079)

**Key Features:**
- **Interactive TreeView:** Browse the full syntax tree. Nodes show field names and IDs where applicable.
- **Source Selection:** Selecting a node in the tree automatically highlights the corresponding code in the editor.
- **Node Inspector:** A detailed grid showing all properties of the currently selected node (type, symbol, range, etc.).
- **Language Metadata:** A secondary form lists all symbols and fields defined by the loaded grammar.

![VCL Language Info](https://github.com/modersohn/delphi-tree-sitter/assets/44807458/1243f2fe-ca26-4658-a24e-55ab11c5c153)

- **Query Tester:** Write and execute tree-sitter queries. Iterates over matches and lists captures. Selecting a capture highlights it in both the tree and the source code.

![VCL Query Tester](https://github.com/modersohn/delphi-tree-sitter/assets/44807458/ac2cba4f-06b2-4a02-8bb4-d02f5adac857)

### [FMX Tree Explorer](fmx/DelphiTreeSitterFMXDemo.dproj)

A FireMonkey version of the explorer, supporting multi-platform deployment (Windows and Linux via FmxLinux). It provides a simplified version of the tree-browsing and source-highlighting functionality found in the VCL demo.

### [Console Read Pas File](Console/ConsoleReadPasFile.dpr)

A simple console application that demonstrates how to parse a `.pas` file using `TTSParser.Parse` with an anonymous method callback for reading the text stream.

---

## Build Scripts

Building the examples involves two phases: compiling the native C/C++ libraries (Zig) and then compiling the Delphi applications (MSBuild).

### [Prerequisites.ps1](Prerequisites.ps1)

Validates that all build requirements are met and offers to install missing tools.

```powershell
# Check prerequisites (interactive)
.\Prerequisites.ps1

# Auto-install missing tools (zig, git submodules)
.\Prerequisites.ps1 -Install
```

### [BuildLibs.ps1](BuildLibs.ps1)

Cross-compiles the `tree-sitter` core and `tree-sitter-pascal` grammars into native shared libraries (`.dll`, `.so`, `.dylib`) for all supported platforms.

```powershell
# Build for specific platforms
.\BuildLibs.ps1 -Platforms Win32,Win64,Linux64

# Clean and rebuild all
.\BuildLibs.ps1 -Clean
```

| Platform    | Zig Target         | Output Files                                          |
| ----------- | ------------------ | ----------------------------------------------------- |
| Win32       | x86-windows-gnu    | `tree-sitter.dll`, `tree-sitter-pascal.dll`           |
| Win64       | x86_64-windows-gnu | `tree-sitter.dll`, `tree-sitter-pascal.dll`           |
| Linux64     | x86_64-linux-gnu   | `libtree-sitter.so`, `libtree-sitter-pascal.so`       |

### [BuildAll.ps1](BuildAll.ps1)

The master orchestration script. It builds all native libraries for the requested platforms and then compiles every Delphi project using MSBuild.

**Features:**
- **Full Automation:** Runs `BuildLibs.ps1` followed by the Delphi build script.
- **Result Tracking:** Keeps track of every project/platform/config combination.
- **Summary Report:** Displays a formatted table at the end showing which builds succeeded or failed.

```powershell
# Build everything for default platforms
.\BuildAll.ps1

# Target specific configurations
.\BuildAll.ps1 -Platforms Win64,Linux64 -Configs Release
```

---

## Quick Start

To build and run the VCL demo on Windows:

1.  **Initialize Submodules:** `git submodule update --init --recursive`
2.  **Install Zig:** `cd Examples; .\Prerequisites.ps1 -Install`
3.  **Build Everything:** `.\BuildAll.ps1 -Platforms Win32`
4.  **Run:** Open `Examples\bin\Win32\Debug\DelphiTreeSitterVCLDemo.exe`
