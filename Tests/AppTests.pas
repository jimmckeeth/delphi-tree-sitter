unit AppTests;

interface

uses
  DUnitX.TestFramework,
  TreeSitter, TreeSitterLib, TreeSitter.Loader, TreeSitter.App;

type
  [TestFixture]
  TGrammarLoaderTests = class
  public
    [Test] procedure TestEnsureCoreLoaded;
    [Test] procedure TestLoadGrammar_Pascal;
    [Test] procedure TestLoadGrammar_Invalid_Raises;
    [Test] procedure TestGrammarCaching;
    [Test] procedure TestConfirmDownloadCallback_NotCalled_WhenLoaded;
  end;

  [TestFixture]
  TAppManagerTests = class
  private
    FLoader: TTSGrammarLoader;
    FManager: TTSAppManager;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure TestSetLanguage;
    [Test] procedure TestParseSource;
    [Test] procedure TestParseSource_Empty_ReturnsFalse;
    [Test] procedure TestGetRootNodeInfo;
    [Test] procedure TestGetChildNodes_All;
    [Test] procedure TestGetChildNodes_NamedOnly;
    [Test] procedure TestGetNodeProperties;
    [Test] procedure TestGetLanguageFields;
    [Test] procedure TestGetLanguageInfo;
    [Test] procedure TestFindChildByField;
    [Test] procedure TestCurrentLanguage;
    [Test] procedure TestSetLanguage_Resets;
  end;

  [TestFixture]
  TNodeDisplayTextTests = class
  public
    [Test] procedure TestWithFieldName;
    [Test] procedure TestWithoutFieldName;
  end;

const
  TestPascalSource =
    'program Test;'#13#10 +
    'var'#13#10 +
    '  x: Integer;'#13#10 +
    'begin'#13#10 +
    '  WriteLn(x);'#13#10 +
    'end.';

implementation

uses
  System.SysUtils;

{ TGrammarLoaderTests }

procedure TGrammarLoaderTests.TestEnsureCoreLoaded;
var
  loader: TTSGrammarLoader;
begin
  loader := TTSGrammarLoader.Create;
  try
    Assert.IsTrue(loader.EnsureCoreLoaded);
  finally
    loader.Free;
  end;
end;

procedure TGrammarLoaderTests.TestLoadGrammar_Pascal;
var
  loader: TTSGrammarLoader;
  lang: PTSLanguage;
begin
  loader := TTSGrammarLoader.Create;
  try
    loader.EnsureCoreLoaded;
    lang := loader.LoadGrammar('pascal');
    Assert.IsNotNull(lang);
  finally
    loader.Free;
  end;
end;

procedure TGrammarLoaderTests.TestLoadGrammar_Invalid_Raises;
var
  loader: TTSGrammarLoader;
begin
  loader := TTSGrammarLoader.Create;
  try
    loader.EnsureCoreLoaded;
    Assert.WillRaise(
      procedure begin loader.LoadGrammar('nonexistent_lang_xyz'); end,
      Exception);
  finally
    loader.Free;
  end;
end;

procedure TGrammarLoaderTests.TestGrammarCaching;
var
  loader: TTSGrammarLoader;
  lang1, lang2: PTSLanguage;
begin
  loader := TTSGrammarLoader.Create;
  try
    loader.EnsureCoreLoaded;
    lang1 := loader.LoadGrammar('pascal');
    lang2 := loader.LoadGrammar('pascal');
    Assert.AreEqual(NativeUInt(lang1), NativeUInt(lang2), 'Same language pointer expected from cache');
  finally
    loader.Free;
  end;
end;

procedure TGrammarLoaderTests.TestConfirmDownloadCallback_NotCalled_WhenLoaded;
var
  loader: TTSGrammarLoader;
  called: Boolean;
begin
  called := False;
  loader := TTSGrammarLoader.Create;
  try
    loader.OnConfirmDownload :=
      function(const AMessage: string): Boolean
      begin
        called := True;
        Result := False;
      end;
    loader.EnsureCoreLoaded;
    Assert.IsFalse(called, 'Callback should not be called when library is already loaded');
  finally
    loader.Free;
  end;
end;

{ TAppManagerTests }

procedure TAppManagerTests.Setup;
begin
  FLoader := TTSGrammarLoader.Create;
  FLoader.EnsureCoreLoaded;
  FManager := TTSAppManager.Create(FLoader);
  FManager.SetLanguage('pascal');
end;

procedure TAppManagerTests.TearDown;
begin
  FreeAndNil(FManager);
  FreeAndNil(FLoader);
end;

procedure TAppManagerTests.TestSetLanguage;
begin
  Assert.IsNotNull(FManager.Parser.Language);
end;

procedure TAppManagerTests.TestParseSource;
begin
  Assert.IsTrue(FManager.ParseSource(TestPascalSource));
  Assert.IsNotNull(FManager.Tree);
