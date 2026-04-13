program ConsoleReadPasFile;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  TreeSitter,
  TreeSitterLib,
  TreeSitter.Loader,
  TreeSitter.App;

procedure ReadAndParsePasFile(const AFileName: string);
var
  parser: TTSParser;
  fs: TFileStream;
  tree: TTSTree;
  grammarLoader: TTSGrammarLoader;
  pascalLang: PTSLanguage;
begin
  grammarLoader := TTSGrammarLoader.Create;
  try
    if not grammarLoader.EnsureCoreLoaded then
      raise Exception.Create('Failed to load tree-sitter core library');

    pascalLang := grammarLoader.LoadGrammar('pascal');

    tree:= nil;
    parser:= nil;
    fs:= TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      parser:= TTSParser.Create;
      parser.Language:= pascalLang;
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
  finally
    grammarLoader.Free;
  end;
end;

var
  fn: string;
begin
  try
    fn:= TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), '..\..\..\..\Source\TreeSitter.pas');
    if TFile.Exists(fn) then
      ReadAndParsePasFile(fn) else
      raise Exception.CreateFmt('Failed to find file to parse: "%s"', [fn]);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

