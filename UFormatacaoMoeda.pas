unit UFormatacaoMoeda;

interface

uses
  System.SysUtils, System.DateUtils, Data.DB;

function FormatarMoedaBRL(AValor: Double): string;
function FormatarQuantidade(AValor: Double): string;
function VencimentoTrintaDiasApos(const AEmissao: TDateTime): string;
function ExtrairDigitos(const ATexto: string): string;
function FormatarCpfCnpj(const AValor: string): string;
function FormatarTelefone(const AValor: string): string;
function FormatarCep(const AValor: string): string;
function FormatarDocumentoConsulta(const ADocumento: string): string;
function FiltroSomenteDigitos(const ATexto: string): Boolean;
function SomarCampoTotal(ADataSet: TDataSet; const ANomeCampo: string): Double;
type
  TConsultaMoedaHandlers = class
  public
    class procedure MoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    class procedure AplicarMoedaCampo(AField: TField);
  end;

implementation

function LocalePtBR: TFormatSettings;
begin
  Result := TFormatSettings.Create;
  Result.DecimalSeparator := ',';
  Result.ThousandSeparator := '.';
end;

function FormatarMoedaBRL(AValor: Double): string;
begin
  Result := 'R$ ' + FormatFloat('#,##0.00', AValor, LocalePtBR);
end;

function FormatarQuantidade(AValor: Double): string;
begin
  Result := FormatFloat('#,##0.###', AValor, LocalePtBR);
end;

function VencimentoTrintaDiasApos(const AEmissao: TDateTime): string;
begin
  Result := FormatDateTime('dd/mm/yyyy', IncDay(AEmissao, 30));
end;

function ExtrairDigitos(const ATexto: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(ATexto) do
    if CharInSet(ATexto[I], ['0'..'9']) then
      Result := Result + ATexto[I];
end;

function FormatarCpfCnpj(const AValor: string): string;
var
  D: string;
begin
  D := ExtrairDigitos(AValor);
  if Length(D) = 11 then
    Exit(Copy(D, 1, 3) + '.' + Copy(D, 4, 3) + '.' + Copy(D, 7, 3) + '-' + Copy(D, 10, 2));
  if Length(D) = 14 then
    Exit(Copy(D, 1, 2) + '.' + Copy(D, 3, 3) + '.' + Copy(D, 6, 3) + '/' +
      Copy(D, 9, 4) + '-' + Copy(D, 13, 2));
  Result := Trim(AValor);
end;

function FormatarTelefone(const AValor: string): string;
var
  D: string;
begin
  D := ExtrairDigitos(AValor);
  if Length(D) = 10 then
    Exit('(' + Copy(D, 1, 2) + ') ' + Copy(D, 3, 4) + '-' + Copy(D, 7, 4));
  if Length(D) = 11 then
    Exit('(' + Copy(D, 1, 2) + ') ' + Copy(D, 3, 5) + '-' + Copy(D, 8, 4));
  Result := Trim(AValor);
end;

function FormatarCep(const AValor: string): string;
var
  D: string;
begin
  D := ExtrairDigitos(AValor);
  if Length(D) = 8 then
    Exit(Copy(D, 1, 5) + '-' + Copy(D, 6, 3));
  Result := Trim(AValor);
end;

function FormatarDocumentoConsulta(const ADocumento: string): string;
begin
  Result := StringReplace(Trim(ADocumento), '/', '-', [rfReplaceAll]);
end;

function SomarCampoTotal(ADataSet: TDataSet; const ANomeCampo: string): Double;
var
  Campo: TField;
begin
  Result := 0;
  if (ADataSet = nil) or (not ADataSet.Active) then
    Exit;
  Campo := ADataSet.FindField(ANomeCampo);
  if Campo = nil then
    Exit;
  ADataSet.First;
  while not ADataSet.Eof do
  begin
    if not Campo.IsNull then
      Result := Result + Campo.AsFloat;
    ADataSet.Next;
  end;
end;

function FiltroSomenteDigitos(const ATexto: string): Boolean;
var
  I: Integer;
begin
  Result := ATexto <> '';
  if not Result then
    Exit;
  for I := 1 to Length(ATexto) do
    if not CharInSet(ATexto[I], ['0'..'9']) then
      Exit(False);
end;

class procedure TConsultaMoedaHandlers.MoedaGetText(Sender: TField; var Text: string;
  DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatarMoedaBRL(Sender.AsFloat);
end;

class procedure TConsultaMoedaHandlers.AplicarMoedaCampo(AField: TField);
begin
  if AField <> nil then
    AField.OnGetText := MoedaGetText;
end;

end.
