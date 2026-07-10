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

Unit MD_PCSCRaw;
{$IFDEF FPC}
{$MODE objfpc}{$H+}
{$ELSE}
{$DEFINE WINDOWS}
{$ENDIF}

Interface

Uses
{$IFDEF WINDOWS}Windows, {$ENDIF}
{$IFDEF UNIX}DynLibs, {$ENDIF}
  SysUtils, Classes, MD_PcscDef;

Type
  TSCardBeginTransaction = Function(hContext: THandle): PCSC_DWORD; stdcall;
  TSCardCancel = Function(hContext: THandle): PCSC_DWORD; stdcall;
  TSCardConnect = Function(hContext: THandle; pReader: PChar; ShareMode: PCSC_DWORD; PreferredProtocols: PCSC_DWORD; Out CardHandle: THandle; Out ActiveProtocol: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardControl = Function(hContext: THandle; IoCtl: PCSC_DWORD; pInBuffer: Pointer; SizeInBuffer: PCSC_DWORD; pOutBuffer: Pointer; SizeOutBuffer: PCSC_DWORD; Var BytesRet: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardDisconnect = Function(hContext: THandle; Disposition: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardEndTransaction = Function(hContext: THandle; Disposition: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardEstablishContext = Function(Scope: PCSC_DWORD; pReserved1, pReserved2: Pointer; Out hContext: THandle): PCSC_DWORD; stdcall;
  TSCardFreeMemory = Function(hContext: THandle; pMem: Pointer): PCSC_DWORD; stdcall;
  TSCardGetAttrib = Function(hCard: THandle; AttrId: PCSC_DWORD; pAttr: Pointer; Var SizeAttr: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardGetProviderId = Function(hContext: THandle; pCard: PChar; Out GuidProviderId: TGUID): PCSC_DWORD; stdcall;
  TSCardGetStatusChange = Function(hContext: THandle; Timeout: PCSC_DWORD; pReaderStates: PSCardReaderStateA; ReaderStatesCount: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardListReaders = Function(hContext: THandle; pGroups, pReaders: PChar; Var SizeReaders: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardListCards = Function(hContext: THandle; pAtr: Pointer; pGuidInterfaces: PGUID; GuidInterfacesCount: PCSC_DWORD; pCards: PChar; Var SizeCards: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardListInterfaces = Function(hContext: THandle; pCard: PChar; pGuidInterfaces: PGUID; Var GuidInterfacesCount: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardListReaderGroups = Function(hContext: THandle; pGroups: PChar; Var SizeGroups: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardLocateCards = Function(hContext: THandle; pCards: PChar; pReaderStates: PSCardReaderStateA; ReaderStatesCount: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardReconnect = Function(hCard: THandle; ShareMode, PreferredProtocols, dwInitialization: PCSC_DWORD; Out ActiveProtocol: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardReleaseContext = Function(hContext: THandle): PCSC_DWORD; stdcall;
  TSCardTransmit = Function(hCard: THandle; PioSendPci: PSCardIoRequest; pSendBuffer: Pointer; SizeSendBuffer: PCSC_DWORD; PioRecvPci: PSCardIoRequest; pRecvBuffer: Pointer; Var SizeRecvBuffer: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardSetAttrib = Function(hCard: THandle; AttrId: PCSC_DWORD; pAttr: Pointer; AttrLen: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardStatus = Function(hCard: THandle; pReaderNames: PChar; Var SizeReaderNames: PCSC_DWORD; Out State, Protocol: PCSC_DWORD; pAtr: Pointer; Var AtrLen: PCSC_DWORD): PCSC_DWORD; stdcall;
  TSCardIsValidContext = Function(hContext: THandle): PCSC_DWORD; stdcall;

  TPCSCRaw = Class(TObject)
  private
    FValid: boolean;
    FhWinSCard: THandle;

    FSCardBeginTransaction: TSCardBeginTransaction;
    FSCardCancel: TSCardCancel;
    FSCardConnect: TSCardConnect;
    FSCardControl: TSCardControl;
    FSCardDisconnect: TSCardDisconnect;
    FSCardEndTransaction: TSCardEndTransaction;
    FSCardEstablishContext: TSCardEstablishContext;
    FSCardFreeMemory: TSCardFreeMemory;
    FSCardGetAttrib: TSCardGetAttrib;
    FSCardGetProviderId: TSCardGetProviderId;
    FSCardGetStatusChange: TSCardGetStatusChange;
    FSCardListReaders: TSCardListReaders;
    FSCardListCards: TSCardListCards;
    FSCardListInterfaces: TSCardListInterfaces;
    FSCardListReaderGroups: TSCardListReaderGroups;
    FSCardLocateCards: TSCardLocateCards;
    FSCardReconnect: TSCardReconnect;
    FSCardReleaseContext: TSCardReleaseContext;
    FSCardTransmit: TSCardTransmit;
    FSCardSetAttrib: TSCardSetAttrib;
    FSCardStatus: TSCardStatus;
    FSCardIsValidContext: TSCardIsValidContext;
    Function CTLCode(DeviceType, _Function, Method, Access: Cardinal): Cardinal;
  public
    Constructor Create;
    Destructor Destroy; override;

    Function Initialize: boolean;
    Function Shutdown: boolean;
    Function SCardBeginTransaction(hContext: THandle): Cardinal;
    Function SCardCancel(hContext: THandle): Cardinal;
    Function SCardConnect(hContext: THandle; pReader: PChar; ShareMode, PreferredProtocols: PCSC_DWORD; Out CardHandle: THandle; Out ActiveProtocol: PCSC_DWORD): Cardinal;
    Function SCardControl(hContext: THandle; IoCtl: PCSC_DWORD; pInBuffer: Pointer; SizeInBuffer: PCSC_DWORD; pOutBuffer: Pointer; SizeOutBuffer: PCSC_DWORD; Var BytesRet: PCSC_DWORD): Cardinal;
    Function SCardDisconnect(hContext: THandle; Disposition: PCSC_DWORD): Cardinal;
    Function SCardEndTransaction(hContext: THandle; Disposition: PCSC_DWORD): Cardinal;
    Function SCardEstablishContext(Scope: PCSC_DWORD; pReserved1, pReserved2: Pointer; Out hContext: THandle): Cardinal;
    Function SCardFreeMemory(hContext: THandle; pMem: Pointer): Cardinal;
    Function SCardGetAttrib(hCard: THandle; AttrId: PCSC_DWORD; pAttr: Pointer; Var SizeAttr: PCSC_DWORD): Cardinal;
    Function SCardGetProviderId(hContext: THandle; pCard: PChar; Out GuidProviderId: TGUID): Cardinal;
    Function SCardGetStatusChange(hContext: THandle; Timeout: PCSC_DWORD; pReaderStates: PSCardReaderStateA; ReadersStatesCount: PCSC_DWORD): Cardinal;
    Function SCardListReaders(hContext: THandle; pGroups, pReaders: PChar; Var SizeReaders: PCSC_DWORD): Cardinal;
    Function SCardListCards(hContext: THandle; pAtr: Pointer; pGuidInterfaces: PGUID; GuidInterfacesCount: PCSC_DWORD; pCards: PChar; Var SizeCards: PCSC_DWORD): Cardinal;
    Function SCardListInterfaces(hContext: THandle; pCard: PChar; pGuidInterfaces: PGUID; Var GuidInterfacesCount: PCSC_DWORD): Cardinal;
    Function SCardListReaderGroups(hContext: THandle; pGroups: PChar; Var SizeGroups: PCSC_DWORD): Cardinal;
    Function SCardLocateCards(hContext: THandle; pCards: PChar; pReaderStates: PSCardReaderStateA; ReaderStatesCount: PCSC_DWORD): Cardinal;
    Function SCardReconnect(hCard: THandle; ShareMode, PreferredProtocols, dwInitialization: PCSC_DWORD; Out ActiveProtocol: PCSC_DWORD): Cardinal;
    Function SCardReleaseContext(hContext: THandle): Cardinal;
    Function SCardTransmit(hCard: THandle; PioSendPci: PSCardIoRequest; SendBuffer: Pointer; SizeSendBuffer: PCSC_DWORD; PioRecvPci: PSCardIoRequest; RecvBuffer: Pointer; Var SizeRecvBuffer: PCSC_DWORD): Cardinal;
    Function SCardSetAttrib(hCard: THandle; AttrId: PCSC_DWORD; pAttr: Pointer; AttrLen: PCSC_DWORD): Cardinal;
    Function SCardStatus(hCard: THandle; pReaderNames: PChar; Var SizeReaderNames: PCSC_DWORD; Out State, Protocol: PCSC_DWORD; pAtr: Pointer; Var AtrLen: PCSC_DWORD): Cardinal;
    Function SCardIsValidContext(hContext: THandle): Cardinal;

    Function SCardCTLCode(Code: Cardinal): Cardinal;

    Property hWinSCard: THandle read FhWinSCard;
    Property Valid: boolean read FValid;
  End;

Function MultiStrToStringList(pBuffer: PChar; SizeStr: LongInt; StrList: TStringList): boolean;

Implementation

// MultiString:  str1#0str2#0str3#0.....strN#0#0

Function MultiStrToStringList(pBuffer: PChar; SizeStr: LongInt; StrList: TStringList): boolean;
Var
  i: integer;
  s: String;
  c: char;
Begin
  Result := false;
  If StrList = Nil Then exit;
  StrList.Clear;
  If ((pBuffer = Nil) Or (SizeStr = 0)) Then
    Result := true
  Else If (SizeStr = 1) Then Begin
    If (pBuffer^ = #0) Then Result := true;
  End
  Else If ((pBuffer + SizeStr - 1)^ <> #0) Or ((pBuffer + SizeStr - 2)^ <> #0) Then
    exit
  Else Begin
    s := '';
    For i := 0 To SizeStr - 1 Do Begin
      c := (pBuffer + i)^;
      If c <> #0 Then
        s := s + c
      Else Begin
        If s <> '' Then StrList.Add(s);
        s := '';
      End;
    End;
    Result := true;
  End;
End;

Constructor TPCSCRaw.Create;
Begin
  Inherited Create;
  FhWinSCard := 0;
  FValid := false;
End;

Destructor TPCSCRaw.Destroy;
Begin
  If FValid Then Shutdown;
  Inherited Destroy;
End;

Function TPCSCRaw.SCardBeginTransaction(hContext: THandle): Cardinal;
Begin
  If FValid And Assigned(FSCardBeginTransaction) Then
    Result := FSCardBeginTransaction(hContext)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardCancel(hContext: THandle): Cardinal;
Begin
  If FValid And Assigned(FSCardCancel) Then
    Result := FSCardCancel(hContext)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardConnect(hContext: THandle; pReader: PChar; ShareMode, PreferredProtocols: PCSC_DWORD; Out CardHandle: THandle; Out ActiveProtocol: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardConnect) Then
    Result := FSCardConnect(hContext, pReader, ShareMode, PreferredProtocols, CardHandle, ActiveProtocol)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardControl(hContext: THandle; IoCtl: PCSC_DWORD; pInBuffer: Pointer; SizeInBuffer: PCSC_DWORD; pOutBuffer: Pointer; SizeOutBuffer: PCSC_DWORD; Var BytesRet: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardControl) Then
    Result := FSCardControl(hContext, IoCtl, pInBuffer, SizeInBuffer, pOutBuffer, SizeOutBuffer, BytesRet)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardDisconnect(hContext: THandle; Disposition: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardDisconnect) Then
    Result := FSCardDisconnect(hContext, Disposition)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardEndTransaction(hContext: THandle; Disposition: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardEndTransaction) Then
    Result := FSCardEndTransaction(hContext, Disposition)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardEstablishContext(Scope: PCSC_DWORD; pReserved1, pReserved2: Pointer; Out hContext: THandle): Cardinal;
Begin
  If FValid And Assigned(FSCardEstablishContext) Then
    Result := FSCardEstablishContext(Scope, pReserved1, pReserved2, hContext)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardFreeMemory(hContext: THandle; pMem: Pointer): Cardinal;
Begin
  If FValid And Assigned(FSCardFreeMemory) Then
    Result := FSCardFreeMemory(hContext, pMem)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardGetAttrib(hCard: THandle; AttrId: PCSC_DWORD; pAttr: Pointer; Var SizeAttr: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardGetAttrib) Then
    Result := FSCardGetAttrib(hCard, AttrId, pAttr, SizeAttr)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardGetProviderId(hContext: THandle; pCard: PChar; Out GuidProviderId: TGUID): Cardinal;
Begin
  If FValid And Assigned(FSCardGetProviderId) Then
    Result := FSCardGetProviderId(hContext, pCard, GuidProviderId)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardGetStatusChange(hContext: THandle; Timeout: PCSC_DWORD; pReaderStates: PSCardReaderStateA; ReadersStatesCount: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardGetStatusChange) Then
    Result := FSCardGetStatusChange(hContext, Timeout, pReaderStates, ReadersStatesCount)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardListReaders(hContext: THandle; pGroups, pReaders: PChar; Var SizeReaders: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardListReaders) Then
    Result := FSCardListReaders(hContext, pGroups, pReaders, SizeReaders)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardListCards(hContext: THandle; pAtr: Pointer; pGuidInterfaces: PGUID; GuidInterfacesCount: PCSC_DWORD; pCards: PChar; Var SizeCards: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardListCards) Then
    Result := FSCardListCards(hContext, pAtr, pGuidInterfaces, GuidInterfacesCount, pCards, SizeCards)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardListInterfaces(hContext: THandle; pCard: PChar; pGuidInterfaces: PGUID; Var GuidInterfacesCount: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardListInterfaces) Then
    Result := FSCardListInterfaces(hContext, pCard, pGuidInterfaces, GuidInterfacesCount)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardListReaderGroups(hContext: THandle; pGroups: PChar; Var SizeGroups: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardListReaderGroups) Then
    Result := FSCardListReaderGroups(hContext, pGroups, SizeGroups)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardLocateCards(hContext: THandle; pCards: PChar; pReaderStates: PSCardReaderStateA; ReaderStatesCount: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardLocateCards) Then
    Result := FSCardLocateCards(hContext, pCards, pReaderStates, ReaderStatesCount)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardReconnect(hCard: THandle; ShareMode, PreferredProtocols, dwInitialization: PCSC_DWORD; Out ActiveProtocol: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardReconnect) Then
    Result := FSCardReconnect(hCard, ShareMode, PreferredProtocols, dwInitialization, ActiveProtocol)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardReleaseContext(hContext: THandle): Cardinal;
Begin
  If FValid And Assigned(FSCardReleaseContext) Then
    Result := FSCardReleaseContext(hContext)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardTransmit(hCard: THandle; PioSendPci: PSCardIoRequest; SendBuffer: Pointer; SizeSendBuffer: PCSC_DWORD; PioRecvPci: PSCardIoRequest; RecvBuffer: Pointer;
  Var SizeRecvBuffer: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardTransmit) Then
    Result := FSCardTransmit(hCard, PioSendPci, SendBuffer, SizeSendBuffer, PioRecvPci, RecvBuffer, SizeRecvBuffer)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardSetAttrib(hCard: THandle; AttrId: PCSC_DWORD; pAttr: Pointer; AttrLen: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardSetAttrib) Then
    Result := FSCardSetAttrib(hCard, AttrId, pAttr, AttrLen)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardStatus(hCard: THandle; pReaderNames: PChar; Var SizeReaderNames: PCSC_DWORD; Out State, Protocol: PCSC_DWORD; pAtr: Pointer; Var AtrLen: PCSC_DWORD): Cardinal;
Begin
  If FValid And Assigned(FSCardStatus) Then
    Result := FSCardStatus(hCard, pReaderNames, SizeReaderNames, State, Protocol, pAtr, AtrLen)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.SCardIsValidContext(hContext: THandle): Cardinal;
Begin
  If FValid And Assigned(FSCardIsValidContext) Then
    Result := FSCardIsValidContext(hContext)
  Else
    Result := SCARD_E_UNSUPPORTED_FEATURE;
End;

Function TPCSCRaw.CTLCode(DeviceType, _Function, Method, Access: Cardinal): Cardinal;
Begin
  Result := (DeviceType Shl 16) Or (Access Shl 14) Or (_Function Shl 2) Or Method;
End;

Function TPCSCRaw.SCardCTLCode(Code: Cardinal): Cardinal;
Begin
{$IFDEF WINDOWS}
  Result := CTLCode(FILE_DEVICE_SMARTCARD, Code, METHOD_BUFFERED, FILE_ANY_ACCESS);
{$ELSE}
  Result := $42000000 Or Code;
{$ENDIF}
End;

Function TPCSCRaw.Initialize: boolean;
Const
{$IFDEF WINDOWS}
  _LIB_NAME = 'winscard.dll';
{$ELSE}
{$IFDEF DARWIN}
  _LIB_NAME = '/System/Library/Frameworks/PCSC.framework/PCSC';
{$ELSE}
  _LIB_NAME = 'libpcsclite.so.1';
  _LIB_NAME_FALLBACK = 'libpcsclite.so';
{$ENDIF}
{$ENDIF}
Var
  tmpDLLH: THandle;
Begin
  Result := false;
  tmpDLLH := LoadLibrary(_LIB_NAME);
{$IFDEF LINUX}
  If (tmpDLLH = 0) Then tmpDLLH := LoadLibrary(_LIB_NAME_FALLBACK);
{$ENDIF}
  If (tmpDLLH = 0) Then exit;

  FSCardBeginTransaction := TSCardBeginTransaction(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardBeginTransaction'))));
  FSCardCancel := TSCardCancel(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardCancel'))));
{$IFDEF WINDOWS}
{$IFNDEF UNICODE}
  FSCardConnect := TSCardConnect(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardConnectA'))));
  FSCardGetStatusChange := TSCardGetStatusChange(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardGetStatusChangeA'))));
  FSCardListReaders := TSCardListReaders(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListReadersA'))));
  FSCardListCards := TSCardListCards(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListCardsA'))));
  FSCardListInterfaces := TSCardListInterfaces(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListInterfacesA'))));
  FSCardGetProviderId := TSCardGetProviderId(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardGetProviderIdA'))));
  FSCardListReaderGroups := TSCardListReaderGroups(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListReaderGroupsA'))));
  FSCardLocateCards := TSCardLocateCards(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardLocateCardsA'))));
  FSCardStatus := TSCardStatus(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardStatusA'))));
  FSCardIsValidContext := Nil;
{$ELSE}
  FSCardConnect := TSCardConnect(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardConnectW'))));
  FSCardGetStatusChange := TSCardGetStatusChange(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardGetStatusChangeW'))));
  FSCardListReaders := TSCardListReaders(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListReadersW'))));
  FSCardListCards := TSCardListCards(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListCardsW'))));
  FSCardListInterfaces := TSCardListInterfaces(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListInterfacesW'))));
  FSCardGetProviderId := TSCardGetProviderId(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardGetProviderIdW'))));
  FSCardListReaderGroups := TSCardListReaderGroups(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListReaderGroupsW'))));
  FSCardLocateCards := TSCardLocateCards(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardLocateCardsW'))));
  FSCardStatus := TSCardStatus(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardStatusW'))));
  FSCardIsValidContext := Nil;
{$ENDIF}
{$ELSE}
  FSCardConnect := TSCardConnect(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardConnect'))));
  FSCardGetStatusChange := TSCardGetStatusChange(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardGetStatusChange'))));
  FSCardListReaders := TSCardListReaders(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListReaders'))));
  FSCardListCards := TSCardListCards(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListCards'))));
  FSCardListInterfaces := TSCardListInterfaces(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListInterfaces'))));
  FSCardGetProviderId := TSCardGetProviderId(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardGetProviderId'))));
  FSCardListReaderGroups := TSCardListReaderGroups(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardListReaderGroups'))));
  FSCardLocateCards := TSCardLocateCards(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardLocateCards'))));
  FSCardStatus := TSCardStatus(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardStatus'))));
  FSCardIsValidContext := TSCardIsValidContext(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardIsValidContext'))));
{$ENDIF}
{$IFDEF DARWIN}
  FSCardControl := TSCardControl(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardControl132'))));
{$ELSE}
  FSCardControl := TSCardControl(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardControl'))));
{$ENDIF}
  FSCardDisconnect := TSCardDisconnect(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardDisconnect'))));
  FSCardEndTransaction := TSCardEndTransaction(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardEndTransaction'))));
  FSCardEstablishContext := TSCardEstablishContext(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardEstablishContext'))));
  FSCardFreeMemory := TSCardFreeMemory(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardFreeMemory'))));
  FSCardGetAttrib := TSCardGetAttrib(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardGetAttrib'))));
  FSCardReconnect := TSCardReconnect(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardReconnect'))));
  FSCardReleaseContext := TSCardReleaseContext(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardReleaseContext'))));
  FSCardTransmit := TSCardTransmit(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardTransmit'))));
  FSCardSetAttrib := TSCardSetAttrib(GetProcAddress(tmpDLLH, PAnsiChar(AnsiString('SCardSetAttrib'))));

  // check for minimum set of function
  FValid :=
    Assigned(FSCardConnect) And
    Assigned(FSCardControl) And
    Assigned(FSCardDisconnect) And
    Assigned(FSCardEstablishContext) And
    Assigned(FSCardGetAttrib) And
    Assigned(FSCardListReaders) And
    Assigned(FSCardReconnect) And
    Assigned(FSCardReleaseContext) And
    Assigned(FSCardTransmit) And
    Assigned(FSCardStatus);

  If FValid Then Begin
    FValid := true;
    Result := true;
    FhWinSCard := tmpDLLH;
  End;
End;

Function TPCSCRaw.Shutdown: boolean;
Begin
  If FValid Then Begin
    Result := true;
    FValid := false;
    FreeLibrary(FhWinSCard);
    FhWinSCard := 0;
  End
  Else
    Result := false;
End;

End.

