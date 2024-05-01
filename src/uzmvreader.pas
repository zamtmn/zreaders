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
{$Mode objfpc}{$H+}
{Inline off}

interface
uses
  SysUtils,Classes,
  uzMemViewInterface;

type
  TSetOfBytes=set of AnsiChar;
  TInMemReaderInt=int64;

const
  ChLF=#10;
  ChCR=#13;
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
      function FindEOL:int64;inline;
      procedure SkipEOL;inline;
      procedure SkipEOLifNeed;inline;
      function fastReadByte:byte;inline;
      procedure ResetLastChar;inline;
      procedure setFromTMemViewInfo(AMVI:TMemViewInfo);
    public
      procedure setSource(AIS:IMemViewSource);
      function EOF:Boolean;inline;
      function ParseString:String;
  end;

implementation

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


function TZMemReader.EOF:Boolean;
begin
  SkipEOLifNeed;
  if FCurrentViewPos<>CVPLast then
    result:=false
  else
    result:=(fCurrentViewOffset+fInMemPosition)>=fSize;
end;

procedure TZMemReader.setFromTMemViewInfo(AMVI:TMemViewInfo);
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

procedure TZMemReader.setSource(AIS:IMemViewSource);
begin
  fIS:=AIS;
  FNeedScipEOL:=false;
  setFromTMemViewInfo(fIS.GetMemViewInfo);
end;

procedure TZMemReader.SkipEOLifNeed;
begin
  if FNeedScipEOL then begin
    SkipEOL;
    FNeedScipEOL:=false;
  end;
end;
procedure TZMemReader.SkipEOL;
var
  CurrentByte:Byte;
  CurrentWord:Word;
begin
  if fCurrentViewSize-fInMemPosition<2 then
    setFromTMemViewInfo(fIS.MoveMemViewProc(fCurrentViewOffset+fInMemPosition));

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
 {$push}
 {$OVERFLOWCHECKS OFF}
 {$RANGECHECKS OFF}
  InMemPos:PtrUInt;
  pch:pchar;
  i,n,optin:PtrInt;
  X4,T4,V4:Integer;
 {$ifdef cpu64}
  X8,T8,V8:Int64;
 {$endif}
begin
 {$ifdef FPC_LITTLE_ENDIAN}
  SkipEOLifNeed;

  InMemPos:=fInMemPosition;
  pch:=@fMemory[InMemPos];
  n:=fCurrentViewSize-InMemPos;
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
      T8 := T8 or V8;
      if (T8 and OVERFLOW_MASK8<>0) then begin
        {$if DECLARED(BsfQWord)}
        n := BsfQWord(T8 and OVERFLOW_MASK8) shr 3;
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
      T4 := T4 or V4;
      if (T4 and OVERFLOW_MASK4)<>0 then begin
        {$if DECLARED(BsrDWord)}
        n := BsrDWord(T4 and OVERFLOW_MASK4) shr 3;
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
      T4 := T4 or V4;
      if (T4 and OVERFLOW_MASK4)<>0 then begin
        n := Byte(Byte(T4 and $80 = 0));
        FNeedScipEOL:=True;
        inc(InMemPos,(optin-i)*sizeof(qword)-(8-n));
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


  if InMemPos=fSize then
    result:=InMemPos
  else
    result:=CNotInThisPage;
 {$else}
  {$Error Not Implemented}
 {$endif}
 {$pop}
end;


function TZMemReader.ParseString:String;
var
  PEOL:int64;
  l:int64;
  ts:string;
begin
 {$push}
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
    ts:=ParseString();
    {//}result:=result+ts;
  end else begin
    //Конец строки найден, создаем и возвращаем строку
    {//}l:=PEOL-fInMemPosition;
    {//}SetLength(Result,l);
    {//}Move(fMemory[fInMemPosition],Result[1],l);
    fInMemPosition:=PEOL;
  end;
 {$pop}
end;

begin
end.
