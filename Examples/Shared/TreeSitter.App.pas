unit TreeSitter.App;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  TreeSitter, TreeSitterLib, TreeSitter.Loader, TreeSitter.Downloader;

type
  TTSConfirmDownloadFunc = reference to function(const AMessage: string): Boolean;

  TTSNodeInfo = record
    Node: TTSNode;
    NodeType: string;
    FieldName: string;
    FieldId: TSFieldId;
    IsNamed: Boolean;
    ChildCount: Integer;
    NamedChildCount: Integer;
  end;

  TTSNodeProperties = record
    Symbol: UInt32;
    SymbolName: string;
    GrammarType: string;
    GrammarSymbol: UInt32;
    GrammarSymbolName: string;
    IsError: Boolean;
    HasError: Boolean;
    IsExtra: Boolean;
    IsMissing: Boolean;
    IsNamed: Boolean;
    ChildCount: Integer;
    NamedChildCount: Integer;
    StartByte: UInt32;
    EndByte: UInt32;
    StartPoint: TTSPoint;
    EndPoint: TTSPoint;
    DescendantCount: UInt32;
  end;

  TTSFieldInfo = record
    FieldId: TSFieldId;
    FieldName: string;
  end;

  TTSSymbolInfo = record
    Symbol: TSSymbol;
    SymbolName: string;
    SymbolType: TSSymbolType;
  end;

  TTSLanguageInfo = record
    Version: UInt32;
    FieldCount: UInt32;
    SymbolCount: UInt32;
    Fields: TArray<TTSFieldInfo>;
    Symbols: TArray<TTSSymbolInfo>;
  end;

  TTSGrammarLoader = class
  private
    FGrammarHandles: TDictionary<string, THandle>;
    FOnConfirmDownload: TTSConfirmDownloadFunc;
    function InternalLoadLibrary(const APath: string): THandle;
  public
    constructor Create;
    destructor Destroy; override;
    function EnsureCoreLoaded: Boolean;
    function LoadGrammar(const ALangBaseName: string): PTSLanguage;
    procedure UnloadAll;
    property OnConfirmDownload: TTSConfirmDownloadFunc read FOnConfirmDownload write FOnConfirmDownload;
  end;

  TTSLanguageEntry = record
    BaseName: string;
    DisplayName: string;
    SampleFile: string;
  end;

  TTSAppManager = class
  private
    FGrammarLoader: TTSGrammarLoader;
    FParser: TTSParser;
    FTree: TTSTree;
    FCurrentLanguage: string;
    FLanguages: TList<TTSLanguageEntry>;
    procedure InitLanguages;
  public
    constructor Create(AGrammarLoader: TTSGrammarLoader);
    destructor Destroy; override;
    procedure SetLanguage(const ALangBaseName: string);
    function ParseSource(const ASource: string): Boolean;
    function ParseStream(AReadFunc: TTSParseReadFunction; AEncoding: TTSInputEncoding): Boolean;
    function GetRootNodeInfo: TTSNodeInfo;
    function GetChildNodes(ANode: TTSNode; ANamedOnly: Boolean): TArray<TTSNodeInfo>;
    function GetNodeProperties(ANode: TTSNode): TTSNodeProperties;
    function GetLanguageFields: TArray<TTSFieldInfo>;
    function GetLanguageInfo: TTSLanguageInfo;
    function FindChildByField(ANode: TTSNode; AFieldId: UInt32): TTSNode;
    property Parser: TTSParser read FParser;
    property Tree: TTSTree read FTree;
    property CurrentLanguage: string read FCurrentLanguage;
    property Languages: TList<TTSLanguageEntry> read FLanguages;
  end;

function BuildNodeDisplayText(const AInfo: TTSNodeInfo): string;

implementation

{$IFDEF MSWINDOWS}
uses Winapi.Windows;
{$ELSE}
uses Posix.Dlfcn;
{$ENDIF}

function BuildNodeDisplayText(const AInfo: TTSNodeInfo): string;
begin
  if AInfo.FieldId > 0 then
    Result := Format('%s (%d): %s', [AInfo.FieldName, AInfo.FieldId, AInfo.NodeType])
  else
    Result := AInfo.NodeType;
end;

{ TTSGrammarLoader }
// ... (omitted for brevity in replace call, will provide full implementation if needed, 
// but replace requires full context or surgical match)


{ TTSGrammarLoader }

constructor TTSGrammarLoader.Create;
begin
  inherited;
  FGrammarHandles := TDictionary<string, THandle>.Create;
end;

destructor TTSGrammarLoader.Destroy;
begin
  UnloadAll;
  FGrammarHandles.Free;
  inherited;
end;

function TTSGrammarLoader.InternalLoadLibrary(const APath: string): THandle;
begin
{$IFDEF MSWINDOWS}
  Result := Winapi.Windows.LoadLibrary(PChar(APath));
{$ELSE}
  Result := THandle(NativeUInt(dlopen(PAnsiChar(AnsiString(APath)), RTLD_LAZY)));
{$ENDIF}
end;

function TTSGrammarLoader.EnsureCoreLoaded: Boolean;
var
  errMsg: string;
