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

unit uzMVSReadBufStream;
{$Mode objfpc}{$H+}

interface
uses
  SysUtils,Classes,
  uzMemView,
  bufstream;

type
  TZMVSReadBufStream=class(TReadBufStream,IMemViewSource)
    function MoveMemViewProc(ANewPosition:int64):TMemViewInfo;
    function GetMemViewInfo:TMemViewInfo;
  end;

implementation

function TZMVSReadBufStream.GetMemViewInfo:TMemViewInfo;
begin
  result.Memory:=buffer;
  result.Position:=GetPosition;
  result.Size:=GetSize;
  result.CurrentViewSize:=Capacity;
  result.CurrentViewOffset:=result.Position-(result.Position mod result.CurrentViewSize);
end;

function TZMVSReadBufStream.MoveMemViewProc(ANewPosition:int64):TMemViewInfo;
begin
  Seek(ANewPosition,soBeginning);
  result:=GetMemViewInfo;
  FillBuffer;
end;

begin
end.
