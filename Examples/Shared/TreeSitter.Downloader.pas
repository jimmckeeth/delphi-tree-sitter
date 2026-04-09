unit TreeSitter.Downloader;

interface

uses
  System.SysUtils, System.Classes, System.Net.HttpClient, System.Net.HttpClientComponent;

type
  TTreeSitterDownloader = class
  public
    class function DownloadFile(const AURL: string; const ADestPath: string): Boolean;
    class function GetBaseURL: string;
    class function GetPlatformExtension: string;
    class function GetCoreURL: string;
    class function GetGrammarURL(const ALang: string): string;
  end;

implementation

{ TTreeSitterDownloader }

class function TTreeSitterDownloader.DownloadFile(const AURL: string; const ADestPath: string): Boolean;
var
  LClient: TNetHTTPClient;
  LFileStream: TFileStream;
begin
  Result := False;
  LClient := TNetHTTPClient.Create(nil);
  try
    ForceDirectories(ExtractFilePath(ADestPath));
    LFileStream := TFileStream.Create(ADestPath, fmCreate);
    try
      try
        LClient.Get(AURL, LFileStream);
        Result := True;
      except
        // Handle download error
      end;
    finally
      LFileStream.Free;
    end;
  finally
    LClient.Free;
  end;
end;

class function TTreeSitterDownloader.GetBaseURL: string;
begin
  // Example placeholder for pre-compiled binaries
  Result := 'https://github.com/jimmckeeth/tree-sitter-pascal/releases/download/v0.1.0/';
end;

class function TTreeSitterDownloader.GetCoreURL: string;
begin
  Result := GetBaseURL + 'tree-sitter' + GetPlatformExtension;
end;

class function TTreeSitterDownloader.GetGrammarURL(const ALang: string): string;
begin
  Result := GetBaseURL + 'tree-sitter-' + ALang + GetPlatformExtension;
end;

class function TTreeSitterDownloader.GetPlatformExtension: string;
begin
{$IFDEF MSWINDOWS}
  Result := '.dll';
{$ENDIF}
{$IFDEF LINUX}
  Result := '.so';
{$ENDIF}
{$IFDEF MACOS}
  Result := '.dylib';
{$ENDIF}
end;

end.
