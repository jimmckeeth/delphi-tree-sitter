unit frmDTSMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.StdCtrls, TreeSitter, TreeSitterLib,
  TreeSitter.App, Vcl.Grids,
  System.Actions, Vcl.ActnList, Vcl.Menus;

type
  TTSTreeViewNode = class(TTreeNode)
  public
    TSNode: TTSNode;
  end;

  TDTSMainForm = class(TForm)
    memCode: TMemo;
    pnlTop: TPanel;
    treeView: TTreeView;
    Splitter1: TSplitter;
    OD: TFileOpenDialog;
    btnLoad: TButton;
    lblCode: TLabel;
    cbCode: TComboBox;
    Splitter2: TSplitter;
    Panel1: TPanel;
    sgNodeProps: TStringGrid;
    AL: TActionList;
    actGoto: TAction;
    actGotoParent: TAction;
    pmTree: TPopupMenu;
    mnuactGoto: TMenuItem;
    mnuactGotoParent: TMenuItem;
    cbFields: TComboBox;
    Label1: TLabel;
    btnGetChildByField: TButton;
    actGetChildByField: TAction;
    actShowNodeAsString: TAction;
    mnuactShowNodeAsString: TMenuItem;
    N1: TMenuItem;
    actGotoFirstChild: TAction;
    actGotoNextSibling: TAction;
    actGotoPrevSibling: TAction;
    mnuactGotoFirstChild: TMenuItem;
    mnuactGotoNextSibling: TMenuItem;
    mnuactGotoPrevSibling: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    btnLangInfo: TButton;
    btnQuery: TButton;
    actNamedNodesOnly: TAction;
    mnuactNamedNodesOnly: TMenuItem;
    N4: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure memCodeExit(Sender: TObject);
    procedure treeViewCreateNodeClass(Sender: TCustomTreeView;
      var NodeClass: TTreeNodeClass);
    procedure treeViewExpanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
    procedure btnLoadClick(Sender: TObject);
    procedure cbCodeChange(Sender: TObject);
    procedure treeViewChange(Sender: TObject; Node: TTreeNode);
    procedure memCodeChange(Sender: TObject);
    procedure actGotoUpdate(Sender: TObject);
    procedure actGotoParentExecute(Sender: TObject);
    procedure actGotoParentUpdate(Sender: TObject);
    procedure actGotoExecute(Sender: TObject);
    procedure actGetChildByFieldExecute(Sender: TObject);
    procedure actGetChildByFieldUpdate(Sender: TObject);
    procedure actShowNodeAsStringUpdate(Sender: TObject);
    procedure actShowNodeAsStringExecute(Sender: TObject);
    procedure actGotoFirstChildExecute(Sender: TObject);
    procedure actGotoFirstChildUpdate(Sender: TObject);
    procedure actGotoNextSiblingExecute(Sender: TObject);
    procedure actGotoNextSiblingUpdate(Sender: TObject);
    procedure actGotoPrevSiblingExecute(Sender: TObject);
    procedure actGotoPrevSiblingUpdate(Sender: TObject);
    procedure btnLangInfoClick(Sender: TObject);
    procedure btnQueryClick(Sender: TObject);
    procedure actNamedNodesOnlyExecute(Sender: TObject);
  private
    FGrammarLoader: TTSGrammarLoader;
    FAppManager: TTSAppManager;
    FInitialized: Boolean;
    FEditChanged: Boolean;
    procedure ParseContent;
    procedure LoadLanguageParser(const ALangBaseName: string);
    procedure LoadLanguageFields;
    procedure FillNodeProps(const ANode: TTSNode);
    procedure ClearNodeProps;
    function GetSelectedTSNode: TTSNode;
    procedure SetSelectedTSNode(const Value: TTSNode);
    procedure SetupTreeTSNode(ATreeNode: TTSTreeViewNode; ATSNode: TTSNode);
  public
    property SelectedTSNode: TTSNode read GetSelectedTSNode write SetSelectedTSNode;
  end;

var
  DTSMainForm: TDTSMainForm;

implementation

uses
  frmDTSLanguage,
  frmDTSQuery,
  UITypes;

{$R *.dfm}

