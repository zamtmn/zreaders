{
*****************************************************************************
*                                                                           *
*  This file is part of the ZCAD                                            *
*                                                                           *
*  See the file GPL-3.0.txt, included in this distribution,                 *
*  for details about the copyright.                                         *
*                                                                           *
*  This program is distributed in the hope that it will be useful,          *
*  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
*                                                                           *
*****************************************************************************
}
{
@author(Andrey Zubarev <zamtmn@yandex.ru>) 
}

unit uzMVReader;
{$ifdef fpc}
  {$Mode objfpc}{$H+}
{$endif}
{Inline off}

interface
uses
  SysUtils,Classes,
  uzMemViewInterface;

type
  TSetOfBytes=set of AnsiChar;
  TInMemReaderInt=int64;
 {$ifndef fpc}
   PtrUInt=NativeUInt;
   PtrInt=NativeInt;
   dword=Cardinal;
   pdword=^dword;
   qword=UInt64;
   {$define FPC_LITTLE_ENDIAN}
 {$endif}

const
  BCDToInt:array [0..$99] of integer=
   //0, 1, 2, 3, 4, 5, 6, 7, 8, 9, a, b, c, d, e, f
   (00,10,20,30,40,50,60,70,80,90,-1,-1,-1,-1,-1,-1,
    01,11,21,31,41,51,61,71,81,91,-1,-1,-1,-1,-1,-1,
    02,12,22,32,42,52,62,72,82,92,-1,-1,-1,-1,-1,-1,
    03,13,23,33,43,53,63,73,83,93,-1,-1,-1,-1,-1,-1,
    04,14,24,34,44,54,64,74,84,94,-1,-1,-1,-1,-1,-1,
    05,15,25,35,45,55,65,75,85,95,-1,-1,-1,-1,-1,-1,
    06,16,26,36,46,56,66,76,86,96,-1,-1,-1,-1,-1,-1,
    07,17,27,37,47,57,67,77,87,97,-1,-1,-1,-1,-1,-1,
    08,18,28,38,48,58,68,78,88,98,-1,-1,-1,-1,-1,-1,
    09,19,29,39,49,59,69,79,89,99);
  ChLF=#10;
  ChCR=#13;
  ChTab=#09;
  ChSpace=#20;
  CNotInThisPage=low(TInMemReaderInt);//возвращаем когда конец строки не найден на текущей странице
type
  TZMemReader=class
    protected
      type
        TCurrentViewPos=(CVPNext  //не последняя страница
                        ,CVPLast);//последняя/единственная страница;
      var
        fMemory:pbyte;
        fCurrentViewOffset:TInMemReaderInt;
        fCurrentViewSize:TInMemReaderInt;
        fInMemPosition:TInMemReaderInt;
        fSize:TInMemReaderInt;
        fIS:IMemViewSource;
        FCurrentViewPos:TCurrentViewPos;
        FNeedScipEOL:boolean;
      function GetCurrentPos:TInMemReaderInt;//без инлайна чуть чуть быстрее??
      function FindEOL:int64;//без инлайна чуть чуть быстрее??
      function SkipSpaces:int64;inline;
      procedure SkipEOL;inline;
      procedure SkipEOLifNeed;inline;
      function fastReadByte:byte;inline;
      procedure ResetLastChar;inline;
      procedure setFromTMemViewInfo(const AMVI:TMemViewInfo);
    public
      procedure setSource(const AIS:IMemViewSource);
      function EOF:Boolean;inline;
      function ParseString:AnsiString;
      function ParseString2:AnsiString;
      function ParseShortString:ShortString;
      function ParseShortString2:ShortString;
      procedure SkipString;
      procedure SkipString2;
      function ParseInteger:Integer;
      function ParseInteger2:Integer;
      function ParseDouble:Double;
      function ParseDouble2:Double;
      function ParseHexQWord:QWord;
      function ParseHexQWord2:QWord;

      property Size:TInMemReaderInt read fSize;
      property CurrentPos:TInMemReaderInt read GetCurrentPos;
  end;

implementation

procedure TZMemReader.setFromTMemViewInfo(const AMVI:TMemViewInfo);
begin
  with AMVI do begin
    fMemory:=Memory;
    fCurrentViewOffset:=CurrentViewOffset;
    fCurrentViewSize:=CurrentViewSize;
    fInMemPosition:=Position-CurrentViewOffset;
    fSize:=Size;

    {if CurrentViewOffset=0 then
      FCurrentViewPos:=CVPFirst
    else }if fCurrentViewOffset+fCurrentViewSize>=fSize then
      FCurrentViewPos:=CVPLast
    else
      FCurrentViewPos:=CVPNext;
  end;
