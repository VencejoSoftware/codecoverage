(***********************************************************************)
(* Delphi Code Coverage                                                *)
(*                                                                     *)
(* A quick hack of a Code Coverage Tool for Delphi                     *)
(* by Christer Fahlgren and Nick Ring                                  *)
(*                                                                     *) 
(* This Source Code Form is subject to the terms of the Mozilla Public *)
(* License, v. 2.0. If a copy of the MPL was not distributed with this *)
(* file, You can obtain one at http://mozilla.org/MPL/2.0/.            *)

unit EmmaFileHelper;

interface

uses
  System.SysUtils,
  System.Types,
  System.Classes;

type
  TMultiBooleanArray = array of TBooleanDynArray;

  TDataIO = class(TInterfacedObject, IInterface)
  strict private
    FFile: TStream;
  protected
    function ReverseInt64_Pure(const AValue: Int64): Int64;
    function ReverseInt_Pure(const AValue: Integer): Integer; inline;
    function ReverseWord(const AValue: Word): Word; inline;
    property DataFile: TStream read FFile write FFile;
  public
    constructor Create(AFile: TStream);
  end;

  IEmmaDataInput = interface
    ['{4846A91D-E71E-4DDE-9F68-19CFA7060F84}']
    function ReadInt64: Int64;
    function ReadInteger: Integer;
    function ReadByte: Byte;
    function ReadBoolean: Boolean;
    function ReadWord: Word;
    function ReadUTF: string;
    procedure ReadIntArray(var AIntArray: TIntegerDynArray);
    function ReadBooleanArray: TBooleanDynArray;
  end;

  TEmmaDataInput = class(TDataIO, IEmmaDataInput)
  public
    function ReadInt64: Int64;
    function ReadInteger: Integer;
    function ReadByte: Byte;
    function ReadBoolean: Boolean;
    function ReadWord: Word;
    function ReadUTF: string;
    procedure ReadIntArray(var AIntArray: TIntegerDynArray);
    function ReadBooleanArray: TBooleanDynArray;
  end;

  IEmmaDataOutput = interface
    ['{ACE23F4B-1BCD-466D-BE4B-2EA2812C807E}']
    procedure WriteInt64(const AValue: Int64);
    procedure WriteInteger(const AValue: Integer);
    procedure WriteByte(const AValue: Byte);
    procedure WriteBoolean(const AValue: Boolean);
    procedure WriteWord(const AValue: Word);
    procedure WriteUTF(const AValue: String);
    procedure WriteIntArray(const AValues: TIntegerDynArray);
    procedure WriteBooleanArray(const AValues: TBooleanDynArray);
  end;

  TEmmaDataOutput = class(TDataIO, IEmmaDataOutput)
  public
    procedure WriteInt64(const AValue: Int64);
    procedure WriteInteger(const AValue: Integer);
    procedure WriteByte(const AValue: Byte);
    procedure WriteBoolean(const AValue: Boolean);
    procedure WriteWord(const AValue: Word);
    procedure WriteUTF(const AValue: String);
    procedure WriteIntArray(const AValues: TIntegerDynArray);
    procedure WriteBooleanArray(const AValues: TBooleanDynArray);
  end;
  EEmmaException = Exception;

function GetUtf8Length(const AValue: string): Integer;
function GetEntryLength(const AIntArray: TIntegerDynArray): Int64; overload;
function GetEntryLength(const ABoolArray: TBooleanDynArray): Int64; overload;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.WinSock
{$ELSE}
  Posix.ArpaInet
{$ENDIF};

{$region 'Helpers'}

function GetUtf8Length(const AValue: string): Integer;
var
  Str: RawByteString;
begin
  Str := UTF8Encode(AValue);
  Result := Length(Str) + SizeOf(Word);
end;

function GetEntryLength(const AIntArray: TIntegerDynArray): Int64;
begin
  Result := SizeOf(Integer) + Length(AIntArray) * SizeOf(Integer);
end;

function GetEntryLength(const ABoolArray: TBooleanDynArray): Int64;
begin
  Result := SizeOf(Integer) + Length(ABoolArray) * SizeOf(Boolean);
end;
{$endregion 'Helpers'}

{$region 'TDataIO'}
constructor TDataIO.Create(AFile: TStream);
begin
  inherited Create;
  FFile := AFile;
end;

function TDataIO.ReverseInt64_Pure(const AValue: Int64): Int64;
begin
  Int64Rec(Result).Bytes[0] := Int64Rec(AValue).Bytes[7];
  Int64Rec(Result).Bytes[1] := Int64Rec(AValue).Bytes[6];
  Int64Rec(Result).Bytes[2] := Int64Rec(AValue).Bytes[5];
  Int64Rec(Result).Bytes[3] := Int64Rec(AValue).Bytes[4];
  Int64Rec(Result).Bytes[4] := Int64Rec(AValue).Bytes[3];
  Int64Rec(Result).Bytes[5] := Int64Rec(AValue).Bytes[2];
  Int64Rec(Result).Bytes[6] := Int64Rec(AValue).Bytes[1];
  Int64Rec(Result).Bytes[7] := Int64Rec(AValue).Bytes[0];
end;

function TDataIO.ReverseInt_Pure(const AValue: Integer): Integer;
begin
  Result := ntohl(AValue);
end;

function TDataIO.ReverseWord(const AValue: Word): Word;
begin
  Result := ntohs(AValue);
end;
{$endregion 'TDataIO'}

{$region 'TDataInput'}
function TEmmaDataInput.ReadByte: Byte;
begin
  DataFile.Read(Result, 1);
end;

function TEmmaDataInput.ReadBoolean: Boolean;
begin
  Result := Boolean(ReadByte);
end;

function TEmmaDataInput.ReadUTF: string;
var
  DataSize: Word;
  RawData: RawByteString;
  BytesRead: Integer;
begin
  DataSize := ReadWord;
  SetLength(RawData, DataSize);
  BytesRead := DataFile.Read(RawData[1], DataSize);
  if (DataSize <> BytesRead) then
  begin
    raise EEmmaException.Create('Reading string but EOF encountered');
  end;
  Result := UTF8ToString(RawData);
end;

procedure TEmmaDataInput.ReadIntArray(var AIntArray: TIntegerDynArray);
var
  ArrayLength: Integer;
  I: Integer;
begin
  ArrayLength := ReadInteger;
  SetLength(AIntArray, ArrayLength);

  for I := 0 to ArrayLength - 1 do
  begin
    AIntArray[I] := ReadInteger;
  end;
end;

function TEmmaDataInput.ReadBooleanArray: TBooleanDynArray;
var
  ArrayLength: Integer;
  I: Integer;
begin
  ArrayLength := ReadInteger;
  SetLength(Result, ArrayLength);

  for I := 0 to ArrayLength - 1 do
  begin
    Result[I] := ReadBoolean;
  end;
end;

function TEmmaDataInput.ReadInt64: Int64;
var
  Int64Value: Int64;
  BytesRead: Integer;
begin
  BytesRead := DataFile.Read(Int64Value, SizeOf(Int64Value));
  if (BytesRead <> SizeOf(Int64Value)) then
  begin
    raise EEmmaException.Create('Not enough bytes to read an Int64');
  end;
  Result := ReverseInt64_Pure(Int64Value);
end;

function TEmmaDataInput.ReadInteger: Integer;
var
  IntValue: Integer;
  BytesRead: Integer;
begin
  BytesRead := DataFile.Read(IntValue, SizeOf(IntValue));

  if (BytesRead <> SizeOf(IntValue)) then
  begin
    raise EEmmaException.Create('Not enough bytes to read an Integer');
  end;

  Result := ReverseInt_Pure(IntValue);
end;

function TEmmaDataInput.ReadWord: Word;
var
  WordValue: Word;
  BytesRead: Integer;
begin
  BytesRead := DataFile.Read(WordValue, SizeOf(WordValue));

  if (BytesRead <> SizeOf(WordValue)) then
  begin
    raise EEmmaException.Create('Not enough bytes to read a Word');
  end;

  Result := ReverseWord(WordValue);
end;
{$endregion 'TDataInput'}

{$region 'TDataOutput'}
procedure TEmmaDataOutput.WriteByte(const AValue: Byte);
begin
  DataFile.Write(AValue, 1);
end;

procedure TEmmaDataOutput.WriteBoolean(const AValue: Boolean);
begin
  WriteByte(Byte(AValue));
end;

procedure TEmmaDataOutput.WriteUTF(const AValue: string);
var
  DataSize: Word;
  RawData: RawByteString;
  BytesWritten: Integer;
begin
  RawData := UTF8Encode(AValue);
  DataSize := Length(RawData);
  WriteWord(DataSize);

  BytesWritten := DataFile.Write(RawData[1], DataSize);
  if (DataSize <> BytesWritten) then
  begin
    raise EEmmaException.Create('Writing string but not enough chars were written');
  end;
end;

procedure TEmmaDataOutput.WriteIntArray(const AValues: TIntegerDynArray);
var
  I: Integer;
begin
  WriteInteger(Length(AValues));

  for I := 0 to High(AValues) do
  begin
    WriteInteger(AValues[I]);
  end;
end;

procedure TEmmaDataOutput.WriteBooleanArray(const AValues: TBooleanDynArray);
var
  I: Integer;
begin
  WriteInteger(Length(AValues));

  for I := 0 to High(AValues) do
  begin
    WriteBoolean(AValues[I]);
  end;
end;

procedure TEmmaDataOutput.WriteInt64(const AValue: Int64);
var
  RawData: Int64;
  BytesWritten: Integer;
begin
  RawData := ReverseInt64_Pure(AValue);
  BytesWritten := DataFile.Write(RawData, SizeOf(RawData));

  if (BytesWritten <> SizeOf(RawData)) then
  begin
    raise EEmmaException.Create('Not enough bytes written');
  end;
end;

procedure TEmmaDataOutput.WriteInteger(const AValue: Integer);
var
  RawData: Integer;
  BytesWritten: Integer;
begin
  RawData := ReverseInt_Pure(AValue);
  BytesWritten := DataFile.Write(RawData, SizeOf(RawData));

  if (BytesWritten <> SizeOf(RawData)) then
  begin
    raise EEmmaException.Create('Not enough bytes written for  an Integer');
  end;
end;

procedure TEmmaDataOutput.WriteWord(const AValue: Word);
var
  RawData: Word;
  BytesWritten: Integer;
begin
  RawData := ReverseWord(AValue);
  BytesWritten := DataFile.Write(RawData, SizeOf(RawData));

  if (BytesWritten <> SizeOf(RawData)) then
  begin
    raise EEmmaException.Create('Not enough bytes written for a word');
  end;
end;
{$endregion 'TDataInput'}

end.



