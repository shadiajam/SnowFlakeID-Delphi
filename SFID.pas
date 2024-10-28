{
  *******************************************************
  *              Snowflake ID Generator                 *
  * Unique Identifier Generator for Distributed Systems *
  * https://github.com/shadiajam/SnowFlakeID-Delphi     *
  *******************************************************

  Unit Information:
    * Purpose      : Provides a structure for generating unique Snowflake IDs.
    * Notes:
       --> This implementation provides a simple way to create distributed unique identifiers.

    Initial Author:
      * Shadi AJAM (https://github.com/shadiajam)

    License:
      * This project is open-source and free to use. You are encouraged to
        contribute, modify, and redistribute it under the MIT license.

  Usage Example:
    var
      Sfid: TSFID;
    begin
      // Create a new Snowflake ID with the current timestamp, default machine ID, and a new sequence
      Sfid := TSFID.NewSfid;

      // Access components of the Snowflake ID
      WriteLn('Timestamp: ', Sfid.Timestamp);
      WriteLn('Machine ID: ', Sfid.MachineID);
      WriteLn('Sequence: ', Sfid.Sequence);
      WriteLn('Snowflake ID as Integer: ', Sfid.AsInt);
    end;
}

unit SFID;     // Snowflake ID

interface

uses
  DateUtils, SysUtils;

type
  ESFIDException = class(Exception);

  PSFID = ^TSFID;
  TSFID = packed record  // Total 64 Bits
  private
    D: Int64;

    function GetTimestamp: Int64;
    procedure SetTimestamp(Value: Int64);

    function GetMachineID: Cardinal;
    procedure SetMachineID(Value: Cardinal);

    function GetSequence: Cardinal;
    procedure SetSequence(Value: Cardinal);

    function GetInt: Int64;

    class function GetDefaultMachineID: Cardinal; static;
    class procedure SetDefaultMachineID(Value: Cardinal); static;
    class procedure GenerateDefaultMachineIDFromGUID; static;

    // Validation assertions
    class procedure AssertTimestamp(Value: Int64); static;
    class procedure AssertMachineID(Value: Cardinal); static;
    class procedure AssertSequence(Value: Cardinal); static;

  public
    class operator Equal(const Left, Right: TSFID): Boolean;
    class operator NotEqual(const Left, Right: TSFID): Boolean;
    class function Empty: TSFID; static;

    // Properties to access components
    property Timestamp: Int64 read GetTimestamp write SetTimestamp;    // 41 bits
    property MachineID: Cardinal read GetMachineID write SetMachineID; // 10 bits
    property Sequence: Cardinal read GetSequence write SetSequence;    // 12 bits
    property AsInt: Int64 read GetInt;

    class property DefaultMachineID: Cardinal read GetDefaultMachineID write SetDefaultMachineID;
  end;

  TSfidHelper = record helper for TSFID
    class function Create(Timestamp: Int64; MachineID, Sequence: Cardinal): TSFID; overload; static;
    class function NewSfid: TSFID; static;
  end;

implementation

uses
  Windows; // Include Windows for TGuid (or any other relevant unit)

var
  DefMachineID: Cardinal = 0;
  LastSequence: Cardinal = 0;

const
  TIMESTAMP_SHIFT = 22;
  MACHINE_ID_SHIFT = 12;
  SEQUENCE_MASK = $FFF;  // 12 bits for sequence
  SEQUENCE_MAX = $FFF;
  MAX_TIMESTAMP = $1FFFFFFFFFF;  // 41 bits for timestamp
  MAX_MACHINE_ID = $3FF;         // 10 bits for machine ID

function DateTimeToUnixEpoch(const AValue: TDateTime; AInputIsUTC: Boolean): Int64;
var
  LDate: TDateTime;
begin
  if AInputIsUTC then
    LDate := AValue
  else
    LDate := TTimeZone.Local.ToUniversalTime(AValue);

  Result := MilliSecondsBetween(UnixDateDelta, LDate);
  if LDate < UnixDateDelta then
    Result := -Result;
end;

function GetNewSequence: Cardinal;
begin
  Inc(LastSequence);
  if LastSequence > SEQUENCE_MAX then
    LastSequence := 0;
  Result := LastSequence;
end;

{ TSFID }

class function TSFID.Empty: TSFID;
begin
  Result.D := 0;
end;

class operator TSFID.Equal(const Left, Right: TSFID): Boolean;
begin
  Result := (Left.D = Right.D);
end;

class operator TSFID.NotEqual(const Left, Right: TSFID): Boolean;
begin
  Result := not (Left = Right);
end;

function TSFID.GetTimestamp: Int64;
begin
  Result := (D shr TIMESTAMP_SHIFT) and MAX_TIMESTAMP;
end;

procedure TSFID.SetTimestamp(Value: Int64);
begin
  AssertTimestamp(Value);
  D := (D and not (Int64(MAX_TIMESTAMP) shl TIMESTAMP_SHIFT)) or (Value shl TIMESTAMP_SHIFT);
end;

function TSFID.GetMachineID: Cardinal;
begin
  Result := (D shr MACHINE_ID_SHIFT) and MAX_MACHINE_ID;
end;

procedure TSFID.SetMachineID(Value: Cardinal);
begin
  AssertMachineID(Value);
  D := (D and not (Int64(MAX_MACHINE_ID) shl MACHINE_ID_SHIFT)) or (Int64(Value) shl MACHINE_ID_SHIFT);
end;

function TSFID.GetSequence: Cardinal;
begin
  Result := D and SEQUENCE_MASK;
end;

procedure TSFID.SetSequence(Value: Cardinal);
begin
  AssertSequence(Value);
  D := (D and not SEQUENCE_MASK) or (Value and SEQUENCE_MASK);
end;

class function TSFID.GetDefaultMachineID: Cardinal;
begin
  Result := DefMachineID;
end;

function TSFID.GetInt: Int64;
begin
  Result := D;
end;

class procedure TSFID.SetDefaultMachineID(Value: Cardinal);
begin
  AssertMachineID(Value);
  DefMachineID := Value;
end;

// Generates a random default machine ID from a GUID
class procedure TSFID.GenerateDefaultMachineIDFromGUID;
var
  GUID: TGUID;
begin
  CreateGUID(GUID);
  DefMachineID := (Cardinal(GUID.D1) mod (MAX_MACHINE_ID + 1)); // Ensure it fits within 10 bits
end;

// Assertion procedures for validations
class procedure TSFID.AssertTimestamp(Value: Int64);
begin
  if (Value < 0) or (Value > MAX_TIMESTAMP) then
    raise ESFIDException.CreateFmt('Invalid Timestamp value: %d. Must be between 0 and %d.', [Value, MAX_TIMESTAMP]);
end;

class procedure TSFID.AssertMachineID(Value: Cardinal);
begin
  if Value > MAX_MACHINE_ID then
    raise ESFIDException.CreateFmt('Invalid MachineID value: %d. Must be between 0 and %d.', [Value, MAX_MACHINE_ID]);
end;

class procedure TSFID.AssertSequence(Value: Cardinal);
begin
  if Value > SEQUENCE_MAX then
    raise ESFIDException.CreateFmt('Invalid Sequence value: %d. Must be between 0 and %d.', [Value, SEQUENCE_MAX]);
end;

{ TSfidHelper }

class function TSfidHelper.Create(Timestamp: Int64; MachineID, Sequence: Cardinal): TSFID;
begin
  // Validate values with assertions
  TSFID.AssertTimestamp(Timestamp);
  TSFID.AssertMachineID(MachineID);
  TSFID.AssertSequence(Sequence);

  Result.D := (Timestamp shl TIMESTAMP_SHIFT) or (MachineID shl MACHINE_ID_SHIFT) or Sequence;
end;

class function TSfidHelper.NewSfid: TSFID;
begin
  Result := Create(DateTimeToUnixEpoch(Now, False), DefMachineID, GetNewSequence);
end;

// Initialize default machine ID from GUID
initialization
  TSFID.GenerateDefaultMachineIDFromGUID;

end.

