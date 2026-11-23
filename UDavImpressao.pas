unit UDavImpressao;



interface



uses

  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao, UMapaDav;



type

  TDavCabecalho = record

    Numero: string;

    Emissao: string;

    Cliente: string;

    Vencimento: string;

    ValorTotal: string;

    Usuario: string;

    Observacao: string;

  end;



  TDavImpressao = class

  public

    class function CarregarCabecalho(AEmpCodigo, ADavContador: Integer): TDavCabecalho;

    class procedure Visualizar(AEmpCodigo, ADavContador: Integer);

    class procedure ImprimirFisico(AEmpCodigo, ADavContador: Integer);

  end;



implementation



uses

  Data.DB, Vcl.Forms, Vcl.Graphics, Vcl.Printers, Vcl.Dialogs,

  UFormatacaoMoeda, UImpressaoUtil, UDavRelatorioImpressao, UCampoObservacao,

  UConsultaCampos;



class procedure TDavImpressao.Visualizar(AEmpCodigo, ADavContador: Integer);

var

  Dados: TDavRelatorioDados;

  Cab: TDavCabecalho;

begin

  if not dmConexao.Conectado then

    raise Exception.Create('Banco de dados nao conectado.');



  Cab := CarregarCabecalho(AEmpCodigo, ADavContador);

  if Cab.Numero = '' then

    raise Exception.Create('DAV nao encontrado para impressao.');



  Dados := TDavRelatorioImpressao.CarregarDados(AEmpCodigo, ADavContador);

  try

    if Trim(Dados.Numero) = '' then
      raise Exception.Create('Nao foi possivel carregar os dados do DAV para impressao.');
    TDavRelatorioImpressao.VisualizarPdf(Dados, 'DAV ' + Cab.Numero);

  finally

    Dados.Free;

  end;

end;



class function TDavImpressao.CarregarCabecalho(AEmpCodigo, ADavContador: Integer): TDavCabecalho;

var

  Q: TFDQuery;
  UsuCodigo: Integer;

  procedure CarregarUsuario;
  begin
    UsuCodigo := 0;
    if Q.FindField('USUCODIGO') <> nil then
      UsuCodigo := Q.FieldByName('USUCODIGO').AsInteger;
    Result.Usuario := Trim(Q.FieldByName('USUARIO_NOME').AsString);
    if Result.Usuario = '' then
      Result.Usuario := NomeUsuarioPorCodigo(AEmpCodigo, UsuCodigo);
  end;

begin

  FillChar(Result, SizeOf(Result), 0);

  Q := TFDQuery.Create(nil);

  try

    Q.Connection := dmConexao.FDConnection1;

    try
      Q.SQL.Text :=
        'SELECT D.*, P.PESNOME, COALESCE(PU.PESNOME, U.USUNOME, U.USULOGIN) AS USUARIO_NOME ' +
        'FROM DAV D ' +
        'LEFT JOIN CLIENTE C ON C.CLICODIGO = D.CLICODIGO AND C.EMPCODIGO = D.EMPCODIGO ' +
        'LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO ' +
        'LEFT JOIN USUARIO U ON U.USUCODIGO = D.USUCODIGO AND U.EMPCODIGO = D.EMPCODIGO ' +
        'LEFT JOIN PESSOA PU ON PU.PESCODIGO = U.PESCODIGO ' +
        'WHERE D.EMPCODIGO = :EMPCODIGO AND D.DAVCONTADOR = :DAVCONTADOR';
      Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
      Q.ParamByName('DAVCONTADOR').AsInteger := ADavContador;
      Q.Open;
    except
      Q.Close;
      Q.SQL.Text :=
        'SELECT D.*, P.PESNOME ' +
        'FROM DAV D ' +
        'LEFT JOIN CLIENTE C ON C.CLICODIGO = D.CLICODIGO AND C.EMPCODIGO = D.EMPCODIGO ' +
        'LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO ' +
        'WHERE D.EMPCODIGO = :EMPCODIGO AND D.DAVCONTADOR = :DAVCONTADOR';
      Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
      Q.ParamByName('DAVCONTADOR').AsInteger := ADavContador;
      Q.Open;
    end;

    if Q.IsEmpty then

      Exit;



    Result.Numero := Q.FieldByName('DAVNUMERO').AsString;

    if not Q.FieldByName('DAVEMISSAO').IsNull then

    begin

      Result.Emissao := FormatDateTime('dd/mm/yyyy', Q.FieldByName('DAVEMISSAO').AsDateTime);

      Result.Vencimento := VencimentoTrintaDiasApos(Q.FieldByName('DAVEMISSAO').AsDateTime);

    end;

    Result.Cliente := Trim(Q.FieldByName('PESNOME').AsString);

    Result.ValorTotal := FormatarMoedaBRL(Q.FieldByName('DAVTOTALLIQUIDO').AsFloat);

    if Q.FindField('USUARIO_NOME') <> nil then
      CarregarUsuario
    else
    begin
      UsuCodigo := 0;
      if Q.FindField('USUCODIGO') <> nil then
        UsuCodigo := Q.FieldByName('USUCODIGO').AsInteger;
      Result.Usuario := NomeUsuarioPorCodigo(AEmpCodigo, UsuCodigo);
    end;

    Result.Observacao := CarregarObservacaoDocumento(Q,
      ['DAVOBS', 'DAVINFORMACOESADICIONAIS', 'DAVOBSERVACAO', 'OBSERVACAO', 'OBS'],
      'DAV', 'DAVCONTADOR', AEmpCodigo, ADavContador);

  finally

    Q.Free;

  end;

end;



class procedure TDavImpressao.ImprimirFisico(AEmpCodigo, ADavContador: Integer);

var

  Dados: TDavRelatorioDados;

  Paginas: TListaPaginasImpressao;

  Dlg: TPrintDialog;

begin

  if not dmConexao.Conectado then

    raise Exception.Create('Banco de dados nao conectado.');



  if Printer.Printers.Count = 0 then

    raise Exception.Create('Nenhuma impressora instalada no Windows.');



  Dados := TDavRelatorioImpressao.CarregarDados(AEmpCodigo, ADavContador);

  Paginas := nil;

  Dlg := TPrintDialog.Create(nil);

  try

    if Dados.Numero = '' then

      raise Exception.Create('DAV nao encontrado para impressao.');



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