end;

function TZMemReader.GetCurrentPos:TInMemReaderInt;
begin
  result:=fCurrentViewOffset+fInMemPosition;
end;

procedure TZMemReader.ResetLastChar;
begin
  if fInMemPosition>0 then
    dec(fInMemPosition);
end;


function TZMemReader.fastReadByte:byte;
begin
  result:=fMemory[fInMemPosition];
  if (fInMemPosition<(fCurrentViewSize-1))or((fInMemPosition+fCurrentViewOffset)=(fSize-1)) then
    inc(fInMemPosition)
  else begin
    setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
  end;
end;

procedure TZMemReader.SkipEOL;
var
  CurrentByte:Byte;
  CurrentWord:Word;
begin
  if fCurrentViewSize-fInMemPosition<2 then begin
    CurrentByte:=fastReadByte;
    if CurrentByte=byte(ChCR)then begin
      CurrentByte:=fastReadByte;
      if CurrentByte<>byte(ChLF)then
        ResetLastChar;
    end;
  end else begin
    CurrentWord:=PWord(@fMemory[fInMemPosition])^;
   {$ifdef FPC_LITTLE_ENDIAN}
    if CurrentWord=$0A0D then
      inc(fInMemPosition,2)
    else
      inc(fInMemPosition);
   {$else}
    if CurrentWord=$0D0A then
      inc(fInMemPosition,2)
    else
      inc(fInMemPosition);
   {$endif}
  end;
end;

procedure TZMemReader.SkipEOLifNeed;
begin
  if FNeedScipEOL then begin
    SkipEOL;
    FNeedScipEOL:=false;
  end;
end;

function TZMemReader.EOF:Boolean;
begin
  SkipEOLifNeed;
  if FCurrentViewPos<>CVPLast then
    result:=false
  else
    result:=(fCurrentViewOffset+fInMemPosition)>=fSize;
end;

procedure TZMemReader.setSource(const AIS:IMemViewSource);
begin
  fIS:=AIS;
  FNeedScipEOL:=false;
  setFromTMemViewInfo(fIS.GetMemViewInfo);
end;

function TZMemReader.FindEOL:int64;
const
  CR_XOR_MASK4=$0d0d0d0d;
  LF_XOR_MASK4=$0a0a0a0a;
  SUB_MASK4=Integer(-$01010101);
  OVERFLOW_MASK4=Integer($80808080);
 {$ifdef cpu64}
  CR_XOR_MASK8=$0d0d0d0d0d0d0d0d;
  LF_XOR_MASK8=$0a0a0a0a0a0a0a0a;
  SUB_MASK8=Int64(-$0101010101010101);
  OVERFLOW_MASK8=Int64($8080808080808080);
 {$endif}
var
{$ifdef fpc}
  {$push}
{$endif}
 {$OVERFLOWCHECKS OFF}
 {$RANGECHECKS OFF}
  InMemPos:PtrUInt;
  pch:pansichar;
  i,n,optin:PtrInt;
  X4,T4,V4:Integer;
 {$ifdef cpu64}
  X8,T8,V8:Int64;
 {$endif}
