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

unit uzMemViewInterface;
{$Mode objfpc}{$H+}
{$Interfaces CORBA}

interface
uses
  SysUtils;

type
  TMemViewInfo=record
    Memory:pointer;
    CurrentViewOffset:int64;
    CurrentViewSize:int64;
    Position:int64;
    Size:int64;
  end;

  TMoveMemViewProc=function (ANewPosition:int64):TMemViewInfo of object;

  IMemViewSource=interface
    function MoveMemViewProc(ANewPosition:int64):TMemViewInfo;
    function GetMemViewInfo:TMemViewInfo;
  end;

implementation
begin
end.
