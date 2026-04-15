unit frmDTSMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.IOUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.StdCtrls, TreeSitter, TreeSitterLib,
  TreeSitter.App, Vcl.Grids,
  System.Actions, Vcl.ActnList, Vcl.Menus,
  frmDTSMain.Controller;

type
  TTSTreeViewNode = class(TTreeNode)
  public
    TSNode: TTSNode;
  end;

  TDTSMainForm = class(TForm, IDTSMainView)
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
    lblFields: TLabel;
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
    FController: TDTSMainController;
    FEditChanged: Boolean;
    function FindRepoRoot: string;
    procedure LoadSampleForLanguage;
    { IDTSMainView }
    procedure UpdateTreeView(ATree: TTSTree);
    procedure UpdateNodeProperties(const AProps: TTSNodeProperties);
    procedure UpdateLanguageFields(const AFields: TArray<TTSFieldInfo>);
    procedure SelectCodeRange(AStartRow, AStartCol, AEndRow, AEndCol: Integer);
    procedure ClearNodeProperties;
    function ConfirmDownload(const AMessage: string): Boolean;
    procedure ShowError(const AMessage: string);

    procedure FillNodeProps(const AProps: TTSNodeProperties);
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

procedure TDTSMainForm.UpdateTreeView(ATree: TTSTree);
var
  root: TTSNode;
  rootNode: TTSTreeViewNode;
begin
  treeView.Items.BeginUpdate;
  try
    treeView.Items.Clear;
    if ATree = nil then Exit;
    root := ATree.RootNode;
    rootNode := TTSTreeViewNode(treeView.Items.AddChild(nil, root.NodeType));
    SetupTreeTSNode(rootNode, root);
    if DTSQueryForm <> nil then
      DTSQueryForm.NewTreeGenerated(ATree);
  finally
    treeView.Items.EndUpdate;
  end;
end;

procedure TDTSMainForm.UpdateNodeProperties(const AProps: TTSNodeProperties);
begin
  FillNodeProps(AProps);
end;

procedure TDTSMainForm.UpdateLanguageFields(const AFields: TArray<TTSFieldInfo>);
var
  field: TTSFieldInfo;
begin
  cbFields.Items.BeginUpdate;
  try
    cbFields.Items.Clear;
    for field in AFields do
      cbFields.Items.AddObject(field.FieldName, TObject(field.FieldId));
  finally
    cbFields.Items.EndUpdate;
  end;
end;

procedure TDTSMainForm.SelectCodeRange(AStartRow, AStartCol, AEndRow, AEndCol: Integer);
var
  line: LRESULT;
  startPos, endPos: Integer;
begin
  line := memCode.Perform(EM_LineIndex, AStartRow, 0);
  if line < 0 then Exit;
  startPos := line + AStartCol div 2;

  line := memCode.Perform(EM_LineIndex, AEndRow, 0);
  if line < 0 then Exit;
  endPos := line + AEndCol div 2;

  SendMessage(memCode.Handle, EM_SETSEL, startPos, endPos);
  SendMessage(memCode.Handle, EM_SCROLLCARET, 0, 0);
end;

procedure TDTSMainForm.ClearNodeProperties;
var
  row: TSGNodePropRow;
begin
  for row := Low(TSGNodePropRow) to High(TSGNodePropRow) do
    sgNodeProps.Cells[1, Ord(row)] := '';
end;