begin
  if TTreeSitterLoader.IsLoaded then
    Exit(True);

  if TTreeSitterLoader.Load then
    Exit(True);

  if Assigned(FOnConfirmDownload) then
  begin
    if FOnConfirmDownload('Tree-sitter library not found. Download it?') then
    begin
      if not TTreeSitterDownloader.DownloadFile(TTreeSitterDownloader.GetCoreURL,
        TTreeSitterLoader.DefaultLibName, errMsg) then
        raise Exception.CreateFmt('Failed to download tree-sitter library: %s', [errMsg]);
      Result := TTreeSitterLoader.Load;
      if not Result then
        raise Exception.Create('Failed to load tree-sitter library after download.');
      Exit;
    end;
  end;
  Result := False;
end;

function TTSGrammarLoader.LoadGrammar(const ALangBaseName: string): PTSLanguage;
var
  tsLibName, tsAPIName: string;
  libHandle: THandle;
  pAPI: TTSGetLanguageFunc;
  errMsg: string;
begin
  tsLibName := Format('tree-sitter-%s', [ALangBaseName]) + TTreeSitterDownloader.GetPlatformExtension;
  tsAPIName := Format('tree_sitter_%s', [ALangBaseName]);

  if FGrammarHandles.TryGetValue(ALangBaseName, libHandle) then
  begin
{$IFDEF MSWINDOWS}
    pAPI := GetProcAddress(libHandle, PChar(tsAPIName));
{$ELSE}
    pAPI := TTSGetLanguageFunc(NativeUInt(dlsym(NativeUInt(libHandle), PAnsiChar(AnsiString(tsAPIName)))));
{$ENDIF}
    if Assigned(pAPI) then
      Exit(pAPI());
  end;

  libHandle := InternalLoadLibrary(tsLibName);

  if libHandle = 0 then
  begin
    if Assigned(FOnConfirmDownload) then
    begin
      if FOnConfirmDownload(Format('Grammar library "%s" not found. Download it?', [tsLibName])) then
      begin
        if not TTreeSitterDownloader.DownloadFile(
          TTreeSitterDownloader.GetGrammarURL(ALangBaseName), tsLibName, errMsg) then
          raise Exception.CreateFmt('Failed to download grammar library "%s": %s', [tsLibName, errMsg]);
        libHandle := InternalLoadLibrary(tsLibName);
      end;
    end;
  end;

  if libHandle = 0 then
    raise Exception.CreateFmt('Could not load library "%s"', [tsLibName]);

{$IFDEF MSWINDOWS}
  pAPI := GetProcAddress(libHandle, PChar(tsAPIName));
{$ELSE}
  pAPI := TTSGetLanguageFunc(NativeUInt(dlsym(NativeUInt(libHandle), PAnsiChar(AnsiString(tsAPIName)))));
{$ENDIF}
  if not Assigned(pAPI) then
    raise Exception.CreateFmt('The library "%s" does not provide a method "%s"', [tsLibName, tsAPIName]);

  FGrammarHandles.AddOrSetValue(ALangBaseName, libHandle);
  Result := pAPI();
end;

procedure TTSGrammarLoader.UnloadAll;
var
  h: THandle;
begin
  for h in FGrammarHandles.Values do
  begin
{$IFDEF MSWINDOWS}
    FreeLibrary(h);
{$ELSE}
    dlclose(NativeUInt(h));
{$ENDIF}
  end;
  FGrammarHandles.Clear;
end;

{ TTSAppManager }

constructor TTSAppManager.Create(AGrammarLoader: TTSGrammarLoader);
begin
  inherited Create;
  FGrammarLoader := AGrammarLoader;
  FParser := TTSParser.Create;
  FLanguages := TList<TTSLanguageEntry>.Create;
  InitLanguages;
end;

destructor TTSAppManager.Destroy;
begin
  FLanguages.Free;
  FreeAndNil(FTree);
  FreeAndNil(FParser);
  inherited;
end;

procedure TTSAppManager.InitLanguages;
  procedure Add(const ABaseName, ADisplayName, ASample: string);
  var
    entry: TTSLanguageEntry;
  begin
    entry.BaseName := ABaseName;
    entry.DisplayName := ADisplayName;
    entry.SampleFile := ASample;
    FLanguages.Add(entry);
  end;
begin
  FLanguages.Clear;
  Add('pascal', 'Pascal (Delphi/FPC)', 'modernDelphi.pas');
  Add('c', 'C', 'sample.c');
  Add('python', 'Python', 'sample.py');
  Add('typescript', 'TypeScript', 'sample.ts');
  Add('javascript', 'JavaScript', 'sample.js');
  Add('json', 'JSON', 'sample.json');
end;

procedure TTSAppManager.SetLanguage(const ALangBaseName: string);
var
  lang: PTSLanguage;
begin
  lang := FGrammarLoader.LoadGrammar(ALangBaseName);
  FParser.Reset;
  FreeAndNil(FTree);
  FParser.Language := lang;
  FCurrentLanguage := ALangBaseName;
end;

