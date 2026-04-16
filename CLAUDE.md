# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Delphi bindings for the [tree-sitter](https://tree-sitter.github.io/tree-sitter/) incremental parsing library. The `Source/` units provide a thin Delphi wrapper over tree-sitter's C API (loaded dynamically at runtime). `Examples/` contains demo applications. `Tests/` has exhaustive DUnitX tests.

The repo also contains `tree-sitter-pascal/` as a submodule — that is the _grammar_ (JS/C) for parsing Pascal/Delphi source, not these Delphi bindings.

## Build Commands

All builds use the `Examples\DelphiBuildDPROJ.ps1` script. **Default platform is Win32** (not Win64) unless specified.

```powershell
# Test project
.\Examples\DelphiBuildDPROJ.ps1 -ProjectFile Tests\TreeSitterTests.dproj -Config Debug -Platform Win32

# VCL demo
.\Examples\DelphiBuildDPROJ.ps1 -ProjectFile Examples\VCL\DelphiTreeSitterVCLDemo.dproj -Config Debug -Platform Win32

# FMX demo
.\Examples\DelphiBuildDPROJ.ps1 -ProjectFile Examples\FMX\DelphiTreeSitterFMXDemo.dproj -Config Debug -Platform Win32

# Console demo
.\Examples\DelphiBuildDPROJ.ps1 -ProjectFile Examples\Console\ConsoleReadPasFile.dproj -Config Debug -Platform Win32
```

## Running Tests

The test binary requires `tree-sitter.dll` and `tree-sitter-pascal.dll` alongside it:

```powershell
cp Libs\Win32\tree-sitter*.dll Tests\Win32\Debug\
.\Tests\Win32\Debug\TreeSitterTests.exe --exit:continue
```

Run a single test fixture by name:

```powershell
.\Tests\Win32\Debug\TreeSitterTests.exe --fixture:TParserTests --exit:continue
```

There are 98 tests across 10 fixtures. All should pass.

## Building Native Libraries (DLLs)

The DLLs are not checked in. Build them with Zig from the submodule sources:

```powershell
cd Examples
.\Prerequisites.ps1 -Install    # install zig if needed, init submodules
.\BuildLibs.ps1 -Platforms Win32,Win64
```

Output goes to `Libs/<platform>/`. Copy to the executable's directory before running.

## Source Architecture

### `Source/` — Core Delphi Bindings

| Unit                    | Purpose                                                                                                                                                                                               |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TreeSitterLib.pas`     | Raw FFI: `var` procedure pointers for every `ts_*` C function; C structs as opaque `record end`. Do not call these directly.                                                                          |
| `TreeSitter.pas`        | Object-oriented wrapper: `TTSParser`, `TTSTree`, `TTSTreeCursor`, `TTSNode` (record helper), `TTSLanguageHelper`. **This is the primary API.**                                                        |
| `TreeSitter.Query.pas`  | `TTSQuery` and `TTSQueryCursor` for S-expression pattern queries.                                                                                                                                     |
| `TreeSitter.Loader.pas` | `TTreeSitterLoader` — loads `tree-sitter.dll` (or platform equivalent) via `LoadLibrary`/`dlopen`, resolves all function pointers in `TreeSitterLib`. Must be called before creating any `TTSParser`. |

**Critical loading order:** `TTreeSitterLoader.Load` → resolves `TreeSitterLib` pointers → then `TTSParser.Create` works. Creating a parser without loading raises `ETreeSitterNotLoadedException`.

**API rename gotcha:** In tree-sitter ≥ 0.24 `ts_language_version` was renamed to `ts_language_abi_version`. The loader tries both names.

### `Examples/Shared/` — Shared App Logic (UI-independent)

| Unit                        | Purpose                                                                                                                                                                                                                                               |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TreeSitter.App.pas`        | `TTSGrammarLoader` (loads core + grammar DLLs with optional download callback), `TTSAppManager` (owns parser + tree, exposes high-level methods), data records (`TTSNodeInfo`, `TTSNodeProperties`, `TTSLanguageInfo`, etc.), `BuildNodeDisplayText`. |
| `TreeSitter.Downloader.pas` | `TTreeSitterDownloader` — HTTP download of DLLs from GitHub releases via `TNetHTTPClient`.                                                                                                                                                            |

`TTSGrammarLoader.OnConfirmDownload` is an injectable `reference to function(const AMessage: string): Boolean`. VCL/FMX set it to their dialog; tests set it to always return `False` so no download is triggered.

### `Examples/` — Demo Applications

- **VCL** (`frmDTSMain.pas`): Full-featured API explorer — treeview with lazy node expansion, node property grid, field selector, query form, language info form. Depends on `TTSGrammarLoader` + `TTSAppManager`.
- **FMX** (`frmDTSMainFMX.pas`): Cross-platform version with same shared classes. Uses synchronous `MessageDlg` (not async `TDialogService`) for download confirmation.
- **Console** (`ConsoleReadPasFile.dpr`): Shows `TTSParser.Parse` with an anonymous read callback.

### `Tests/`

| Unit                      | Fixtures                                                                                                    | What's tested                        |
| ------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| `TreeSitterCoreTests.pas` | `TLoaderTests`, `TParserTests`, `TTreeTests`, `TNodeTests`, `TCursorTests`, `TLanguageTests`, `TQueryTests` | All `Source/` units directly         |
| `AppTests.pas`            | `TGrammarLoaderTests`, `TAppManagerTests`, `TNodeDisplayTextTests`                                          | `Examples/Shared/TreeSitter.App.pas` |

All fixtures inherit from `TTreeSitterTestBase` which loads `tree-sitter.dll` + `tree-sitter-pascal.dll` once in `[SetupFixture]`.

**Pascal grammar root:** The parser wraps all source in a `root` node (type `'root'`), not `'program'`. Tests and assertions should expect `'root'` as the top-level node type.

**Sibling tests:** `root` has only one child (`program`), so sibling navigation tests must descend into `program`'s children to find nodes that actually have siblings.

## DLL Naming Convention

Grammar DLLs follow `tree-sitter-<lang>` + platform extension (`.dll`/`.so`/`.dylib`). The export function is `tree_sitter_<lang>` returning `PTSLanguage`. This is the standard tree-sitter grammar convention.

## Project Search Paths

The test project's `.dproj` includes `$(DUnitX);..\Source;..\Examples\Shared` in `DCC_UnitSearchPath`. The VCL/FMX demo projects include `..\Source;..\Examples\Shared`.

## Git Submodules

`tree-sitter-pascal/` — the Pascal grammar (has its own `CLAUDE.md` with grammar-specific guidance).  
`tree-sitter-pascal/tree-sitter/` — tree-sitter core C library sources, used only by `BuildLibs.ps1`.

Initialize with: `git submodule update --init --recursive`