type
  TSGNodePropRow = (rowSymbol, rowGrammarType, rowGrammarSymbol, rowIsError,
    rowHasError, rowIsExtra, rowIsMissing, rowIsNamed, rowChildCount,
    rowNamedChildCount, rowStartByte, rowStartPoint, rowEndByte, rowEndPoint,
    rowDescendantCount);

const
  sgNodePropCaptions: array[TSGNodePropRow] of string = (
    'Symbol', 'GrammarType', 'GrammarSymbol', 'IsError',
    'HasError', 'IsExtra', 'IsMissing', 'IsNamed', 'ChildCount',
    'NamedChildCount', 'StartByte', 'StartPoint', 'EndByte', 'EndPoint',
    'DescendantCount');

procedure TDTSMainForm.actGetChildByFieldExecute(Sender: TObject);
var
  foundNode: TTSNode;
begin
  foundNode:= SelectedTSNode.ChildByField(cbFields.ItemIndex + 1);
  //foundNode:= SelectedTSNode.ChildByField(cbFields.Text);
  if foundNode.IsNull then
    MessageDlg(Format('No child for field "%s" (%d) found', [cbFields.Text, cbFields.ItemIndex]),
      TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0) else
    SelectedTSNode:= foundNode;
end;

procedure TDTSMainForm.actGetChildByFieldUpdate(Sender: TObject);
begin
  if not FInitialized then begin actGetChildByField.Enabled := False; Exit; end;
  actGetChildByField.Enabled:= (not SelectedTSNode.IsNull) and
    (cbFields.ItemIndex >= 0);
end;

procedure TDTSMainForm.actGotoExecute(Sender: TObject);
begin
  //to keep it enabled
end;

procedure TDTSMainForm.actGotoFirstChildExecute(Sender: TObject);
begin
  if actNamedNodesOnly.Checked then
    SelectedTSNode:= SelectedTSNode.NamedChild(0) else
    SelectedTSNode:= SelectedTSNode.Child(0);
end;

procedure TDTSMainForm.actGotoFirstChildUpdate(Sender: TObject);
begin
  if not FInitialized then begin actGotoFirstChild.Enabled := False; Exit; end;
  if actNamedNodesOnly.Checked then
    actGotoFirstChild.Enabled:= SelectedTSNode.NamedChildCount > 0 else
    actGotoFirstChild.Enabled:= SelectedTSNode.ChildCount > 0;
end;

procedure TDTSMainForm.actGotoNextSiblingExecute(Sender: TObject);
begin
  if actNamedNodesOnly.Checked then
    SelectedTSNode:= SelectedTSNode.NextNamedSibling else
    SelectedTSNode:= SelectedTSNode.NextSibling;
end;

procedure TDTSMainForm.actGotoNextSiblingUpdate(Sender: TObject);
begin
  if not FInitialized then begin actGotoNextSibling.Enabled := False; Exit; end;
  if actNamedNodesOnly.Checked then
    actGotoNextSibling.Enabled:= not SelectedTSNode.NextNamedSibling.IsNull else
    actGotoNextSibling.Enabled:= not SelectedTSNode.NextSibling.IsNull;
end;

procedure TDTSMainForm.actGotoParentExecute(Sender: TObject);
begin
  SelectedTSNode:= SelectedTSNode.Parent;
end;

procedure TDTSMainForm.actGotoParentUpdate(Sender: TObject);
begin
  if not FInitialized then begin actGotoParent.Enabled := False; Exit; end;
  actGotoParent.Enabled:= not SelectedTSNode.Parent.IsNull;
end;

procedure TDTSMainForm.actGotoPrevSiblingExecute(Sender: TObject);
begin
  if actNamedNodesOnly.Checked then
    SelectedTSNode:= SelectedTSNode.PrevNamedSibling else
    SelectedTSNode:= SelectedTSNode.PrevSibling;
end;

procedure TDTSMainForm.actGotoPrevSiblingUpdate(Sender: TObject);
begin
  if not FInitialized then begin actGotoPrevSibling.Enabled := False; Exit; end;
  if actNamedNodesOnly.Checked then
    actGotoPrevSibling.Enabled:= not SelectedTSNode.PrevNamedSibling.IsNull else
    actGotoPrevSibling.Enabled:= not SelectedTSNode.PrevSibling.IsNull;
end;

