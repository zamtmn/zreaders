program streamtest;
uses
 SysUtils,
 uzMVReader,uzMVSMemoryMappedFile,uzMVSReadBufStream,
 bufstream;

var
  filename:string='test.dxf';
procedure testReadLn;
var
  f:text;
  LinesCount:int64;
  LPTime:Tdatetime;
  s:string;
  buf:array[word]of byte;
begin
  LPTime:=now();
  LinesCount:=0;
  assign(f,filename);
  SetTextBuf(f,buf);
  reset(f);
  while not EOF(f) do begin
    readln(f,s);
    inc(LinesCount);
  end;
  Close(f);
  lptime:=now()-LPTime;
  writeln('Lines readed: ',LinesCount);
  writeln('ReadLn+SetTextBuf(65536): '+inttostr(round(lptime*10e7))+'msec');
end;

procedure testMMF;
var
  newStream:TZMVSMemoryMappedFile;
  mr:TZMemReader;
  intValue:integer;
  LinesCount:int64;
  LPTime:Tdatetime;
  s:String;
begin
  LPTime:=now();
  LinesCount:=0;
  intValue:=1;
  newStream:=TZMVSMemoryMappedFile.Create(filename,fmOpenRead);
  mr:=TZMemReader.Create;
  mr.setSource(newStream);
  while not mr.EOF do begin
    s:=mr.ParseString;
    LinesCount:=LinesCount+intValue;
  end;
  newStream.Destroy;
  mr.Destroy;
  lptime:=now()-LPTime;
  writeln('Lines readed: ',LinesCount);
  writeln('MMF: '+inttostr(round(lptime*10e7))+'msec');
end;

procedure testBufferedFileStream;
var
  newStream:TBufferedFileStream;
  bs:TZMVSReadBufStream;
  mr:TZMemReader;
  intValue:integer;
  LinesCount:int64;
  LPTime:Tdatetime;
  s:String;
begin
  LPTime:=now();
  LinesCount:=0;
  intValue:=1;
  newStream:=TBufferedFileStream.Create(filename,fmOpenRead);
  bs:=TZMVSReadBufStream.Create(newStream);
  bs.MoveMemViewProc(0);
  mr:=TZMemReader.Create;
  mr.setSource(bs);
  while not mr.EOF do begin
    s:=mr.ParseString;
    LinesCount:=LinesCount+intValue;
  end;
  newStream.Destroy;
  bs.Destroy;
  mr.Destroy;
  lptime:=now()-LPTime;
  writeln('Lines readed: ',LinesCount);
  writeln('BufferedFileStream+ReadBufStream: '+inttostr(round(lptime*10e7))+'msec');
end;

begin
  if ParamStr(1)<>'' then filename:=ParamStr(1);
  //testReadLn;
  testMMF;
  testBufferedFileStream;
end.


