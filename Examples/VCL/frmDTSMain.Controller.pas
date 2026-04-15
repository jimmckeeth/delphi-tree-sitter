unit frmDTSMain.Controller;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  TreeSitter, TreeSitterLib, TreeSitter.App;

type
  IDTSMainView = interface
    ['{7D7E8B2C-7C4B-4E9D-A53B-9C8E7D6F5E4D}']
    procedure UpdateTreeView(ATree: TTSTree);
    procedure UpdateNodeProperties(const AProps: TTSNodeProperties);
    procedure UpdateLanguageFields(const AFields: TArray<TTSFieldInfo>);
    procedure SelectCodeRange(AStartRow, AStartCol, AEndRow, AEndCol: Integer);
    procedure ClearNodeProperties;
    function ConfirmDownload(const AMessage: string): Boolean;
    procedure ShowError(const AMessage: string);
  end;

  TDTSMainController = class
  private
    FView: IDTSMainView;
    FGrammarLoader: TTSGrammarLoader;
    FAppManager: TTSAppManager;
    FInitialized: Boolean;
    FSelectedNode: TTSNode;
    procedure SetSelectedNode(const Value: TTSNode);
  public
    constructor Create(AView: IDTSMainView);
    destructor Destroy; override;
    procedure Initialize;
    procedure LoadFile(const AFileName: string; out ASource: string);
    procedure ParseSource(const ASource: string);
    procedure ChangeLanguage(const ALangBaseName: string);
    procedure SelectNode(const ANode: TTSNode);
    procedure GetChildByField(AFieldId: Integer);
    property AppManager: TTSAppManager read FAppManager;
    property SelectedNode: TTSNode read FSelectedNode write SetSelectedNode;
    property Initialized: Boolean read FInitialized;
  end;

implementation

{ TDTSMainController }

constructor TDTSMainController.Create(AView: IDTSMainView);
begin
  inherited Create;
  FView := AView;
  FGrammarLoader := TTSGrammarLoader.Create;
  FGrammarLoader.OnConfirmDownload :=
    function(const AMessage: string): Boolean
    begin
      Result := FView.ConfirmDownload(AMessage);
    end;
  FAppManager := TTSAppManager.Create(FGrammarLoader);
end;

destructor TDTSMainController.Destroy;
begin
  FAppManager.Free;
  FGrammarLoader.Free;
  inherited;
end;

procedure TDTSMainController.Initialize;
begin
  if not FGrammarLoader.EnsureCoreLoaded then
  begin
    FView.ShowError('Tree-sitter core library not found and download was declined.');
    Exit;
  end;
  FInitialized := True;
end;

procedure TDTSMainController.LoadFile(const AFileName: string; out ASource: string);
begin
  with TStringList.Create do
  try
    LoadFromFile(AFileName);
    ASource := Text;
  finally
    Free;
  end;
end;

procedure TDTSMainController.ParseSource(const ASource: string);
begin
  if FAppManager.ParseSource(ASource) then
    FView.UpdateTreeView(FAppManager.Tree);
end;

procedure TDTSMainController.ChangeLanguage(const ALangBaseName: string);
begin
  FAppManager.SetLanguage(ALangBaseName);
  FView.UpdateLanguageFields(FAppManager.GetLanguageFields);
end;

procedure TDTSMainController.SelectNode(const ANode: TTSNode);
begin
  FSelectedNode := ANode;
  if not ANode.IsNull then
  begin
    FView.UpdateNodeProperties(FAppManager.GetNodeProperties(ANode));
    FView.SelectCodeRange(ANode.StartPoint.row, ANode.StartPoint.column,
      ANode.EndPoint.row, ANode.EndPoint.column);
  end
  else
    FView.ClearNodeProperties;
end;

procedure TDTSMainController.SetSelectedNode(const Value: TTSNode);
begin
  if not (FSelectedNode = Value) then
    SelectNode(Value);
end;

procedure TDTSMainController.GetChildByField(AFieldId: Integer);
var
  foundNode: TTSNode;
begin
  if FSelectedNode.IsNull then Exit;
  foundNode := FSelectedNode.ChildByField(AFieldId);
  if not foundNode.IsNull then
    SelectedNode := foundNode
  else
    FView.ShowError(Format('No child found for field ID %d', [AFieldId]));
end;

end.
