unit UNotaFiscalImpressao;



interface



uses

  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao, UMapaNotaFiscal;



type

  TNotaFiscalCabecalho = record

    Numero: string;

    Emissao: string;

    Saida: string;

    Cliente: string;

    ValorTotal: string;

    ChaveNfe: string;

    Observacao: string;

  end;



  TNotaFiscalImpressao = class

  public

    class function CarregarCabecalho(AEmpCodigo, ANfContador: Integer): TNotaFiscalCabecalho;

    class procedure Visualizar(AEmpCodigo, ANfContador: Integer);

    class procedure ImprimirFisico(AEmpCodigo, ANfContador: Integer);

  end;



implementation



uses

  Data.DB, Vcl.Forms, Vcl.Graphics, Vcl.Printers, Vcl.Dialogs,

  UFormatacaoMoeda, UImpressaoUtil, UDavRelatorioImpressao,

  UNFeDanfeVisualizacao;



class function TNotaFiscalImpressao.CarregarCabecalho(AEmpCodigo,

  ANfContador: Integer): TNotaFiscalCabecalho;

var

  Q: TFDQuery;

begin

  FillChar(Result, SizeOf(Result), 0);

  Q := TFDQuery.Create(nil);

  try

    Q.Connection := dmConexao.FDConnection1;

    Q.SQL.Text :=

      'SELECT N.NFNUMEROFISCAL, N.NFDTEMISSAO, N.NFDTSAIDA, N.NFTOTALNOTA, ' +

      'N.NFADCIONAIS, P.PESNOME, NFEN.NFNFECHAVE ' +

      'FROM NOTAFISCAL N ' +

      'LEFT JOIN PESSOA P ON P.PESCODIGO = N.PESCODIGO ' +

      'LEFT JOIN NOTAFISCALNFE NFEN ON NFEN.EMPCODIGO = N.EMPCODIGO AND NFEN.NFCONTADOR = N.NFCONTADOR ' +

      'WHERE N.EMPCODIGO = :EMPCODIGO AND N.NFCONTADOR = :NFCONTADOR';

    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;

    Q.ParamByName('NFCONTADOR').AsInteger := ANfContador;

    Q.Open;

    if Q.IsEmpty then

      Exit;



    Result.Numero := Q.FieldByName('NFNUMEROFISCAL').AsString;

    if not Q.FieldByName('NFDTEMISSAO').IsNull then

      Result.Emissao := FormatDateTime('dd/mm/yyyy', Q.FieldByName('NFDTEMISSAO').AsDateTime);

    if not Q.FieldByName('NFDTSAIDA').IsNull then

      Result.Saida := FormatDateTime('dd/mm/yyyy', Q.FieldByName('NFDTSAIDA').AsDateTime);

    Result.Cliente := Trim(Q.FieldByName('PESNOME').AsString);

    Result.ValorTotal := FormatarMoedaBRL(Q.FieldByName('NFTOTALNOTA').AsFloat);

    Result.ChaveNfe := Trim(Q.FieldByName('NFNFECHAVE').AsString);

    Result.Observacao := Trim(Q.FieldByName('NFADCIONAIS').AsString);

  finally

    Q.Free;

  end;

end;



class procedure TNotaFiscalImpressao.Visualizar(AEmpCodigo, ANfContador: Integer);

var

  Dados: TDavRelatorioDados;

  Cab: TNotaFiscalCabecalho;

  Xml: string;

begin

  if not dmConexao.Conectado then

    raise Exception.Create('Banco de dados nao conectado.');



  Cab := CarregarCabecalho(AEmpCodigo, ANfContador);

  if Cab.Numero = '' then

    raise Exception.Create('Nota fiscal nao encontrada para impressao.');



  Xml := TNFeDanfeVisualizacao.ObterXmlNotaFiscal(AEmpCodigo, ANfContador);

  if Xml <> '' then

  begin

    TNFeDanfeVisualizacao.VisualizarDanfe(Xml, 'DANFE - NF ' + Cab.Numero);

    Exit;

  end;



  Dados := TDavRelatorioImpressao.CarregarDadosNotaFiscal(AEmpCodigo, ANfContador);

  try

    TDavRelatorioImpressao.VisualizarPdf(Dados, 'NF ' + Cab.Numero);

  finally

    Dados.Free;

  end;

end;



class procedure TNotaFiscalImpressao.ImprimirFisico(AEmpCodigo, ANfContador: Integer);

var

  Dados: TDavRelatorioDados;

  Paginas: TListaPaginasImpressao;

  Dlg: TPrintDialog;

  Cab: TNotaFiscalCabecalho;

  Xml: string;

begin

  if not dmConexao.Conectado then

    raise Exception.Create('Banco de dados nao conectado.');



  if Printer.Printers.Count = 0 then

    raise Exception.Create('Nenhuma impressora instalada no Windows.');



  Cab := CarregarCabecalho(AEmpCodigo, ANfContador);

  if Cab.Numero = '' then

    raise Exception.Create('Nota fiscal nao encontrada para impressao.');



  Xml := TNFeDanfeVisualizacao.ObterXmlNotaFiscal(AEmpCodigo, ANfContador);

  if Xml <> '' then

  begin

    try

      TNFeDanfeVisualizacao.ImprimirDanfe(Xml, 'DANFE - NF ' + Cab.Numero);

      Exit;

    except

      on E: Exception do

        MessageDlg('DANFE oficial indisponivel (' + E.Message + ').' + sLineBreak +

          'Sera usado o resumo simplificado.', mtWarning, [mbOK], 0);

    end;

  end;



  Dados := TDavRelatorioImpressao.CarregarDadosNotaFiscal(AEmpCodigo, ANfContador);

  Paginas := nil;

  Dlg := TPrintDialog.Create(nil);

  try

    Paginas := TDavRelatorioImpressao.GerarPaginasPreview(Dados);

    if Paginas.Count = 0 then

      raise Exception.Create('Nao foi possivel gerar as paginas para impressao.');



    if not Dlg.Execute then

      Exit;



    TImpressaoPagina.ImprimirPaginasPreview(Paginas);

  finally

    Paginas.Free;

    Dlg.Free;

    Dados.Free;

  end;

end;



end.

