//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//  Modified by Corpsman & Claude Opus on 22.04.2026                            //
//  Adapted for Windows and Linux 64-bit compatibility.                         //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

Program PCSC_Sample;

{$MODE objfpc}{$H+}
{$DEFINE UseCThreads}

Uses
{$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
{$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Main, MD_Events, MD_PCSC, MD_PCSCDef, MD_PCSCRaw, MD_Tools;

{$R *.res}

Begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
End.