begin
 {$ifdef FPC_LITTLE_ENDIAN}
  SkipEOLifNeed;

  n:=fCurrentViewSize-fInMemPosition;
  if n>0 then begin
    InMemPos:=fInMemPosition;
    pch:=@fMemory[InMemPos];
   {$ifdef cpu64}
    //проверяем по 8 байт
    optin:=n div sizeof(qword);
    if optin>0 then begin
      for i:=optin-1 downto 0 do begin
        X8:=pqword(pch)^;
        T8 := (X8 xor CR_XOR_MASK8);
        X8 := (X8 xor LF_XOR_MASK8);
        V8 := T8 + SUB_MASK8;
        T8 := not T8;
        T8 := T8 and V8;
        V8 := X8 + SUB_MASK8;
        X8 := (not X8);
        V8 := V8 and X8;
        T8 := (T8 or V8) and OVERFLOW_MASK8;
        if (T8<>0) then begin
          {$if DECLARED(BsfQWord)}
          n := BsfQWord(T8) shr 3;
          {$else}
          n := Byte(Byte(T8 and $80 = 0) + Byte(T8 and $8080 = 0) + Byte(T8 and $808080 = 0) + Byte(T8 and $80808080 = 0) + Byte(T8 and $8080808080 = 0) + Byte(T8 and $808080808080 = 0) + Byte(T8 and $80808080808080 = 0));
          {$endif}
          FNeedScipEOL:=True;
          inc(InMemPos,(optin-i)*sizeof(qword)-(8-n));
          exit(InMemPos);
        end;
        inc(pqword(pch));
      end;
      inc(InMemPos,optin*sizeof(qword));
      n:=n mod sizeof(qword);
    end;
   {$endif}
    //проверяем по 4 байта
    optin:=n div sizeof(dword);
    if optin>0 then begin
      for i:=optin-1 downto 0 do begin
        X4:=pdword(pch)^;
        T4 := (X4 xor CR_XOR_MASK4);
        X4 := (X4 xor LF_XOR_MASK4);
        V4 := T4 + SUB_MASK4;
        T4 := not T4;
        T4 := T4 and V4;
        V4 := X4 + SUB_MASK4;
        X4 := (not X4);
        V4 := V4 and X4;
        T4 := (T4 or V4) and OVERFLOW_MASK4;
        if T4<>0 then begin
          {$if DECLARED(BsfDWord)}
          n := BsfDWord(T4) shr 3;
          {$else}
          n := Byte(Byte(T4 and $80 = 0) + Byte(T4 and $8080 = 0) + Byte(T4 and $808080 = 0));
          {$endif}
          FNeedScipEOL:=True;
          inc(InMemPos,(optin-i)*sizeof(dword)-(4-n));
          exit(InMemPos);
        end;
        inc(pdword(pch));
      end;
      inc(InMemPos,optin*sizeof(dword));
      n:=n mod sizeof(dword);
    end;

    //проверяем по 2 байта
    optin:=n div sizeof(word);
    if optin>0 then begin
      for i:=optin-1 downto 0 do begin
        X4:=pword(pch)^;
        T4 := (X4 xor CR_XOR_MASK4);
        X4 := (X4 xor LF_XOR_MASK4);
        V4 := T4 + SUB_MASK4;
        T4 := not T4;
        T4 := T4 and V4;
        V4 := X4 + SUB_MASK4;
        X4 := (not X4);
        V4 := V4 and X4;
        T4 := (T4 or V4) and OVERFLOW_MASK4;
        if T4<>0 then begin
          n := Byte(Byte(T4 and $80 = 0));
          FNeedScipEOL:=True;
          inc(InMemPos,(optin-i)*sizeof(word)-(2-n));
          exit(InMemPos);
        end;
        inc(pword(pch));
      end;
      inc(InMemPos,optin*sizeof(word));
      n:=n mod sizeof(word);
    end;

    //остатки проверяем по байту
    for i:=n-1 downto 0 do begin
      if byte(pch^)<14 then
        if (pch^=ChLF)or(pch^=ChCR) then begin  //pch^ in CLFCR медленней в 2 раза
          FNeedScipEOL:=True;
          inc(InMemPos,n-i-1);
          exit(InMemPos);
        end;
      inc(pch);
    end;
    inc(InMemPos,n);
    //перевод строки не найден, проверяем достигли ли мы конца файла,
    //если достигли, возвращаем позицию конца, если не достигли, возвращаем
    //CNotInThisPage сигналя что надо сдвинуть окно чтения и искать дальше
    if fCurrentViewOffset+InMemPos=fSize then
      result:=InMemPos
    else
      result:=CNotInThisPage;
  end else
    result:=CNotInThisPage;
 {$else}
  {$Error Not Implemented}
 {$endif}
{$ifdef fpc}
  {$pop}
{$endif}
end;

function TZMemReader.SkipSpaces:int64;
const
  SPACE_XOR_MASK4=$20202020;
  TAB_XOR_MASK4=$09090909;
  SUB_MASK4=Integer(-$01010101);
  OVERFLOW_MASK4=Integer($80808080);
 {$ifdef cpu64}
  SPACE_XOR_MASK8=$2020202020202020;
  TAB_XOR_MASK8=$0909090909090909;
  SUB_MASK8=Int64(-$0101010101010101);
  OVERFLOW_MASK8=Int64($8080808080808080);
 {$endif}
