{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit zreaders;

{$warn 5023 off : no warning about unused units}
interface

uses
  BeRoFileMappedStream, uzMemViewInterface, uzMVReader, uzMVSMemoryMappedFile, 
  uzMVSReadBufStream, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('zreaders', @Register);
end.
