//////////////////////////////////////////////////////////////////////////////////
//     This source code is provided 'as-is', without any express or implied     //
//     warranty. In no event will Infintuary be held liable for any damages     //
//     arising from the use of this software.                                   //
//                                                                              //
//     Infintuary does not warrant, that the source code will be free from      //
//     defects in design or workmanship or that operation of the source code    //
//     will be error-free. No implied or statutory warranty of merchantability  //
//     or fitness for a particular purpose shall apply. The entire risk of      //
//     quality and performance is with the user of this source code.            //
//                                                                              //
//     Permission is granted to anyone to use this software for any purpose,    //
//     including commercial applications, and to alter it and redistribute it   //
//     freely, subject to the following restrictions:                           //
//                                                                              //
//     1. The origin of this source code must not be misrepresented; you must   //
//        not claim that you wrote the original source code.                    //
//                                                                              //
//     2. Altered source versions must be plainly marked as such, and must not  //
//        be misrepresented as being the original source code.                  //
//                                                                              //
//     3. This notice may not be removed or altered from any source             //
//        distribution.                                                         //
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//  Modified by Corpsman & Claude Opus on 22.04.2026                            //
//  Adapted for Windows and Linux 64-bit compatibility.                         //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

Unit MD_PCSC;
{$IFDEF FPC}
{$MODE objfpc}{$H+}
{$MODESWITCH arrayoperators}
{$ELSE}
{$DEFINE WINDOWS}
{$ENDIF}

Interface

Uses
{$IFDEF WINDOWS}Windows, {$ENDIF}
{$IFDEF FPC}LCLType, {$ENDIF}
{$IFDEF LINUX}Forms, {$ENDIF}
  SysUtils, Classes,
  MD_PCSCRaw, MD_PCSCDef, MD_Events, MD_Tools;

