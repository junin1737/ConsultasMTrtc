unit UConsultaDialogs;

interface

uses
  Vcl.Forms, System.Classes, System.UITypes;

procedure ErroConsulta(AOwner: TForm; const ATitulo, AMensagem: string);

implementation

uses
  Vcl.Dialogs, System.SysUtils, Winapi.Windows;

procedure ErroConsulta(AOwner: TForm; const ATitulo, AMensagem: string);
var
  Texto: string;
  Dono: HWND;
begin
  Texto := ATitulo;
  if AMensagem <> '' then
  begin
    if Texto <> '' then
      Texto := Texto + sLineBreak + sLineBreak;
    Texto := Texto + AMensagem;
  end;

  Dono := 0;
  if Assigned(AOwner) and AOwner.HandleAllocated then
    Dono := AOwner.Handle
  else if Assigned(Application.MainForm) and Application.MainForm.HandleAllocated then
    Dono := Application.MainForm.Handle;

  if Dono <> 0 then
    MessageBox(Dono, PChar(Texto), PChar(Application.Title), MB_OK or MB_ICONERROR)
  else
    MessageDlg(Texto, mtError, [mbOK], 0);
end;

end.