function TDTSMainForm.ConfirmDownload(const AMessage: string): Boolean;
begin
  Result := MessageDlg(AMessage, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

procedure TDTSMainForm.ShowError(const AMessage: string);
begin
  MessageDlg(AMessage, mtError, [mbOK], 0);
end;

procedure TDTSMainForm.actGetChildByFieldExecute(Sender: TObject);
begin
  FController.GetChildByField(Integer(cbFields.Items.Objects[cbFields.ItemIndex]));
end;

procedure TDTSMainForm.actGetChildByFieldUpdate(Sender: TObject);
begin
  if (FController = nil) or (not FController.Initialized) then begin actGetChildByField.Enabled := False; Exit; end;
  actGetChildByField.Enabled := (not FController.SelectedNode.IsNull) and
    (cbFields.ItemIndex >= 0);
end;

procedure TDTSMainForm.actGotoExecute(Sender: TObject);
begin
  //to keep it enabled
end;

procedure TDTSMainForm.actGotoFirstChildExecute(Sender: TObject);
begin
  if actNamedNodesOnly.Checked then
    FController.SelectedNode := FController.SelectedNode.NamedChild(0) else
    FController.SelectedNode := FController.SelectedNode.Child(0);
end;

procedure TDTSMainForm.actGotoFirstChildUpdate(Sender: TObject);
begin
  if (FController = nil) or (not FController.Initialized) then begin actGotoFirstChild.Enabled := False; Exit; end;
  if actNamedNodesOnly.Checked then
    actGotoFirstChild.Enabled := FController.SelectedNode.NamedChildCount > 0 else
    actGotoFirstChild.Enabled := FController.SelectedNode.ChildCount > 0;
end;

procedure TDTSMainForm.actGotoNextSiblingExecute(Sender: TObject);
begin
  if actNamedNodesOnly.Checked then
    FController.SelectedNode := FController.SelectedNode.NextNamedSibling else
    FController.SelectedNode := FController.SelectedNode.NextSibling;
end;

procedure TDTSMainForm.actGotoNextSiblingUpdate(Sender: TObject);
begin
  if (FController = nil) or (not FController.Initialized) then begin actGotoNextSibling.Enabled := False; Exit; end;
  if actNamedNodesOnly.Checked then
    actGotoNextSibling.Enabled := not FController.SelectedNode.NextNamedSibling.IsNull else
    actGotoNextSibling.Enabled := not FController.SelectedNode.NextSibling.IsNull;
end;

procedure TDTSMainForm.actGotoParentExecute(Sender: TObject);
begin
  FController.SelectedNode := FController.SelectedNode.Parent;
end;

procedure TDTSMainForm.actGotoParentUpdate(Sender: TObject);
begin
  if (FController = nil) or (not FController.Initialized) then begin actGotoParent.Enabled := False; Exit; end;
  actGotoParent.Enabled := not FController.SelectedNode.Parent.IsNull;
end;

procedure TDTSMainForm.actGotoPrevSiblingExecute(Sender: TObject);
begin
  if actNamedNodesOnly.Checked then
    FController.SelectedNode := FController.SelectedNode.PrevNamedSibling else
    FController.SelectedNode := FController.SelectedNode.PrevSibling;
end;

procedure TDTSMainForm.actGotoPrevSiblingUpdate(Sender: TObject);
begin
  if (FController = nil) or (not FController.Initialized) then begin actGotoPrevSibling.Enabled := False; Exit; end;
  if actNamedNodesOnly.Checked then
    actGotoPrevSibling.Enabled := not FController.SelectedNode.PrevNamedSibling.IsNull else
    actGotoPrevSibling.Enabled := not FController.SelectedNode.PrevSibling.IsNull;
end;

procedure TDTSMainForm.actGotoUpdate(Sender: TObject);
begin
  if (FController = nil) or (not FController.Initialized) then begin actGoto.Enabled := False; Exit; end;
  actGoto.Enabled := not FController.SelectedNode.IsNull;
end;

procedure TDTSMainForm.actNamedNodesOnlyExecute(Sender: TObject);
var
  prevSelected: TTSNode;
begin
  if FController = nil then Exit;
  prevSelected := FController.SelectedNode;
  UpdateTreeView(FController.AppManager.Tree);
  FController.SelectedNode := prevSelected;
end;

procedure TDTSMainForm.actShowNodeAsStringExecute(Sender: TObject);
begin
  ShowMessage(FController.SelectedNode.ToString);
end;

procedure TDTSMainForm.actShowNodeAsStringUpdate(Sender: TObject);
begin
  if (FController = nil) or (not FController.Initialized) then begin actShowNodeAsString.Enabled := False; Exit; end;
  actShowNodeAsString.Enabled := not FController.SelectedNode.IsNull;
end;

procedure TDTSMainForm.btnLangInfoClick(Sender: TObject);
begin
  if FController <> nil then
    ShowLanguageInfo(FController.AppManager.Parser.Language);
end;

procedure TDTSMainForm.btnLoadClick(Sender: TObject);
var
  sSource: string;
begin
  if not OD.Execute(Handle) then Exit;
  try
    FController.LoadFile(OD.FileName, sSource);
    memCode.Lines.Text := sSource;
    FEditChanged := True;
    FController.ParseSource(sSource);
  except
    on E: Exception do
      ShowError('Failed to load file: ' + E.Message);
  end;
end;

procedure TDTSMainForm.btnQueryClick(Sender: TObject);
begin
  if FController <> nil then
    ShowQueryForm(FController.AppManager.Tree);
end;

function TDTSMainForm.FindRepoRoot: string;
var
  i: Integer;
begin
  Result := ExtractFilePath(ParamStr(0));
  for i := 1 to 5 do
  begin
    if TDirectory.Exists(TPath.Combine(Result, 'Source')) then
      Exit;
    Result := TPath.GetFullPath(TPath.Combine(Result, '..'));
  end;
  Result := '';
end;

procedure TDTSMainForm.LoadSampleForLanguage;
var
  entry: TTSLanguageEntry;
  samplePath: string;
  repoRoot: string;
begin
  if cbCode.ItemIndex < 0 then Exit;
  entry := FController.AppManager.Languages[cbCode.ItemIndex];
  if entry.SampleFile = '' then Exit;
  repoRoot := FindRepoRoot;
  if repoRoot = '' then Exit;
  samplePath := TPath.Combine(TPath.Combine(repoRoot, 'Examples' + PathDelim + 'Samples'), entry.SampleFile);
  if TFile.Exists(samplePath) then
  begin
    memCode.Lines.LoadFromFile(samplePath);
    FEditChanged := False;
  end;
end;

procedure TDTSMainForm.cbCodeChange(Sender: TObject);
var
  entry: TTSLanguageEntry;
begin
  if cbCode.ItemIndex < 0 then Exit;
  if (FController = nil) or (not FController.Initialized) then Exit;
  entry := FController.AppManager.Languages[cbCode.ItemIndex];
  try
    FController.ChangeLanguage(entry.BaseName);
    LoadSampleForLanguage;
    FController.ParseSource(memCode.Lines.Text);
  except
    on E: Exception do
      ShowError('Failed to load grammar: ' + E.Message);
  end;
end;

procedure TDTSMainForm.FillNodeProps(const AProps: TTSNodeProperties);
begin
  sgNodeProps.Cells[1, Ord(rowSymbol)] := Format('%d (%s)', [AProps.Symbol, AProps.SymbolName]);
  sgNodeProps.Cells[1, Ord(rowGrammarType)] := AProps.GrammarType;
  sgNodeProps.Cells[1, Ord(rowGrammarSymbol)] := Format('%d (%s)', [AProps.GrammarSymbol, AProps.GrammarSymbolName]);
  sgNodeProps.Cells[1, Ord(rowIsError)] := BoolToStr(AProps.IsError, True);
  sgNodeProps.Cells[1, Ord(rowHasError)] := BoolToStr(AProps.HasError, True);
  sgNodeProps.Cells[1, Ord(rowIsExtra)] := BoolToStr(AProps.IsExtra, True);
  sgNodeProps.Cells[1, Ord(rowIsMissing)] := BoolToStr(AProps.IsMissing, True);
  sgNodeProps.Cells[1, Ord(rowIsNamed)] := BoolToStr(AProps.IsNamed, True);
  sgNodeProps.Cells[1, Ord(rowChildCount)] := IntToStr(AProps.ChildCount);
  sgNodeProps.Cells[1, Ord(rowNamedChildCount)] := IntToStr(AProps.NamedChildCount);
  sgNodeProps.Cells[1, Ord(rowStartByte)] := IntToStr(AProps.StartByte);
  sgNodeProps.Cells[1, Ord(rowStartPoint)] := AProps.StartPoint.ToString;
  sgNodeProps.Cells[1, Ord(rowEndByte)] := IntToStr(AProps.EndByte);
  sgNodeProps.Cells[1, Ord(rowEndPoint)] := AProps.EndPoint.ToString;
  sgNodeProps.Cells[1, Ord(rowDescendantCount)] := IntToStr(AProps.DescendantCount);
end;

procedure TDTSMainForm.FormCreate(Sender: TObject);
var
  row: TSGNodePropRow;
  entry: TTSLanguageEntry;
begin
  FController := TDTSMainController.Create(Self);
  try
    FController.Initialize;

    // If Initialize failed (DLL not found / download declined), stop here.
    if not FController.Initialized then
    begin
      Close;
      Exit;
    end;

    //initialize property grid captions
    sgNodeProps.RowCount := Ord(High(TSGNodePropRow)) - Ord(Low(TSGNodePropRow)) + 1;
    for row := Low(TSGNodePropRow) to High(TSGNodePropRow) do
      sgNodeProps.Cells[0, Ord(row)] := sgNodePropCaptions[row];

    cbCode.Items.Clear;
    for entry in FController.AppManager.Languages do
      cbCode.Items.Add(entry.DisplayName);

    cbCode.ItemIndex := 0;
    cbCodeChange(nil);
  except
    on E: Exception do
    begin
      ShowError('Initialization error: ' + E.Message);
      Close;
    end;
  end;
end;

procedure TDTSMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FController);
end;