var
{$ifdef fpc}
  {$push}
{$endif}
 {$OVERFLOWCHECKS OFF}
 {$RANGECHECKS OFF}
  InMemPos:PtrUInt;
  pch:pansichar;
  i,n,optin:PtrUInt;
  X4,T4,V4:Integer;
 {$ifdef cpu64}
  X8,T8,V8:Int64;
 {$endif}
begin
 {$ifdef FPC_LITTLE_ENDIAN}
  SkipEOLifNeed;

  n:=fCurrentViewSize-fInMemPosition;
  if n>0 then begin
    InMemPos:=fInMemPosition;
    pch:=@fMemory[InMemPos];
   {$ifdef cpu64}
    //проверяем по 8 байт
    optin:=n div sizeof(qword);
    if optin>0 then begin
      for i:=optin-1 downto 0 do begin
        X8:=pqword(pch)^;
        T8 := (X8 xor SPACE_XOR_MASK8);
        X8 := (X8 xor TAB_XOR_MASK8);
        V8 := T8 + SUB_MASK8;
        T8 := not T8;
        T8 := T8 and V8;
        V8 := X8 + SUB_MASK8;
        X8 := (not X8);
        V8 := V8 and X8;
        T8 := ((T8 or V8) and OVERFLOW_MASK8) xor OVERFLOW_MASK8;
        if T8<>0 then begin
          {$if DECLARED(BsfQWord)}
          n := BsfQWord(T8) shr 3;
          {$else}
          n := Byte(Byte(T8 and $80 = 0) + Byte(T8 and $8080 = 0) + Byte(T8 and $808080 = 0) + Byte(T8 and $80808080 = 0) + Byte(T8 and $8080808080 = 0) + Byte(T8 and $808080808080 = 0) + Byte(T8 and $80808080808080 = 0));
          {$endif}
          inc(InMemPos,(optin-i)*sizeof(qword)-(8-n));
          exit(InMemPos);
        end;
        inc(pqword(pch));
      end;
      inc(InMemPos,optin*sizeof(qword));
      n:=n mod sizeof(qword);
    end;
   {$endif}
    //проверяем по 4 байта
    optin:=n div sizeof(dword);
    if optin>0 then begin
      for i:=optin-1 downto 0 do begin
        X4:=pdword(pch)^;
        T4 := (X4 xor SPACE_XOR_MASK4);
        X4 := (X4 xor TAB_XOR_MASK4);
        V4 := T4 + SUB_MASK4;
        T4 := not T4;
        T4 := T4 and V4;
        V4 := X4 + SUB_MASK4;
        X4 := (not X4);
        V4 := V4 and X4;
        T4 := (((T4 or V4)and OVERFLOW_MASK4)xor OVERFLOW_MASK4);
        if T4<>0 then begin
          {$if DECLARED(BsrDWord)}
          n := BsfDWord(T4) shr 3;
          {$else}
          n := Byte(Byte(T4 and $80 = 0) + Byte(T4 and $8080 = 0) + Byte(T4 and $808080 = 0));
          {$endif}
          inc(InMemPos,(optin-i)*sizeof(dword)-(4-n));
          exit(InMemPos);
        end;
        inc(pdword(pch));
      end;
      inc(InMemPos,optin*sizeof(dword));
      n:=n mod sizeof(dword);
    end;

    //проверяем по 2 байта
    optin:=n div sizeof(word);
    if optin>0 then begin
      for i:=optin-1 downto 0 do begin
        X4:=pword(pch)^;
        T4 := (X4 xor SPACE_XOR_MASK4);
        X4 := (X4 xor TAB_XOR_MASK4);
        V4 := T4 + SUB_MASK4;
        T4 := not T4;
        T4 := T4 and V4;
        V4 := X4 + SUB_MASK4;
        X4 := (not X4);
        V4 := V4 and X4;
        T4 := (((T4 or V4) and OVERFLOW_MASK4)xor OVERFLOW_MASK4);
        if T4<>0 then begin
          n := Byte(T4 = 0);
          inc(InMemPos,(optin-i)*sizeof(word)-(2-n));
          exit(InMemPos);
        end;
        inc(pword(pch));
      end;
      inc(InMemPos,optin*sizeof(word));
      n:=n mod sizeof(word);
    end;

    //остатки проверяем по байту
    for i:=n-1 downto 0 do begin
      if byte(pch^)>32 then
        if (pch^<>ChSpace)and(pch^<>ChTab) then begin
          inc(InMemPos,n-i-1);
          exit(InMemPos);
        end;
      inc(pch);
    end;
    inc(InMemPos,n);
    //не пробелы и не табы не найдены, проверяем достигли ли мы конца файла,
    //если достигли, возвращаем позицию конца, если не достигли, возвращаем
    //CNotInThisPage сигналя что надо сдвинуть окно чтения и искать дальше
    if fCurrentViewOffset+InMemPos=fSize then
      result:=InMemPos
    else
      result:=CNotInThisPage;
  end else
    result:=CNotInThisPage;
 {$else}
  {$Error Not Implemented}
 {$endif}
{$ifdef fpc}
  {$pop}
{$endif}
end;
function TZMemReader.ParseShortString:ShortString;
var
  PEOL:int64;
