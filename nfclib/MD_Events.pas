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

Unit MD_Events;
{$IFDEF FPC}
{$MODE objfpc}{$H+}
{$ELSE}
{$DEFINE WINDOWS}
{$ENDIF}

Interface

Uses
  SysUtils, Classes, MD_Tools;

Type
  TEventType = (evNone, evCardInsert, evCardRemove, evCardError, evReaderFound, evReaderRemoved);

  TPCSCCardInsertProc = Procedure(ReaderName: String; ATR: String) Of Object;
  TPCSCCardRemoveProc = Procedure(ReaderName: String) Of Object;
  TPCSCCardErrorProc = Procedure(ReaderName: String) Of Object;
  TPCSCReaderFoundProc = Procedure(ReaderName: String) Of Object;
  TPCSCReaderRemovedProc = Procedure(ReaderName: String) Of Object;

  TPCSCEvent = Class
  protected
    FEventType: TEventType;
    FReaderName: String;
    FATR: String;
  public
    Constructor Create;
    Destructor Destroy; override;

    Property EventType: TEventType read FEventType;
    Property ReaderName: String read FReaderName;
    Property ATR: String read FATR;
  End;

  TPCSCCardInsertEvent = Class(TPCSCEvent)
  public
    Constructor Create(AReaderName: String; AATR: String);
    Destructor Destroy; override;
  End;

  TPCSCCardRemoveEvent = Class(TPCSCEvent)
  public
    Constructor Create(AReaderName: String);
    Destructor Destroy; override;
  End;

  TPCSCCardErrorEvent = Class(TPCSCEvent)
  public
    Constructor Create(AReaderName: String);
    Destructor Destroy; override;
  End;

  TPCSCReaderFoundEvent = Class(TPCSCEvent)
  public
    Constructor Create(AReaderName: String);
    Destructor Destroy; override;
  End;

  TPCSCReaderRemovedEvent = Class(TPCSCEvent)
  public
    Constructor Create(AReaderName: String);
    Destructor Destroy; override;
  End;

  TPCSCEventList = Class
  private
    FEventList: TList;
    FOnCardInsert: TPCSCCardInsertProc;
    FOnCardRemove: TPCSCCardRemoveProc;
    FOnCardError: TPCSCCardErrorProc;
    FOnReaderFound: TPCSCReaderFoundProc;
    FOnReaderRemoved: TPCSCReaderRemovedProc;
    FProcessingEvent: boolean;
    Function ExistsCardInsertEvent(ReaderName: String): boolean;
    Function ExistsCardRemoveEvent(ReaderName: String): boolean;
    Function ExistsCardErrorEvent(ReaderName: String): boolean;
    Function ExistsReaderFoundEvent(ReaderName: String): boolean;
    Function ExistsReaderRemovedEvent(ReaderName: String): boolean;
  protected
    Procedure CardInsert(ReaderName: String; ATR: String);
    Procedure CardRemove(ReaderName: String);
    Procedure CardError(ReaderName: String);
    Procedure ReaderFound(ReaderName: String);
    Procedure ReaderRemoved(ReaderName: String);
  public
    Constructor Create;
    Destructor Destroy; override;
    Procedure ProcessEvent;
    Procedure ProcessAllEvents;

    Procedure CardInsertedAsync(Sender: TObject; ReaderName: String; ATR: TBytes);
    Procedure CardRemovedAsync(Sender: TObject; ReaderName: String);
    Procedure CardErrorAsync(Sender: TObject; ReaderName: String);
    Procedure ReaderFoundAsync(Sender: TObject; ReaderName: String);
    Procedure ReaderRemovedAsync(Sender: TObject; ReaderName: String);

    Property OnCardInsert: TPCSCCardInsertProc read FOnCardInsert write FOnCardInsert;
    Property OnCardRemove: TPCSCCardRemoveProc read FOnCardRemove write FOnCardRemove;
    Property OnCardError: TPCSCCardErrorProc read FOnCardError write FOnCardError;
    Property OnReaderFound: TPCSCReaderFoundProc read FOnReaderFound write FOnReaderFound;
    Property OnReaderRemoved: TPCSCReaderRemovedProc read FOnReaderRemoved write FOnReaderRemoved;
  End;

Implementation

Constructor TPCSCEvent.Create;
Begin
  Inherited Create;
  FEventType := evNone;
  FReaderName := '';
End;

Destructor TPCSCEvent.Destroy;
Begin
  Inherited Destroy;
