unit TreeSitter.Loader;

interface

uses
  System.SysUtils,
  System.IOUtils,
  TreeSitterLib;

type
  TTreeSitterLoader = class
  private
    class var FLibHandle: THandle;
    class function GetIsLoaded: Boolean; static;
    class procedure SetupAllocator;
  public
    class function Load(const ALibPath: string = ''): Boolean;
    class procedure Unload;
    class function DefaultLibName: string;
    class function GetPlatformPrefix: string;
    class function GetPlatformExtension: string;
    class property IsLoaded: Boolean read GetIsLoaded;
  end;

implementation

{$IFDEF MSWINDOWS}
uses Winapi.Windows;
{$ELSE}
uses Posix.Dlfcn;
{$ENDIF}

{ Allocator functions }

function ts_malloc_func(sizeOf: NativeUInt): Pointer; cdecl;
begin
  GetMem(Result, sizeOf);
end;

function ts_calloc_func(nitems: NativeUInt; size: NativeUInt): Pointer; cdecl;
begin
  GetMem(Result, nitems * size);
  FillChar(Result^, nitems * size, 0);
end;

procedure ts_free_func(ptr: Pointer); cdecl;
begin
  FreeMem(ptr);
end;

function ts_realloc_func(ptr: Pointer; sizeOf: NativeUInt): Pointer; cdecl;
begin
  Result:= ptr;
  ReallocMem(Result, sizeOf);
end;

{ TTreeSitterLoader }

class function TTreeSitterLoader.GetPlatformPrefix: string;
begin
{$IFDEF MSWINDOWS}
  Result := '';
{$ELSE}
  Result := 'lib';
{$ENDIF}
end;

class function TTreeSitterLoader.GetPlatformExtension: string;
begin
{$IFDEF MSWINDOWS}
  Result := '.dll';
{$ELSEIF Defined(MACOS)}
  Result := '.dylib';
{$ELSE}
  Result := '.so';
{$ENDIF}
end;

class function TTreeSitterLoader.DefaultLibName: string;
begin
  Result := GetPlatformPrefix + 'tree-sitter' + GetPlatformExtension;
end;

class function TTreeSitterLoader.GetIsLoaded: Boolean;
begin
  Result := FLibHandle <> 0;
end;

class procedure TTreeSitterLoader.SetupAllocator;
begin
  if Assigned(ts_set_allocator) then
    ts_set_allocator(@ts_malloc_func, @ts_calloc_func, @ts_realloc_func, @ts_free_func);
end;

class function TTreeSitterLoader.Load(const ALibPath: string): Boolean;
label
  Loaded;
var
  LPath: string;
  LExePath: string;
  LSearchPaths: TArray<string>;
  LS: string;

  function GetAddr(const AName: string): Pointer;
  begin
{$IFDEF MSWINDOWS}
    Result := GetProcAddress(FLibHandle, PChar(AName));
{$ELSE}
    // Try both ways to be safe
    Result := Pointer(NativeUInt(dlsym(NativeUInt(FLibHandle), PAnsiChar(AnsiString(AName)))));
{$ENDIF}
  end;

  function TryLoad(const APath: string): Boolean;
  begin
{$IFDEF MSWINDOWS}
    FLibHandle := LoadLibrary(PChar(APath));
{$ELSE}
    FLibHandle := THandle(NativeUInt(dlopen(PAnsiChar(AnsiString(APath)), RTLD_LAZY or RTLD_GLOBAL)));
{$ENDIF}
    Result := FLibHandle <> 0;
  end;

begin
  if IsLoaded then Exit(True);

  LPath := ALibPath;
  if LPath = '' then
    LPath := DefaultLibName;

  if TryLoad(LPath) then
    goto Loaded;

  // Try relative to EXE
  LExePath := TPath.GetDirectoryName(TPath.GetFullPath(ParamStr(0)));
  if not LExePath.EndsWith(PathDelim) then
    LExePath := LExePath + PathDelim;
  SetLength(LSearchPaths, 4);
  LSearchPaths[0] := LExePath;
{$IFDEF WIN64}
  LSearchPaths[1] := LExePath + '..\..\Libs\Win64';
  LSearchPaths[2] := LExePath + '..\..\..\Libs\Win64';
  LSearchPaths[3] := LExePath + 'Libs\Win64';
{$ELSEIF Defined(LINUX64)}
  LSearchPaths[1] := LExePath + '../../Libs/Linux64';
  LSearchPaths[2] := LExePath + '../../../Libs/Linux64';
  LSearchPaths[3] := LExePath + 'Libs/Linux64';
{$ELSE}
  LSearchPaths[1] := LExePath + '..\..\Libs\Win32';
  LSearchPaths[2] := LExePath + '..\..\..\Libs\Win32';
  LSearchPaths[3] := LExePath + 'Libs\Win32';
{$ENDIF}

  for LS in LSearchPaths do
    if TryLoad(TPath.Combine(LS, LPath)) then
      goto Loaded;

  Exit(False);

