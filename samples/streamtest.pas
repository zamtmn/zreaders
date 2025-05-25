program streamtest;
{$ifdef fpc}
  {$Mode objfpc}{$H+}
{$else}
  {$apptype console}
{$endif}

uses
 SysUtils,{$ifdef fpc}bufstream,{$endif}StrUtils,Classes,
 uzMVReader,uzMVSMemoryMappedFile{$ifdef fpc},uzMVSReadBufStream{$endif};

const
  CLinesCount=100000000;
  CModule=10;
  CCharLen=1;
  CLoopCount=1;

resourcestring
  RSLinesReadaed='%d lines readed';
  RSLinesReadaedWithSum='%d lines with ints readed, sum = %d';
  RSFileExists='File "%s" already exists';
  RSFileCreated='File "%s" created, %d lines with ints, sum = %d"';

type
  TTestFunc=function(AFileName:string):string;

var
  DefaultFileName:string='intnumbers.txt';//'test.dxf';

function WritelnInts(AFileName:string):string;
var
  i:integer;
  linescount,sum:Int64;
  f:text;
  s:ShortString;
  buf:array[word]of byte;
begin
  if FileExists(AFileName) then
    result:=format(RSFileExists,[AFileName])
  else begin
    assign(f,AFileName);
    SetTextBuf(f,buf);
    Rewrite(f);
    sum:=0;
    linescount:=0;
    for i:=0 to CLinesCount-1 do begin
      s:=IntToStr(i mod CModule);
      if length(s)<CCharLen then
        s:=DupeString('0',CCharLen-length(s))+s;
        writeln(f,s);
      sum:=sum+strtoint(s);
      inc(linescount);
    end;
    Close(f);
    Result:=format(RSFileCreated,[AFileName,linescount,sum]);
  end;
end;

function TestReadLn(AFileName:string):string;
var
  f:text;
  s:AnsiString;
  buf:array[word]of byte;
  linescount:int64;
begin
  linescount:=0;
  assign(f,AFileName);
  SetTextBuf(f,buf);
  reset(f);
  while not EOF(f) do begin
    readln(f,s);
    inc(linescount);
  end;
  Close(f);
  result:=format(RSLinesReadaed,[linescount]);
end;

function TestTStringList(AFileName:string):string;
var
  sl:TStringList;
begin
  sl:=TStringList.Create;
  sl.LoadFromFile(AFileName);
  result:=format(RSLinesReadaed,[sl.Count]);
  sl.Destroy;
end;

function TestTStringListPlusIntToStr(AFileName:string):string;
var
  sl:TStringList;
  sum:int64;
  i:integer;
begin
  sl:=TStringList.Create;
  sl.LoadFromFile(AFileName);
  sum:=0;
  for i:=0 to sl.Count-1 do
    sum:=sum+StrToInt(sl.strings[i]);
  result:=format(RSLinesReadaedWithSum,[sl.Count,sum]);
  sl.Destroy;
end;

function TestMMFSkipString(AFileName:string):string;
var
  newStream:TZMVSMemoryMappedFile;
  mr:TZMemReader;
  linescount:int64;
begin
  linescount:=0;
  newStream:=TZMVSMemoryMappedFile.Create(AFileName,fmOpenRead);
  mr:=TZMemReader.Create;
  mr.setSource(newStream);
  while not mr.EOF do begin
    mr.SkipString;
    inc(linescount);
  end;
  newStream.Destroy;
  mr.Destroy;
  result:=format(RSLinesReadaed,[linescount]);
end;

{$ifdef fpc}
function TestBufferedFileStream(AFileName:string):string;
var
  newStream:TBufferedFileStream;
  bs:TZMVSReadBufStream;
  mr:TZMemReader;
  linescount:int64;
begin
  linescount:=0;
  newStream:=TBufferedFileStream.Create(AFileName,fmOpenRead);
  bs:=TZMVSReadBufStream.Create(newStream);
  bs.MoveMemViewProc(0);
  mr:=TZMemReader.Create;
  mr.setSource(bs);
  while not mr.EOF do begin
    mr.SkipString;
    inc(linescount);
  end;
  newStream.Destroy;
  bs.Destroy;
  mr.Destroy;
  result:=format(RSLinesReadaed,[linescount]);
