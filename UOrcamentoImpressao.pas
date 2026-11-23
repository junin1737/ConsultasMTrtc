unit UOrcamentoImpressao;



interface



uses

  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao, UMapaOrcamento;



type

  TOrcamentoCabecalho = record

    Numero: string;

    Emissao: string;

    Cliente: string;

    Vencimento: string;

    ValorTotal: string;

    Usuario: string;

    Observacao: string;

  end;



  TOrcamentoImpressao = class

  public

    class function CarregarCabecalho(AEmpCodigo, AOrcContador: Integer): TOrcamentoCabecalho;

    class procedure Visualizar(AEmpCodigo, AOrcContador: Integer);

    class procedure ImprimirFisico(AEmpCodigo, AOrcContador: Integer);

  end;



implementation



uses

  Data.DB, Vcl.Forms, Vcl.Graphics, Vcl.Printers,

  Vcl.Dialogs, UFormatacaoMoeda, UImpressaoUtil, UDavRelatorioImpressao,

  UCampoObservacao, UConsultaCampos;



class procedure TOrcamentoImpressao.Visualizar(AEmpCodigo, AOrcContador: Integer);

var

  Dados: TDavRelatorioDados;

  Cab: TOrcamentoCabecalho;

begin

  if not dmConexao.Conectado then

    raise Exception.Create('Banco de dados nao conectado.');



  Cab := CarregarCabecalho(AEmpCodigo, AOrcContador);

  if Cab.Numero = '' then

    raise Exception.Create('Orcamento nao encontrado para impressao.');



  Dados := TDavRelatorioImpressao.CarregarDadosOrcamento(AEmpCodigo, AOrcContador);

  try

    if Trim(Dados.Numero) = '' then
      raise Exception.Create('Nao foi possivel carregar os dados do orcamento para impressao.');
    TDavRelatorioImpressao.VisualizarPdf(Dados, 'Orcamento ' + Cab.Numero);

  finally

    Dados.Free;

  end;

end;



class function TOrcamentoImpressao.CarregarCabecalho(AEmpCodigo, AOrcContador: Integer): TOrcamentoCabecalho;

var

  Q: TFDQuery;
  UsuCodigo: Integer;

begin

  FillChar(Result, SizeOf(Result), 0);

  Q := TFDQuery.Create(nil);

  try

    Q.Connection := dmConexao.FDConnection1;

    try
      Q.SQL.Text := TMapaOrcamento.MontarSQLCabecalho;
      Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
      Q.ParamByName('ORCCONTADOR').AsInteger := AOrcContador;
      Q.Open;
    except
      Q.Close;
      Q.SQL.Text :=
        'SELECT O.ORCNUMERO, O.ORCEMISSAO, O.PESNOME, O.ORCTOTALLIQUIDO, ' +
        'O.ORCDATAENTREGA, O.ORCPRAZOVALIDADE, O.USUCODIGO ' +
        'FROM ORCAMENTO O ' +
        'WHERE O.EMPCODIGO = :EMPCODIGO AND O.ORCCONTADOR = :ORCCONTADOR';
      Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
      Q.ParamByName('ORCCONTADOR').AsInteger := AOrcContador;
      Q.Open;
    end;

    if Q.IsEmpty then

      Exit;



    Result.Numero := Q.FieldByName('ORCNUMERO').AsString;

    if not Q.FieldByName('ORCEMISSAO').IsNull then

    begin

      Result.Emissao := FormatDateTime('dd/mm/yyyy', Q.FieldByName('ORCEMISSAO').AsDateTime);

      Result.Vencimento := VencimentoTrintaDiasApos(Q.FieldByName('ORCEMISSAO').AsDateTime);

    end;

    Result.Cliente := Trim(Q.FieldByName('PESNOME').AsString);

    Result.ValorTotal := FormatarMoedaBRL(Q.FieldByName('ORCTOTALLIQUIDO').AsFloat);

    UsuCodigo := 0;
    if Q.FindField('USUCODIGO') <> nil then
      UsuCodigo := Q.FieldByName('USUCODIGO').AsInteger;
    if Q.FindField('USUARIO_NOME') <> nil then
      Result.Usuario := Trim(Q.FieldByName('USUARIO_NOME').AsString);
    if Result.Usuario = '' then
      Result.Usuario := NomeUsuarioPorCodigo(AEmpCodigo, UsuCodigo);

    Result.Observacao := CarregarObservacaoDocumento(Q,
      ['ORCOBSERVACAO', 'ORCOBS', 'OBSERVACAO', 'OBS'],
      'ORCAMENTO', 'ORCCONTADOR', AEmpCodigo, AOrcContador);

  finally

    Q.Free;

  end;

end;



class procedure TOrcamentoImpressao.ImprimirFisico(AEmpCodigo, AOrcContador: Integer);

var

  Dados: TDavRelatorioDados;

  Paginas: TListaPaginasImpressao;

  Dlg: TPrintDialog;

  Cab: TOrcamentoCabecalho;

begin

  if not dmConexao.Conectado then

    raise Exception.Create('Banco de dados nao conectado.');



  if Printer.Printers.Count = 0 then

    raise Exception.Create('Nenhuma impressora instalada no Windows.');



  Cab := CarregarCabecalho(AEmpCodigo, AOrcContador);

  if Cab.Numero = '' then

    raise Exception.Create('Orcamento nao encontrado para impressao.');



  Dados := TDavRelatorioImpressao.CarregarDadosOrcamento(AEmpCodigo, AOrcContador);

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

