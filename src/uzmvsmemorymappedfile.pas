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

unit uzMVSMemoryMappedFile;
{$ifdef fpc}
  {$Mode objfpc}{$H+}
{$endif}

interface
uses
  SysUtils,Classes,
  BeRoFileMappedStream,uzMemViewInterface;
type

  TZMVSMemoryMappedFile=class(TBeRoFileMappedStream,IMemViewSource)

    function MoveMemViewProc(ANewPosition:int64):TMemViewInfo;
    function GetMemViewInfo:TMemViewInfo;
  {$ifndef fpc}
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  {$endif}
  end;

implementation

function TZMVSMemoryMappedFile.GetMemViewInfo:TMemViewInfo;
begin
  result.Memory:=fMemory;
  result.CurrentViewOffset:=fCurrentViewOffset;
  result.CurrentViewSize:=fCurrentViewSize;
  result.Position:=fPosition;
  result.Size:=fSize;
end;

function TZMVSMemoryMappedFile.MoveMemViewProc(ANewPosition:int64):TMemViewInfo;
begin
  Seek(ANewPosition,soBeginning);
  result:=GetMemViewInfo;
end;

{$ifndef fpc}
function TZMVSMemoryMappedFile.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
end;
function TZMVSMemoryMappedFile._AddRef: Integer; stdcall;
begin
end;
function TZMVSMemoryMappedFile._Release: Integer; stdcall;
begin
end;
{$endif}

begin
end.