end;
{$endif}

function TestMMFParseString(AFileName:string):string;
var
  newStream:TZMVSMemoryMappedFile;
  mr:TZMemReader;
  linescount:int64;
begin
  linescount:=0;
  newStream:=TZMVSMemoryMappedFile.Create(AFileName,fmOpenRead);
  mr:=TZMemReader.Create;
  mr.setSource(newStream);
  while not mr.EOF do begin
    mr.ParseString;
    inc(linescount);
  end;
  newStream.Destroy;
  mr.Destroy;
  result:=format(RSLinesReadaed,[linescount]);
end;

function TestMMFParseStringPlusIntToStr(AFileName:string):string;
var
  newStream:TZMVSMemoryMappedFile;
  mr:TZMemReader;
  s:AnsiString;
  linescount,sum:Int64;
begin
  linescount:=0;
  sum:=0;
  newStream:=TZMVSMemoryMappedFile.Create(AFileName,fmOpenRead);
  mr:=TZMemReader.Create;
  mr.setSource(newStream);
  while not mr.EOF do begin
    s:=mr.ParseString;
    sum:=sum+StrToInt(s);
    inc(linescount);
  end;
  newStream.Destroy;
  mr.Destroy;
  Result:=format(RSLinesReadaedWithSum,[linescount,sum]);
end;

function TestMMFParseInteger(AFileName:string):string;
var
  newStream:TZMVSMemoryMappedFile;
  mr:TZMemReader;
  linescount,sum:Int64;
begin
  sum:=0;
  linescount:=0;
  newStream:=TZMVSMemoryMappedFile.Create(AFileName,fmOpenRead);
  mr:=TZMemReader.Create;
  mr.setSource(newStream);
  while not mr.EOF do begin
    sum:=sum+mr.ParseInteger;
    inc(linescount);
  end;
  newStream.Destroy;
  mr.Destroy;
  Result:=format(RSLinesReadaedWithSum,[linescount,sum]);
end;

procedure DoTest(ATestFunc:TTestFunc;ATestName,AFileName:string);
var
  TestResult:string;
  LPTime:Tdatetime;
begin
  writeln(format('  %s:',[ATestName]));
  TestResult:='no run((';
  LPTime:=now();
  //if FileExists(DefaultFileName) then
    TestResult:=ATestFunc(AFileName);
  LPTime:=now()-LPTime;
  writeln(format('    Test result  = %s',[TestResult]));
  writeln(format('    Time elapsed = %dms',[round(lptime*10e7)]));
end;

var
  i:integer;

begin
  if ParamStr(1)<>'' then DefaultFileName:=ParamStr(1);
  writeln(format('Check "%s" file:',[DefaultFileName]));
  DoTest(@WritelnInts,'WritelnInts',DefaultFileName);
  for i:=1 to CLoopCount do begin
    writeln(format('Loop %d from %d:',[i,CLoopCount]));
    //раскоментируй нужные тесты
      //DoTest(@TestReadLn,'ReadLn+SetTextBuf(65536)',DefaultFileName);
      //DoTest(@TestTStringList,'TStringList.LoadFromFile',DefaultFileName);
      DoTest(@TestMMFSkipString,'TZMVSMemoryMappedFile (Skip)',DefaultFileName);
   {$ifdef fpc}
      DoTest(@TestBufferedFileStream,'TBufferedFileStream (Skip)',DefaultFileName);
   {$endif}
      //DoTest(@TestMMFParseString,'TZMVSMemoryMappedFile (ParseString)',DefaultFileName);
      //DoTest(@TestMMFParseStringPlusIntToStr,'TZMVSMemoryMappedFile (ParseString+IntToStr)',DefaultFileName);
      //DoTest(@TestMMFParseinteger,'TZMVSMemoryMappedFile (ParseInteger)',DefaultFileName);
  end;
  //readln;
end.




