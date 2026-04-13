unit TreeSitterCoreTests;

interface

uses
  DUnitX.TestFramework,
  TreeSitter, TreeSitterLib, TreeSitter.Loader, TreeSitter.Query;

type
  { Shared setup: loads tree-sitter core + pascal grammar once }
  [TestFixture]
  TTreeSitterTestBase = class
  protected
    class var FPascalLang: PTSLanguage;
    class var FPascalLibHandle: THandle;
  public
    [SetupFixture]
    procedure FixtureSetup;
  end;

  [TestFixture]
  TLoaderTests = class(TTreeSitterTestBase)
  public
    [Test] procedure TestLoadReturnsTrue;
    [Test] procedure TestIsLoadedAfterLoad;
    [Test] procedure TestDefaultLibName;
    [Test] procedure TestUnloadAndReload;
  end;

  [TestFixture]
  TParserTests = class(TTreeSitterTestBase)
  public
    [Test] procedure TestCreateParser;
    [Test] procedure TestSetLanguage;
    [Test] procedure TestGetLanguage;
    [Test] procedure TestParseString_Simple;
    [Test] procedure TestParseString_Empty_Raises;
    [Test] procedure TestParseString_Unicode;
    [Test] procedure TestParseString_WithOldTree;
    [Test] procedure TestParse_WithCallback;
    [Test] procedure TestReset;
  end;

  [TestFixture]
  TTreeTests = class(TTreeSitterTestBase)
  public
    [Test] procedure TestRootNodeNotNull;
    [Test] procedure TestTreeLanguageNotNil;
    [Test] procedure TestClone;
    [Test] procedure TestTreeNilSafe;
    [Test] procedure TestTreeNilSafe_NilSelf;
  end;

  [TestFixture]
  TNodeTests = class(TTreeSitterTestBase)
  private
    FParser: TTSParser;
    FTree: TTSTree;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure TestNodeType;
    [Test] procedure TestSymbol;
    [Test] procedure TestGrammarType;
    [Test] procedure TestGrammarSymbol;
    [Test] procedure TestIsNull_False;
    [Test] procedure TestIsNamed;
    [Test] procedure TestIsError_NoError;
    [Test] procedure TestHasError_NoError;
    [Test] procedure TestIsExtra;
    [Test] procedure TestIsMissing;
    [Test] procedure TestParent;
    [Test] procedure TestChildCount;
    [Test] procedure TestChild;
    [Test] procedure TestNamedChild;
    [Test] procedure TestNamedChildCount;
    [Test] procedure TestNextSibling;
    [Test] procedure TestPrevSibling;
    [Test] procedure TestNextNamedSibling;
    [Test] procedure TestPrevNamedSibling;
    [Test] procedure TestChildByFieldName;
    [Test] procedure TestChildByFieldId;
    [Test] procedure TestStartByte;
    [Test] procedure TestEndByte;
    [Test] procedure TestStartPoint;
    [Test] procedure TestEndPoint;
    [Test] procedure TestDescendantCount;
    [Test] procedure TestToString;
    [Test] procedure TestEqual;
  end;

  [TestFixture]
  TCursorTests = class(TTreeSitterTestBase)
  private
    FParser: TTSParser;
    FTree: TTSTree;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure TestCreateFromNode;
    [Test] procedure TestCopyConstructor;
    [Test] procedure TestGotoFirstChild;
    [Test] procedure TestGotoLastChild;
    [Test] procedure TestGotoNextSibling;
    [Test] procedure TestGotoPrevSibling;
    [Test] procedure TestGotoParent;
    [Test] procedure TestGotoDescendant;
    [Test] procedure TestGotoFirstChildForByte;
    [Test] procedure TestCurrentNode;
    [Test] procedure TestCurrentFieldName;
    [Test] procedure TestCurrentFieldId;
    [Test] procedure TestCurrentDepth;
    [Test] procedure TestResetToNode;
  end;

  [TestFixture]
  TLanguageTests = class(TTreeSitterTestBase)
  public
    [Test] procedure TestVersion;
    [Test] procedure TestFieldCount;
    [Test] procedure TestSymbolCount;
    [Test] procedure TestFieldName;
    [Test] procedure TestFieldId;
    [Test] procedure TestSymbolName;
    [Test] procedure TestSymbolForName;
    [Test] procedure TestSymbolType;
  end;

  [TestFixture]
  TQueryTests = class(TTreeSitterTestBase)
  private
    FParser: TTSParser;
    FTree: TTSTree;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure TestCreateValidQuery;
    [Test] procedure TestCreateInvalidQuery_ErrorOffset;
    [Test] procedure TestPatternCount;
    [Test] procedure TestCaptureCount;
    [Test] procedure TestCaptureNameForID;
    [Test] procedure TestStringCount;
    [Test] procedure TestExecuteNextMatch;
    [Test] procedure TestExecuteNextCapture;
    [Test] procedure TestMatchLimit;
    [Test] procedure TestMultiPatternQuery;
    [Test] procedure TestQueryNoMatches;
  end;