Type
  TPCSC = Class;
  TPCSCReader = Class;

  TOnReaderListChanged = Procedure Of Object;
  TOnTimer = Procedure Of Object;
  TOnTerminated = Procedure Of Object;
  TOnReaderEvent = Procedure(Sender: TObject; ReaderName: String) Of Object;
  TOnCardInsertEvent = Procedure(Sender: TObject; ReaderName: String; ATR: TBytes) Of Object;
  TOnPCSCReaderEvent = Procedure(PCSCReader: TPCSCReader) Of Object;

  TCardState = (csUnknown = 0, csExclusive, csShared, csAvailable, csBadCard, csNoCard);

  TReaderListThread = Class(TThread)
  private
    FPCSCRaw: TPCSCRaw;
    FPCSCDeviceContext: THandle;
{$IFDEF WINDOWS}
    FReaderState: TSCardReaderStateA;
{$ELSE}
    FLastReaderSize: PCSC_DWORD;
    FOnTerminated: TOnTerminated;
{$ENDIF}
    FOnTimer: TOnTimer;
    FOnReaderListChanged: TOnReaderListChanged;
  public
    Constructor Create(PCSCRaw: TPCSCRaw);
    Procedure Execute; override;

    Property OnReaderListChanged: TOnReaderListChanged read FOnReaderListChanged write FOnReaderListChanged;
    Property OnTimer: TOnTimer read FOnTimer write FOnTimer;
{$IFDEF UNIX}
    Property OnTerminated: TOnTerminated read FOnTerminated write FOnTerminated;
{$ENDIF}
  End;

  TPCSCReader = Class
  private
    FOnCardStateChanged: TOnPCSCReaderEvent;
    FPCSCRaw: TPCSCRaw;

    FReaderName: String;
    FCardState: TCardState;

    FCardHandle: THandle;
    FProtocolType: TPcscProtocol;
    FPCSCDeviceContext: THandle;
    FVendorName: String;
    FDisplayName: String;

    FVendorIFDVersion: Cardinal;
    FIFDMajor, FIFDMinor: integer;
    FDrvMajor, FDrvMinor: integer;
    FSerial: String;

    FValidCard: boolean;
    FATR: TBytes;
    FDirectMode: boolean;

    Function ReadSCardAttrDW(AttrCode: Cardinal; Out Attrib: Cardinal): boolean;
    Function ReadSCardAttrS(AttrCode: Cardinal; Out Attrib: String): boolean;
    Procedure CollectReaderData;
    Function GetVendorName: boolean;
    Function GetDisplayName: boolean;
    Function GetDriverVersion: boolean;
    Function GetFirmwareVersion: boolean;
    Function GetDeviceSerial: boolean;
    Function GetDeviceSerialStd: boolean;
{$IFDEF UNIX}
    Function GetDeviceSerialLinux: boolean;
{$ENDIF}
    Procedure ClearCardInfo;

    Function GetAtrAsString: String;
    Function SCSendAPDU(InBuffer: Pointer; InSize: Cardinal; OutBuffer: Pointer; Var OutSize: PCSC_DWORD; Out SW12: Word): Cardinal;
    Function SCIOCTL(IOCtlCode: Cardinal; InBuffer: Pointer; InSize: Cardinal; OutBuffer: Pointer; Var OutSize: PCSC_DWORD): Cardinal;
  public
    Constructor Create(AReaderName: String; PCSCRaw: TPCSCRaw);
    Destructor Destroy; override;

    Function Connect(ShareMode: Cardinal = SCARD_SHARE_SHARED): Cardinal;
    Function Disconnect(Disposition: Cardinal = SCARD_UNPOWER_CARD): Cardinal;
    Function ResetCard(WarmReset: boolean): Cardinal;

    Function BeginTransaction: Cardinal;
    Function EndTransaction: Cardinal;

    Function TransmitSW(DataIn: TBytes; Out DataOut: TBytes; Out SW12: Word): Cardinal;
    Function Transmit(DataIn: TBytes; Out DataOut: TBytes): Cardinal;
    Function TransmitAsString(DataIn: String; Out DataOut: TBytes): Cardinal;
    Function TransmitAsStringSW(DataIn: String; Out DataOut: TBytes; Out SW12: Word): Cardinal;
    Function IOCTL(IOCtlCode: Cardinal; DataIn: TBytes; Out DataOut: TBytes): Cardinal;
    Function IOCTLString(IOCtlCode: Cardinal; DataIn: String; Out DataOut: TBytes): Cardinal;

    Procedure CheckCardState;

    Function Send(DataIn: Array Of TBytes; Var DataOut; DataOutLen: Integer):
      Cardinal;

    Property ReaderName: String read FReaderName;
    Property CardState: TCardState read FCardState;
    Property ATR: TBytes read FATR;
    Property ATRasString: String read GetAtrAsString;
    Property Protocol: TPcscProtocol read FProtocolType;
    Property CardHandle: THandle read FCardHandle;

    Property OnCardStateChanged: TOnPCSCReaderEvent read FOnCardStateChanged write FOnCardStateChanged;

    Property VendorName: String read FVendorName;
    Property DisplayName: String read FDisplayName;
    Property DrvMajor: integer read FDrvMajor;
    Property DrvMinor: integer read FDrvMinor;
    Property FirmwareMajor: integer read FIFDMajor;
    Property FirmwareMinor: integer read FIFDMinor;
  End;

  TPCSC = Class
  private
    FOnReaderFoundAsync: TOnReaderEvent;
    FOnReaderRemovedAsync: TOnReaderEvent;
    FOnCardInsertedAsync: TOnCardInsertEvent;
    FOnCardRemovedAsync: TOnReaderEvent;
    FOnCardErrorAsync: TOnReaderEvent;
    FOnReaderListChanged: TNotifyEvent;
    FOnCardStateChanged: TOnReaderEvent;

    FOnReaderFound: TOnReaderEvent;
    FOnReaderRemoved: TOnReaderEvent;
    FOnCardInserted: TOnCardInsertEvent;
    FOnCardRemoved: TOnReaderEvent;
    FOnCardError: TOnReaderEvent;

    FValid: boolean;
    FReaderList: TStringList;
    FPCSCDeviceContext: THandle;
    FPCSCRaw: TPCSCRaw;
    FReaderListThread: TReaderListThread;
    FMCardSupport: boolean;
    FGetReaderDetails: boolean;

    FPCSCEventList: TPCSCEventList;
{$IFDEF UNIX}
    FReaderListThreadRunning: boolean;
{$ENDIF}

    Function InitPCSC: Cardinal;
    Procedure CheckCardStates;
    Procedure ReaderListChanged;
    Procedure UpdatePCSCReaderList;
    Procedure GetPCSCReaderList(ReaderList: TStringList);
    Procedure CardStateChanged(PCSCReader: TPCSCReader);
{$IFDEF UNIX}
    Procedure ReaderListThreadTerminated;
{$ENDIF}

    Procedure CardInsertSync(ReaderName, ATR: String);
    Procedure CardRemoveSync(ReaderName: String);
    Procedure CardErrorSync(ReaderName: String);
    Procedure ReaderFoundSync(ReaderName: String);
    Procedure ReaderRemovedSync(ReaderName: String);
  public
    Constructor Create;
    Destructor Destroy; override;

    Procedure Start;
    Procedure ProcessEvent;
    Function GetPCSCReader(ReaderName: String): TPCSCReader;

    Property Valid: boolean read FValid;
    Property ReaderList: TStringList read FReaderList;
    Property MCardSupport: boolean read FMCardSupport write FMCardSupport;
    Property GetReaderDetails: boolean read FGetReaderDetails write FGetReaderDetails;

    Property OnReaderFound: TOnReaderEvent read FOnReaderFound write FOnReaderFound;
    Property OnReaderRemoved: TOnReaderEvent read FOnReaderRemoved write FOnReaderRemoved;
    Property OnCardStateChanged: TOnReaderEvent read FOnCardStateChanged write FOnCardStateChanged;
    Property OnCardInserted: TOnCardInsertEvent read FOnCardInserted write FOnCardInserted;
    Property OnCardRemoved: TOnReaderEvent read FOnCardRemoved write FOnCardRemoved;
    Property OnCardError: TOnReaderEvent read FOnCardError write FOnCardError;
  End;

Implementation

Constructor TReaderListThread.Create(PCSCRaw: TPCSCRaw);
Begin
  Inherited Create(true);
  FPCSCRaw := PCSCRaw;
  FPCSCDeviceContext := 0;
  FOnReaderListChanged := Nil;
{$IFDEF UNIX}
  FLastReaderSize := high(PCSC_DWORD);
  FOnTerminated := Nil;
{$ENDIF}
  FOnTimer := Nil;
  FreeOnTerminate := true;

  FPCSCRaw.SCardEstablishContext(SCARD_SCOPE_SYSTEM, Nil, Nil, FPCSCDeviceContext);
End;