begin
  PEOL:=SkipSpaces;
  if PEOL=CNotInThisPage then begin
    setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
    result:=ParseShortString();
  end else begin
    fInMemPosition:=PEOL;
    result:=ParseShortString2;
  end;
end;
function TZMemReader.ParseShortString2:ShortString;
var
  PEOL:int64;
  l:integer;
  ts:ShortString;
begin
{$ifdef fpc}
  {$push}
{$endif}
 {$OVERFLOWCHECKS OFF}
 {$RANGECHECKS OFF}
  PEOL:=FindEOL;
  if PEOL=fInMemPosition then
    //сразу встретился перевод строки, пустая строка
    exit('')
  else if PEOL=CNotInThisPage then begin
    //уперлись в границу области отображения, двигаем и читаем дальше
    l:=fCurrentViewSize-fInMemPosition;
    if l>255 then
        raise EConvertError.Create('TZMemReader.ParseShortString2 l>255');
    SetLength(Result,l);
    Move(fMemory[fInMemPosition],Result[1],l);
    setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
    ts:=ParseShortString2();
    if (l+length(ts))>255 then
      raise EConvertError.Create('TZMemReader.ParseShortString2 (l+length(ts))>255');
    result:=result+ts;
  end else begin
    //Конец строки найден, создаем и возвращаем строку
    l:=PEOL-fInMemPosition;
    if l>255 then
        raise EConvertError.Create('TZMemReader.ParseShortString2 l>255');
    SetLength(Result,l);
    Move(fMemory[fInMemPosition],Result[1],l);
    fInMemPosition:=PEOL;
  end;
{$ifdef fpc}
  {$pop}
{$endif}
end;


function TZMemReader.ParseString:AnsiString;
var
  PEOL:int64;
begin
  PEOL:=SkipSpaces;
  if PEOL=CNotInThisPage then begin
    setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
    result:=ParseString();
  end else begin
    fInMemPosition:=PEOL;
    result:=ParseString2;
  end;
end;

function TZMemReader.ParseString2:AnsiString;
var
  PEOL:int64;
  l:int64;
  ts:AnsiString;