procedure TDTSMainForm.actGotoUpdate(Sender: TObject);
begin
  if not FInitialized then begin actGoto.Enabled := False; Exit; end;
  actGoto.Enabled:= not SelectedTSNode.IsNull;
end;

procedure TDTSMainForm.actNamedNodesOnlyExecute(Sender: TObject);
var
  root, prevSelected: TTSNode;
  rootNode: TTSTreeViewNode;
begin
  if not Assigned(FAppManager) then Exit;
  prevSelected:= SelectedTSNode;
  try
    treeView.Items.Clear;
    if FAppManager.Tree = nil then Exit;
    root:= FAppManager.Tree.RootNode;
    rootNode:= TTSTreeViewNode(treeView.Items.AddChild(nil, root.NodeType));
    SetupTreeTSNode(rootNode, root);
  finally
    SelectedTSNode:= prevSelected;
  end;
end;

procedure TDTSMainForm.actShowNodeAsStringExecute(Sender: TObject);
begin
  ShowMessage(SelectedTSNode.ToString);
end;

procedure TDTSMainForm.actShowNodeAsStringUpdate(Sender: TObject);
begin
  if not FInitialized then begin actShowNodeAsString.Enabled := False; Exit; end;
  actShowNodeAsString.Enabled:= not SelectedTSNode.IsNull;
end;

procedure TDTSMainForm.btnLangInfoClick(Sender: TObject);
begin
  if Assigned(FAppManager) then
    ShowLanguageInfo(FAppManager.Parser.Language);
end;

procedure TDTSMainForm.btnLoadClick(Sender: TObject);
begin
  if not OD.Execute(Handle) then
    Exit;
  memCode.Lines.LoadFromFile(OD.FileName);
  FEditChanged:= True;
  if Assigned(FAppManager) then
    ParseContent;
end;

procedure TDTSMainForm.btnQueryClick(Sender: TObject);
begin
  if Assigned(FAppManager) then
    ShowQueryForm(FAppManager.Tree);
end;

procedure TDTSMainForm.LoadLanguageParser(const ALangBaseName: string);
begin
  if Assigned(FAppManager) then
  begin
    FAppManager.SetLanguage(ALangBaseName);
    LoadLanguageFields;
  end;
end;

procedure TDTSMainForm.LoadLanguageFields;
var
  fields: TArray<TTSFieldInfo>;
  field: TTSFieldInfo;
begin
  if not Assigned(FAppManager) then Exit;
  cbFields.Items.BeginUpdate;
  try
    cbFields.Items.Clear;
    fields := FAppManager.GetLanguageFields;
    for field in fields do
      cbFields.Items.AddObject(field.FieldName, TObject(field.FieldId));
  finally
    cbFields.Items.EndUpdate;
  end;
end;

procedure TDTSMainForm.cbCodeChange(Sender: TObject);
begin
  if cbCode.ItemIndex >= 0 then
  begin
    LoadLanguageParser(cbCode.Items[cbCode.ItemIndex]);
    ParseContent;
  end;
end;

procedure TDTSMainForm.ClearNodeProps;
var
  row: TSGNodePropRow;
begin
  for row:= Low(TSGNodePropRow) to High(TSGNodePropRow) do
    sgNodeProps.Cells[1, Ord(row)]:= '';
end;