function TDTSMainForm.GetSelectedTSNode: TTSNode;
begin
  if (FController = nil) or (not FController.Initialized) then
    Exit(Default(TTSNode));
  if (treeView.Selected is TTSTreeViewNode) then
    Result := TTSTreeViewNode(treeView.Selected).TSNode
  else if (FController.AppManager.Tree <> nil) then
    Result := FController.AppManager.Tree.RootNode.Parent
  else
    Result := Default(TTSNode);
end;

procedure TDTSMainForm.SetSelectedTSNode(const Value: TTSNode);

  function FindViaParent(const ATSNode: TTSNode): TTreeNode;
  var
    tsParent: TTSNode;
  begin
    tsParent := ATSNode.Parent;
    if tsParent.IsNull then
      Result := treeView.Items.GetFirstNode else
    begin
      Result := FindViaParent(tsParent);
      if Result <> nil then
      begin
        Result.Expand(False);
        Result := Result.getFirstChild;
      end;
    end;
    if Result = nil then
      Exit;
    while Result is TTSTreeViewNode do
    begin
      if TTSTreeViewNode(Result).TSNode = ATSNode then
        Exit;
      Result := Result.getNextSibling as TTSTreeViewNode;
    end;
  end;

begin
  treeView.Selected := FindViaParent(Value);
