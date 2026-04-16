unit frmDTSMainFMX;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.IOUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts,
  FMX.TreeView, FMX.Memo, FMX.StdCtrls, FMX.Controls.Presentation, FMX.Edit,
  TreeSitter, TreeSitterLib, TreeSitter.App,
  FMX.ScrollBox, FMX.ListBox, FMX.Memo.Types, FMX.DialogService.Sync;

type
  TDTSMainFormFMX = class(TForm)
    pnlTop: TPanel;
    btnLoad: TButton;
    cbCode: TComboBox;
    treeView: TTreeView;
    memCode: TMemo;
    Splitter1: TSplitter;
    Label1: TLabel;
    cbFiles: TComboBox;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure cbCodeChange(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure memCodeExit(Sender: TObject);
    procedure cbFilesChange(Sender: TObject);
  private
    FGrammarLoader: TTSGrammarLoader;
    FAppManager: TTSAppManager;
    FEditChanged: Boolean;
    FRepoRoot: string;
    function FindRepoRoot: string;
    procedure LoadSampleForLanguage;
    procedure ParseContent;
    procedure FillTreeView;
    procedure FillNode(AParentItem: TTreeViewItem; const ANode: TTSNode);
    procedure ExpandTreeToDepth(AItem: TTreeViewItem; ADepth: Integer);
    procedure PopulateFiles;
    procedure treeViewChange(Sender: TObject);
  public
  end;

var
  DTSMainFormFMX: TDTSMainFormFMX;

implementation

{$R *.fmx}

procedure TDTSMainFormFMX.FormCreate(Sender: TObject);
begin
  FGrammarLoader := TTSGrammarLoader.Create;
  FGrammarLoader.OnConfirmDownload :=
    function(const AMessage: string): Boolean
    begin
      Result := TDialogServiceSync.MessageDialog(AMessage, TMsgDlgType.mtConfirmation,
        [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbYes, 0) = mrYes;
    end;
  if not FGrammarLoader.EnsureCoreLoaded then
  begin
    TDialogServiceSync.ShowMessage('Tree-sitter core library is required. Exiting.');
    Application.Terminate;
    Exit;
  end;
  FAppManager := TTSAppManager.Create(FGrammarLoader);

  treeView.OnChange := treeViewChange;

  cbCode.Items.Clear;
  for var entry in FAppManager.Languages do
    cbCode.Items.Add(entry.DisplayName);
  cbCode.ItemIndex := 0;
  cbCodeChange(nil); // Set default language first

  PopulateFiles;
  if cbFiles.Count > 0 then
  begin
    cbFiles.ItemIndex := 0;
    cbFilesChange(nil); // Load and parse first file
  end;
end;

function TDTSMainFormFMX.FindRepoRoot: string;
var
  i: Integer;
begin
  if FRepoRoot <> '' then
    Exit(FRepoRoot);
  Result := TPath.GetDirectoryName(TPath.GetFullPath(ParamStr(0)));
  for i := 1 to 6 do
  begin
    if TDirectory.Exists(TPath.Combine(Result, 'Source')) then
    begin
      FRepoRoot := Result;
      Exit;
    end;
    Result := TPath.GetFullPath(TPath.Combine(Result, '..'));
  end;
  Result := '';
end;

procedure TDTSMainFormFMX.LoadSampleForLanguage;
var
  entry: TTSLanguageEntry;
  samplePath: string;
  repoRoot: string;
begin
  if cbCode.ItemIndex < 0 then Exit;
  entry := FAppManager.Languages[cbCode.ItemIndex];
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

procedure TDTSMainFormFMX.PopulateFiles;
var
  LBaseDir, LSepBase, LPath, LFile, LRelPath: string;
  LPaths: TArray<string>;
  LFiles: TArray<string>;
begin
  cbFiles.Items.BeginUpdate;
  try
    cbFiles.Items.Clear;
    LBaseDir := FindRepoRoot;
    if LBaseDir = '' then Exit;

    // Ensure base has trailing separator for reliable prefix stripping
    LSepBase := LBaseDir;
    if not LSepBase.EndsWith(PathDelim) then
      LSepBase := LSepBase + PathDelim;

    LPaths := [
      TPath.Combine(LBaseDir, 'Source'),
      TPath.Combine(LBaseDir, TPath.Combine('Examples', 'FMX')),
      TPath.Combine(LBaseDir, TPath.Combine('Examples', 'Shared')),
      TPath.Combine(LBaseDir, TPath.Combine('Examples', 'Samples'))
    ];

    for LPath in LPaths do
    begin
      if not TDirectory.Exists(LPath) then Continue;
      LFiles := TDirectory.GetFiles(LPath, '*', TSearchOption.soAllDirectories);
      for LFile in LFiles do
      begin
        // Make path relative to repo root
        if LFile.StartsWith(LSepBase, True) then
          LRelPath := Copy(LFile, Length(LSepBase) + 1, MaxInt)
        else
          LRelPath := LFile;

        // Skip files inside any directory component that begins with '__'
        if LRelPath.Contains(PathDelim + '__') or LRelPath.Contains('/' + '__') then
          Continue;

        cbFiles.Items.Add(LRelPath);
      end;
    end;
  finally
    cbFiles.Items.EndUpdate;
  end;
end;

procedure TDTSMainFormFMX.cbFilesChange(Sender: TObject);
var
  relPath, absPath: string;
begin
  if cbFiles.ItemIndex < 0 then Exit;
  relPath := cbFiles.Items[cbFiles.ItemIndex];
  absPath := TPath.Combine(FindRepoRoot, relPath);
  if TFile.Exists(absPath) then
  begin
    memCode.Lines.LoadFromFile(absPath);
    FEditChanged := True;
    ParseContent;
  end;
end;

procedure TDTSMainFormFMX.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FAppManager);
  FreeAndNil(FGrammarLoader);
end;

procedure TDTSMainFormFMX.cbCodeChange(Sender: TObject);
begin
  if cbCode.ItemIndex < 0 then Exit;
  try
    FAppManager.SetLanguage(FAppManager.Languages[cbCode.ItemIndex].BaseName);
    LoadSampleForLanguage;
    ParseContent;
  except
    on E: Exception do
      TDialogServiceSync.ShowMessage('Failed to load grammar: ' + E.Message);
  end;
end;

procedure TDTSMainFormFMX.btnLoadClick(Sender: TObject);
var
  OD: TOpenDialog;
begin
  OD := TOpenDialog.Create(Self);
  try
    OD.Filter := 'Source files (*.pas;*.dpr;*.dpk;*.c;*.h;*.cpp;*.py;*.ts;*.js;*.json)|*.pas;*.dpr;*.dpk;*.c;*.h;*.cpp;*.py;*.ts;*.js;*.json|All files (*.*)|*.*';
    if OD.Execute then
    begin
      memCode.Lines.LoadFromFile(OD.FileName);
      FEditChanged := True;
      ParseContent;
    end;
  finally
    OD.Free;
  end;
end;

procedure TDTSMainFormFMX.memCodeExit(Sender: TObject);
begin
  if FEditChanged then
    ParseContent;
end;

procedure TDTSMainFormFMX.FillNode(AParentItem: TTreeViewItem; const ANode: TTSNode);
var
  children: TArray<TTSNodeInfo>;
  info: TTSNodeInfo;
  item: TTreeViewItem;
begin
  children := FAppManager.GetChildNodes(ANode, False);
  for info in children do
  begin
    item := TTreeViewItem.Create(Self);
    item.Text := BuildNodeDisplayText(info);
    item.Tag := info.Node.StartPoint.row; // Store start row for scroll-to-line
    if AParentItem = nil then
      treeView.AddObject(item)
    else
      AParentItem.AddObject(item);
    if info.ChildCount > 0 then
      FillNode(item, info.Node);
  end;
end;

procedure TDTSMainFormFMX.ExpandTreeToDepth(AItem: TTreeViewItem; ADepth: Integer);
var
  i: Integer;
begin
  if ADepth <= 0 then Exit;
  AItem.IsExpanded := True;
  for i := 0 to AItem.Count - 1 do
    ExpandTreeToDepth(AItem.Items[i], ADepth - 1);
end;

procedure TDTSMainFormFMX.FillTreeView;
var
  rootItem: TTreeViewItem;
  rootInfo: TTSNodeInfo;
begin
  treeView.BeginUpdate;
  try
    treeView.Clear;
    if FAppManager.Tree = nil then Exit;
    rootInfo := FAppManager.GetRootNodeInfo;
    rootItem := TTreeViewItem.Create(Self);
    rootItem.Text := rootInfo.NodeType;
    rootItem.Tag := 0;
    treeView.AddObject(rootItem);
    FillNode(rootItem, FAppManager.Tree.RootNode);
  finally
    treeView.EndUpdate;
  end;
  // Expand 3 levels after rendering is ready
  if treeView.Count > 0 then
    ExpandTreeToDepth(treeView.Items[0], 3);
end;

procedure TDTSMainFormFMX.treeViewChange(Sender: TObject);
var
  item: TTreeViewItem;
  startRow: Integer;
  caretPos: TCaretPosition;
begin
  item := treeView.Selected;
  if item = nil then Exit;
  startRow := item.Tag;
  if (startRow >= 0) and (startRow < memCode.Lines.Count) then
  begin
    caretPos.Line := startRow;
    caretPos.Pos := 0;
    memCode.CaretPosition := caretPos;
  end;
end;

procedure TDTSMainFormFMX.ParseContent;
begin
  FEditChanged := False;
  if not FAppManager.ParseSource(memCode.Text) then
  begin
    treeView.Clear;
    Exit;
  end;
  FillTreeView;
end;

end.
