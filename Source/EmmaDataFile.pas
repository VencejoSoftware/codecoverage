(***********************************************************************)
(* Delphi Code Coverage                                                *)
(*                                                                     *)
(* A quick hack of a Code Coverage Tool for Delphi                     *)
(* by Christer Fahlgren and Nick Ring                                  *)
(*                                                                     *) 
(* This Source Code Form is subject to the terms of the Mozilla Public *)
(* License, v. 2.0. If a copy of the MPL was not distributed with this *)
(* file, You can obtain one at http://mozilla.org/MPL/2.0/.            *)

unit EmmaDataFile;

interface

uses
  System.Classes,
  System.Generics.Collections,
  EmmaMergable;

type
  TEmmaFile = class
  strict private
    FMergables: TList<TMergable>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const AMergable: TMergable);
    procedure Read(const AFile: TStream);
    procedure Write(AFile: TStream; const AVersion: Int64);
  end;

implementation

uses
  EmmaFileHelper,
  EmmaMetaData,
  System.SysUtils,
  uConsoleOutput,
  EmmaCoverageData;

const
  SKIP_LENGTH = 3 * 4;
  TYPE_METADATA = 0;

constructor TEmmaFile.Create;
begin
  inherited Create;

  FMergables := TList<TMergable>.create;
end;

destructor TEmmaFile.Destroy;
begin
  FMergables.Free;
  inherited Destroy;
end;

procedure TEmmaFile.Add(const AMergable: TMergable);
begin
  FMergables.Add(AMergable);
end;

procedure TEmmaFile.Read(const AFile: TStream);
var
  MagicValue: array [0 .. 3] of Byte;
  FileHeaderBuffer: array [0 .. SKIP_LENGTH - 1] of Byte;

  Version: Int64;
  BytesRead: Integer;
  EntryLength: Int64;
  EntryType: Byte;
  Mergable: TMergable;
  DataInput: IEmmaDataInput;
begin
  DataInput := TEmmaDataInput.Create(AFile);
  AFile.Read(MagicValue[0], 4);

  Version := DataInput.ReadInt64;
  if (Version = EmmaVersion20) or (Version = EmmaVersion21) then
  begin
    VerboseOutput('Yes, version 2.0 or version 2.1');
    BytesRead := AFile.Read(FileHeaderBuffer, SKIP_LENGTH);
    if (BytesRead <> SKIP_LENGTH) then
    begin
      raise EEmmaException.Create('Consuming file header, but file ended unexpectedly');
    end;

    while AFile.Position < AFile.Size do
    begin
      EntryLength := DataInput.ReadInt64;
      EntryType := DataInput.ReadByte;
      VerboseOutput('EntryLength:' + IntToStr(EntryLength));
      VerboseOutput('EntryType:' + IntToStr(EntryType));
      if (EntryType = TYPE_METADATA) then
      begin
        Mergable := TEmmaMetaData.Create(Version);
        Mergable.LoadFromFile(DataInput);
        FMergables.Add(Mergable);
      end
      else
      begin
        Mergable := TEmmaCoverageData.Create;
        Mergable.LoadFromFile(DataInput);
        FMergables.Add(Mergable);
      end;
    end;
  end
  else
  begin
    ConsoleOutput('ERROR: Not version 2.0 or 2.1)');
  end;
end;

procedure TEmmaFile.Write(AFile: TStream; const AVersion: Int64);
var
  Buffer: array [0 .. 3] of Byte;
  Mergable: TMergable;
  DataOutput: IEmmaDataOutput;
begin
  DataOutput := TEmmaDataOutput.Create(AFile);
  Buffer[0] := Byte('E');
  Buffer[1] := Byte('M');
  Buffer[2] := Byte('M');
  Buffer[3] := Byte('A');

  AFile.Write(Buffer[0], 4);

  DataOutput.WriteInt64(AVersion);
  // Write file header with application version info
  DataOutput.WriteInteger($2);
  DataOutput.WriteInteger(0);
  DataOutput.WriteInteger($14C0);

  for Mergable in FMergables do
  begin
    DataOutput.WriteInt64(Mergable.EntryLength);
    DataOutput.WriteByte(Mergable.EntryType);
    Mergable.WriteToFile(DataOutput);
  end;
end;

end.