const
  TestPascalSource = 'program Test; begin WriteLn(''Hello''); end.';
  TestPascalSourceMultiLine =
    'program Test;'#13#10 +
    'var'#13#10 +
    '  x: Integer;'#13#10 +
    'begin'#13#10 +
    '  WriteLn(x);'#13#10 +
    'end.';

implementation

uses
  System.SysUtils
{$IFDEF MSWINDOWS}
  , Winapi.Windows
{$ELSE}
  , Posix.Dlfcn
{$ENDIF};

type
  TTSGetLanguageFunc = function(): PTSLanguage; cdecl;

{ TTreeSitterTestBase }

procedure TTreeSitterTestBase.FixtureSetup;
var
  pAPI: TTSGetLanguageFunc;
begin
  if not TTreeSitterLoader.IsLoaded then
    Assert.IsTrue(TTreeSitterLoader.Load, 'Failed to load tree-sitter core library');

  if FPascalLang = nil then
  begin
{$IFDEF MSWINDOWS}
    FPascalLibHandle := LoadLibrary('tree-sitter-pascal.dll');
{$ELSE}
    FPascalLibHandle := THandle(dlopen(PAnsiChar('libtree-sitter-pascal.so'), RTLD_LAZY));
{$ENDIF}
    Assert.AreNotEqual(THandle(0), FPascalLibHandle, 'Failed to load tree-sitter-pascal library');
{$IFDEF MSWINDOWS}
    pAPI := GetProcAddress(FPascalLibHandle, 'tree_sitter_pascal');
{$ELSE}
    pAPI := dlsym(Pointer(NativeUInt(FPascalLibHandle)), 'tree_sitter_pascal');
{$ENDIF}
    Assert.IsTrue(Assigned(pAPI), 'tree_sitter_pascal function not found');
    FPascalLang := pAPI();
    Assert.IsNotNull(FPascalLang, 'tree_sitter_pascal returned nil');
  end;
end;

{ TLoaderTests }

procedure TLoaderTests.TestLoadReturnsTrue;
begin
  Assert.IsTrue(TTreeSitterLoader.IsLoaded);
end;

procedure TLoaderTests.TestIsLoadedAfterLoad;
begin
  Assert.IsTrue(TTreeSitterLoader.IsLoaded);
end;

procedure TLoaderTests.TestDefaultLibName;
begin
{$IFDEF MSWINDOWS}
  Assert.AreEqual('tree-sitter.dll', TTreeSitterLoader.DefaultLibName);
{$ENDIF}
{$IFDEF LINUX}
  Assert.AreEqual('libtree-sitter.so', TTreeSitterLoader.DefaultLibName);
{$ENDIF}
{$IFDEF MACOS}
  Assert.AreEqual('libtree-sitter.dylib', TTreeSitterLoader.DefaultLibName);
{$ENDIF}
end;

