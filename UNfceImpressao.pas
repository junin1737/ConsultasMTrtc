unit UNfceImpressao;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao, UMapaNfce;

type
  TNfceCabecalho = record
    Numero: string;
    Emissao: string;
    Saida: string;
    Cliente: string;
    ValorTotal: string;
    ChaveNfe: string;
    Observacao: string;
  end;

  TNfceImpressao = class
  public
    class function CarregarCabecalho(AEmpCodigo, AVenNumero, ATerNumero,
      ANfceNumero: Integer): TNfceCabecalho;
    class procedure Visualizar(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero: Integer);
    class procedure ImprimirFisico(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero: Integer);
  end;

implementation

uses
  Data.DB, Vcl.Forms, Vcl.Dialogs, Winapi.Windows, Winapi.ShellAPI,
  UFormatacaoMoeda, UNfceDanfeVisualizacao, UNfceRelatorioFr3;

class function TNfceImpressao.CarregarCabecalho(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer): TNfceCabecalho;
var
  Q: TFDQuery;
begin
  FillChar(Result, SizeOf(Result), 0);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text := TMapaNfce.MontarSQLCabecalho;
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('VENNUMERO').AsInteger := AVenNumero;
    Q.ParamByName('TERNUMERO').AsInteger := ATerNumero;
    Q.ParamByName('VENRNFCENUMEROFISCAL').AsInteger := ANfceNumero;
    Q.Open;
    if Q.IsEmpty then
      Exit;

    Result.Numero := Q.FieldByName('VENRNFCENUMEROFISCAL').AsString;
    if not Q.FieldByName('VENDTEMISSAO').IsNull then
      Result.Emissao := FormatDateTime('dd/mm/yyyy', Q.FieldByName('VENDTEMISSAO').AsDateTime);
    if not Q.FieldByName('VENRNFCEDTTRANSMISSAO').IsNull then
      Result.Saida := FormatDateTime('dd/mm/yyyy', Q.FieldByName('VENRNFCEDTTRANSMISSAO').AsDateTime);
    Result.Cliente := Trim(Q.FieldByName('NOME_CLIENTE').AsString);
    if Result.Cliente = '' then
      Result.Cliente := NFCe_NOME_CLIENTE_FINAL;
    Result.ValorTotal := FormatarMoedaBRL(Q.FieldByName('VENVALORLIQUIDO').AsFloat);
    Result.ChaveNfe := Trim(Q.FieldByName('VENRNFCECHAVE').AsString);
    Result.Observacao := Trim(Q.FieldByName('VENRNFCEADICIONAIS').AsString);
  finally
    Q.Free;
  end;
end;

class procedure TNfceImpressao.Visualizar(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer);
var
  Cab: TNfceCabecalho;
  Xml: string;
begin
  if not dmConexao.Conectado then
    raise Exception.Create('Banco de dados nao conectado.');

  Cab := CarregarCabecalho(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  if Cab.Numero = '' then
    raise Exception.Create('NFC-e nao encontrada para impressao.');

  Xml := TNfceDanfeVisualizacao.ObterXmlNfce(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  if Xml <> '' then
  begin
    TNfceDanfeVisualizacao.VisualizarDanfe(Xml, 'DANFE NFC-e ' + Cab.Numero);
    Exit;
  end;

  TNfceRelatorioFr3.Visualizar(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
end;

class procedure TNfceImpressao.ImprimirFisico(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer);
var
  Cab: TNfceCabecalho;
  Xml: string;
begin
  if not dmConexao.Conectado then
    raise Exception.Create('Banco de dados nao conectado.');

  Cab := CarregarCabecalho(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  if Cab.Numero = '' then
    raise Exception.Create('NFC-e nao encontrada para impressao.');

  Xml := TNfceDanfeVisualizacao.ObterXmlNfce(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  if Xml <> '' then
  begin
    TNfceDanfeVisualizacao.ImprimirDanfe(Xml, 'DANFE NFC-e ' + Cab.Numero);
    Exit;
  end;

  TNfceRelatorioFr3.Imprimir(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
end;

end.