end;

procedure TAppManagerTests.TestParseSource_Empty_ReturnsFalse;
begin
  Assert.IsFalse(FManager.ParseSource(''));
end;

procedure TAppManagerTests.TestGetRootNodeInfo;
var
  info: TTSNodeInfo;
begin
  FManager.ParseSource(TestPascalSource);
  info := FManager.GetRootNodeInfo;
  Assert.AreEqual('root', info.NodeType); // pascal grammar wraps in 'root'
  Assert.IsTrue(info.ChildCount > 0);
end;

procedure TAppManagerTests.TestGetChildNodes_All;
var
  children: TArray<TTSNodeInfo>;
begin
  FManager.ParseSource(TestPascalSource);
  children := FManager.GetChildNodes(FManager.Tree.RootNode, False);
  Assert.IsTrue(Length(children) > 0);
end;

procedure TAppManagerTests.TestGetChildNodes_NamedOnly;
var
  allChildren, namedChildren: TArray<TTSNodeInfo>;
  info: TTSNodeInfo;
begin
  FManager.ParseSource(TestPascalSource);
  allChildren := FManager.GetChildNodes(FManager.Tree.RootNode, False);
  namedChildren := FManager.GetChildNodes(FManager.Tree.RootNode, True);
  Assert.IsTrue(Length(namedChildren) <= Length(allChildren));
  for info in namedChildren do
    Assert.IsTrue(info.IsNamed);
end;

procedure TAppManagerTests.TestGetNodeProperties;
var
  props: TTSNodeProperties;
begin
  FManager.ParseSource(TestPascalSource);
  props := FManager.GetNodeProperties(FManager.Tree.RootNode);
  Assert.IsTrue(props.Symbol > 0);
  Assert.IsFalse(props.SymbolName = '');
  Assert.IsTrue(props.ChildCount > 0);
  Assert.IsFalse(props.IsError);
  Assert.IsTrue(props.EndByte > props.StartByte);
end;

procedure TAppManagerTests.TestGetLanguageFields;
var
  fields: TArray<TTSFieldInfo>;
begin
  fields := FManager.GetLanguageFields;
  Assert.IsTrue(Length(fields) > 0);
  Assert.IsFalse(fields[0].FieldName = '');
  Assert.IsTrue(fields[0].FieldId > 0);
end;

procedure TAppManagerTests.TestGetLanguageInfo;
var
  info: TTSLanguageInfo;
begin
  info := FManager.GetLanguageInfo;
  Assert.IsTrue(info.Version >= 13);
  Assert.IsTrue(info.FieldCount > 0);
  Assert.IsTrue(info.SymbolCount > 0);
  Assert.AreEqual<Integer>(Integer(info.FieldCount), Length(info.Fields));
  Assert.AreEqual<Integer>(Integer(info.SymbolCount), Length(info.Symbols));
end;

procedure TAppManagerTests.TestFindChildByField;
var
  node: TTSNode;
  lang: PTSLanguage;
  fieldId: TSFieldId;
begin
  FManager.ParseSource(TestPascalSource);
  lang := FManager.Parser.Language;
  fieldId := lang^.FieldId['name'];
  if fieldId > 0 then
  begin
    node := FManager.FindChildByField(FManager.Tree.RootNode, fieldId);
    // May be null if grammar doesn't use this field on root
    if not node.IsNull then
      Assert.IsFalse(node.NodeType = '');
  end;
end;

procedure TAppManagerTests.TestCurrentLanguage;
begin
  Assert.AreEqual('pascal', FManager.CurrentLanguage);
end;

procedure TAppManagerTests.TestSetLanguage_Resets;
begin
  FManager.ParseSource(TestPascalSource);
  Assert.IsNotNull(FManager.Tree);
  FManager.SetLanguage('pascal');
  Assert.IsNull(FManager.Tree, 'Tree should be freed when language changes');
end;

{ TNodeDisplayTextTests }

procedure TNodeDisplayTextTests.TestWithFieldName;
var
  info: TTSNodeInfo;
begin
  info.NodeType := 'identifier';
  info.FieldName := 'name';
  info.FieldId := 5;
  Assert.AreEqual('name (5): identifier', BuildNodeDisplayText(info));
end;

procedure TNodeDisplayTextTests.TestWithoutFieldName;
var
  info: TTSNodeInfo;
begin
  info.NodeType := 'program';
  info.FieldName := '';
  info.FieldId := 0;
  Assert.AreEqual('program', BuildNodeDisplayText(info));
end;

initialization
  TDUnitX.RegisterTestFixture(TGrammarLoaderTests);
  TDUnitX.RegisterTestFixture(TAppManagerTests);
  TDUnitX.RegisterTestFixture(TNodeDisplayTextTests);

end.
