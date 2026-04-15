unit AppTests;

interface

uses
  DUnitX.TestFramework,
  TreeSitter, TreeSitterLib, TreeSitter.Loader, TreeSitter.App,
  frmDTSMain.Controller;

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
    [Test] procedure TestLanguagesList;
  end;

  [TestFixture]
  TNodeDisplayTextTests = class
  public
    [Test] procedure TestWithFieldName;
    [Test] procedure TestWithoutFieldName;
  end;

  // Mock view: implements IInterface with no-op ref counting so the test
  // fixture can hold a plain object reference alongside the interface pointer
  // used by the controller, without premature automatic destruction.
  TDTSMockView = class(TObject, IDTSMainView, IInterface)
  private
    FLastError: string;
    FTreeUpdated: Boolean;
    FLastTree: TTSTree;
    FLastNodeProps: TTSNodeProperties;
    FNodePropsUpdated: Boolean;
    FNodePropsCleared: Boolean;
    FFieldsUpdated: Boolean;
    FLastFieldCount: Integer;
    FCodeRangeStartRow: Integer;
    FCodeRangeSelected: Boolean;
    FConfirmResult: Boolean;
    // IInterface - manual, non-counting lifetime
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
  public
    constructor Create(AConfirmResult: Boolean = False);
    // IDTSMainView
    procedure UpdateTreeView(ATree: TTSTree);
    procedure UpdateNodeProperties(const AProps: TTSNodeProperties);
    procedure UpdateLanguageFields(const AFields: TArray<TTSFieldInfo>);
    procedure SelectCodeRange(AStartRow, AStartCol, AEndRow, AEndCol: Integer);
    procedure ClearNodeProperties;
    function ConfirmDownload(const AMessage: string): Boolean;
    procedure ShowError(const AMessage: string);
    // Inspection
    procedure ResetFlags;
    property LastError: string read FLastError;
    property TreeUpdated: Boolean read FTreeUpdated;
    property LastTree: TTSTree read FLastTree;
    property NodePropsUpdated: Boolean read FNodePropsUpdated;
    property LastNodeProps: TTSNodeProperties read FLastNodeProps;
    property NodePropsCleared: Boolean read FNodePropsCleared;
    property FieldsUpdated: Boolean read FFieldsUpdated;
    property LastFieldCount: Integer read FLastFieldCount;
    property CodeRangeStartRow: Integer read FCodeRangeStartRow;
    property CodeRangeSelected: Boolean read FCodeRangeSelected;
  end;

  [TestFixture]
  TDTSMainControllerTests = class
  private
    FView: TDTSMockView;
    FController: TDTSMainController;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure TestInitialize_SetsInitialized;
    [Test] procedure TestChangeLanguage_LoadsGrammar;
    [Test] procedure TestChangeLanguage_UpdatesFields;
    [Test] procedure TestParseSource_UpdatesTree;
    [Test] procedure TestParseSource_Empty_DoesNotUpdateTree;
    [Test] procedure TestSelectNode_UpdatesNodeProperties;
    [Test] procedure TestSelectNode_UpdatesCodeRange;
    [Test] procedure TestSelectNode_Null_ClearsNodeProperties;
    [Test] procedure TestGetChildByField_NoChild_ShowsError;
    [Test] procedure TestConfirmDownload_DeclinedGrammar_ShowsError;
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

{ TDTSMockView }

constructor TDTSMockView.Create(AConfirmResult: Boolean);
begin
  inherited Create;
  FConfirmResult := AConfirmResult;
  FCodeRangeStartRow := -1;
end;

function TDTSMockView._AddRef: Integer;
begin
  Result := -1; // no reference counting
end;

function TDTSMockView._Release: Integer;
begin
  Result := -1; // no reference counting
end;

function TDTSMockView.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

procedure TDTSMockView.UpdateTreeView(ATree: TTSTree);
begin
  FTreeUpdated := True;
  FLastTree := ATree;
end;

procedure TDTSMockView.UpdateNodeProperties(const AProps: TTSNodeProperties);
begin
  FNodePropsUpdated := True;
  FLastNodeProps := AProps;
end;

procedure TDTSMockView.UpdateLanguageFields(const AFields: TArray<TTSFieldInfo>);
begin
  FFieldsUpdated := True;
  FLastFieldCount := Length(AFields);
end;

procedure TDTSMockView.SelectCodeRange(AStartRow, AStartCol, AEndRow, AEndCol: Integer);
begin
  FCodeRangeSelected := True;
  FCodeRangeStartRow := AStartRow;
end;

procedure TDTSMockView.ClearNodeProperties;
begin
  FNodePropsCleared := True;
end;

function TDTSMockView.ConfirmDownload(const AMessage: string): Boolean;
begin
  Result := FConfirmResult;
end;

procedure TDTSMockView.ShowError(const AMessage: string);
begin
  FLastError := AMessage;
end;

procedure TDTSMockView.ResetFlags;
begin
  FLastError := '';
  FTreeUpdated := False;
  FLastTree := nil;
  FNodePropsUpdated := False;
  FNodePropsCleared := False;
  FFieldsUpdated := False;
  FLastFieldCount := 0;
  FCodeRangeSelected := False;
  FCodeRangeStartRow := -1;
end;

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

procedure TAppManagerTests.TestLanguagesList;
begin
  Assert.IsNotNull(FManager.Languages);
  Assert.IsTrue(FManager.Languages.Count >= 4, 'Should have at least pascal, c, python, typescript');
  Assert.AreEqual('pascal', FManager.Languages[0].BaseName);
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