end;

procedure TDTSMainForm.treeViewChange(Sender: TObject; Node: TTreeNode);
begin
  if Node = nil then
  begin
    FController.SelectNode(Default(TTSNode));
    Exit;
  end;
  FController.SelectNode(TTSTreeViewNode(Node).TSNode);
end;

procedure TDTSMainForm.treeViewCreateNodeClass(Sender: TCustomTreeView;
  var NodeClass: TTreeNodeClass);
begin
  NodeClass := TTSTreeViewNode;
end;

procedure TDTSMainForm.treeViewExpanding(Sender: TObject; Node: TTreeNode;
  var AllowExpansion: Boolean);
var
  tsCursor: TTSTreeCursor;
  tsNode: TTSNode;
  newTreeNode: TTSTreeViewNode;
  s: string;
begin
  AllowExpansion := True;
  if Node.getFirstChild <> nil then
    Exit;
  tsCursor := TTSTreeCursor.Create(TTSTreeViewNode(Node).TSNode);
  try
    if tsCursor.GotoFirstChild then
    begin
      repeat
        tsNode := tsCursor.CurrentNode;
        if actNamedNodesOnly.Checked and not tsNode.IsNamed then
          Continue;
        if tsCursor.CurrentFieldId > 0 then
          s := Format('%s (%d): %s', [tsCursor.CurrentFieldName,
            tsCursor.CurrentFieldId, tsNode.NodeType])
        else
          s := tsNode.NodeType;
        newTreeNode := TTSTreeViewNode(treeView.Items.AddChild(Node, s));
        SetupTreeTSNode(newTreeNode, tsNode);
      until not tsCursor.GotoNextSibling;
    end;
  finally
    tsCursor.Free;
  end;
end;

procedure TDTSMainForm.memCodeChange(Sender: TObject);
begin
  FEditChanged := True;
end;

procedure TDTSMainForm.memCodeExit(Sender: TObject);
begin
  if FEditChanged and (FController <> nil) and FController.Initialized then
    FController.ParseSource(memCode.Lines.Text);
end;

procedure TDTSMainForm.SetupTreeTSNode(ATreeNode: TTSTreeViewNode; ATSNode: TTSNode);
begin
  ATreeNode.TSNode := ATSNode;
  if actNamedNodesOnly.Checked then
    ATreeNode.HasChildren := ATSNode.NamedChildCount > 0 else
    ATreeNode.HasChildren := ATSNode.ChildCount > 0;
end;

end.