procedure TLoaderTests.TestUnloadAndReload;
begin
  TTreeSitterLoader.Unload;
  Assert.IsFalse(TTreeSitterLoader.IsLoaded);
  Assert.IsTrue(TTreeSitterLoader.Load, 'Reload failed');
  Assert.IsTrue(TTreeSitterLoader.IsLoaded);
end;

{ TParserTests }

procedure TParserTests.TestCreateParser;
var
  p: TTSParser;
begin
  p := TTSParser.Create;
  try
    Assert.IsNotNull(p);
    Assert.IsNotNull(p.Parser);
  finally
    p.Free;
  end;
end;

procedure TParserTests.TestSetLanguage;
var
  p: TTSParser;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    Assert.IsNotNull(p.Language);
  finally
    p.Free;
  end;
end;

procedure TParserTests.TestGetLanguage;
var
  p: TTSParser;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    Assert.AreEqual(NativeUInt(FPascalLang), NativeUInt(p.Language));
  finally
    p.Free;
  end;
end;

procedure TParserTests.TestParseString_Simple;
var
  p: TTSParser;
  t: TTSTree;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    t := p.ParseString(TestPascalSource);
    try
      Assert.IsNotNull(t);
      Assert.IsFalse(t.RootNode.IsNull);
    finally
      t.Free;
    end;
  finally
    p.Free;
  end;
end;

procedure TParserTests.TestParseString_Empty_Raises;
var
  p: TTSParser;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    Assert.WillRaise(
      procedure begin p.ParseString(''); end,
      ETreeSitterException);
  finally
    p.Free;
  end;
end;