{ TDTSMainControllerTests }

procedure TDTSMainControllerTests.Setup;
begin
  FView := TDTSMockView.Create(False); // Never auto-download in tests
  FController := TDTSMainController.Create(FView);
  FController.Initialize;
end;

procedure TDTSMainControllerTests.TearDown;
begin
  FreeAndNil(FController);
  FreeAndNil(FView);
end;

procedure TDTSMainControllerTests.TestInitialize_SetsInitialized;
begin
  Assert.IsTrue(FController.Initialized,
    'Controller should be initialized after Initialize call');
end;

procedure TDTSMainControllerTests.TestChangeLanguage_LoadsGrammar;
begin
  FController.ChangeLanguage('pascal');
  Assert.IsNotNull(FController.AppManager.Parser.Language,
    'Parser should have a language after ChangeLanguage');
end;

procedure TDTSMainControllerTests.TestChangeLanguage_UpdatesFields;
begin
  FView.ResetFlags;
  FController.ChangeLanguage('pascal');
  Assert.IsTrue(FView.FieldsUpdated,
    'View.UpdateLanguageFields should be called after language change');
  Assert.IsTrue(FView.LastFieldCount > 0,
    'Pascal grammar should expose at least one field');
end;

procedure TDTSMainControllerTests.TestParseSource_UpdatesTree;
begin
  FController.ChangeLanguage('pascal');
  FView.ResetFlags;
  FController.ParseSource(TestPascalSource);
  Assert.IsTrue(FView.TreeUpdated,
    'View.UpdateTreeView should be called after a successful parse');
  Assert.IsNotNull(FView.LastTree,
    'Tree passed to the view should not be nil');
end;

procedure TDTSMainControllerTests.TestParseSource_Empty_DoesNotUpdateTree;
begin
  FController.ChangeLanguage('pascal');
  FView.ResetFlags;
  FController.ParseSource('');
  Assert.IsFalse(FView.TreeUpdated,
    'View.UpdateTreeView should NOT be called for empty source');
end;

procedure TDTSMainControllerTests.TestSelectNode_UpdatesNodeProperties;
var
  firstChild: TTSNode;
begin
  FController.ChangeLanguage('pascal');
  FController.ParseSource(TestPascalSource);
  firstChild := FController.AppManager.Tree.RootNode.Child(0);
  Assert.IsFalse(firstChild.IsNull, 'Root node must have at least one child');
  FView.ResetFlags;
  FController.SelectNode(firstChild);
  Assert.IsTrue(FView.NodePropsUpdated,
    'View.UpdateNodeProperties should be called when a valid node is selected');
end;

procedure TDTSMainControllerTests.TestSelectNode_UpdatesCodeRange;
var
  firstChild: TTSNode;
begin
  FController.ChangeLanguage('pascal');
  FController.ParseSource(TestPascalSource);
  firstChild := FController.AppManager.Tree.RootNode.Child(0);
  FView.ResetFlags;
  FController.SelectNode(firstChild);
  Assert.IsTrue(FView.CodeRangeSelected,
    'View.SelectCodeRange should be called when a valid node is selected');
  Assert.IsTrue(FView.CodeRangeStartRow >= 0,
    'Code range start row should be a valid line index');
end;

procedure TDTSMainControllerTests.TestSelectNode_Null_ClearsNodeProperties;
begin
  FController.ChangeLanguage('pascal');
  FController.ParseSource(TestPascalSource);
  FView.ResetFlags;
  FController.SelectNode(Default(TTSNode));
  Assert.IsTrue(FView.NodePropsCleared,
    'View.ClearNodeProperties should be called when a null node is selected');
  Assert.IsFalse(FView.NodePropsUpdated,
    'View.UpdateNodeProperties should NOT be called for a null node');
end;

procedure TDTSMainControllerTests.TestGetChildByField_NoChild_ShowsError;
var
  root: TTSNode;
begin
  FController.ChangeLanguage('pascal');
  FController.ParseSource(TestPascalSource);
  root := FController.AppManager.Tree.RootNode;
  FController.SelectNode(root);
  FView.ResetFlags;
  // Field ID 9999 does not exist; controller must call ShowError
  FController.GetChildByField(9999);
  Assert.IsFalse(FView.LastError = '',
    'View.ShowError should be called when no child is found for the given field');
end;

procedure TDTSMainControllerTests.TestConfirmDownload_DeclinedGrammar_ShowsError;
var
  view: TDTSMockView;
  controller: TDTSMainController;
  raised: Boolean;
begin
  // Use a fresh controller whose confirm callback always returns False.
  // Loading a non-existent grammar DLL should propagate an exception (the
  // controller does not swallow it - callers are responsible for wrapping).
  view := TDTSMockView.Create(False);
  controller := TDTSMainController.Create(view);
  try
    controller.Initialize;
    raised := False;
    try
      controller.ChangeLanguage('nonexistent_lang_xyz_9999');
    except
      raised := True;
    end;
    Assert.IsTrue(raised,
      'ChangeLanguage with a missing grammar DLL and no download consent must raise');
  finally
    controller.Free;
    view.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TGrammarLoaderTests);
  TDUnitX.RegisterTestFixture(TAppManagerTests);
  TDUnitX.RegisterTestFixture(TNodeDisplayTextTests);
  TDUnitX.RegisterTestFixture(TDTSMainControllerTests);

end.
