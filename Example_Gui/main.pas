//////////////////////////////////////////////////////////////////////////////////
//     This source code is provided 'as-is', without any express or implied     //
//     warranty. In no event will Infintuary be held liable for any damages     //
//     arising from the use of this software.                                   //
//                                                                              //
//     Infintuary does not warrant, that the source code will be free from      //
//     defects in design or workmanship or that operation of the source code    //
//     will be error-free. No implied or statutory warranty of merchantability  //
//     or fitness for a particulat purpose shall apply. The entire risk of      //
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

Unit Main;

{$MODE objfpc}{$H+}

Interface

Uses
  LCLIntf, LCLType, SysUtils, Classes, Forms, Controls, ComCtrls, StdCtrls,
  ExtCtrls, Graphics, Menus,
  MD_PCSC, MD_PCSCDef, MD_Tools;

Type

  { TMainForm }

  TMainForm = Class(TForm)
    MenuItem1: TMenuItem;
    PopupMenu1: TPopupMenu;
    TopPanel: TPanel;
    Panel1: TPanel;
    Splitter1: TSplitter;
    Panel2: TPanel;
    Label2: TLabel;
    Panel3: TPanel;
    Label1: TLabel;
    ReaderListBox: TListBox;
    StatusBar1: TStatusBar;
    ConnectSharedButton: TButton;
    ConnectExclusiveButton: TButton;
    ConnectDirectButton: TButton;
    DisconnectButton: TButton;
    Label3: TLabel;
    CommandComboBox: TComboBox;
    TransmitButton: TButton;
    Bevel1: TBevel;
    LogMemo: TMemo;
    Procedure ConnectDirectButtonClick(Sender: TObject);
    Procedure FormCreate(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
    Procedure MenuItem1Click(Sender: TObject);
    Procedure ReaderListBoxDrawItem(Control: TWinControl; Index: Integer; RC: TRect; State: TOwnerDrawState);
    Procedure ConnectSharedButtonClick(Sender: TObject);
    Procedure ConnectExclusiveButtonClick(Sender: TObject);
    Procedure DisconnectButtonClick(Sender: TObject);
    Procedure TransmitButtonClick(Sender: TObject);
    Procedure ReaderListBoxClick(Sender: TObject);
    Procedure CommandComboBoxChange(Sender: TObject);
    Procedure CommandComboBoxEnter(Sender: TObject);
    Procedure CommandComboBoxKeyPress(Sender: TObject; Var Key: Char);
    Procedure CommandComboBoxKeyDown(Sender: TObject; Var Key: Word; {%H-} Shift: TShiftState);
    Procedure FormActivate(Sender: TObject);
    Procedure CommandComboBoxExit(Sender: TObject);
  private
    FPCSC: TPCSC;
    Initialized: boolean;
    Procedure UpdatePCSCReaderList;
    Procedure CardStateChanged(Sender: TObject; ReaderName: String);
    Procedure UpdateButtons;
    Procedure ProcessEvents(Sender: TObject; Var Done: boolean);

    Procedure ReaderFound(Sender: TObject; ReaderName: String);
    Procedure ReaderRemoved(Sender: TObject; ReaderName: String);
    Procedure CardInserted(Sender: TObject; ReaderName: String; ATR: TBytes);
    Procedure CardRemoved(Sender: TObject; ReaderName: String);
    Procedure CardError(Sender: TObject; ReaderName: String);

    Procedure AddLogMemo(Msg: String);
    Function ErrorToString(ErrorCode: DWORD): String;
  public
  End;

Var
  MainForm: TMainForm;

Implementation

{$R *.lfm}

Function CleanCommandString(Const S: String): String;
Var
  p: Integer;
Begin
  Result := Trim(S);
  p := Pos('(', Result);
  If p > 0 Then
    Result := Trim(Copy(Result, 1, p - 1));
End;

Function TryNormalizeCommandHex(Const S: String; Out Normalized: String): boolean;
Var
  i: Integer;
  c: Char;
  nibbleCount: Integer;
Begin
  Normalized := '';
  nibbleCount := 0;

  For i := 1 To length(S) Do Begin
    c := UpCase(S[i]);
    If c = ' ' Then
      Continue;
    If Not (c In ['0'..'9', 'A'..'F']) Then Begin
      Result := false;
      Exit;
    End;
    Normalized := Normalized + c;
    Inc(nibbleCount);
  End;

  If (nibbleCount = 0) Or ((nibbleCount Mod 2) <> 0) Then Begin
    Result := false;
    Exit;
  End;

  Normalized := BufferToHexString(HexStringToBuffer(Normalized));
  Result := length(Normalized) > 0;
End;

Function CardStatusHint(SW12: Word; Const CommandHex: String): String;
Begin
  Result := '';
  Case SW12 Of
    $9000: Result := 'Command executed successfully.';
    $6300: Result := 'Command was processed, but state/conditions on card side changed or were not ideal.';
    $6700: Result := 'Wrong APDU length. Check Lc/Le bytes.';
    $6982: Result := 'Security status not satisfied. Authentication is likely required first.';
    $6985: Result := 'Conditions of use not satisfied for this command.';
    $6A81: Result := 'Function/parameter not supported by this card or current mode.';
    $6A82: Result := 'Requested object/application/file was not found.';
    $6B00: Result := 'Wrong parameter P1/P2.';
  End;

  If (SW12 = $6A81) And (CommandHex = 'FF CA 01 00 00') Then
    Result := Result + ' ATS is not available on many cards/readers.';

  If (SW12 = $6300) And (CommandHex = 'FF CA 02 00 00') Then
    Result := Result + ' ATQA/SAK retrieval is reader/card dependent and may be unavailable.';

  If (SW12 = $6300) And (Pos('FF B0', CommandHex) = 1) Then
    Result := Result + ' For MIFARE read, first load key (FF 82 ...) and authenticate (FF 86 ...). If this persists, the card may not be MIFARE Classic.';

  If (SW12 = $6300) And (Pos('FF D6', CommandHex) = 1) Then
    Result := Result + ' For MIFARE write, authenticate first and ensure the target block is writable with your key.';

  If (SW12 = $6982) And ((Pos('FF B0', CommandHex) = 1) Or (Pos('FF D6', CommandHex) = 1)) Then
    Result := Result + ' Run FF 82 (load key) and FF 86 (authenticate) before memory read/write.';

  If (SW12 = $9000) And (Pos('FF D6 00 07 10', CommandHex) = 1) Then
    Result := Result + ' Sector trailer block 07 was updated (keys/access bits changed). Keep the new keys documented.';
End;

Procedure TMainForm.FormActivate(Sender: TObject);
Begin
  If Not Initialized Then Begin
    Initialized := true;

    If Not (FPCSC.Valid) Then
      AddLogMemo('SCardEstablishContext failed.')
    Else Begin
      AddLogMemo('SCardEstablishContext succeeded.');
      FPCSC.OnReaderFound := @ReaderFound;
      FPCSC.OnReaderRemoved := @ReaderRemoved;
      FPCSC.OnCardStateChanged := @CardStateChanged;
      FPCSC.OnCardInserted := @CardInserted;
      FPCSC.OnCardRemoved := @CardRemoved;
      FPCSC.OnCardError := @CardError;

      FPCSC.Start;
    End;
  End;
End;

Procedure TMainForm.FormCreate(Sender: TObject);
Begin
  Caption := 'PC/SC Sample Application V1.3';
  Application.Title := Caption;
  Application.OnIdle := @ProcessEvents;
  LogMemo.Clear;
  Initialized := false;
  FPCSC := TPCSC.Create;

  CommandComboBox.Items.Clear;
  CommandComboBox.Items.Add('FF CA 00 00 00 (identify card: get UID)');
  CommandComboBox.Items.Add('FF CA 01 00 00 (identify card: get ATS historical bytes)');
  CommandComboBox.Items.Add('FF CA 02 00 00 (identify card: get ATQA/SAK if supported)');
  CommandComboBox.Items.Add('FF 82 00 00 06 FF FF FF FF FF FF (mifare: load default key into reader key slot 00)');
  CommandComboBox.Items.Add('FF 86 00 00 05 01 00 04 60 00 (mifare: authenticate block 04 with key A from slot 00)');
  CommandComboBox.Items.Add('FF B0 00 04 10 (mifare: read 16 bytes from block 04)');
  CommandComboBox.Items.Add('FF D6 00 04 10 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 (mifare: write 16 zero bytes to block 04)');
  CommandComboBox.Items.Add('FF 86 00 00 05 01 00 07 60 00 (mifare: authenticate sector trailer block 07 with key A from slot 00)');
  CommandComboBox.Items.Add('FF D6 00 07 10 A0 A1 A2 A3 A4 A5 FF 07 80 69 B0 B1 B2 B3 B4 B5 (mifare: set sector 1 keys in trailer block 07; use with care)');
  CommandComboBox.Text := CommandComboBox.Items[0];

{$IFDEF LINUX}
  CommandComboBox.Top := 40;
{$ENDIF}
{$IFDEF WINDOWS}
  CommandComboBox.Top := 43;
{$ENDIF}
End;

Procedure TMainForm.ConnectDirectButtonClick(Sender: TObject);
Var
  PCSCResult: DWORD;
  PCSCReader: TPCSCReader;
Begin
  Try
    If ReaderListBox.ItemIndex < 0 Then exit;
    PCSCReader := FPCSC.GetPCSCReader(ReaderListBox.Items[ReaderListBox.ItemIndex]);
    If PCSCReader = Nil Then exit;

    PCSCResult := PCSCReader.Connect(SCARD_SHARE_DIRECT);
    If PCSCResult = SCARD_S_SUCCESS Then Begin
      AddLogMemo('SCardConnect (direct) succeeded.');
      AddLogMemo('Hint: Direct mode is for reader control (escape/IOCTL), not normal card APDU commands.')
    End
    Else
      AddLogMemo(Format('SCardConnect (direct) failed with error code %s (%s)', [IntToHex(PCSCResult, 8), ErrorToString(PCSCResult)]));
  Finally
    UpdateButtons;
  End;
End;

Procedure TMainForm.FormDestroy(Sender: TObject);
Begin
  FPCSC.Free;
End;

Procedure TMainForm.MenuItem1Click(Sender: TObject);
Begin
  LogMemo.Clear;
End;

Procedure TMainForm.CardStateChanged(Sender: TObject; ReaderName: String);
Var
  CardState: TCardState;
  PCSCReader: TPCSCReader;
  sState: String;
Begin
  PCSCReader := TPCSC(Sender).GetPCSCReader(ReaderName);
  If PCSCReader = Nil Then exit;

  CardState := PCSCReader.CardState;
  ReaderName := PCSCReader.ReaderName;
  Case CardState Of
    csExclusive: sState := 'exclusive';
    csShared: sState := 'shared';
    csAvailable: sState := 'available';
    csBadCard: sState := 'bad card';
    csNoCard: sState := 'no card';
  Else
    sState := 'unknown';
  End;
  AddLogMemo('Card State changed in ' + ReaderName + ' to ' + sState);
  ReaderListBox.Repaint;
  UpdateButtons;
End;

Procedure TMainForm.UpdatePCSCReaderList;
Var
  i, j: Integer;
  Found: boolean;
  ReaderName: String;
Begin
  For i := ReaderListBox.Items.Count - 1 Downto 0 Do Begin
    ReaderName := ReaderListBox.Items[i];
    Found := false;
    For j := 0 To FPCSC.ReaderList.Count - 1 Do Begin
      If ReaderName = FPCSC.ReaderList[j] Then Begin
        Found := true;
        break;
      End;
    End;
    If Not Found Then ReaderListBox.Items.Delete(i);
  End;

  For i := 0 To FPCSC.ReaderList.Count - 1 Do Begin
    Found := false;
    For j := 0 To ReaderListBox.Items.Count - 1 Do Begin
      ReaderName := ReaderListBox.Items[j];
      If ReaderName = FPCSC.ReaderList[i] Then Begin
        Found := true;
        break;
      End;
    End;
    If Not Found Then Begin
      ReaderName := FPCSC.ReaderList[i];
      ReaderListBox.Items.Add(ReaderName);
    End;
  End;
End;

Procedure TMainForm.ReaderListBoxDrawItem(Control: TWinControl; Index: Integer; RC: TRect; State: TOwnerDrawState);
Var
  sState: String;
  PCSCReader: TPCSCReader;
Begin
  With TListBox(Control).Canvas Do Begin
    PCSCReader := FPCSC.GetPCSCReader(TListBox(Control).Items[Index]);
    If PCSCReader = Nil Then exit;

    If odSelected In State Then Begin
      Brush.Color := $00CEFF;
      Font.Color := clBlack;
    End
    Else Begin
      Brush.Color := clWhite;
      Font.Color := clBlack;
    End;
    Pen.Color := Brush.Color;

    Rectangle(RC.Left, RC.Top, RC.Right, RC.Bottom);
    TextOut(RC.Left + 4, RC.Top + 2, TListBox(Control).Items[Index]);

    If PCSCReader <> Nil Then Begin
      Case PCSCReader.CardState Of
        csExclusive: Begin
            Font.Color := clGreen;
            sState := 'Card state = exclusive, ATR = ' + PCSCReader.ATRasString;
          End;
        csShared: Begin
            Font.Color := clGreen;
            sState := 'Card state = shared, ATR = ' + PCSCReader.ATRasString;
          End;
        csAvailable: Begin
            Font.Color := clGreen;
            sState := 'Card state = available, ATR = ' + PCSCReader.ATRasString;
          End;
        csBadCard: Begin
            Font.Color := $808080;
            sState := 'Card state = bad card';
          End;
        csNoCard: Begin
            Font.Color := clGray;
            sState := 'Card state = no card';
          End;
      Else Begin
          Font.Color := clGray;
          sState := 'Card state = unknown';
        End;
      End;
      TextOut(RC.Left + 20, RC.Top + 15, sState);
    End;
  End;
End;

Procedure TMainForm.UpdateButtons;
Var
  PCSCReader: TPCSCReader;
Begin
  ConnectSharedButton.Enabled := false;
  ConnectExclusiveButton.Enabled := false;
  ConnectDirectButton.Enabled := false;
  DisconnectButton.Enabled := false;
  CommandComboBox.Enabled := false;
  TransmitButton.Enabled := false;

  If ReaderListBox.ItemIndex < 0 Then exit;
  PCSCReader := FPCSC.GetPCSCReader(ReaderListBox.Items[ReaderListBox.ItemIndex]);
  If PCSCReader = Nil Then exit;

  If (PCSCReader.CardState = csAvailable) Or (PCSCReader.CardState = csExclusive) Or (PCSCReader.CardState = csShared) Then Begin
    If PCSCReader.CardHandle = PCSC_NO_HANDLE Then Begin
      ConnectSharedButton.Enabled := true;
      ConnectExclusiveButton.Enabled := true;
      ConnectDirectButton.Enabled := true;
    End;
  End;
  If PCSCReader.CardHandle <> PCSC_NO_HANDLE Then Begin
    DisconnectButton.Enabled := true;
    CommandComboBox.Enabled := true;
    TransmitButton.Enabled := length(trim(CommandComboBox.Text)) > 1;
  End;
End;

Procedure TMainForm.ConnectSharedButtonClick(Sender: TObject);
Var
  PCSCResult: DWORD;
  PCSCReader: TPCSCReader;
Begin
  Try
    If ReaderListBox.ItemIndex < 0 Then exit;
    PCSCReader := FPCSC.GetPCSCReader(ReaderListBox.Items[ReaderListBox.ItemIndex]);
    If PCSCReader = Nil Then exit;

    PCSCResult := PCSCReader.Connect(SCARD_SHARE_SHARED);
    If PCSCResult = SCARD_S_SUCCESS Then
      AddLogMemo('SCardConnect (shared) succeeded.')
    Else
      AddLogMemo(Format('SCardConnect (shared) failed with error code %s (%s)', [IntToHex(PCSCResult, 8), ErrorToString(PCSCResult)]));
  Finally
    UpdateButtons;
  End;
End;

Procedure TMainForm.ConnectExclusiveButtonClick(Sender: TObject);
Var
  PCSCResult: DWORD;
  PCSCReader: TPCSCReader;
Begin
  Try
    If ReaderListBox.ItemIndex < 0 Then exit;
    PCSCReader := FPCSC.GetPCSCReader(ReaderListBox.Items[ReaderListBox.ItemIndex]);
    If PCSCReader = Nil Then exit;

    PCSCResult := PCSCReader.Connect(SCARD_SHARE_EXCLUSIVE);
    If PCSCResult = SCARD_S_SUCCESS Then
      AddLogMemo('SCardConnect (exclusive) succeeded.')
    Else
      AddLogMemo(Format('SCardConnect (exclusive) failed with error code %s (%s)', [IntToHex(PCSCResult, 8), ErrorToString(PCSCResult)]));
  Finally
    UpdateButtons;
  End;
End;

Procedure TMainForm.DisconnectButtonClick(Sender: TObject);
Var
  PCSCResult: DWORD;
  PCSCReader: TPCSCReader;
Begin
  Try
    If ReaderListBox.ItemIndex < 0 Then exit;
    PCSCReader := FPCSC.GetPCSCReader(ReaderListBox.Items[ReaderListBox.ItemIndex]);
    If PCSCReader = Nil Then exit;

    PCSCResult := PCSCReader.Disconnect();
    If PCSCResult = SCARD_S_SUCCESS Then
      AddLogMemo('SCardDisconnect succeeded.')
    Else
      AddLogMemo(Format('SCardDisconnect failed with error code %s (%s)', [IntToHex(PCSCResult, 8), ErrorToString(PCSCResult)]));
  Finally
    UpdateButtons;
  End;
End;

Procedure TMainForm.TransmitButtonClick(Sender: TObject);
Var
  PCSCResult: DWORD;
  PCSCReader: TPCSCReader;
  DataIn: TBytes;
  DataOut: TBytes;
  SW12: Word;
  CleanText: String;
  NormalizedHex: String;
  HintText: String;
Begin
  Try
    If ReaderListBox.ItemIndex < 0 Then exit;
    PCSCReader := FPCSC.GetPCSCReader(ReaderListBox.Items[ReaderListBox.ItemIndex]);
    If PCSCReader = Nil Then exit;

    CleanText := CleanCommandString(CommandComboBox.Text);
    If Not TryNormalizeCommandHex(CleanText, NormalizedHex) Then Begin
      AddLogMemo('Command is empty or invalid.');
      AddLogMemo('Use hex bytes like: FF CA 00 00 00');
      Exit;
    End;

    If CommandComboBox.Items.IndexOf(Trim(CommandComboBox.Text)) < 0 Then
      CommandComboBox.Items.Insert(0, Trim(CommandComboBox.Text));
    DataIn := HexStringToBuffer(NormalizedHex);

    If PCSCReader.Protocol = prRaw Then Begin
      AddLogMemo('Sending Escape command to reader: ' + BufferToHexString(DataIn));
      PCSCResult := PCSCReader.IOCTL(IOCTL_CCID_ESCAPE, DataIn, DataOut);
      If PCSCResult = SCARD_S_SUCCESS Then Begin
        AddLogMemo('SCardControl succeeded.');
        If length(DataOut) > 0 Then AddLogMemo('Response data: ' + BufferToHexString(DataOut));
      End
      Else Begin
        AddLogMemo(Format('SCardControl failed with error code %s (%s)', [IntToHex(PCSCResult, 8), ErrorToString(PCSCResult)]));
        If PCSCResult = SCARD_E_NOT_TRANSACTED Then Begin
          AddLogMemo('Hint: You are connected in direct/raw mode.');
          AddLogMemo('For card APDU commands like FF CA 00 00 00, disconnect and use Connect shared or Connect exclusive.');
        End;
      End;
    End
    Else Begin
      AddLogMemo('Sending APDU to card: ' + BufferToHexString(DataIn));
      PCSCResult := PCSCReader.TransmitSW(DataIn, DataOut, SW12);
      If PCSCResult = SCARD_S_SUCCESS Then Begin
        AddLogMemo('SCardTransmit succeeded.');
        AddLogMemo('Card response status word: ' + IntToHex(SW12, 4) + ' (' + CardErrorToString(SW12) + ')');
        HintText := CardStatusHint(SW12, NormalizedHex);
        If length(HintText) > 0 Then
          AddLogMemo('Hint: ' + HintText);
        If length(DataOut) > 0 Then AddLogMemo('Card response data: ' + BufferToHexString(DataOut));
      End
      Else
        AddLogMemo(Format('SCardTransmit failed with error code %s (%s)', [IntToHex(PCSCResult, 8), ErrorToString(PCSCResult)]));
    End;
  Finally
    UpdateButtons;
  End;
End;

Function TMainForm.ErrorToString(ErrorCode: DWORD): String;
Begin
  If ErrorCode >= $80000000 Then
    result := PCSCErrorToString(ErrorCode)
  Else
    result := WindowsErrorToString(ErrorCode);
End;

Procedure TMainForm.ReaderListBoxClick(Sender: TObject);
Begin
  UpdateButtons;
End;

Procedure TMainForm.CommandComboBoxChange(Sender: TObject);
Var
  i: Integer;
  s: String;
  aChanged: boolean;
  SelStart: Integer;
  CleanText: String;
  NormalizedHex: String;
Const
  AllowedChars = ['A'..'F', '0'..'9', ' '];
Begin
  If Pos('(', CommandComboBox.Text) > 0 Then Begin
    CleanText := CleanCommandString(CommandComboBox.Text);
    TransmitButton.Enabled := TryNormalizeCommandHex(CleanText, NormalizedHex);
    Exit;
  End;

  aChanged := false;
  SelStart := CommandComboBox.SelStart;
  s := '';
  For i := 1 To length(CommandComboBox.Text) Do Begin
    If UpCase(CommandComboBox.Text[i]) In AllowedChars Then Begin
      s := s + UpCase(CommandComboBox.Text[i]);
    End
    Else
      aChanged := true;
  End;
  If aChanged Then Begin
    CommandComboBox.Text := s;
    CommandComboBox.SelStart := SelStart;
    CommandComboBox.SelLength := 0;
  End;
  TransmitButton.Enabled := TryNormalizeCommandHex(CommandComboBox.Text, NormalizedHex);
End;

Procedure TMainForm.CommandComboBoxEnter(Sender: TObject);
Begin
  CommandComboBox.SelStart := length(TEdit(Sender).Text);
  CommandComboBox.SelLength := 0;
End;

Procedure TMainForm.CommandComboBoxExit(Sender: TObject);
Var
  CleanText: String;
  NormalizedHex: String;
Begin
  If Pos('(', CommandComboBox.Text) > 0 Then Exit;

  CleanText := CleanCommandString(CommandComboBox.Text);
  If Not TryNormalizeCommandHex(CleanText, NormalizedHex) Then Exit;
  CommandComboBox.Text := NormalizedHex;
End;

Procedure TMainForm.CommandComboBoxKeyPress(Sender: TObject; Var Key: Char);
Begin
  If ((Key >= '0') And (Key <= '9')) Or (Key <= #32) Or ((UpCase(Key) >= 'A') And (UpCase(Key) <= 'F')) Then
    Key := UpCase(Key)
  Else
    Key := #0;
End;

Procedure TMainForm.CommandComboBoxKeyDown(Sender: TObject; Var Key: Word; Shift: TShiftState);
Begin
  If Key = VK_RETURN Then Begin
    If TransmitButton.Enabled Then TransmitButton.Click;
  End;
End;

Procedure TMainForm.ReaderFound(Sender: TObject; ReaderName: String);
Begin
  AddLogMemo('New reader found: ' + ReaderName);
  UpdatePCSCReaderList;
  ReaderListBox.Repaint;
  UpdateButtons;
End;

Procedure TMainForm.ReaderRemoved(Sender: TObject; ReaderName: String);
Begin
  AddLogMemo('Reader removed: ' + ReaderName);
  UpdatePCSCReaderList;
  ReaderListBox.Repaint;
  UpdateButtons;
End;

Procedure TMainForm.CardInserted(Sender: TObject; ReaderName: String; ATR: TBytes);
Var
  PCSCReader: TPCSCReader;
Begin
  AddLogMemo('Card inserted in ' + ReaderName);
  PCSCReader := TPCSCReader(FPCSC.GetPCSCReader(ReaderName));
  If PCSCReader <> Nil Then Begin
    If length(ATR) > 0 Then AddLogMemo('ATR = ' + BufferToHexString(ATR));
  End;
  ReaderListBox.Repaint;
  UpdateButtons;
End;

Procedure TMainForm.CardRemoved(Sender: TObject; ReaderName: String);
Begin
  AddLogMemo('Card removed from ' + ReaderName);
  ReaderListBox.Repaint;
  UpdateButtons;
End;

Procedure TMainForm.CardError(Sender: TObject; ReaderName: String);
Begin
  AddLogMemo('Card error in ' + ReaderName);
  ReaderListBox.Repaint;
  UpdateButtons;
End;

Procedure TMainForm.ProcessEvents(Sender: TObject; Var Done: boolean);
Begin
  If FPCSC.Valid Then FPCSC.ProcessEvent;
  Done := true;
End;

Procedure TMainForm.AddLogMemo(Msg: String);
Begin
  LogMemo.Lines.Add(Msg);
End;

End.