procedure TParserTests.TestParseString_Unicode;
var
  p: TTSParser;
  t: TTSTree;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    t := p.ParseString('program '#$00DC'nic'#$00F6'de; begin end.');
    try
      Assert.IsNotNull(t);
      Assert.IsFalse(t.RootNode.IsNull);
    finally
      t.Free;
    end;
  finally
    p.Free;
  end;
end;

procedure TParserTests.TestParseString_WithOldTree;
var
  p: TTSParser;
  t1, t2: TTSTree;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    t1 := p.ParseString(TestPascalSource);
    try
      t2 := p.ParseString(TestPascalSource, t1);
      try
        Assert.IsNotNull(t2);
        Assert.IsFalse(t2.RootNode.IsNull);
      finally
        t2.Free;
      end;
    finally
      t1.Free;
    end;
  finally
    p.Free;
  end;
end;

procedure TParserTests.TestParse_WithCallback;
var
  p: TTSParser;
  t: TTSTree;
  srcBytes: TBytes;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    srcBytes := TEncoding.UTF8.GetBytes(TestPascalSource);
    t := p.Parse(
      function(AByteIndex: UInt32; APosition: TTSPoint; var ABytesRead: UInt32): TBytes
      begin
        if AByteIndex >= UInt32(Length(srcBytes)) then
        begin
          ABytesRead := 0;
          Result := nil;
          Exit;
        end;
        ABytesRead := Length(srcBytes) - AByteIndex;
        Result := Copy(srcBytes, AByteIndex, ABytesRead);
      end,
      TTSInputEncoding.TSInputEncodingUTF8);
    try
      Assert.IsNotNull(t);
      Assert.IsFalse(t.RootNode.IsNull);
    finally
      t.Free;
    end;
  finally
    p.Free;
  end;
end;

procedure TParserTests.TestReset;
var
  p: TTSParser;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    p.Reset;
    Assert.IsNotNull(p.Parser, 'Parser should still be valid after reset');
  finally
    p.Free;
  end;
end;

{ TTreeTests }

procedure TTreeTests.TestRootNodeNotNull;
var
  p: TTSParser;
  t: TTSTree;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    t := p.ParseString(TestPascalSource);
    try
      Assert.IsFalse(t.RootNode.IsNull);
    finally
      t.Free;
    end;
  finally
    p.Free;
  end;
end;

procedure TTreeTests.TestTreeLanguageNotNil;
var
  p: TTSParser;
  t: TTSTree;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    t := p.ParseString(TestPascalSource);
    try
      Assert.IsNotNull(t.Language);
    finally
      t.Free;
    end;
  finally
    p.Free;
  end;
end;

procedure TTreeTests.TestClone;
var
  p: TTSParser;
  t, t2: TTSTree;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    t := p.ParseString(TestPascalSource);
    try
      t2 := t.Clone;
      try
        Assert.IsNotNull(t2);
        Assert.IsFalse(t2.RootNode.IsNull);
        Assert.AreEqual(t.RootNode.NodeType, t2.RootNode.NodeType);
      finally
        t2.Free;
      end;
    finally
      t.Free;
    end;
  finally
    p.Free;
  end;
end;

procedure TTreeTests.TestTreeNilSafe;
var
  p: TTSParser;
  t: TTSTree;
begin
  p := TTSParser.Create;
  try
    p.Language := FPascalLang;
    t := p.ParseString(TestPascalSource);
    try
      Assert.IsNotNull(t.TreeNilSafe);
    finally
      t.Free;
    end;
  finally
    p.Free;
  end;
end;

procedure TTreeTests.TestTreeNilSafe_NilSelf;
var
  t: TTSTree;
begin
  t := nil;
  Assert.IsNull(t.TreeNilSafe);
end;

{ TNodeTests }

procedure TNodeTests.Setup;
begin
  FParser := TTSParser.Create;
  FParser.Language := FPascalLang;
  FTree := FParser.ParseString(TestPascalSourceMultiLine);
end;

procedure TNodeTests.TearDown;
begin
  FreeAndNil(FTree);
  FreeAndNil(FParser);
end;

procedure TNodeTests.TestNodeType;
begin
  // The pascal grammar wraps everything in a 'root' node
  Assert.AreEqual('root', FTree.RootNode.NodeType);
end;

procedure TNodeTests.TestSymbol;
begin
  Assert.IsTrue(FTree.RootNode.Symbol > 0);
end;

procedure TNodeTests.TestGrammarType;
begin
  Assert.IsFalse(FTree.RootNode.GrammarType = '');
end;

procedure TNodeTests.TestGrammarSymbol;
begin
  Assert.IsTrue(FTree.RootNode.GrammarSymbol > 0);
end;

procedure TNodeTests.TestIsNull_False;
begin
  Assert.IsFalse(FTree.RootNode.IsNull);
end;

procedure TNodeTests.TestIsNamed;
begin
  Assert.IsTrue(FTree.RootNode.IsNamed);
end;

procedure TNodeTests.TestIsError_NoError;
begin
  Assert.IsFalse(FTree.RootNode.IsError);
end;

procedure TNodeTests.TestHasError_NoError;
begin
  Assert.IsFalse(FTree.RootNode.HasError);
end;

procedure TNodeTests.TestIsExtra;
begin
  Assert.IsFalse(FTree.RootNode.IsExtra);
end;

procedure TNodeTests.TestIsMissing;
begin
  Assert.IsFalse(FTree.RootNode.IsMissing);
end;

procedure TNodeTests.TestParent;
begin
  // Root's parent should be null
  Assert.IsTrue(FTree.RootNode.Parent.IsNull);
  // First child's parent should be root
  if FTree.RootNode.ChildCount > 0 then
    Assert.AreEqual(FTree.RootNode.NodeType, FTree.RootNode.Child(0).Parent.NodeType);
end;

procedure TNodeTests.TestChildCount;
begin
  Assert.IsTrue(FTree.RootNode.ChildCount > 0);
end;

procedure TNodeTests.TestChild;
var
  child: TTSNode;
begin
  child := FTree.RootNode.Child(0);
  Assert.IsFalse(child.IsNull);
end;

procedure TNodeTests.TestNamedChild;
var
  child: TTSNode;
begin
  Assert.IsTrue(FTree.RootNode.NamedChildCount > 0);
  child := FTree.RootNode.NamedChild(0);
  Assert.IsFalse(child.IsNull);
  Assert.IsTrue(child.IsNamed);
end;

procedure TNodeTests.TestNamedChildCount;
begin
  Assert.IsTrue(FTree.RootNode.NamedChildCount > 0);
  Assert.IsTrue(FTree.RootNode.NamedChildCount <= FTree.RootNode.ChildCount);
end;

procedure TNodeTests.TestNextSibling;
var
  progNode, first, second: TTSNode;
begin
  // root -> program -> [children with siblings]
  progNode := FTree.RootNode.NamedChild(0); // program node
  Assert.IsTrue(progNode.ChildCount >= 2, 'program node must have >= 2 children');
  first := progNode.Child(0);
  second := first.NextSibling;
  Assert.IsFalse(second.IsNull);
end;

procedure TNodeTests.TestPrevSibling;
var
  progNode, first, second: TTSNode;
begin
  // root -> program -> [children with siblings]
  progNode := FTree.RootNode.NamedChild(0); // program node
  Assert.IsTrue(progNode.ChildCount >= 2, 'program node must have >= 2 children');
  second := progNode.Child(1);
  first := second.PrevSibling;
  Assert.IsFalse(first.IsNull);
  Assert.IsTrue(progNode.Child(0) = first);
end;

procedure TNodeTests.TestNextNamedSibling;
var
  first: TTSNode;
  next: TTSNode;
begin
  first := FTree.RootNode.NamedChild(0);
  next := first.NextNamedSibling;
  // May or may not be null depending on grammar, just test it doesn't crash
  if not next.IsNull then
    Assert.IsTrue(next.IsNamed);
end;

procedure TNodeTests.TestPrevNamedSibling;
var
  nc: Integer;
  last, prev: TTSNode;
begin
  nc := FTree.RootNode.NamedChildCount;
  if nc >= 2 then
  begin
    last := FTree.RootNode.NamedChild(nc - 1);
    prev := last.PrevNamedSibling;
    Assert.IsFalse(prev.IsNull);
    Assert.IsTrue(prev.IsNamed);
  end;
end;

procedure TNodeTests.TestChildByFieldName;
var
  nameNode: TTSNode;
begin
  // 'program Test;' -> program node should have a 'name' field
  nameNode := FTree.RootNode.ChildByField('name');
  if not nameNode.IsNull then
    Assert.IsFalse(nameNode.NodeType = '');
end;

procedure TNodeTests.TestChildByFieldId;
var
  lang: PTSLanguage;
  fieldId: TSFieldId;
  node: TTSNode;
begin
  lang := FTree.RootNode.Language;
  fieldId := lang^.FieldId['name'];
  if fieldId > 0 then
  begin
    node := FTree.RootNode.ChildByField(fieldId);
    if not node.IsNull then
      Assert.IsFalse(node.NodeType = '');
  end;
end;

procedure TNodeTests.TestStartByte;
begin
  Assert.AreEqual(UInt32(0), FTree.RootNode.StartByte);
end;

procedure TNodeTests.TestEndByte;
begin
  Assert.IsTrue(FTree.RootNode.EndByte > 0);
end;

procedure TNodeTests.TestStartPoint;
var
  pt: TTSPoint;
begin
  pt := FTree.RootNode.StartPoint;
  Assert.AreEqual(UInt32(0), pt.row);
  Assert.AreEqual(UInt32(0), pt.column);
end;

procedure TNodeTests.TestEndPoint;
var
  pt: TTSPoint;
begin
  pt := FTree.RootNode.EndPoint;
  Assert.IsTrue(pt.row > 0);
end;

procedure TNodeTests.TestDescendantCount;
begin
  Assert.IsTrue(FTree.RootNode.DescendantCount > 0);
end;

procedure TNodeTests.TestToString;
var
  s: string;
begin
  s := FTree.RootNode.ToString;
  Assert.IsFalse(s = '');
  Assert.IsTrue(Pos('program', s) > 0);
end;

procedure TNodeTests.TestEqual;
var
  a, b: TTSNode;
begin
  a := FTree.RootNode;
  b := FTree.RootNode;
  Assert.IsTrue(a = b);
  if a.ChildCount > 0 then
    Assert.IsFalse(a = a.Child(0));
end;

{ TCursorTests }

procedure TCursorTests.Setup;
begin
  FParser := TTSParser.Create;
  FParser.Language := FPascalLang;
  FTree := FParser.ParseString(TestPascalSourceMultiLine);
end;

procedure TCursorTests.TearDown;
begin
  FreeAndNil(FTree);
  FreeAndNil(FParser);
end;

procedure TCursorTests.TestCreateFromNode;
var
  c: TTSTreeCursor;
begin
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    Assert.IsFalse(c.CurrentNode.IsNull);
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestCopyConstructor;
var
  c1, c2: TTSTreeCursor;
begin
  c1 := TTSTreeCursor.Create(FTree.RootNode);
  try
    c1.GotoFirstChild;
    c2 := TTSTreeCursor.Create(c1);
    try
      Assert.AreEqual(c1.CurrentNode.NodeType, c2.CurrentNode.NodeType);
    finally
      c2.Free;
    end;
  finally
    c1.Free;
  end;
end;

procedure TCursorTests.TestGotoFirstChild;
var
  c: TTSTreeCursor;
begin
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    Assert.IsTrue(c.GotoFirstChild);
    Assert.IsFalse(c.CurrentNode.IsNull);
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestGotoLastChild;
var
  c: TTSTreeCursor;
begin
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    Assert.IsTrue(c.GotoLastChild);
    Assert.IsFalse(c.CurrentNode.IsNull);
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestGotoNextSibling;
var
  c: TTSTreeCursor;
begin
  // root -> program -> [multiple children]
  // Descend into program node to find siblings
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    Assert.IsTrue(c.GotoFirstChild, 'root must have a child');     // goto program
    Assert.IsTrue(c.GotoFirstChild, 'program must have a child');  // goto first child of program
    Assert.IsTrue(c.GotoNextSibling, 'program children must have siblings');
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestGotoPrevSibling;
var
  c: TTSTreeCursor;
begin
  // root -> program -> [multiple children]
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    c.GotoFirstChild;  // goto program
    c.GotoFirstChild;  // goto first child of program
    c.GotoNextSibling; // goto second child
    Assert.IsTrue(c.GotoPrevSibling);
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestGotoParent;
var
  c: TTSTreeCursor;
begin
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    c.GotoFirstChild;
    Assert.IsTrue(c.GotoParent);
    Assert.AreEqual(FTree.RootNode.NodeType, c.CurrentNode.NodeType);
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestGotoDescendant;
var
  c: TTSTreeCursor;
begin
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    c.GotoDescendant(1);
    Assert.IsFalse(c.CurrentNode.IsNull);
    Assert.IsTrue(c.CurrentDescendantIndex <= 1);
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestGotoFirstChildForByte;
var
  c: TTSTreeCursor;
  idx: Int64;
begin
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    idx := c.GotoFirstChildForGoal(UInt32(0));
    Assert.IsTrue(idx >= 0);
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestCurrentNode;
var
  c: TTSTreeCursor;
begin
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    Assert.AreEqual(FTree.RootNode.NodeType, c.CurrentNode.NodeType);
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestCurrentFieldName;
var
  c: TTSTreeCursor;
begin
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    c.GotoFirstChild;
    // First child may or may not have a field name — just ensure no crash
    c.CurrentFieldName;
    Assert.Pass;
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestCurrentFieldId;
var
  c: TTSTreeCursor;
begin
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    c.GotoFirstChild;
    // Just ensure no crash
    c.CurrentFieldId;
    Assert.Pass;
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestCurrentDepth;
var
  c: TTSTreeCursor;
begin
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    Assert.AreEqual(UInt32(0), c.CurrentDepth);
    c.GotoFirstChild;
    Assert.AreEqual(UInt32(1), c.CurrentDepth);
  finally
    c.Free;
  end;
end;

procedure TCursorTests.TestResetToNode;
var
  c: TTSTreeCursor;
begin
  c := TTSTreeCursor.Create(FTree.RootNode);
  try
    c.GotoFirstChild;
    c.Reset(FTree.RootNode);
    Assert.AreEqual(FTree.RootNode.NodeType, c.CurrentNode.NodeType);
    Assert.AreEqual(UInt32(0), c.CurrentDepth);
  finally
    c.Free;
  end;
end;

{ TLanguageTests }

procedure TLanguageTests.TestVersion;
begin
  Assert.IsTrue(FPascalLang^.Version >= TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION);
end;

procedure TLanguageTests.TestFieldCount;
begin
  Assert.IsTrue(FPascalLang^.FieldCount > 0);
end;

procedure TLanguageTests.TestSymbolCount;
begin
  Assert.IsTrue(FPascalLang^.SymbolCount > 0);
end;

procedure TLanguageTests.TestFieldName;
var
  name: string;
begin
  name := FPascalLang^.FieldName[1];
  Assert.IsFalse(name = '');
end;

procedure TLanguageTests.TestFieldId;
var
  name: string;
  id: TSFieldId;
begin
  name := FPascalLang^.FieldName[1];
  id := FPascalLang^.FieldId[name];
  Assert.AreEqual(TSFieldId(1), id);
end;

procedure TLanguageTests.TestSymbolName;
begin
  // Symbol 0 is usually the end/error marker
  Assert.IsFalse(FPascalLang^.SymbolName[1] = '');
end;

procedure TLanguageTests.TestSymbolForName;
var
  sym: TSSymbol;
begin
  sym := FPascalLang^.SymbolForName['program', True];
  Assert.IsTrue(sym > 0);
end;

procedure TLanguageTests.TestSymbolType;
var
  st: TSSymbolType;
begin
  st := FPascalLang^.SymbolType[1];
  Assert.IsTrue(Ord(st) <= Ord(High(TSSymbolType)));
end;

{ TQueryTests }

procedure TQueryTests.Setup;
begin
  FParser := TTSParser.Create;
  FParser.Language := FPascalLang;
  FTree := FParser.ParseString(TestPascalSourceMultiLine);
end;

procedure TQueryTests.TearDown;
begin
  FreeAndNil(FTree);
  FreeAndNil(FParser);
end;

procedure TQueryTests.TestCreateValidQuery;
var
  q: TTSQuery;
  errOff: UInt32;
  errType: TTSQueryError;
begin
  q := TTSQuery.Create(FPascalLang, '(program)', errOff, errType);
  try
    Assert.AreEqual(Ord(TSQueryErrorNone), Ord(errType));
    Assert.IsNotNull(q.Query);
  finally
    q.Free;
  end;
end;

procedure TQueryTests.TestCreateInvalidQuery_ErrorOffset;
var
  q: TTSQuery;
  errOff: UInt32;
  errType: TTSQueryError;
begin
  q := TTSQuery.Create(FPascalLang, '(nonexistent_node_xyz)', errOff, errType);
  try
    Assert.AreNotEqual(Ord(TSQueryErrorNone), Ord(errType));
  finally
    q.Free;
  end;
end;

procedure TQueryTests.TestPatternCount;
var
  q: TTSQuery;
  errOff: UInt32;
  errType: TTSQueryError;
begin
  q := TTSQuery.Create(FPascalLang, '(program)', errOff, errType);
  try
    Assert.AreEqual(UInt32(1), q.PatternCount);
  finally
    q.Free;
  end;
end;

procedure TQueryTests.TestCaptureCount;
var
  q: TTSQuery;
  errOff: UInt32;
  errType: TTSQueryError;
begin
  q := TTSQuery.Create(FPascalLang, '(program) @prog', errOff, errType);
  try
    Assert.AreEqual(Ord(TSQueryErrorNone), Ord(errType));
    Assert.AreEqual(UInt32(1), q.CaptureCount);
  finally
    q.Free;
  end;
end;

procedure TQueryTests.TestCaptureNameForID;
var
  q: TTSQuery;
  errOff: UInt32;
  errType: TTSQueryError;
begin
  q := TTSQuery.Create(FPascalLang, '(program) @prog', errOff, errType);
  try
    Assert.AreEqual('prog', q.CaptureNameForID(0));
  finally
    q.Free;
  end;
end;

procedure TQueryTests.TestStringCount;
var
  q: TTSQuery;
  errOff: UInt32;
  errType: TTSQueryError;
begin
  q := TTSQuery.Create(FPascalLang, '(program)', errOff, errType);
  try
    // A simple query without string predicates should have 0 strings
    Assert.AreEqual(UInt32(0), q.StringCount);
  finally
    q.Free;
  end;
end;

procedure TQueryTests.TestExecuteNextMatch;
var
  q: TTSQuery;
  qc: TTSQueryCursor;
  match: TTSQueryMatch;
  errOff: UInt32;
  errType: TTSQueryError;
begin
  q := TTSQuery.Create(FPascalLang, '(program) @prog', errOff, errType);
  try
    qc := TTSQueryCursor.Create;
    try
      qc.Execute(q, FTree.RootNode);
      Assert.IsTrue(qc.NextMatch(match));
      Assert.IsTrue(match.capture_count > 0);
      Assert.AreEqual('program', match.CapturesArray[0].node.NodeType);
    finally
      qc.Free;
    end;
  finally
    q.Free;
  end;
end;

procedure TQueryTests.TestExecuteNextCapture;
var
  q: TTSQuery;
  qc: TTSQueryCursor;
  match: TTSQueryMatch;
  capIdx: UInt32;
  errOff: UInt32;
  errType: TTSQueryError;
begin
  q := TTSQuery.Create(FPascalLang, '(program) @prog', errOff, errType);
  try
    qc := TTSQueryCursor.Create;
    try
      qc.Execute(q, FTree.RootNode);
      Assert.IsTrue(qc.NextCapture(match, capIdx));
    finally
      qc.Free;
    end;
  finally
    q.Free;
  end;
end;

procedure TQueryTests.TestMatchLimit;
var
  qc: TTSQueryCursor;
begin
  qc := TTSQueryCursor.Create;
  try
    qc.MatchLimit := 100;
    Assert.AreEqual(UInt32(100), qc.MatchLimit);
  finally
    qc.Free;
  end;
end;

procedure TQueryTests.TestMultiPatternQuery;
var
  q: TTSQuery;
  errOff: UInt32;
  errType: TTSQueryError;
begin
  q := TTSQuery.Create(FPascalLang, '(program) @p (identifier) @id', errOff, errType);
  try
    Assert.AreEqual(Ord(TSQueryErrorNone), Ord(errType));
    Assert.AreEqual(UInt32(2), q.PatternCount);
    Assert.AreEqual(UInt32(2), q.CaptureCount);
  finally
    q.Free;
  end;
end;

procedure TQueryTests.TestQueryNoMatches;
var
  q: TTSQuery;
  qc: TTSQueryCursor;
  match: TTSQueryMatch;
  errOff: UInt32;
  errType: TTSQueryError;
begin
  // Query for something unlikely in our test source
  q := TTSQuery.Create(FPascalLang, '(class_declaration) @cls', errOff, errType);
  try
    if errType <> TSQueryErrorNone then
    begin
      Assert.Pass('class_declaration not a valid node in this grammar');
      Exit;
    end;
    qc := TTSQueryCursor.Create;
    try
      qc.Execute(q, FTree.RootNode);
      Assert.IsFalse(qc.NextMatch(match));
    finally
      qc.Free;
    end;
  finally
    q.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLoaderTests);
  TDUnitX.RegisterTestFixture(TParserTests);
  TDUnitX.RegisterTestFixture(TTreeTests);
  TDUnitX.RegisterTestFixture(TNodeTests);
  TDUnitX.RegisterTestFixture(TCursorTests);
  TDUnitX.RegisterTestFixture(TLanguageTests);
  TDUnitX.RegisterTestFixture(TQueryTests);

end.
