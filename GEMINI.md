# delphi-tree-sitter

## Project Overview
Delphi (and potentially FreePascal) bindings for the Tree-sitter parsing library. This project provides a high-level Object-Oriented wrapper around the Tree-sitter C API.

### Structure
- **Source/**: Core library units.
  - `TreeSitterLib.pas`: Low-level C API translation (dynamic loading).
  - `TreeSitter.pas`: High-level OO wrapper.
  - `TreeSitter.Query.pas`: Query and pattern matching support.
  - `TreeSitter.Loader.pas`: Cross-platform dynamic library loader.
- **Examples/**:
  - **VCL/**: VCL-based demo showing tree navigation and property inspection.
  - **FMX/**: FireMonkey-based cross-platform demo.
  - **Console/**: Simple console-based parsing example.
  - **Shared/**: Shared demo units like `TreeSitter.Downloader.pas`.
- **Packages/**: Delphi package for easy integration.

## Getting Started
1. Open the project in Delphi.
2. Add the `Source` directory to your project's Search Path.
3. Call `TTreeSitterLoader.Load` before using any Tree-sitter features.
4. Use `TTreeSitterDownloader` (in Examples) to fetch pre-compiled binaries if needed.

## Cross-Platform Support
The library supports Windows, Linux, and macOS. It uses dynamic loading (`LoadLibrary` on Windows, `dlopen` on POSIX) to ensure the application can start even if the Tree-sitter shared library is not immediately present.
