program streamtest;
{$ifdef fpc}
  {$Mode objfpc}{$H+}
{$else}
  {$apptype console}
{$endif}

uses
 SysUtils,{$ifdef fpc}bufstream,{$endif}
 uzMVReader,uzMVSMemoryMappedFile{$ifdef fpc},uzMVSReadBufStream{$endif};

type
  TTestFunc=function(AFileName:string):int64;

var
  DefaultFileName:string='test.dxf';

function TestReadLn(AFileName:string):int64;
var
  f:text;
  s:AnsiString;
  buf:array[word]of byte;
begin
  Result:=0;
  assign(f,AFileName);
  SetTextBuf(f,buf);
  reset(f);
  while not EOF(f) do begin
    readln(f,s);
    inc(Result);
  end;
  Close(f);
end;

function TestMMF(AFileName:string):int64;
var
  newStream:TZMVSMemoryMappedFile;
  mr:TZMemReader;
  s:AnsiString;
begin
  Result:=0;
  newStream:=TZMVSMemoryMappedFile.Create(AFileName,fmOpenRead);
  mr:=TZMemReader.Create;
  mr.setSource(newStream);
  while not mr.EOF do begin
    s:=mr.ParseString;
    inc(result);
  end;
  newStream.Destroy;
  mr.Destroy;
end;
{$ifdef fpc}
function TestBufferedFileStream(AFileName:string):int64;
var
  newStream:TBufferedFileStream;
  bs:TZMVSReadBufStream;
  mr:TZMemReader;
  s:AnsiString;
begin
  Result:=0;
  newStream:=TBufferedFileStream.Create(AFileName,fmOpenRead);
  bs:=TZMVSReadBufStream.Create(newStream);
  bs.MoveMemViewProc(0);
  mr:=TZMemReader.Create;
  mr.setSource(bs);
  while not mr.EOF do begin
    s:=mr.ParseString;
    inc(result);
  end;
  newStream.Destroy;
  bs.Destroy;
  mr.Destroy;
end;
{$endif}
procedure DoTest(ATestFunc:TTestFunc;ATestName,AFileName:string);
var
  TestResult:int64;
  LPTime:Tdatetime;
begin
  writeln(ATestName,':');
  LPTime:=now();
  TestResult:=ATestFunc(AFileName);
  LPTime:=now()-LPTime;
  writeln('  Test result  = ',TestResult);
  writeln('  Time elapsed = '+inttostr(round(lptime*10e7))+'ms');
end;

begin
  if ParamStr(1)<>'' then DefaultFileName:=ParamStr(1);
  //DoTest(@TestReadLn,'ReadLn+SetTextBuf(65536)',DefaultFileName);
  DoTest(@TestMMF,'Memory Mapped File',DefaultFileName);
  {$ifdef fpc}
  DoTest(@TestBufferedFileStream,'TBufferedFileStream+TReadBufStream',DefaultFileName);
  {$endif}
end.


