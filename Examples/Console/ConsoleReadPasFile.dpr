program ConsoleReadPasFile;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Winapi.Windows,
  Classes,
  System.SysUtils,
  IOUtils,
  TreeSitter,
  TreeSitterLib,
  TreeSitter.Loader;

type
  TTSGetLanguageFunc = function(): PTSLanguage; cdecl;

procedure ReadAndParsePasFile(const AFileName: string);
var
  parser: TTSParser;
  fs: TFileStream;
  tree: TTSTree;
  libHandle: THandle;
  pAPI: TTSGetLanguageFunc;
begin
  if not TTreeSitterLoader.Load then
    raise Exception.Create('Failed to load tree-sitter core library');

  libHandle := LoadLibrary('tree-sitter-pascal.dll');
  if libHandle = 0 then
    raise Exception.Create('Failed to load tree-sitter-pascal.dll');

  pAPI := GetProcAddress(libHandle, 'tree_sitter_pascal');
  if not Assigned(pAPI) then
    raise Exception.Create('Failed to find tree_sitter_pascal function');

  tree:= nil;
  parser:= nil;
  fs:= TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    parser:= TTSParser.Create;
    parser.Language:= pAPI;
    tree:= parser.parse(
      function (AByteIndex: UInt32; APosition: TTSPoint; var ABytesRead: UInt32): TBytes
      const
        BufSize = 10 * 1024;
      begin
        if fs.Seek(AByteIndex, soFromBeginning) < 0 then
        begin
          ABytesRead:= 0;
          Exit;
        end;
        SetLength(Result, BufSize);
        try
          ABytesRead:= fs.Read(Result, BufSize);
        except
          ABytesRead:= 0;
        end;
        SetLength(Result, ABytesRead);
      end, TTSInputEncoding.TSInputEncodingUTF8);

    WriteLn(tree.RootNode.ToString);
  finally
    tree.Free;
    parser.Free;
    fs.Free;
  end;
end;

var
  fn: string;
begin
  try
    fn:= TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), '..\..\..\Source\TreeSitter.pas');
    if TFile.Exists(fn) then
      ReadAndParsePasFile(fn) else
      raise Exception.CreateFmt('Failed to find file to parse: "%s"', [fn]);
    ReadLn;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