Procedure TReaderListThread.Execute;
Var
  PCSCResult: Cardinal;
{$IFDEF UNIX}
  SizeReaders: PCSC_DWORD;
{$ENDIF}
Begin
{$IFDEF WINDOWS}
  FReaderState.cbAtr := 0;
  FReaderState.dwEventState := SCARD_STATE_UNAWARE;
  FReaderState.dwCurrentState := SCARD_STATE_UNAWARE;
  FReaderState.szReader := '\\?PNP?\Notification';
  FReaderState.pvUserData := Nil;
{$ENDIF}

  While Not Terminated Do Begin
{$IFDEF WINDOWS}
    PCSCResult := FPCSCRaw.SCardGetStatusChange(FPCSCDeviceContext, 0, @FReaderState, 1);
    If PCSCResult = SCARD_E_CANCELLED Then break;
    If PCSCResult = SCARD_S_SUCCESS Then Begin
      FReaderState.dwCurrentState := FReaderState.dwEventState;
      If Assigned(FOnReaderListChanged) Then Synchronize(FOnReaderListChanged);
    End;
{$ELSE}
    PCSCResult := FPCSCRaw.SCardListReaders(FPCSCDeviceContext, Nil, Nil, SizeReaders);
    If PCSCResult = SCARD_E_CANCELLED Then break;
    If (PCSCResult = SCARD_S_SUCCESS) Or (PCSCResult = SCARD_E_NO_READERS_AVAILABLE) Then Begin
      If FLastReaderSize <> SizeReaders Then Begin
        FLastReaderSize := SizeReaders;
        If Assigned(FOnReaderListChanged) Then Synchronize(FOnReaderListChanged);
      End;
    End
    Else If (PCSCResult = SCARD_E_INVALID_HANDLE) Or (PCSCResult = SCARD_E_SERVICE_STOPPED) Or (PCSCResult = SCARD_E_NO_SERVICE) Then Begin
      FPCSCRaw.SCardReleaseContext(FPCSCDeviceContext);
      PCSCResult := FPCSCRaw.SCardEstablishContext(SCARD_SCOPE_SYSTEM, Nil, Nil, FPCSCDeviceContext);
      If PCSCResult <> SCARD_S_SUCCESS Then FPCSCRaw.SCardEstablishContext(SCARD_SCOPE_USER, Nil, Nil, FPCSCDeviceContext);
    End;
{$ENDIF}
    If Not Terminated Then Begin
      If Assigned(FOnTimer) Then Synchronize(FOnTimer);
      Sleep(100);
    End;
  End;
  If FPCSCDeviceContext <> 0 Then FPCSCRaw.SCardReleaseContext(FPCSCDeviceContext);
{$IFDEF UNIX}
  If Assigned(FOnTerminated) Then Synchronize(FOnTerminated);
{$ENDIF}
End;

Constructor TPCSCReader.Create(AReaderName: String; PCSCRaw: TPCSCRaw);
Begin
  FReaderName := AReaderName;
  FOnCardStateChanged := Nil;
  FPCSCRaw := PCSCRaw;

  FCardState := csUnknown;
  FCardHandle := PCSC_NO_HANDLE;
  FDirectMode := false;

  FVendorName := '';
  FDisplayName := FReaderName;
  FVendorIFDVersion := 0;
  FIFDMajor := 0;
  FIFDMinor := 0;
  FDrvMajor := 0;
  FDrvMinor := 0;
  FSerial := '';

  FPCSCDeviceContext := 0;
  If FPCSCRaw.SCardEstablishContext(SCARD_SCOPE_SYSTEM, Nil, Nil, FPCSCDeviceContext) <> SCARD_S_SUCCESS Then
    FPCSCRaw.SCardEstablishContext(SCARD_SCOPE_USER, Nil, Nil, FPCSCDeviceContext);

  ClearCardInfo;
End;

Destructor TPCSCReader.Destroy;
Begin
  If FPCSCDeviceContext <> 0 Then FPCSCRaw.SCardReleaseContext(FPCSCDeviceContext);
  Inherited;
End;

Function TPCSCReader.Connect(ShareMode: Cardinal = SCARD_SHARE_SHARED): Cardinal;
Var
  aProtocol: PCSC_DWORD;
Begin
  If FCardHandle <> PCSC_NO_HANDLE Then Begin
    result := SCARD_S_SUCCESS;
    exit;
  End;
  If ShareMode = SCARD_SHARE_DIRECT Then
    result := FPCSCRaw.SCardConnect(FPCSCDeviceContext, PChar(FReaderName), SCARD_SHARE_DIRECT, 0, FCardHandle, aProtocol)
  Else
    result := FPCSCRaw.SCardConnect(FPCSCDeviceContext, PChar(FReaderName), ShareMode, SCARD_PROTOCOL_Tx, FCardHandle, aProtocol);
  If result = SCARD_S_SUCCESS Then Begin
    FDirectMode := (ShareMode = SCARD_SHARE_DIRECT);
    If aProtocol = SCARD_PROTOCOL_T0 Then
      FProtocolType := prT0
    Else If aProtocol = SCARD_PROTOCOL_T1 Then
      FProtocolType := prT1
    Else If aProtocol = SCARD_PROTOCOL_RAW Then
      FProtocolType := prRaw
    Else Begin
      If ShareMode = SCARD_SHARE_DIRECT Then
        FProtocolType := prRaw
      Else
        FProtocolType := prNC;
    End;
  End
  Else
    FCardHandle := PCSC_NO_HANDLE;
End;

Function TPCSCReader.Disconnect(Disposition: Cardinal = SCARD_UNPOWER_CARD): Cardinal;
Begin
  result := SCARD_S_SUCCESS;
  If FCardHandle = PCSC_NO_HANDLE Then exit;
  result := FPCSCRaw.SCardDisconnect(FCardHandle, Disposition);
  FProtocolType := prNC;
  FCardHandle := PCSC_NO_HANDLE;
End;

