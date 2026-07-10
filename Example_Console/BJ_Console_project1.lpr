//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//  Modified by Corpsman & Claude Opus on 22.04.2026                            //
//  Adapted for Windows and Linux 64-bit compatibility.                         //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

Program BJ_Console_project1;

{$MODE objfpc}{$H+}

Uses
  cmem, // Muss erste Unit sein - nutzt C malloc/free fuer Kompatibilitaet mit pcsclite
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  Classes, SysUtils, CustApp, crt
  , MD_PCSCRaw, MD_PCSCDef, MD_Tools
  ;

Type

  { TMyApplication }

  TMyApplication = Class(TCustomApplication)
  private
    FPCSCRaw: TPCSCRaw;
    Procedure CardRead;
  protected
    Procedure DoRun; override;
  public
    Constructor Create(TheOwner: TComponent); override;
    Destructor Destroy; override;
    Procedure AddLogMemo(Msg: String); virtual;
  End;

  { TMyApplication }

Procedure TMyApplication.AddLogMemo(Msg: String);
Begin
  Writeln(Msg);
End;


Procedure TMyApplication.CardRead;
Var
  PCSCResult: Dword;
  hContext: THandle;
  SizeReaders: PCSC_DWORD;
  pReaders: PChar;
  hCard: THandle;
  dwActiveProtocol: PCSC_DWORD;
  pioSendPCI, pioRecvPCI: pSCardIORequest;
  inBuffer: TBytes;
  outBuffer: TBytes;
  outSize: PCSC_DWORD;
  ret: Cardinal;
  i: Integer;
  dwAtrLen: PCSC_DWORD;
  dwReaderLen: PCSC_DWORD;
  ATR: String;
  byAtr: Array[0..32] Of Byte; // MAX_ATR_SIZE ist 33
  dwState, dwProtocol: PCSC_DWORD;
  dataLen: Integer;
  sw12: Word;

  Procedure TransmitAndLog(Const Caption, CommandHex: String);
  Begin
    inBuffer := HexStringToBuffer(CommandHex);
    outSize := 258;
    SetLength(outBuffer, outSize);
    PCSCResult := FPCSCRaw.SCardTransmit(hCard, pioSendPCI, Pointer(inBuffer),
      Length(inBuffer), pioRecvPCI, Pointer(outBuffer), outSize);
    If PCSCResult <> SCARD_S_SUCCESS Then Begin
      AddLogMemo(Caption + ' failed: ' + PCSCErrorToString(PCSCResult));
      Exit;
    End;

    SetLength(outBuffer, outSize);
    AddLogMemo(Caption + ' succeeded.');

    If outSize >= 2 Then Begin
      sw12 := (Word(outBuffer[outSize - 2]) Shl 8) Or outBuffer[outSize - 1];
      dataLen := outSize - 2;
      AddLogMemo('Status word: ' + IntToHex(sw12, 4) + ' (' + CardErrorToString(sw12) + ')');

      If dataLen > 0 Then Begin
        SetLength(outBuffer, dataLen);
        AddLogMemo('Response data (' + IntToStr(dataLen) + ' bytes): ' + BufferToHexString(outBuffer));
      End
      Else
        AddLogMemo('Response data (0 bytes):');
    End
    Else
      AddLogMemo('Response too short (' + IntToStr(outSize) + ' bytes): ' + BufferToHexString(outBuffer));
  End;