procedure TDTSMainForm.FillNodeProps(const ANode: TTSNode);
begin
  if ANode.IsNull then Exit;
  sgNodeProps.Cells[1, Ord(rowSymbol)]:= Format('%d (%s)', [ANode.Symbol, ANode.Language^.SymbolName[ANode.Symbol]]);
  sgNodeProps.Cells[1, Ord(rowGrammarType)]:= ANode.GrammarType;
  sgNodeProps.Cells[1, Ord(rowGrammarSymbol)]:= Format('%d (%s)', [ANode.GrammarSymbol, ANode.Language^.SymbolName[ANode.GrammarSymbol]]);
  sgNodeProps.Cells[1, Ord(rowIsError)]:= BoolToStr(ANode.IsError, True);
  sgNodeProps.Cells[1, Ord(rowHasError)]:= BoolToStr(ANode.HasError, True);
  sgNodeProps.Cells[1, Ord(rowIsExtra)]:= BoolToStr(ANode.IsExtra, True);
  sgNodeProps.Cells[1, Ord(rowIsMissing)]:= BoolToStr(ANode.IsMissing, True);
  sgNodeProps.Cells[1, Ord(rowIsNamed)]:= BoolToStr(ANode.IsNamed, True);
  sgNodeProps.Cells[1, Ord(rowChildCount)]:= IntToStr(ANode.ChildCount);
  sgNodeProps.Cells[1, Ord(rowNamedChildCount)]:= IntToStr(ANode.NamedChildCount);
  sgNodeProps.Cells[1, Ord(rowStartByte)]:= IntToStr(ANode.StartByte);
  sgNodeProps.Cells[1, Ord(rowStartPoint)]:= ANode.StartPoint.ToString;
  sgNodeProps.Cells[1, Ord(rowEndByte)]:= IntToStr(ANode.EndByte);
  sgNodeProps.Cells[1, Ord(rowEndPoint)]:= ANode.EndPoint.ToString;
  sgNodeProps.Cells[1, Ord(rowDescendantCount)]:= IntToStr(ANode.DescendantCount);
end;

procedure TDTSMainForm.FormCreate(Sender: TObject);
var
  row: TSGNodePropRow;
begin
  FGrammarLoader := TTSGrammarLoader.Create;
  FGrammarLoader.OnConfirmDownload :=
    function(const AMessage: string): Boolean
    begin
      Result := MessageDlg(AMessage, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
    end;
  try
    if not FGrammarLoader.EnsureCoreLoaded then
    begin
      MessageDlg(
        'Tree-sitter core library not found and download was declined.' + #13#10 +
        'Run Examples\BuildLibs.ps1 -Platforms Win32 to build the DLLs,' + #13#10 +
        'then copy Libs\Win32\tree-sitter*.dll next to this executable.',
        mtError, [mbOK], 0);
      Close;
      Exit;
    end;

    FAppManager := TTSAppManager.Create(FGrammarLoader);

    //initialize property grid captions
    sgNodeProps.RowCount:= Ord(High(TSGNodePropRow)) - Ord(Low(TSGNodePropRow)) + 1;
    for row:= Low(TSGNodePropRow) to High(TSGNodePropRow) do
      sgNodeProps.Cells[0, Ord(row)]:= sgNodePropCaptions[row];

    cbCode.ItemIndex:= 0;
    cbCodeChange(nil);
    FInitialized := True;
  except
    on E: Exception do
    begin
      MessageDlg(
        'Initialization error: ' + E.Message + #13#10#13#10 +
        'Run Examples\BuildLibs.ps1 -Platforms Win32 to build the DLLs,' + #13#10 +
        'then copy Libs\Win32\tree-sitter*.dll next to this executable.',
        mtError, [mbOK], 0);
      Close;
    end;
  end;
end;

procedure TDTSMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FAppManager);
  FreeAndNil(FGrammarLoader);
end;

function TDTSMainForm.GetSelectedTSNode: TTSNode;
begin
  if not FInitialized then
    Exit(Default(TTSNode));
  if (treeView.Selected is TTSTreeViewNode) then
    Result:= TTSTreeViewNode(treeView.Selected).TSNode
  else if Assigned(FAppManager) and (FAppManager.Tree <> nil) then
    Result:= FAppManager.Tree.RootNode.Parent //easy way to create a NULL node
  else
    Result:= Default(TTSNode); //zero-initialized null node
end;

procedure TDTSMainForm.ParseContent;
var
  root: TTSNode;
  rootNode: TTSTreeViewNode;
  sCode: string;
begin
  if not Assigned(FAppManager) then
    Exit;
  treeView.Items.Clear;
  sCode:= memCode.Lines.Text;
  if DTSQueryForm <> nil then
    DTSQueryForm.TreeDeleted;
  if not FAppManager.ParseSource(sCode) then
    Exit;
  root:= FAppManager.Tree.RootNode;
  rootNode:= TTSTreeViewNode(treeView.Items.AddChild(nil, root.NodeType));
  SetupTreeTSNode(rootNode, root);
  FEditChanged:= False;
  if DTSQueryForm <> nil then
    DTSQueryForm.NewTreeGenerated(FAppManager.Tree);
end;