Loaded:
  ts_parser_new := GetAddr('ts_parser_new');
  ts_parser_delete := GetAddr('ts_parser_delete');
  ts_parser_language := GetAddr('ts_parser_language');
  ts_parser_set_language := GetAddr('ts_parser_set_language');
  ts_parser_parse := GetAddr('ts_parser_parse');
  ts_parser_parse_string := GetAddr('ts_parser_parse_string');
  ts_parser_parse_string_encoding := GetAddr('ts_parser_parse_string_encoding');
  ts_parser_reset := GetAddr('ts_parser_reset');
  ts_tree_copy := GetAddr('ts_tree_copy');
  ts_tree_delete := GetAddr('ts_tree_delete');
  ts_tree_root_node := GetAddr('ts_tree_root_node');
  ts_tree_language := GetAddr('ts_tree_language');
  ts_node_type := GetAddr('ts_node_type');
  ts_node_symbol := GetAddr('ts_node_symbol');
  ts_node_language := GetAddr('ts_node_language');
  ts_node_grammar_type := GetAddr('ts_node_grammar_type');
  ts_node_grammar_symbol := GetAddr('ts_node_grammar_symbol');
  ts_node_start_byte := GetAddr('ts_node_start_byte');
  ts_node_start_point := GetAddr('ts_node_start_point');
  ts_node_end_byte := GetAddr('ts_node_end_byte');
  ts_node_end_point := GetAddr('ts_node_end_point');
  ts_node_string := GetAddr('ts_node_string');
  ts_node_is_null := GetAddr('ts_node_is_null');
  ts_node_is_named := GetAddr('ts_node_is_named');
  ts_node_is_missing := GetAddr('ts_node_is_missing');
  ts_node_is_extra := GetAddr('ts_node_is_extra');
  ts_node_has_changes := GetAddr('ts_node_has_changes');
  ts_node_has_error := GetAddr('ts_node_has_error');
  ts_node_is_error := GetAddr('ts_node_is_error');
  ts_node_parent := GetAddr('ts_node_parent');
  ts_node_child := GetAddr('ts_node_child');
  ts_node_child_count := GetAddr('ts_node_child_count');
  ts_node_named_child := GetAddr('ts_node_named_child');
  ts_node_named_child_count := GetAddr('ts_node_named_child_count');
  ts_node_child_by_field_name := GetAddr('ts_node_child_by_field_name');
  ts_node_child_by_field_id := GetAddr('ts_node_child_by_field_id');
  ts_node_next_sibling := GetAddr('ts_node_next_sibling');
  ts_node_prev_sibling := GetAddr('ts_node_prev_sibling');
  ts_node_next_named_sibling := GetAddr('ts_node_next_named_sibling');
  ts_node_prev_named_sibling := GetAddr('ts_node_prev_named_sibling');
  ts_node_descendant_count := GetAddr('ts_node_descendant_count');
  ts_node_eq := GetAddr('ts_node_eq');
  ts_tree_cursor_new := GetAddr('ts_tree_cursor_new');
  ts_tree_cursor_delete := GetAddr('ts_tree_cursor_delete');
  ts_tree_cursor_reset := GetAddr('ts_tree_cursor_reset');
  ts_tree_cursor_reset_to := GetAddr('ts_tree_cursor_reset_to');
  ts_tree_cursor_current_node := GetAddr('ts_tree_cursor_current_node');
  ts_tree_cursor_current_field_name := GetAddr('ts_tree_cursor_current_field_name');
  ts_tree_cursor_current_field_id := GetAddr('ts_tree_cursor_current_field_id');
  ts_tree_cursor_goto_parent := GetAddr('ts_tree_cursor_goto_parent');
  ts_tree_cursor_goto_next_sibling := GetAddr('ts_tree_cursor_goto_next_sibling');
  ts_tree_cursor_goto_previous_sibling := GetAddr('ts_tree_cursor_goto_previous_sibling');
  ts_tree_cursor_goto_first_child := GetAddr('ts_tree_cursor_goto_first_child');
  ts_tree_cursor_goto_last_child := GetAddr('ts_tree_cursor_goto_last_child');
  ts_tree_cursor_goto_descendant := GetAddr('ts_tree_cursor_goto_descendant');
  ts_tree_cursor_current_descendant_index := GetAddr('ts_tree_cursor_current_descendant_index');
  ts_tree_cursor_current_depth := GetAddr('ts_tree_cursor_current_depth');
  ts_tree_cursor_goto_first_child_for_byte := GetAddr('ts_tree_cursor_goto_first_child_for_byte');
  ts_tree_cursor_goto_first_child_for_point := GetAddr('ts_tree_cursor_goto_first_child_for_point');
  ts_tree_cursor_copy := GetAddr('ts_tree_cursor_copy');
  ts_query_new := GetAddr('ts_query_new');
  ts_query_delete := GetAddr('ts_query_delete');
  ts_query_pattern_count := GetAddr('ts_query_pattern_count');
  ts_query_capture_count := GetAddr('ts_query_capture_count');
  ts_query_string_count := GetAddr('ts_query_string_count');
  ts_query_start_byte_for_pattern := GetAddr('ts_query_start_byte_for_pattern');
  ts_query_predicates_for_pattern := GetAddr('ts_query_predicates_for_pattern');
  ts_query_capture_name_for_id := GetAddr('ts_query_capture_name_for_id');
  ts_query_capture_quantifier_for_id := GetAddr('ts_query_capture_quantifier_for_id');
  ts_query_string_value_for_id := GetAddr('ts_query_string_value_for_id');
  ts_query_cursor_new := GetAddr('ts_query_cursor_new');
  ts_query_cursor_delete := GetAddr('ts_query_cursor_delete');
  ts_query_cursor_exec := GetAddr('ts_query_cursor_exec');
  ts_query_cursor_did_exceed_match_limit := GetAddr('ts_query_cursor_did_exceed_match_limit');
  ts_query_cursor_match_limit := GetAddr('ts_query_cursor_match_limit');
  ts_query_cursor_set_match_limit := GetAddr('ts_query_cursor_set_match_limit');
  ts_query_cursor_next_match := GetAddr('ts_query_cursor_next_match');
  ts_query_cursor_remove_match := GetAddr('ts_query_cursor_remove_match');
  ts_query_cursor_next_capture := GetAddr('ts_query_cursor_next_capture');
  ts_query_cursor_set_max_start_depth := GetAddr('ts_query_cursor_set_max_start_depth');
  ts_language_symbol_count := GetAddr('ts_language_symbol_count');
  ts_language_state_count := GetAddr('ts_language_state_count');
  ts_language_symbol_name := GetAddr('ts_language_symbol_name');
  ts_language_symbol_for_name := GetAddr('ts_language_symbol_for_name');
  ts_language_field_count := GetAddr('ts_language_field_count');
  ts_language_field_name_for_id := GetAddr('ts_language_field_name_for_id');
  ts_language_field_id_for_name := GetAddr('ts_language_field_id_for_name');
  ts_language_symbol_type := GetAddr('ts_language_symbol_type');
  // Renamed to ts_language_abi_version in tree-sitter >= 0.24
  ts_language_version := GetAddr('ts_language_abi_version');
  if not Assigned(ts_language_version) then
    ts_language_version := GetAddr('ts_language_version');
  ts_language_next_state := GetAddr('ts_language_next_state');
  ts_set_allocator := GetAddr('ts_set_allocator');

  SetupAllocator;

  Result := True;
end;

class procedure TTreeSitterLoader.Unload;
begin
  if IsLoaded then
  begin
{$IFDEF MSWINDOWS}
    FreeLibrary(FLibHandle);
{$ELSE}
    dlclose(NativeUInt(FLibHandle));
{$ENDIF}
    FLibHandle := 0;
  end;
end;

initialization

finalization
  TTreeSitterLoader.Unload;

end.