Function TPCSCReader.ResetCard(WarmReset: boolean): Cardinal;
Var
  ReqProt, ActProt, IMode: PCSC_DWORD;
Begin
  If FProtocolType = prT0 Then
    ReqProt := SCARD_PROTOCOL_T0
  Else If FProtocolType = prT1 Then
    ReqProt := SCARD_PROTOCOL_T1
  Else If FProtocolType = prRaw Then
    ReqProt := SCARD_PROTOCOL_RAW
  Else Begin
    result := SCARD_E_INVALID_PARAMETER;
    exit;
  End;

  If WarmReset Then
    IMode := SCARD_RESET_CARD
  Else
    IMode := SCARD_UNPOWER_CARD;

  // Try to reconnect
  result := FPCSCRaw.SCardReconnect(FCardHandle, SCARD_SHARE_SHARED, ReqProt, IMode, ActProt);
  If result = SCARD_S_SUCCESS Then Begin
    // Actions after reconnection
    If ActProt = SCARD_PROTOCOL_T0 Then
      FProtocolType := prT0
    Else If ActProt = SCARD_PROTOCOL_T1 Then
      FProtocolType := prT1
    Else If ActProt = SCARD_PROTOCOL_RAW Then
      FProtocolType := prRaw;
  End;
End;

Function TPCSCReader.BeginTransaction: Cardinal;
Begin
  result := FPCSCRaw.SCardBeginTransaction(FCardHandle);
End;

Function TPCSCReader.EndTransaction: Cardinal;
Begin
  result := FPCSCRaw.SCardEndTransaction(FCardHandle, SCARD_LEAVE_CARD);
End;

Function TPCSCReader.TransmitSW(DataIn: TBytes; Out DataOut: TBytes; Out SW12: Word): Cardinal;
Var
  OutBufLen: PCSC_DWORD;
Begin
{$IFDEF WINDOWS}
  OutBufLen := 66000;
{$ELSE}
  OutBufLen := 264;
{$ENDIF}
  DataOut := Nil;
  SetLength(DataOut, OutBufLen);
  result := SCSendAPDU(@DataIn[0], length(DataIn), @DataOut[0], OutBufLen, SW12);
  If result = SCARD_S_SUCCESS Then Begin
    If OutBufLen < 2 Then
      SetLength(DataOut, 0)
    Else
      SetLength(DataOut, OutBufLen - 2);
  End
  Else
    SetLength(DataOut, 0);
End;

Function TPCSCReader.Transmit(DataIn: TBytes; Out DataOut: TBytes): Cardinal;
Var
  SW12: Word;
  OutBufLen: PCSC_DWORD;
Begin
{$IFDEF WINDOWS}
  OutBufLen := 66000;
{$ELSE}
  OutBufLen := 264;
{$ENDIF}
  DataOut := Nil;
  SetLength(DataOut, OutBufLen);
  result := SCSendAPDU(@DataIn[0], length(DataIn), @DataOut[0], OutBufLen, SW12);
  If result = SCARD_S_SUCCESS Then Begin
    SetLength(DataOut, OutBufLen);
  End
  Else
    SetLength(DataOut, 0);
End;

Function TPCSCReader.TransmitAsString(DataIn: String; Out DataOut: TBytes): Cardinal;
Var
  InBuffer: TBytes;
Begin
  InBuffer := HexStringToBuffer(DataIn);
  result := Transmit(InBuffer, DataOut);
  SetLength(InBuffer, 0);
End;

Function TPCSCReader.TransmitAsStringSW(DataIn: String; Out DataOut: TBytes; Out SW12: Word): Cardinal;
Var
  InBuffer: TBytes;
Begin
  InBuffer := HexStringToBuffer(DataIn);
  result := TransmitSW(InBuffer, DataOut, SW12);
  SetLength(InBuffer, 0);
End;

Function TPCSCReader.SCSendAPDU(InBuffer: Pointer; InSize: Cardinal; OutBuffer: Pointer; Var OutSize: PCSC_DWORD; Out SW12: Word): Cardinal;
Var
  pioSendPCI, pioRecvPCI: pSCardIORequest;
Begin
  SW12 := 0;
  Case FProtocolType Of
    prT0: Begin
        pioSendPCI := @SCARDPCIT0;
        pioRecvPCI := Nil;
      End;
    prT1: Begin
        pioSendPCI := @SCARDPCIT1;
        pioRecvPCI := Nil;
      End;
  Else Begin
      result := SCARD_E_INVALID_PARAMETER;
      exit;
    End;
  End;
  result := FPCSCRaw.SCardTransmit(FCardHandle, pioSendPCI, InBuffer, InSize, pioRecvPCI, OutBuffer, OutSize);
  If result = SCARD_S_SUCCESS Then Begin
    If OutSize >= 2 Then Begin
      SW12 := ((PByteArray(OutBuffer)^[OutSize - 2]) Shl 8) Or PByteArray(OutBuffer)^[OutSize - 1];
    End;
  End
End;

Function TPCSCReader.SCIOCTL(IOCtlCode: Cardinal; InBuffer: Pointer; InSize: Cardinal; OutBuffer: Pointer; Var OutSize: PCSC_DWORD): Cardinal;
Var
  dwIoctlCode: PCSC_DWORD;
Begin
  dwIoctlCode := FPCSCRaw.SCardCTLCode(IOCtlCode);
  result := FPCSCRaw.ScardControl(FCardHandle, dwIoctlCode, InBuffer, InSize, OutBuffer, OutSize, OutSize);
End;

Function TPCSCReader.IOCTL(IOCtlCode: Cardinal; DataIn: TBytes; Out DataOut: TBytes): Cardinal;
Var
  OutBufLen: PCSC_DWORD;
