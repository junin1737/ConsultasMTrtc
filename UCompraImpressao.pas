unit UCompraImpressao;



interface



uses

  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao, UMapaCompra;



type

  TCompraCabecalho = record

    Numero: string;

    Serie: string;

    Emissao: string;

    Entrada: string;

    Fornecedor: string;

    ValorTotal: string;

    ChaveNfe: string;

    Observacao: string;

  end;



  TCompraImpressao = class

  public

    class function CarregarCabecalho(AEmpCodigo, AEntcContador: Integer): TCompraCabecalho;

    class procedure Visualizar(AEmpCodigo, AEntcContador: Integer);

    class procedure ImprimirFisico(AEmpCodigo, AEntcContador: Integer);

  end;



implementation



uses

  Data.DB, Vcl.Forms, Vcl.Graphics, Vcl.Printers, Vcl.Dialogs,

  UFormatacaoMoeda, UImpressaoUtil, UDavRelatorioImpressao,

  UNFeDanfeVisualizacao;



class function TCompraImpressao.CarregarCabecalho(AEmpCodigo,

  AEntcContador: Integer): TCompraCabecalho;

var

  Q: TFDQuery;

begin

  FillChar(Result, SizeOf(Result), 0);

  Q := TFDQuery.Create(nil);

  try

    Q.Connection := dmConexao.FDConnection1;

    Q.SQL.Text :=

      'SELECT E.ENTCNUMERO, E.ENTCSERIE, E.ENTCDTEMISSAO, E.ENTCDTENTRADA, ' +

      'E.ENTCVRTOTAL, E.ENTCCHAVENFE, E.ENTCOBSDOCUMENTO, P.PESNOME ' +

      'FROM ENTRADACOMPRA E ' +

      'LEFT JOIN FORNECEDOR F ON F.FORCODIGO = E.FORCODIGO AND F.EMPCODIGO = E.EMPCODIGO ' +

      'LEFT JOIN PESSOA P ON P.PESCODIGO = F.PESCODIGO ' +

      'WHERE E.EMPCODIGO = :EMPCODIGO AND E.ENTCCONTADOR = :ENTCCONTADOR';

    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;

    Q.ParamByName('ENTCCONTADOR').AsInteger := AEntcContador;

    Q.Open;

    if Q.IsEmpty then

      Exit;



    Result.Numero := Q.FieldByName('ENTCNUMERO').AsString;

    Result.Serie := Q.FieldByName('ENTCSERIE').AsString;

    if not Q.FieldByName('ENTCDTEMISSAO').IsNull then

      Result.Emissao := FormatDateTime('dd/mm/yyyy', Q.FieldByName('ENTCDTEMISSAO').AsDateTime);

    if not Q.FieldByName('ENTCDTENTRADA').IsNull then

      Result.Entrada := FormatDateTime('dd/mm/yyyy', Q.FieldByName('ENTCDTENTRADA').AsDateTime);

    Result.Fornecedor := Trim(Q.FieldByName('PESNOME').AsString);

    Result.ValorTotal := FormatarMoedaBRL(Q.FieldByName('ENTCVRTOTAL').AsFloat);

    Result.ChaveNfe := Trim(Q.FieldByName('ENTCCHAVENFE').AsString);

    Result.Observacao := Trim(Q.FieldByName('ENTCOBSDOCUMENTO').AsString);

  finally

    Q.Free;

  end;

end;



class procedure TCompraImpressao.Visualizar(AEmpCodigo, AEntcContador: Integer);

var

  Dados: TDavRelatorioDados;

  Cab: TCompraCabecalho;

  Xml: string;

  Titulo: string;

begin

  if not dmConexao.Conectado then

    raise Exception.Create('Banco de dados nao conectado.');



  Cab := CarregarCabecalho(AEmpCodigo, AEntcContador);

  if Cab.Numero = '' then

    raise Exception.Create('Entrada de compra nao encontrada para impressao.');



  Xml := TNFeDanfeVisualizacao.ObterXmlCompra(AEmpCodigo, AEntcContador);

  if Xml <> '' then

  begin

    Titulo := 'DANFE - Compra ' + Cab.Numero;

    if Cab.Serie <> '' then

      Titulo := Titulo + ' / ' + Cab.Serie;

    TNFeDanfeVisualizacao.VisualizarDanfe(Xml, Titulo);

    Exit;

  end;



  Dados := TDavRelatorioImpressao.CarregarDadosCompra(AEmpCodigo, AEntcContador);

  try

    Titulo := 'Compra ' + Cab.Numero;

    if Cab.Serie <> '' then

      Titulo := Titulo + ' - ' + Cab.Serie;

    TDavRelatorioImpressao.VisualizarPdf(Dados, Titulo);

  finally

    Dados.Free;

  end;

end;



class procedure TCompraImpressao.ImprimirFisico(AEmpCodigo, AEntcContador: Integer);

var

  Dados: TDavRelatorioDados;

  Paginas: TListaPaginasImpressao;

  Dlg: TPrintDialog;

  Cab: TCompraCabecalho;

  Xml: string;

  Titulo: string;

begin

  if not dmConexao.Conectado then

    raise Exception.Create('Banco de dados nao conectado.');



  if Printer.Printers.Count = 0 then

    raise Exception.Create('Nenhuma impressora instalada no Windows.');



  Cab := CarregarCabecalho(AEmpCodigo, AEntcContador);

  if Cab.Numero = '' then

    raise Exception.Create('Entrada de compra nao encontrada para impressao.');



  Xml := TNFeDanfeVisualizacao.ObterXmlCompra(AEmpCodigo, AEntcContador);

  if Xml <> '' then

  begin

    Titulo := 'DANFE - Compra ' + Cab.Numero;

    if Cab.Serie <> '' then

      Titulo := Titulo + ' / ' + Cab.Serie;

    try

      TNFeDanfeVisualizacao.ImprimirDanfe(Xml, Titulo);

      Exit;

    except

      on E: Exception do

        MessageDlg('DANFE oficial indisponivel (' + E.Message + ').' + sLineBreak +

          'Sera usado o resumo simplificado.', mtWarning, [mbOK], 0);

    end;

  end;



  Dados := TDavRelatorioImpressao.CarregarDadosCompra(AEmpCodigo, AEntcContador);

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

