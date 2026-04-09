program DelphiTreeSitterFMXDemo;

uses
  System.StartUpCopy,
  FMX.Forms,
  frmDTSMainFMX in 'frmDTSMainFMX.pas' {DTSMainFormFMX};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TDTSMainFormFMX, DTSMainFormFMX);
  Application.Run;
end.