End;

Constructor TPCSCEventList.Create;
Begin
  Inherited Create;
  FEventList := TList.Create;
  FOnCardInsert := Nil;
  FOnCardRemove := Nil;
  FOnCardError := Nil;
  FProcessingEvent := false;
  FEventList.Clear;
End;

Destructor TPCSCEventList.Destroy;
Var
  i: integer;
Begin
  For i := 0 To FEventList.Count - 1 Do
    TPCSCEvent(FEventList[i]).Free;
  FEventList.Free;
  Inherited Destroy;
End;

Procedure TPCSCEventList.CardInsert(ReaderName: String; ATR: String);
Begin
  If Assigned(FOnCardInsert) Then FOnCardInsert(ReaderName, ATR);
End;

Procedure TPCSCEventList.CardRemove(ReaderName: String);
Begin
  If Assigned(FOnCardRemove) Then FOnCardRemove(ReaderName);
End;

Procedure TPCSCEventList.CardError(ReaderName: String);
Begin
  If Assigned(FOnCardError) Then FOnCardError(ReaderName);
End;

Procedure TPCSCEventList.ReaderFound(ReaderName: String);
Begin
  If Assigned(FOnReaderFound) Then FOnReaderFound(ReaderName);
End;

Procedure TPCSCEventList.ReaderRemoved(ReaderName: String);
Begin
  If Assigned(FOnReaderRemoved) Then FOnReaderRemoved(ReaderName);
End;

Procedure TPCSCEventList.ProcessAllEvents;
Begin
  While FEventList.Count > 0 Do
    ProcessEvent;
End;

Procedure TPCSCEventList.ProcessEvent;
Var
  Event: TPCSCEvent;
Begin
  If FEventList.Count = 0 Then exit;
  Try
    Event := TPCSCEvent(FEventList[0]);
    FEventList.Delete(0);
    If Event = Nil Then exit;
    Try
      Case Event.EventType Of
        evCardInsert: Begin
            If Not ExistsCardInsertEvent(Event.ReaderName) And Not FProcessingEvent Then Begin
              FProcessingEvent := true;
              Try
                CardInsert(Event.ReaderName, Event.ATR);
              Finally
                FProcessingEvent := false;
              End;
            End;
          End;
        evCardRemove: Begin
            If Not ExistsCardRemoveEvent(Event.ReaderName) Then CardRemove(Event.ReaderName);
          End;
        evCardError: Begin
            If Not ExistsCardErrorEvent(Event.ReaderName) And Not FProcessingEvent Then Begin
              FProcessingEvent := true;
              Try
                CardError(Event.ReaderName);
              Finally
                FProcessingEvent := false;
              End;
            End;
          End;
        evReaderFound: Begin
            If Not ExistsReaderFoundEvent(Event.ReaderName) And Not FProcessingEvent Then Begin
              FProcessingEvent := true;
              Try
                ReaderFound(Event.ReaderName);
              Finally
                FProcessingEvent := false;
              End;
            End;
          End;
        evReaderRemoved: Begin
            If Not ExistsReaderRemovedEvent(Event.ReaderName) And Not FProcessingEvent Then Begin
              FProcessingEvent := true;
              Try
                ReaderRemoved(Event.ReaderName);
              Finally
                FProcessingEvent := false;
              End;
            End;
          End;
      Else Begin
        End;
      End;
    Finally
      If Event <> Nil Then Event.Free;
    End;
  Finally
  End;
End;

Procedure TPCSCEventList.CardInsertedAsync(Sender: TObject; ReaderName: String; ATR: TBytes);
Begin
  FEventList.Add(TPCSCCardInsertEvent.Create(ReaderName, BufferToHexString(ATR)));
End;

Procedure TPCSCEventList.CardRemovedAsync(Sender: TObject; ReaderName: String);
Begin
  FEventList.Add(TPCSCCardRemoveEvent.Create(ReaderName));
End;

Procedure TPCSCEventList.CardErrorAsync(Sender: TObject; ReaderName: String);
Begin
  FEventList.Add(TPCSCCardErrorEvent.Create(ReaderName));
End;

Procedure TPCSCEventList.ReaderFoundAsync(Sender: TObject; ReaderName: String);
Begin
  FEventList.Add(TPCSCReaderFoundEvent.Create(ReaderName));
End;

Procedure TPCSCEventList.ReaderRemovedAsync(Sender: TObject; ReaderName: String);
Begin
  FEventList.Add(TPCSCReaderRemovedEvent.Create(ReaderName));