procedure TDTSMainForm.SetSelectedTSNode(const Value: TTSNode);

  function FindViaParent(const ATSNode: TTSNode): TTreeNode;
  var
    tsParent: TTSNode;
  begin
    tsParent:= ATSNode.Parent;
    if tsParent.IsNull then
      Result:= treeView.Items.GetFirstNode else
    begin
      Result:= FindViaParent(tsParent);
      if Result <> nil then
      begin
        Result.Expand(False);
        Result:= Result.getFirstChild;
      end;
    end;
    if Result = nil then
      Exit;
    while Result is TTSTreeViewNode do
    begin
      if TTSTreeViewNode(Result).TSNode = ATSNode then
        Exit;
      Result:= Result.getNextSibling as TTSTreeViewNode;
    end;
  end;

begin
  treeView.Selected:= FindViaParent(Value);
end;

procedure TDTSMainForm.treeViewChange(Sender: TObject; Node: TTreeNode);
var
  tsSelected: TTSNode;
  ptStart, ptEnd: TTSPoint;
  memSel: TSelection;
  line: LRESULT;
begin
  if Node = nil then
  begin
    ClearNodeProps;
    Exit;
  end;
  tsSelected:= TTSTreeViewNode(Node).TSNode;
  FillNodeProps(tsSelected);

  //select the corresponding code in the memo
  ptStart:= tsSelected.StartPoint;
  ptEnd:= tsSelected.EndPoint;

  line:= memcode.Perform(EM_LineIndex, ptStart.row, 0);
  if line < 0 then
    Exit; //something's not right

  //TSPoint.Column is in bytes, we use UTF16, so divide by 2 to get character,
  //which is a simplification not necessarily true
  memSel.StartPos:= line + Integer(ptStart.column) div 2;

  line:= memcode.Perform(EM_LineIndex, ptEnd.row, 0);
  if line < 0 then
    Exit; //something's not right
  memSel.EndPos:= line + Integer(ptEnd.column) div 2;

  SendMessage(memCode.Handle, EM_SETSEL, memSel.StartPos, memSel.EndPos);
  SendMessage(memCode.Handle, EM_SCROLLCARET, 0, 0);
end;

procedure TDTSMainForm.treeViewCreateNodeClass(Sender: TCustomTreeView;
  var NodeClass: TTreeNodeClass);
begin
  NodeClass:= TTSTreeViewNode;
end;

procedure TDTSMainForm.treeViewExpanding(Sender: TObject; Node: TTreeNode;
  var AllowExpansion: Boolean);
var
  tsCursor: TTSTreeCursor;
  tsNode: TTSNode;
  newTreeNode: TTSTreeViewNode;
  s: string;
begin
  AllowExpansion:= True;
  if Node.getFirstChild <> nil then
    Exit;
  tsCursor:= TTSTreeCursor.Create(TTSTreeViewNode(Node).TSNode);
  try
    if tsCursor.GotoFirstChild then
    begin
      repeat
        tsNode:= tsCursor.CurrentNode;
        if actNamedNodesOnly.Checked and not tsNode.IsNamed then
          Continue;
        if tsCursor.CurrentFieldId > 0 then
          s:= Format('%s (%d): %s', [tsCursor.CurrentFieldName,
            tsCursor.CurrentFieldId, tsNode.NodeType])
        else
          s:= tsNode.NodeType;
        newTreeNode:= TTSTreeViewNode(treeView.Items.AddChild(Node, s));
        SetupTreeTSNode(newTreeNode, tsNode);
      until not tsCursor.GotoNextSibling;
    end;
  finally
    tsCursor.Free;
  end;
end;

procedure TDTSMainForm.memCodeChange(Sender: TObject);
begin
  FEditChanged:= True;
end;

procedure TDTSMainForm.memCodeExit(Sender: TObject);
begin
  if FEditChanged then
    ParseContent;
end;

procedure TDTSMainForm.SetupTreeTSNode(ATreeNode: TTSTreeViewNode; ATSNode: TTSNode);
begin
  ATreeNode.TSNode:= ATSNode;
  if actNamedNodesOnly.Checked then
    ATreeNode.HasChildren:= ATSNode.NamedChildCount > 0 else
    ATreeNode.HasChildren:= ATSNode.ChildCount > 0;
end;

end.