Begin
  OutBufLen := 264;
  DataOut := Nil;
  SetLength(DataOut, OutBufLen);

  result := SCIOCTL(IOCtlCode, @DataIn[0], length(DataIn), @DataOut[0], OutBufLen);
  If result = SCARD_S_SUCCESS Then
    SetLength(DataOut, OutBufLen)
  Else
    SetLength(DataOut, 0);
End;

Function TPCSCReader.IOCTLString(IOCtlCode: Cardinal; DataIn: String; Out DataOut: TBytes): Cardinal;
Var
  InBuffer: TBytes;
Begin
  InBuffer := HexStringToBuffer(DataIn);
  result := IOCTL(IOCtlCode, InBuffer, DataOut);
  SetLength(InBuffer, 0);
End;

Procedure TPCSCReader.ClearCardInfo;
Begin
  SetLength(FATR, 0);
  FValidCard := false;
End;

Function TPCSCReader.GetAtrAsString: String;
Var
  i: integer;
Begin
  result := '';
  For i := 0 To length(FATR) - 1 Do
    result := result + IntToHex(FATR[i], 2);
End;

Procedure TPCSCReader.CheckCardState;
Var
  CS: PCSC_DWORD;
  tmpATR: TBytes;
  i: integer;
  PCSCResult: Cardinal;
  NewCardState: TCardState;
  FReaderStateArray: Array[0..0] Of TSCardReaderStateA;
  StatusState, StatusProtocol: PCSC_DWORD;
  StatusReaderLen, StatusAtrLen: PCSC_DWORD;
Begin
  // When we have an active connection, use SCardStatus on the handle.
  // SCardGetStatusChange will keep reporting PRESENT+INUSE as long as
  // the handle is open, even after physical card removal.  SCardStatus
  // returns SCARD_W_REMOVED_CARD immediately in that case.
  If FCardHandle <> PCSC_NO_HANDLE Then Begin
    StatusReaderLen := 0;
    StatusAtrLen := 0;
    PCSCResult := FPCSCRaw.SCardStatus(FCardHandle, Nil, StatusReaderLen,
      StatusState, StatusProtocol, Nil, StatusAtrLen);
    If (PCSCResult = SCARD_W_REMOVED_CARD) Or
      (PCSCResult = SCARD_W_RESET_CARD) Or
      (PCSCResult = SCARD_E_NOT_TRANSACTED) Or
      (PCSCResult = SCARD_E_READER_UNAVAILABLE) Then Begin
      If FCardState <> csNoCard Then Begin
        FCardState := csNoCard;
        ClearCardInfo;
        Disconnect(SCARD_UNPOWER_CARD);
        If Assigned(FOnCardStateChanged) Then FOnCardStateChanged(self);
      End;
      exit;
    End;
    // Handle is still valid – check if state flags indicate a change
    If PCSCResult = SCARD_S_SUCCESS Then Begin
      If (StatusState And SCARD_ABSENT) <> 0 Then Begin
        If FCardState <> csNoCard Then Begin
          FCardState := csNoCard;
          ClearCardInfo;
          Disconnect(SCARD_UNPOWER_CARD);
          If Assigned(FOnCardStateChanged) Then FOnCardStateChanged(self);
        End;
        exit;
      End;
    End;
    // Card still present while connected – nothing to do
    exit;
  End;

  // No active connection – use SCardGetStatusChange for state polling
  FReaderStateArray[0].cbAtr := 0;
  FReaderStateArray[0].dwEventState := SCARD_STATE_UNAWARE;
  FReaderStateArray[0].dwCurrentState := SCARD_STATE_UNAWARE;
  FReaderStateArray[0].szReader := @FReaderName[1];
  FReaderStateArray[0].pvUserData := Nil;

  PCSCResult := FPCSCRaw.SCardGetStatusChange(FPCSCDeviceContext, 1, @FReaderStateArray, 1);
  If PCSCResult = SCARD_E_CANCELLED Then exit;
  If PCSCResult = SCARD_S_SUCCESS Then Begin
    FReaderStateArray[0].dwCurrentState := FReaderStateArray[0].dwEventState;

    NewCardState := FCardState;
    CS := FReaderStateArray[0].dwEventState;
    If (CS And SCARD_STATE_UNAVAILABLE = 0) Then Begin
      If (CS And SCARD_STATE_EMPTY) <> 0 Then
        NewCardState := csNoCard
      Else If (CS And SCARD_STATE_MUTE) <> 0 Then
        NewCardState := csBadCard
      Else If (CS And SCARD_STATE_PRESENT <> 0) Then Begin
        If (CS And SCARD_STATE_EXCLUSIVE <> 0) Then
          NewCardState := csExclusive
        Else If (CS And SCARD_STATE_INUSE <> 0) Then
          NewCardState := csShared
        Else Begin
          NewCardState := csAvailable;
          tmpATR := Nil;
          SetLength(tmpATR, FReaderStateArray[0].cbAtr);
          For i := 0 To FReaderStateArray[0].cbAtr - 1 Do
            tmpATR[i] := FReaderStateArray[0].rgbAtr[i];
        End;
      End
      Else If FReaderStateArray[0].cbAtr = 0 Then
        NewCardState := csBadCard
      Else
        NewCardState := csUnknown;
    End;

    If FCardState <> NewCardState Then Begin
      FCardState := NewCardState;
      Case FCardState Of
        csNoCard, csBadCard, csUnknown: Begin
            ClearCardInfo;
            Disconnect(SCARD_UNPOWER_CARD);
          End;
        csAvailable: Begin
            FATR := copy(tmpATR);
            FValidCard := true;
          End;
      End;

      If Assigned(FOnCardStateChanged) Then FOnCardStateChanged(self);
    End;
  End;