begin
{$ifdef fpc}
  {$push}
{$endif}
 {$OVERFLOWCHECKS OFF}
 {$RANGECHECKS OFF}
  PEOL:=FindEOL;
  if PEOL=fInMemPosition then
    //сразу встретился перевод строки, пустая строка
    exit('')
  else if PEOL=CNotInThisPage then begin
    //уперлись в границу области отображения, двигаем и читаем дальше
    {//}l:=fCurrentViewSize-fInMemPosition;
    {//}SetLength(Result,l);
    {//}Move(fMemory[fInMemPosition],Result[1],l);
    setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
    ts:=ParseString2();
    {//}result:=result+ts;
  end else begin
    //Конец строки найден, создаем и возвращаем строку
    {//}l:=PEOL-fInMemPosition;
    {//}SetLength(Result,l);
    {//}Move(fMemory[fInMemPosition],Result[1],l);
    fInMemPosition:=PEOL;
  end;
{$ifdef fpc}
  {$pop}
{$endif}
end;


procedure TZMemReader.SkipString;
var
  PEOL:int64;
begin
  PEOL:=SkipSpaces;
  if PEOL=CNotInThisPage then begin
    setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
    SkipString();
  end else begin
    fInMemPosition:=PEOL;
    SkipString2;
  end;
end;

procedure TZMemReader.SkipString2;
var
  PEOL:int64;
begin
{$ifdef fpc}
  {$push}
{$endif}
 {$OVERFLOWCHECKS OFF}
 {$RANGECHECKS OFF}
  PEOL:=FindEOL;
  if PEOL=fInMemPosition then
    //сразу встретился перевод строки, пустая строка
    exit
  else if PEOL=CNotInThisPage then begin
    //уперлись в границу области отображения, двигаем и читаем дальше
    setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
    SkipString2();
  end else begin
    //Конец строки найден, создаем и возвращаем строку
    fInMemPosition:=PEOL;
  end;
{$ifdef fpc}
  {$pop}
{$endif}
end;

function TZMemReader.ParseInteger:Integer;
var
  PEOL:int64;
begin
  PEOL:=SkipSpaces;
  if PEOL=CNotInThisPage then begin
    setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
    result:=ParseInteger();
  end else begin
    fInMemPosition:=PEOL;
    result:=ParseInteger2;
  end;
end;

function TZMemReader.ParseInteger2:Integer;
function onedigit(const d:byte):Cardinal;inline;
begin
  result:=d-ord('0');
  if result>9 then
    raise EConvertError.Create('TZMemReader.ParseInteger2.toInt not digit');
end;
function OldtoUInt({const bts:array of byte}const bts:pbyte; const l:integer):integer;inline;
var
  i:integer;
begin
  case l of
    1:result:=onedigit(bts[0]);
    2:result:=10*onedigit(bts[0])+onedigit(bts[1]);
    //3:result:=100*onedigit(bts[0])+10*onedigit(bts[1])+onedigit(bts[2]);
    //4:result:=1000*onedigit(bts[0])+100*onedigit(bts[1])+10*onedigit(bts[2])+onedigit(bts[3]);
    //5:result:=10000*onedigit(bts[0])+1000*onedigit(bts[1])+100*onedigit(bts[2])+10*onedigit(bts[3])+onedigit(bts[4]);
    else begin
      result:=onedigit(bts[0]);
      for i:=1 to l-1 do
        result:=result*10+onedigit(bts[i]);
    end;
  end;
end;
function toUInt(bts:pbyte; l:integer):integer;inline;
var
  i,optin:integer;
  w,w0,w1,w2,w3,wt:word;
  d,dt:DWord;
  q,qt:QWord;
  errbits:QWord;
begin
  errbits:=0;
  {if (l and 1)>0 then begin
    result:=onedigit(bts[0]);
    dec(l);inc(bts);
  end else}
    result:=0;

  {$ifdef cpu64}
  optin:=l div sizeof(qword);
  if optin>0 then begin
    for i:=optin-1 downto 0 do begin
      q:=pqword(bts)^;

      qt:=q and $c0c0c0c0c0c0c0c0;
      q:=q and $0f0f0f0f0f0f0f0f;

      errbits:=errbits or (qt or (q+$0606060606060606)and $f0f0f0f0f0f0f0f0);

      d:=lo(q);
      w3:=lo(d);
      w3:=(w3 shr 4)or w3;
      //result:=result*100+BCDToInt[lo(w)];
      w2:=hi(d);
      w2:=(w2 shr 4)or w2;
      //result:=result*100+BCDToInt[lo(w2)];
      d:=hi(q);
      w1:=lo(d);
      w1:=(w1 shr 4)or w1;
      //result:=result*100+BCDToInt[lo(w1)];
      w0:=hi(d);
      w0:=(w0 shr 4)or w0;
      //result:=result*100+BCDToInt[lo(w0)];

      result:=result*1000000+BCDToInt[lo(w3)]*10000+BCDToInt[lo(w2)]*10000+BCDToInt[lo(w1)]*100+BCDToInt[lo(w0)];

      inc(pqword(bts));
    end;
    l:=l and 3;//l mod sizeof(qword);
  end;
  {$endif}

  optin:=l div sizeof(dword);
  if optin>0 then begin
    for i:=optin-1 downto 0 do begin
      d:=pdword(bts)^;
      dt:=d and $c0c0c0c0;
      d:=d and $0f0f0f0f;

      errbits:=errbits or (dt or {dt2}(d+$06060606)and $f0f0f0f0);

      w:=lo(d);
      w:=(w shr 4)or w;
      result:=result*100+BCDToInt[lo(w)];
      w:=hi(d);
      w:=(w shr 4)or w;
      result:=result*100+BCDToInt[lo(w)];

      inc(pdword(bts));
    end;
    l:=l and 3;//l mod sizeof(dword);
  end;

  optin:=l div sizeof(word);
  if optin>0 then begin
    for i:=optin-1 downto 0 do begin
      w:=pword(bts)^;
      wt:=w and $c0c0;
      w:=w and $0f0f;

      errbits:=errbits or (wt or ((w+$0606)and $f0f0));

      w:=(w shr 4)or w;
      result:=result*100+BCDToInt[lo(w)];
      inc(pword(bts));
    end;
    l:=l and 1;
  end;

  if errbits<>0 then
    raise EConvertError.Create('TZMemReader.ParseInteger2.toInt not digit');

  for i:=0 to l-1 do
    result:=result*10+onedigit(bts[i]);

end;
function toInt({const bts:array of byte}const bts:pbyte; const l:integer):integer;inline;
begin
  case l of
    1:result:=onedigit(bts[0]);
    2:begin
        {case bts[0] of
          ord('-'):result:=-onedigit(bts[1]);
          ord('+'):result:=+onedigit(bts[1]);
          else
            result:=10*onedigit(bts[0])+onedigit(bts[1]);
        end;}
        if bts[0]=ord('-') then
          result:=-onedigit(bts[1])
        else if bts[0]=ord('+') then
          result:=onedigit(bts[1])
        else
          result:=10*onedigit(bts[0])+onedigit(bts[1]);
      end;
    else begin
      if (bts[0]=ord('-'))or(bts[0]=ord('+')) then begin
        result:={toUInt}OldtoUInt(@bts[1],l-1);
        if bts[0]=ord('-') then
         result:=-result;
      end else
        result:={toUInt}OldtoUInt(@bts[0],l);
    end;
  end;
end;
var
  PEOL:int64;
  l:int64;
  ts:ShortString{$ifdef fpc}=''{$endif};
  resultStr:ShortString{$ifdef fpc}=''{$endif};
  code:integer;
begin
  {$ifdef fpc}
    {$push}
  {$endif}
   { $OVERFLOWCHECKS OFF}
   { $RANGECHECKS OFF}
    PEOL:=FindEOL;
    if PEOL=fInMemPosition then
      //сразу встретился перевод строки, пустая строка
      raise EConvertError.Create('TZMemReader.ParseInteger2 empty string')
    else if PEOL=CNotInThisPage then begin
      //уперлись в границу области отображения, двигаем и читаем дальше
      l:=fCurrentViewSize-fInMemPosition;
      SetLength(resultStr,l);
      Move(fMemory[fInMemPosition],resultStr[1],l);
      setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
      ts:=ParseShortString2();
      val(resultStr+ts,result,code);
      if code<>0 then
        raise EConvertError.Create('TZMemReader.ParseInteger2 val with error')
    end else begin
      //Конец строки найден, парсим цыфры
      //вариант с копированием
      //l:=PEOL-fInMemPosition;
      //SetLength(resultStr,l);
      //Move(fMemory[fInMemPosition],resultStr[1],l);
      //val(resultStr,result,code);
      result:=toInt(@fMemory[fInMemPosition],PEOL-fInMemPosition);
      fInMemPosition:=PEOL;
    end;
  {$ifdef fpc}
    {$pop}
  {$endif}
end;

function TZMemReader.ParseDouble:Double;
var
  PEOL:int64;
begin
  PEOL:=SkipSpaces;
  if PEOL=CNotInThisPage then begin
    setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
    result:=ParseDouble();
  end else begin
    fInMemPosition:=PEOL;
    result:=ParseDouble2;
  end;
end;

function TZMemReader.ParseDouble2:Double;
var
  PEOL:int64;
  l:int64;
  ts:AnsiString{$ifdef fpc}=''{$endif};
  resultStr:AnsiString{$ifdef fpc}=''{$endif};
  ts255:shortstring{$ifdef fpc}=''{$endif};
  code:integer;
begin
  {$ifdef fpc}
    {$push}
  {$endif}
   { $OVERFLOWCHECKS OFF}
   { $RANGECHECKS OFF}
    PEOL:=FindEOL;
    if PEOL=fInMemPosition then
      //сразу встретился перевод строки, пустая строка
      raise EConvertError.Create('TZMemReader.ParseDouble2 empty string')
    else if PEOL=CNotInThisPage then begin
      //уперлись в границу области отображения, двигаем и читаем дальше
      l:=fCurrentViewSize-fInMemPosition;
      SetLength(resultStr,l);
      Move(fMemory[fInMemPosition],resultStr[1],l);
      setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
      ts:=ParseString2();
      val(resultStr+ts,result,code);
      if code<>0 then
        raise EConvertError.Create('TZMemReader.ParseDouble2 val with error')
    end else begin
      //Конец строки найден, парсим цыфры
      l:=PEOL-fInMemPosition;
      if l<256 then begin
        SetLength(ts255,l);
        Move(fMemory[fInMemPosition],ts255[1],l);
        val(ts255,result,code);
        if code<>0 then
          raise EConvertError.Create('TZMemReader.ParseDouble2 val with error')
      end else begin
        SetLength(resultStr,l);
        Move(fMemory[fInMemPosition],resultStr[1],l);
        val(resultStr,result,code);
        if code<>0 then
          raise EConvertError.Create('TZMemReader.ParseDouble2 val with error')
      end;
      fInMemPosition:=PEOL;
    end;
  {$ifdef fpc}
    {$pop}
  {$endif}
end;


function TZMemReader.ParseHexQWord:QWord;
var
  PEOL:int64;
begin
  PEOL:=SkipSpaces;
  if PEOL=CNotInThisPage then begin
    setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
    result:=ParseHexQWord();
  end else begin
    fInMemPosition:=PEOL;
    result:=ParseHexQWord2;
  end;
end;

function TZMemReader.ParseHexQWord2:QWord;
function oneHexDigit(const d:byte):Cardinal;inline;
begin
  result:=d-ord('0');
  if result>15 then begin
    result:=(d and $df)-ord('A')+10;
    if result>15 then
      raise EConvertError.Create('TZMemReader.ParseHexInteger2.HextoInt not digit');
  end;
end;
function HextoUInt({const bts:array of byte}const bts:pbyte; const l:integer):integer;inline;
var
  i:integer;
begin
  case l of
    1:result:=oneHexDigit(bts[0]);
    2:result:=16*oneHexDigit(bts[0])+oneHexDigit(bts[1]);
    else begin
      result:=oneHexDigit(bts[0]);
      for i:=1 to l-1 do
        result:=result*16+oneHexDigit(bts[i]);
    end;
  end;
end;
function HextoInt({const bts:array of byte}const bts:pbyte; const l:integer):integer;inline;
begin
  case l of
    1:result:=oneHexDigit(bts[0]);
    2:result:=16*oneHexDigit(bts[0])+oneHexDigit(bts[1]);
    else
      result:=HextoUInt(@bts[0],l);
  end;
end;
var
  PEOL:int64;
  l:int64;
  ts:ShortString{$ifdef fpc}=''{$endif};
  resultStr:ShortString{$ifdef fpc}=''{$endif};
  code:integer;
begin
  {$ifdef fpc}
    {$push}
  {$endif}
   { $OVERFLOWCHECKS OFF}
   { $RANGECHECKS OFF}
    PEOL:=FindEOL;
    if PEOL=fInMemPosition then
      //сразу встретился перевод строки, пустая строка
      raise EConvertError.Create('TZMemReader.ParseHexInteger2 empty string')
    else if PEOL=CNotInThisPage then begin
      //уперлись в границу области отображения, двигаем и читаем дальше
      l:=fCurrentViewSize-fInMemPosition;
      SetLength(resultStr,l);
      Move(fMemory[fInMemPosition],resultStr[1],l);
      setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fCurrentViewSize));
      ts:=ParseString2();
      val('$'+resultStr+ts,result,code);
      if code<>0 then
        raise EConvertError.Create('TZMemReader.ParseHexInteger2 val with error')
    end else begin
      //Конец строки найден, парсим цыфры
      //вариант с копированием
      //l:=PEOL-fInMemPosition;
      //SetLength(resultStr,l);
      //Move(fMemory[fInMemPosition],resultStr[1],l);
      //val(resultStr,result,code);
      result:=HextoInt(@fMemory[fInMemPosition],PEOL-fInMemPosition);
      fInMemPosition:=PEOL;
    end;
  {$ifdef fpc}
    {$pop}
  {$endif}
end;

begin
end.
