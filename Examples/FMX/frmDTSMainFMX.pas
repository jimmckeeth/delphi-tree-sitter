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
    procedure ParseContent;
    procedure FillTreeView;
    procedure FillNode(AParentItem: TTreeViewItem; const ANode: TTSNode);
    procedure PopulateFiles;
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

  cbCode.Items.Add('pascal');
  cbCode.Items.Add('c');
  cbCode.Items.Add('cpp');
  cbCode.Items.Add('proto');
  cbCode.ItemIndex := 0;
  cbCodeChange(nil); // Set default language first

  PopulateFiles;
  if cbFiles.Count > 0 then
  begin
    cbFiles.ItemIndex := 0;
    cbFilesChange(nil); // Load and parse first file
  end;
end;

procedure TDTSMainFormFMX.PopulateFiles;
var
  LBaseDir: string;
  LPaths: TArray<string>;
  LPath: string;
  LFiles: TArray<string>;
  LFile: string;
  i: Integer;
begin
  cbFiles.Items.BeginUpdate;
  try
    cbFiles.Items.Clear;
    
    // Find project root by looking for "Source" folder up the tree
    LBaseDir := ExtractFilePath(ParamStr(0));
    for i := 1 to 5 do
    begin
      if TDirectory.Exists(TPath.Combine(LBaseDir, 'Source')) then
        Break;
      LBaseDir := TPath.GetFullPath(TPath.Combine(LBaseDir, '..'));
    end;

    LPaths := [
      TPath.Combine(LBaseDir, 'Source'),
      TPath.Combine(LBaseDir, 'Examples\FMX'),
      TPath.Combine(LBaseDir, 'Examples\Shared')
    ];

    for LPath in LPaths do
    begin
      if TDirectory.Exists(LPath) then
      begin
        LFiles := TDirectory.GetFiles(LPath, '*', TSearchOption.soAllDirectories,
          function(const Path: string; const SearchRec: TSearchRec): Boolean
          var
            LExt: string;
          begin
            LExt := ExtractFileExt(Path).ToLower;
            Result := (LExt = '.pas') or (LExt = '.dpr') or (LExt = '.inc');
          end);
        
        for LFile in LFiles do
          cbFiles.Items.Add(LFile);
      end;
    end;
  finally
    cbFiles.Items.EndUpdate;
  end;
end;

procedure TDTSMainFormFMX.cbFilesChange(Sender: TObject);
begin
  if cbFiles.ItemIndex >= 0 then
  begin
    memCode.Lines.LoadFromFile(cbFiles.Selected.Text);
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
  if cbCode.Selected = nil then Exit;
  try
    FAppManager.SetLanguage(cbCode.Selected.Text);
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
    OD.Filter := 'Pascal files (*.pas;*.dpr;*.dpk)|*.pas;*.dpr;*.dpk|All files (*.*)|*.*';
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
    if AParentItem = nil then
      treeView.AddObject(item)
    else
      AParentItem.AddObject(item);
    if info.ChildCount > 0 then
      FillNode(item, info.Node);
  end;
end;

procedure TDTSMainFormFMX.FillTreeView;
var
  rootItem: TTreeViewItem;
  rootInfo: TTSNodeInfo;
begin
  treeView.Clear;
  if FAppManager.Tree = nil then Exit;
  rootInfo := FAppManager.GetRootNodeInfo;
  rootItem := TTreeViewItem.Create(Self);
  rootItem.Text := rootInfo.NodeType;
  treeView.AddObject(rootItem);
  FillNode(rootItem, FAppManager.Tree.RootNode);
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