End;

Function TPCSCReader.ReadSCardAttrDW(AttrCode: Cardinal; Out Attrib: Cardinal): boolean;
Var
  len: PCSC_DWORD;
Begin
  result := false;
  Attrib := 0;
  If FCardHandle = PCSC_NO_HANDLE Then exit;
  len := sizeof(Cardinal);
  result := FPCSCRaw.SCardGetAttrib(FCardHandle, AttrCode, @Attrib, len) = SCARD_S_SUCCESS;
End;

Function TPCSCReader.ReadSCardAttrS(AttrCode: Cardinal; Out Attrib: String): boolean;
Var
  len: PCSC_DWORD;
  cstr: Array[0..255] Of char;
Begin
  result := false;
  Attrib := '';
  If FCardHandle = PCSC_NO_HANDLE Then exit;
  len := length(cstr);
{$IFDEF FPC}
{$PUSH}
{$HINTS OFF}
  FillByte(cstr, len * sizeof(char), 0);
{$POP}
{$ELSE}
  FillChar(cstr, len * sizeof(char), 0);
{$ENDIF}
  result := FPCSCRaw.SCardGetAttrib(FCardHandle, AttrCode, @cstr[0], len) = SCARD_S_SUCCESS;
  If result Then Attrib := String(cstr);
End;

Procedure TPCSCReader.CollectReaderData;
Begin
  If Connect(SCARD_SHARE_DIRECT) <> SCARD_S_SUCCESS Then exit;
  Try
    GetVendorName;
    GetDisplayName;
    GetDriverVersion;
    GetFirmwareVersion;
    GetDeviceSerial;
  Finally
    Disconnect(SCARD_LEAVE_CARD);
  End;
End;

Function TPCSCReader.GetVendorName: boolean;
Begin
  result := ReadSCardAttrS(SCARD_ATTR_VENDOR_NAME, FVendorName);
End;

Function TPCSCReader.GetDeviceSerial: boolean;
Begin
  FSerial := '';
  result := GetDeviceSerialStd;
{$IFDEF UNIX}
  If FSerial = '' Then result := GetDeviceSerialLinux;
{$ENDIF}
End;

Function TPCSCReader.GetDeviceSerialStd: boolean;
Begin
  result := ReadSCardAttrS(SCARD_ATTR_VENDOR_IFD_SERIAL_NO, FSerial);
End;

{$IFDEF UNIX}

Function TPCSCReader.GetDeviceSerialLinux: boolean;
Var
  p1, p2: integer;
Begin
  FSerial := '';
  p1 := pos('(', FReaderName);
  p2 := pos(')', FReaderName);
  If (p1 > 10) And (p2 > p1 + 5) Then FSerial := copy(FReaderName, p1 + 1, p2 - p1 - 1);
  result := FSerial <> '';
End;
{$ENDIF}

Function TPCSCReader.GetDisplayName: boolean;
{$IFDEF UNIX}
Var
  p1, p2: integer;
  tmpName: String;
{$ENDIF}
Begin
  result := ReadSCardAttrS(SCARD_ATTR_DEVICE_FRIENDLY_NAME_A, FDisplayName);
  If FDisplayName = '' Then FDisplayName := FReaderName;
{$IFDEF UNIX}
  If FDisplayName = '' Then exit;
  p1 := pos('[', FDisplayName);
  p2 := pos(']', FDisplayName);
  If (p1 > 10) And (p2 > p1 + 10) Then tmpName := trim(copy(FDisplayName, p1 + 1, p2 - p1 - 1));
  If lowercase(tmpName) = 'ccid interface' Then
    FDisplayName := trim(copy(FDisplayName, 1, p1 - 1))
  Else
    FDisplayName := tmpName;
{$ENDIF}
End;

Type
  TVersionControl = Record
    SmclibVersion: Cardinal;
    DriverMajor: byte;
    DriverMinor: byte;
    FirmwareMajor: byte;
    FirmwareMinor: byte;
    UpdateKey: byte;
  End;

Function TPCSCReader.GetDriverVersion: boolean;
Var
  Version: TVersionControl;
  ReturnLength: PCSC_DWORD;
Begin
  ReturnLength := sizeof(TVersionControl);

  result := SCIOCTL(IOCTL_GET_VERSIONS, Nil, 0, @Version, ReturnLength) = SCARD_S_SUCCESS;
  If Not result Then exit;

  FDrvMajor := Version.DriverMajor;
  FDrvMinor := Version.DriverMinor;
  FIFDMajor := Version.FirmwareMajor;
  FIFDMinor := Version.FirmwareMinor;
End;

Function TPCSCReader.GetFirmwareVersion: boolean;
Var
  x: integer;
Begin
  FVendorIFDVersion := 0;
  result := ReadSCardAttrDW(SCARD_ATTR_VENDOR_IFD_VERSION, FVendorIFDVersion);
  If Not result Then exit;

  x := (FVendorIFDVersion Shr 24) And $FF;
  FIFDMajor := ((x Shr 4) And $F) * 10 + x And $F;
  x := (FVendorIFDVersion Shr 16) And $FF;
  FIFDMinor := ((x Shr 4) And $F) * 10 + x And $F;
End;

Function TPCSCReader.Send(DataIn: Array Of TBytes; Var DataOut; DataOutLen:
  Integer): Cardinal;
Var
  bIn, b, bOut: TBytes;
  SW12: Word;