Begin
  pReaders := Nil;

  // Establish context
  PCSCResult := FPCSCRaw.SCardEstablishContext(SCARD_SCOPE_SYSTEM, Nil, Nil, hContext);
  If PCSCResult <> SCARD_S_SUCCESS Then Begin
    AddLogMemo('SCardEstablishContext failed: ' + PCSCErrorToString(PCSCResult));
    Exit;
  End;
  AddLogMemo('SCardEstablishContext succeeded.');

  // List readers - get required size
  SizeReaders := 0;
  PCSCResult := FPCSCRaw.SCardListReaders(hContext, Nil, Nil, SizeReaders);
  If PCSCResult <> SCARD_S_SUCCESS Then Begin
    AddLogMemo('SCardListReaders failed: ' + PCSCErrorToString(PCSCResult));
    FPCSCRaw.SCardReleaseContext(hContext);
    Exit;
  End;

  // Workaround fuer Linux: mehr Speicher allokieren (wie in MD_PCSC.pas)
  If SizeReaders < 50 Then SizeReaders := 50;
  GetMem(pReaders, SizeReaders * 2 + 2);
  FillChar(pReaders^, SizeReaders * 2 + 2, 0);
  Try
    PCSCResult := FPCSCRaw.SCardListReaders(hContext, Nil, pReaders, SizeReaders);
    If PCSCResult <> SCARD_S_SUCCESS Then Begin
      AddLogMemo('SCardListReaders failed: ' + PCSCErrorToString(PCSCResult));
      FPCSCRaw.SCardReleaseContext(hContext);
      Exit;
    End;

    // Use the first reader
    AddLogMemo('Using: ' + pReaders);

    // Connect to the card
    hCard := PCSC_NO_HANDLE;
    dwActiveProtocol := 0;
    PCSCResult := FPCSCRaw.SCardConnect(hContext, pReaders, SCARD_SHARE_SHARED,
      SCARD_PROTOCOL_Tx, hCard, dwActiveProtocol);
    If PCSCResult = SCARD_S_SUCCESS Then Begin
      AddLogMemo('SCardConnect succeeded.');

      // ATR auslesen
      dwReaderLen := 0;
      dwAtrLen := SizeOf(byAtr);
      ret := FPCSCRaw.SCardStatus(hCard, Nil, dwReaderLen, dwState, dwProtocol, @byAtr[0], dwAtrLen);

      If ret = SCARD_S_SUCCESS Then Begin
        // ATR in Hex-String konvertieren
        ATR := '';
        For i := 0 To dwAtrLen - 1 Do
          ATR := ATR + IntToHex(byAtr[i], 2) + ' ';
      End;
      AddLogMemo('ATR=' + ATR);
      AddLogMemo('Hinweis: Bei kontaktlosen Karten am ACR122U ist das oft eine Pseudo-ATR vom Reader und nicht die eindeutige Karten-ID.');

      pioRecvPCI := Nil;
      If dwActiveProtocol = SCARD_PROTOCOL_T0
        Then
        pioSendPCI := @SCARDPCIT0
      Else
        pioSendPCI := @SCARDPCIT1;

      TransmitAndLog('UID command (FF CA 00 00 00)', 'FF CA 00 00 00');
      TransmitAndLog('ATS command (FF CA 01 00 00)', 'FF CA 01 00 00');

      // Disconnect
      PCSCResult := FPCSCRaw.SCardDisconnect(hCard, SCARD_LEAVE_CARD);
      If PCSCResult = SCARD_S_SUCCESS
        Then
        AddLogMemo('SCardDisconnect succeeded.')
      Else
        AddLogMemo('SCardDisconnect failed: ' + PCSCErrorToString(PCSCResult));

    End
    Else
      AddLogMemo('SCardConnect failed: ' + PCSCErrorToString(PCSCResult));

  Finally
    If pReaders <> Nil Then FreeMem(pReaders);
  End;

  // Release context
  PCSCResult := FPCSCRaw.SCardReleaseContext(hContext);
  If PCSCResult = SCARD_S_SUCCESS Then
    AddLogMemo('SCardReleaseContext succeeded.')
  Else
    AddLogMemo('SCardReleaseContext failed: ' + PCSCErrorToString(PCSCResult));
End;

Procedure TMyApplication.DoRun;
Begin
  sleep(1000);
  If FPCSCRaw.Valid Then
    CardRead;
  // stop program loop
  //Write('-->'); Readln;
  If KeyPressed Then
    If ReadKey = #27 Then Terminate;
End;

Constructor TMyApplication.Create(TheOwner: TComponent);
Begin
  Inherited Create(TheOwner);
  StopOnException := True;
  FPCSCRaw := TPCSCRaw.Create;
  If Not FPCSCRaw.Initialize Then
    AddLogMemo('Failed to initialize PC/SC library!');
End;

Destructor TMyApplication.Destroy;
Begin
  FPCSCRaw.Free;
  Inherited Destroy;
End;

Var
  Application: TMyApplication;
Begin
  Application := TMyApplication.Create(Nil);
  Application.Title := 'My Application';
  Application.Run;
  Application.Free;
End.

