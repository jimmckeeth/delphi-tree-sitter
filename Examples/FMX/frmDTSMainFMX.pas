unit frmDTSMainFMX;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts,
  FMX.TreeView, FMX.Memo, FMX.StdCtrls, FMX.Controls.Presentation, FMX.Edit,
  TreeSitter, TreeSitterLib, TreeSitter.Loader, TreeSitter.Downloader,
  FMX.ScrollBox, FMX.ListBox, FMX.DialogService, FMX.Memo.Types;

type
  TDTSMainFormFMX = class(TForm)
    pnlTop: TPanel;
    btnLoad: TButton;
    cbCode: TComboBox;
    treeView: TTreeView;
    memCode: TMemo;
    Splitter1: TSplitter;

    procedure FormCreate(Sender: TObject);
    procedure cbCodeChange(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
  private
    FParser: TTSParser;
    FTree: TTSTree;
    procedure ParseContent;
    procedure LoadLanguageParser(const ALangBaseName: string);
    procedure FillTreeView;
    procedure FillNode(AParentItem: TTreeViewItem; const ANode: TTSNode);
  public
  end;

var
  DTSMainFormFMX: TDTSMainFormFMX;

implementation

{$R *.fmx}

{$IFDEF MSWINDOWS}
uses Winapi.Windows;
{$ELSE}
uses Posix.Dlfcn;
{$ENDIF}

procedure TDTSMainFormFMX.FormCreate(Sender: TObject);
begin
  if not TTreeSitterLoader.Load then
  begin
    TDialogService.MessageDialog('Tree-sitter library not found. Download it?',
      TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbYes, 0,
      procedure(const AResult: TModalResult)
      begin
        if AResult = mrYes then
        begin
           TTreeSitterDownloader.DownloadFile(TTreeSitterDownloader.GetCoreURL, TTreeSitterLoader.DefaultLibName);
           if TTreeSitterLoader.Load then
             TDialogService.ShowMessage('Tree-sitter core loaded successfully.');
        end;
      end);
  end;

  FParser := TTSParser.Create;
  cbCode.Items.Add('pascal');
  cbCode.ItemIndex := 0;
end;

procedure TDTSMainFormFMX.LoadLanguageParser(const ALangBaseName: string);
var
  tsLibName, tsAPIName: string;
  libHandle: THandle;
  pAPI: TTSGetLanguageFunc;
begin
  tsLibName := 'tree-sitter-' + ALangBaseName + TTreeSitterDownloader.GetPlatformExtension;

{$IFDEF MSWINDOWS}
  libHandle := LoadLibrary(PChar(tsLibName));
{$ELSE}
  libHandle := THandle(dlopen(PAnsiChar(AnsiString(tsLibName)), RTLD_LAZY));
{$ENDIF}

  if libHandle = 0 then
  begin
     TTreeSitterDownloader.DownloadFile(TTreeSitterDownloader.GetGrammarURL(ALangBaseName), tsLibName);
{$IFDEF MSWINDOWS}
     libHandle := LoadLibrary(PChar(tsLibName));
{$ELSE}
     libHandle := THandle(dlopen(PAnsiChar(AnsiString(tsLibName)), RTLD_LAZY));
{$ENDIF}
  end;

  if libHandle <> 0 then
  begin
    tsAPIName := 'tree_sitter_' + ALangBaseName;
{$IFDEF MSWINDOWS}
    pAPI := GetProcAddress(libHandle, PChar(tsAPIName));
{$ELSE}
    pAPI := dlsym(Pointer(libHandle), PAnsiChar(AnsiString(tsAPIName)));
{$ENDIF}
    if Assigned(pAPI) then
    begin
      FParser.Language := pAPI;
      ParseContent;
    end;
  end;
end;

procedure TDTSMainFormFMX.FillNode(AParentItem: TTreeViewItem; const ANode: TTSNode);
var
  i: Integer;
  item: TTreeViewItem;
begin
  item := TTreeViewItem.Create(Self);
  item.Text := ANode.NodeType;
  if AParentItem = nil then
    treeView.AddObject(item)
  else
    AParentItem.AddObject(item);

  for i := 0 to ANode.ChildCount - 1 do
    FillNode(item, ANode.Child(i));
end;

procedure TDTSMainFormFMX.FillTreeView;
begin
  treeView.Clear;
  if (FTree <> nil) and not FTree.RootNode.IsNull then
    FillNode(nil, FTree.RootNode);
end;

procedure TDTSMainFormFMX.ParseContent;
var
  sCode: string;
begin
  sCode := memCode.Text;
  if sCode = '' then Exit;
  FreeAndNil(FTree);
  FTree := FParser.ParseString(sCode);
  FillTreeView;
end;

procedure TDTSMainFormFMX.btnLoadClick(Sender: TObject);
begin
  LoadLanguageParser(cbCode.Selected.Text);
end;

procedure TDTSMainFormFMX.cbCodeChange(Sender: TObject);
begin
  LoadLanguageParser(cbCode.Selected.Text);
end;

end.