Begin
  bOut := Nil;
  Result := SCARD_S_SUCCESS;
  For bIn In DataIn Do Begin
    b := [];
    If Protocol = prRaw Then
      Result := IOCTL(IOCTL_CCID_ESCAPE, bIn, b)
    Else
      Result := TransmitSW(bIn, b, SW12);

    If Result <> SCARD_S_SUCCESS Then Break;

    bOut := bOut + b;
  End;
  FillChar(DataOut, DataOutLen, 0);
  If (Result = SCARD_S_SUCCESS) And (Length(bOut) > 0) Then
    Move(bOut[0], DataOut, DataOutLen);
End;

Constructor TPCSC.Create;
Begin
  Inherited;
  FPCSCDeviceContext := 0;
  FMCardSupport := true;
  FGetReaderDetails := true;

  FReaderList := TStringList.Create;
  FPCSCRaw := TPCSCRaw.Create;
  FValid := (InitPCSC = SCARD_S_SUCCESS);

  FReaderListThread := TReaderListThread.Create(FPCSCRaw);
  FReaderListThread.OnReaderListChanged := @ReaderListChanged;
  FReaderListThread.OnTimer := @CheckCardStates;
{$IFDEF UNIX}
  FReaderListThread.OnTerminated := @ReaderListThreadTerminated;
  FReaderListThreadRunning := false;
{$ENDIF}

  FPCSCEventList := TPCSCEventList.Create;

  FPCSCEventList.OnCardInsert := @CardInsertSync;
  FPCSCEventList.OnCardRemove := @CardRemoveSync;
  FPCSCEventList.OnCardError := @CardErrorSync;
  FPCSCEventList.OnReaderFound := @ReaderFoundSync;
  FPCSCEventList.OnReaderRemoved := @ReaderRemovedSync;

  FOnReaderListChanged := Nil;
  FOnCardStateChanged := Nil;
  FOnReaderFound := Nil;
  FOnReaderRemoved := Nil;
  FOnCardInserted := Nil;
  FOnCardRemoved := Nil;
  FOnCardError := Nil;

  FOnReaderFoundAsync := @FPCSCEventList.ReaderFoundAsync;
  FOnReaderRemovedAsync := @FPCSCEventList.ReaderRemovedAsync;
  FOnCardInsertedAsync := @FPCSCEventList.CardInsertedAsync;
  FOnCardRemovedAsync := @FPCSCEventList.CardRemovedAsync;
  FOnCardErrorAsync := @FPCSCEventList.CardErrorAsync;
End;

Destructor TPCSC.Destroy;
Var
  i: integer;
Begin
  FReaderListThread.Terminate;
  // Be sure that thread has been terminated before freeing it
{$IFDEF WINDOWS}
  WaitForSingleObject(FReaderListThread.Handle, 1000);
{$ELSE}
  // WaitForSingleObject is not implemented in Linux
  While FReaderListThreadRunning Do
    Application.ProcessMessages;
{$ENDIF}
  For i := 0 To FReaderList.Count - 1 Do
    TPCSCReader(FReaderList.Objects[i]).Free;
  FReaderList.Free;
  FPCSCEventList.Free;

  If FPCSCDeviceContext <> 0 Then Begin
    FPCSCRaw.SCardCancel(FPCSCDeviceContext);
    FPCSCRaw.SCardReleaseContext(FPCSCDeviceContext);
  End;

  FPCSCRaw.Shutdown;
  FPCSCRaw.Free;
  FPCSCRaw := Nil;

  Inherited;
End;

Function TPCSC.InitPCSC: Cardinal;
Begin
  result := SCARD_F_INTERNAL_ERROR;
  If Not FPCSCRaw.Initialize Then exit;
  result := FPCSCRaw.SCardEstablishContext(SCARD_SCOPE_SYSTEM, Nil, Nil, FPCSCDeviceContext);
  If result <> SCARD_S_SUCCESS Then result := FPCSCRaw.SCardEstablishContext(SCARD_SCOPE_USER, Nil, Nil, FPCSCDeviceContext);
End;

Procedure TPCSC.CheckCardStates;
Var
  i: integer;
Begin
  For i := 0 To FReaderList.Count - 1 Do Begin
    TPCSCReader(FReaderList.Objects[i]).CheckCardState;
  End;
End;

Procedure TPCSC.ReaderListChanged;
Begin
  If Assigned(FOnReaderListChanged) Then FOnReaderListChanged(self);
  UpdatePCSCReaderList;
End;

Procedure TPCSC.UpdatePCSCReaderList;
Var
  i, j: integer;
  Found: boolean;
  ReaderName: String;
  aReaderList: TStringList;
  PCSCReader: TPCSCReader;
Begin
  aReaderList := TStringList.Create;
  Try
    GetPCSCReaderList(aReaderList);
    For i := FReaderList.Count - 1 Downto 0 Do Begin
      ReaderName := FReaderList[i];
      Found := false;
      For j := 0 To aReaderList.Count - 1 Do Begin
        If ReaderName = aReaderList[j] Then Begin
          Found := true;
          break;
        End;
      End;
      If Not Found Then Begin
        If Assigned(FOnReaderRemovedAsync) Then FOnReaderRemovedAsync(self, ReaderName);
        TPCSCReader(FReaderList.Objects[i]).Free;
        FReaderList.Delete(i);
      End;
    End;

    For i := 0 To aReaderList.Count - 1 Do Begin
      Found := false;
      For j := 0 To FReaderList.Count - 1 Do Begin
        ReaderName := FReaderList[j];
        If ReaderName = aReaderList[i] Then Begin
          Found := true;
          break;
        End;
      End;
      If Not Found Then Begin
        ReaderName := aReaderList[i];
        PCSCReader := TPCSCReader.Create(ReaderName, FPCSCRaw);
        PCSCReader.OnCardStateChanged := @CardStateChanged;
        FReaderList.AddObject(ReaderName, PCSCReader);
        If FGetReaderDetails Then PCSCReader.CollectReaderData;
        If Assigned(FOnReaderFoundAsync) Then FOnReaderFoundAsync(self, ReaderName);
      End;
    End;
  Finally
    aReaderList.Free;
  End;
