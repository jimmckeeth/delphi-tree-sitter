program DelphiTreeSitterVCLDemo;

uses
  Vcl.Forms,
  frmDTSMain in 'frmDTSMain.pas' {DTSMainForm},
  frmDTSMain.Controller in 'frmDTSMain.Controller.pas',
  frmDTSLanguage in 'frmDTSLanguage.pas' {DTSLanguageForm},
  frmDTSQuery in 'frmDTSQuery.pas' {DTSQueryForm};

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown:= True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TDTSMainForm, DTSMainForm);
  Application.Run;
end.
