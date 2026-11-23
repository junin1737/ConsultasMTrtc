unit UConsultaManager;

interface

uses
  Vcl.Forms;

type
  TConsultaFecharEvent = procedure(AForm: TForm) of object;

procedure RegistrarFecharConsulta(AHandler: TConsultaFecharEvent);
procedure ExecutarFecharConsulta(AForm: TForm);

implementation

var
  GFecharHandler: TConsultaFecharEvent = nil;

procedure RegistrarFecharConsulta(AHandler: TConsultaFecharEvent);
begin
  GFecharHandler := AHandler;
end;

procedure ExecutarFecharConsulta(AForm: TForm);
begin
  if not Assigned(AForm) then
    Exit;

  if Assigned(GFecharHandler) then
    GFecharHandler(AForm)
  else
    AForm.Free;
end;

end.