End;

Procedure TPCSC.GetPCSCReaderList(ReaderList: TStringList);
Var
  pReaders: PChar;
  PCSCResult: Cardinal;
  SizeReaders: PCSC_DWORD;
  Retried: boolean; // Workaround for Windows 8.1
Begin
  ReaderList.Clear;

  Retried := false; // Workaround for Windows 8.1
  While true Do Begin // Workaround for Windows 8.1
    PCSCResult := FPCSCRaw.SCardListReaders(FPCSCDeviceContext, Nil, Nil, SizeReaders);
    If PCSCResult = SCARD_S_SUCCESS Then Begin
{$IFDEF UNIX}If SizeReaders < 50 Then SizeReaders := 50;
{$ENDIF} // workaround for Linux, where GetMem fails, if the requested amount of memory is too small
      GetMem(pReaders, SizeReaders * 2 + 2);
      Try
        PCSCResult := FPCSCRaw.SCardListReaders(FPCSCDeviceContext, Nil, pReaders, SizeReaders);
        If PCSCResult = SCARD_S_SUCCESS Then Begin
          MultiStrToStringList(pReaders, SizeReaders, ReaderList);
          exit;
        End;
      Finally
        If pReaders <> Nil Then FreeMem(pReaders);
      End;
    End
    Else Begin
      If Retried Then exit; // Workaround for Windows 8.1
      Retried := true; // Workaround for Windows 8.1
      If {$IFDEF WINDOWS}(PCSCResult = ERROR_BROKEN_PIPE) Or (PCSCResult = ERROR_INVALID_HANDLE) Or {$ENDIF}(PCSCResult = SCARD_E_SERVICE_STOPPED) Then Begin
        FPCSCDeviceContext := 0;
        PCSCResult := FPCSCRaw.SCardEstablishContext(SCARD_SCOPE_SYSTEM, Nil, Nil, FPCSCDeviceContext);
        If PCSCResult <> SCARD_S_SUCCESS Then FPCSCRaw.SCardEstablishContext(SCARD_SCOPE_USER, Nil, Nil, FPCSCDeviceContext);
      End;
    End;
  End; // Workaround for Windows 8.1
End;

Procedure TPCSC.CardStateChanged(PCSCReader: TPCSCReader);
Var
  ReaderName: String;
  CardState: TCardState;
Begin
  CardState := PCSCReader.CardState;
  ReaderName := PCSCReader.ReaderName;
  If Assigned(FOnCardStateChanged) Then FOnCardStateChanged(self, ReaderName);
  If CardState = csAvailable Then Begin
    If Assigned(FOnCardInsertedAsync) Then FOnCardInsertedAsync(self, ReaderName, PCSCReader.ATR);
  End
  Else If CardState = csNoCard Then Begin
    If Assigned(FOnCardRemovedAsync) Then FOnCardRemovedAsync(self, ReaderName);
  End
  Else If CardState = csBadCard Then Begin
    If Assigned(FOnCardErrorAsync) Then FOnCardErrorAsync(self, ReaderName);
  End;
End;

{$IFDEF UNIX}

Procedure TPCSC.ReaderListThreadTerminated;
Begin
  FReaderListThreadRunning := false;
End;
{$ENDIF}

Procedure TPCSC.Start;
Begin
{$IFDEF FPC}
  FReaderListThread.Start;
{$ELSE}
{$IF CompilerVersion >= 20}
  FReaderListThread.Start;
{$ELSE}
  FReaderListThread.Resume;
{$IFEND}
{$ENDIF}
{$IFDEF UNIX}
  FReaderListThreadRunning := true;
{$ENDIF}
End;

Procedure TPCSC.ProcessEvent;
Begin
  If FPCSCEventList = Nil Then exit;
  FPCSCEventList.ProcessAllEvents;
End;

Function TPCSC.GetPCSCReader(ReaderName: String): TPCSCReader;
Var
  i: integer;
Begin
  result := Nil;
  For i := 0 To FReaderList.Count - 1 Do Begin
    If FReaderList[i] = ReaderName Then Begin
      result := TPCSCReader(FReaderList.Objects[i]);
      exit;
    End;
  End;
End;

Procedure TPCSC.CardInsertSync(ReaderName, ATR: String);
Begin
  If Assigned(FOnCardInserted) Then FOnCardInserted(self, ReaderName, HexStringToBuffer(ATR));
End;

Procedure TPCSC.CardRemoveSync(ReaderName: String);
Begin
  If Assigned(FOnCardRemoved) Then FOnCardRemoved(self, ReaderName);
End;

Procedure TPCSC.CardErrorSync(ReaderName: String);
Begin
  If Assigned(FOnCardError) Then FOnCardError(self, ReaderName);
End;

Procedure TPCSC.ReaderFoundSync(ReaderName: String);
Begin
  If Assigned(FOnReaderFound) Then FOnReaderFound(self, ReaderName);
End;

Procedure TPCSC.ReaderRemovedSync(ReaderName: String);
Begin
  If Assigned(FOnReaderRemoved) Then FOnReaderRemoved(self, ReaderName);
End;

End.