function TTSAppManager.ParseSource(const ASource: string): Boolean;
begin
  FreeAndNil(FTree);
  if Length(ASource) = 0 then
    Exit(False);
  FTree := FParser.ParseString(ASource);
  Result := FTree <> nil;
end;

function TTSAppManager.ParseStream(AReadFunc: TTSParseReadFunction;
  AEncoding: TTSInputEncoding): Boolean;
begin
  FreeAndNil(FTree);
  FTree := FParser.Parse(AReadFunc, AEncoding);
  Result := FTree <> nil;
end;

function TTSAppManager.GetRootNodeInfo: TTSNodeInfo;
var
  root: TTSNode;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.NodeType := '';
  Result.FieldName := '';
  if FTree = nil then
    Exit;
  root := FTree.RootNode;
  Result.Node := root;
  Result.NodeType := root.NodeType;
  Result.IsNamed := root.IsNamed;
  Result.ChildCount := root.ChildCount;
  Result.NamedChildCount := root.NamedChildCount;
end;

function TTSAppManager.GetChildNodes(ANode: TTSNode; ANamedOnly: Boolean): TArray<TTSNodeInfo>;
var
  cursor: TTSTreeCursor;
  list: TList<TTSNodeInfo>;
  info: TTSNodeInfo;
  childNode: TTSNode;
begin
  list := TList<TTSNodeInfo>.Create;
  try
    cursor := TTSTreeCursor.Create(ANode);
    try
      if cursor.GotoFirstChild then
      begin
        repeat
          childNode := cursor.CurrentNode;
          if ANamedOnly and not childNode.IsNamed then
            Continue;
          info.Node := childNode;
          info.NodeType := childNode.NodeType;
          info.FieldName := cursor.CurrentFieldName;
          info.FieldId := cursor.CurrentFieldId;
          info.IsNamed := childNode.IsNamed;
          info.ChildCount := childNode.ChildCount;
          info.NamedChildCount := childNode.NamedChildCount;
          list.Add(info);
        until not cursor.GotoNextSibling;
      end;
    finally
      cursor.Free;
    end;
    Result := list.ToArray;
  finally
    list.Free;
  end;
end;

function TTSAppManager.GetNodeProperties(ANode: TTSNode): TTSNodeProperties;
begin
  Result.Symbol := ANode.Symbol;
  Result.SymbolName := ANode.Language^.SymbolName[ANode.Symbol];
  Result.GrammarType := ANode.GrammarType;
  Result.GrammarSymbol := ANode.GrammarSymbol;
  Result.GrammarSymbolName := ANode.Language^.SymbolName[ANode.GrammarSymbol];
  Result.IsError := ANode.IsError;
  Result.HasError := ANode.HasError;
  Result.IsExtra := ANode.IsExtra;
  Result.IsMissing := ANode.IsMissing;
  Result.IsNamed := ANode.IsNamed;
  Result.ChildCount := ANode.ChildCount;
  Result.NamedChildCount := ANode.NamedChildCount;
  Result.StartByte := ANode.StartByte;
  Result.EndByte := ANode.EndByte;
  Result.StartPoint := ANode.StartPoint;
  Result.EndPoint := ANode.EndPoint;
  Result.DescendantCount := ANode.DescendantCount;
end;

function TTSAppManager.GetLanguageFields: TArray<TTSFieldInfo>;
var
  lang: PTSLanguage;
  i: UInt32;
  count: UInt32;
begin
  lang := FParser.Language;
  if lang = nil then
    Exit(nil);
  count := lang^.FieldCount;
  SetLength(Result, count);
  for i := 1 to count do
  begin
    Result[i - 1].FieldId := TSFieldId(i);
    Result[i - 1].FieldName := lang^.FieldName[TSFieldId(i)];
  end;
end;

function TTSAppManager.GetLanguageInfo: TTSLanguageInfo;
var
  lang: PTSLanguage;
  i: UInt32;
begin
  lang := FParser.Language;
  if lang = nil then
  begin
    Result.Version := 0;
    Result.FieldCount := 0;
    Result.SymbolCount := 0;
    Exit;
  end;
  Result.Version := lang^.Version;
  Result.FieldCount := lang^.FieldCount;
  Result.SymbolCount := lang^.SymbolCount;

  SetLength(Result.Fields, Result.FieldCount);
  for i := 1 to Result.FieldCount do
  begin
    Result.Fields[i - 1].FieldId := TSFieldId(i);
    Result.Fields[i - 1].FieldName := lang^.FieldName[TSFieldId(i)];
  end;

  SetLength(Result.Symbols, Result.SymbolCount);
  for i := 0 to Result.SymbolCount - 1 do
  begin
    Result.Symbols[i].Symbol := TSSymbol(i);
    Result.Symbols[i].SymbolName := lang^.SymbolName[TSSymbol(i)];
    Result.Symbols[i].SymbolType := lang^.SymbolType[TSSymbol(i)];
  end;
end;

function TTSAppManager.FindChildByField(ANode: TTSNode; AFieldId: UInt32): TTSNode;
begin
  Result := ANode.ChildByField(AFieldId);
end;

end.
