unit TreeSitter.Downloader;

interface

uses
  System.SysUtils, System.Classes, System.Net.HttpClient, System.Net.HttpClientComponent;

type
  TTreeSitterDownloader = class
  public
    class function DownloadFile(const AURL: string; const ADestPath: string): Boolean; overload;
    class function DownloadFile(const AURL: string; const ADestPath: string; out AError: string): Boolean; overload;
    class function GetBaseURL: string;
    class function GetPlatformExtension: string;
    class function GetPlatformSuffix: string;
    class function GetCoreURL: string;
    class function GetGrammarURL(const ALang: string): string;
  end;

implementation

{$IFDEF POSIX}
uses Posix.Unistd;
{$ENDIF}

{ TTreeSitterDownloader }

class function TTreeSitterDownloader.DownloadFile(const AURL: string; const ADestPath: string): Boolean;
var
  dummy: string;
begin
  Result := DownloadFile(AURL, ADestPath, dummy);
end;

class function TTreeSitterDownloader.DownloadFile(const AURL: string; const ADestPath: string;
  out AError: string): Boolean;
var
  LClient: TNetHTTPClient;
  LResponse: IHTTPResponse;
  LFileStream: TFileStream;
  LDir: string;
begin
  Result := False;
  AError := '';
  LClient := TNetHTTPClient.Create(nil);
  try
    LClient.HandleRedirects := True;
    LDir := ExtractFilePath(ADestPath);
    if (LDir <> '') then
      ForceDirectories(LDir);
    LFileStream := TFileStream.Create(ADestPath, fmCreate);
    try
      try
        LResponse := LClient.Get(AURL, LFileStream);
        if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 300) and (LFileStream.Size > 0) then
          Result := True
        else
        begin
          AError := Format('HTTP %d: %s (URL: %s)', [LResponse.StatusCode, LResponse.StatusText, AURL]);
        end;
      except
        on E: Exception do
          AError := E.Message + ' (URL: ' + AURL + ')';
      end;
    finally
      LFileStream.Free;
    end;
    if not Result then
      System.SysUtils.DeleteFile(ADestPath);
  finally
    LClient.Free;
  end;
end;

class function TTreeSitterDownloader.GetBaseURL: string;
begin
  Result := 'https://github.com/jimmckeeth/tree-sitter-pascal/releases/download/v0.1.0/';
end;

class function TTreeSitterDownloader.GetCoreURL: string;
begin
  Result := GetBaseURL + 'tree-sitter' + GetPlatformSuffix + GetPlatformExtension;
end;

class function TTreeSitterDownloader.GetGrammarURL(const ALang: string): string;
begin
  Result := GetBaseURL + 'tree-sitter-' + ALang + GetPlatformSuffix + GetPlatformExtension;
end;

class function TTreeSitterDownloader.GetPlatformSuffix: string;
begin
  Result := '';
{$IFDEF MSWINDOWS}
  {$IFDEF WIN64}
  Result := '-windows-x64';
  {$ELSE}
  Result := '-windows-x86';
  {$ENDIF}
{$ENDIF}
{$IFDEF LINUX}
  {$IFDEF CPUX64}
  Result := '-linux-x64';
  {$ENDIF}
{$ENDIF}
{$IFDEF MACOS}
  {$IFDEF CPUX64}
  Result := '-macos-x64';
  {$ELSEIF Defined(CPUAARCH64)}
  Result := '-macos-arm64';
  {$ENDIF}
{$ENDIF}
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
