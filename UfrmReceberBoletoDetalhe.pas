unit UfrmReceberBoletoDetalhe;

interface

uses
  UMapaReceber, UBoletoImpressao;

type
  TfrmReceberBoletoDetalhe = class
  public
    class procedure Abrir(AEmpCodigo, ACrNumero: Integer; const ADocumento, ACliente: string;
      const ATitulo: string = '');
  end;

implementation

uses
  Vcl.Dialogs, System.SysUtils;

class procedure TfrmReceberBoletoDetalhe.Abrir(AEmpCodigo, ACrNumero: Integer;
  const ADocumento, ACliente: string; const ATitulo: string);
var
  Titulo: string;
begin
  if not TMapaReceber.TemBoleto(AEmpCodigo, ACrNumero) then
  begin
    MessageDlg('Nenhum boleto encontrado para este titulo.', mtInformation, [mbOK], 0);
    Exit;
  end;

  if ATitulo <> '' then
    Titulo := ATitulo
  else if ADocumento <> '' then
    Titulo := 'Boleto - ' + ADocumento
  else
    Titulo := 'Visualizar boleto';

  try
    TBoletoImpressao.VisualizarTitulo(AEmpCodigo, ACrNumero, Titulo);
  except
    on E: Exception do
      MessageDlg('Erro ao gerar boleto:' + sLineBreak + sLineBreak + E.Message,
        mtError, [mbOK], 0);
  end;
end;

end.