End;

Function TPCSCEventList.ExistsCardInsertEvent(ReaderName: String): boolean;
Var
  i: integer;
  Event: TPCSCEvent;
Begin
  result := false;
  For i := 0 To FEventList.Count - 1 Do Begin
    Event := TPCSCEvent(FEventList[i]);
    If Event = Nil Then Begin
      FEventList.Delete(i);
      exit;
    End;
    If (Event.EventType = evCardInsert) Then Begin
      If Event.ReaderName = ReaderName Then Begin
        result := true;
        exit;
      End;
    End;
  End;
End;

Function TPCSCEventList.ExistsCardRemoveEvent(ReaderName: String): boolean;
Var
  i: integer;
  Event: TPCSCEvent;
Begin
  result := false;
  For i := 0 To FEventList.Count - 1 Do Begin
    Event := TPCSCEvent(FEventList[i]);
    If Event = Nil Then Begin
      FEventList.Delete(i);
      exit;
    End;
    If (Event.EventType = evCardRemove) Then Begin
      If Event.ReaderName = ReaderName Then Begin
        result := true;
        exit;
      End;
    End;
  End;
End;

Function TPCSCEventList.ExistsCardErrorEvent(ReaderName: String): boolean;
Var
  i: integer;
  Event: TPCSCEvent;
Begin
  result := false;
  For i := 0 To FEventList.Count - 1 Do Begin
    Event := TPCSCEvent(FEventList[i]);
    If Event = Nil Then Begin
      FEventList.Delete(i);
      exit;
    End;
    If (Event.EventType = evCardError) Then Begin
      If Event.ReaderName = ReaderName Then Begin
        result := true;
        exit;
      End;
    End;
  End;
End;

Function TPCSCEventList.ExistsReaderFoundEvent(ReaderName: String): boolean;
Var
  i: integer;
  Event: TPCSCEvent;
Begin
  result := false;
  For i := 0 To FEventList.Count - 1 Do Begin
    Event := TPCSCEvent(FEventList[i]);
    If Event = Nil Then Begin
      FEventList.Delete(i);
      exit;
    End;
    If (Event.EventType = evReaderFound) Then Begin
      If Event.ReaderName = ReaderName Then Begin
        result := true;
        exit;
      End;
    End;
  End;
End;

Function TPCSCEventList.ExistsReaderRemovedEvent(ReaderName: String): boolean;
Var
  i: integer;
  Event: TPCSCEvent;
Begin
  result := false;
  For i := 0 To FEventList.Count - 1 Do Begin
    Event := TPCSCEvent(FEventList[i]);
    If Event = Nil Then Begin
      FEventList.Delete(i);
      exit;
    End;
    If (Event.EventType = evReaderRemoved) Then Begin
      If Event.ReaderName = ReaderName Then Begin
        result := true;
        exit;
      End;
    End;
  End;
End;

Constructor TPCSCCardInsertEvent.Create(AReaderName: String; AATR: String);
Begin
  Inherited Create;
  FEventType := evCardInsert;
  FReaderName := AReaderName;
  FATR := AATR;
End;

Destructor TPCSCCardInsertEvent.Destroy;
Begin
  Inherited Destroy;
End;

Constructor TPCSCCardRemoveEvent.Create(AReaderName: String);
Begin
  Inherited Create;
  FEventType := evCardRemove;
  FReaderName := AReaderName;
End;

Destructor TPCSCCardRemoveEvent.Destroy;
Begin
  Inherited Destroy;
End;

Constructor TPCSCCardErrorEvent.Create(AReaderName: String);
Begin
  Inherited Create;
  FEventType := evCardError;
  FReaderName := AReaderName;
End;

Destructor TPCSCCardErrorEvent.Destroy;
Begin
  Inherited Destroy;
End;

Constructor TPCSCReaderFoundEvent.Create(AReaderName: String);
Begin
  Inherited Create;
  FEventType := evReaderFound;
  FReaderName := AReaderName;
End;

Destructor TPCSCReaderFoundEvent.Destroy;
Begin
  Inherited Destroy;
End;

Constructor TPCSCReaderRemovedEvent.Create(AReaderName: String);
Begin
  Inherited Create;
  FEventType := evReaderRemoved;
  FReaderName := AReaderName;
End;

Destructor TPCSCReaderRemovedEvent.Destroy;
Begin
  Inherited Destroy;
End;

End.

