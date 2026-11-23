unit UMapaReceber;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao, UFiltroPeriodoConsulta;

type
  TFiltroReceberLista = (frTodas, frRecebidas, frEmAberto, frAtrasadas);
  TFiltroReceberBoleto = (fbBoletoTodos, fbBoletoCom, fbBoletoSem);

  TFiltrosReceberConsulta = record
    Texto: string;
    CodigoCliente: string;
    NossoNumero: string;
    PeriodoEmissao: TFiltroPeriodoConsulta;
    PeriodoVencimento: TFiltroPeriodoConsulta;
    PeriodoRecebimento: TFiltroPeriodoConsulta;
  end;

  TDetalheReceber = record
    Encontrado: Boolean;
    EmpCodigo: Integer;
    Numero: Integer;
    Documento: string;
    Emissao: string;
    Vencimento: string;
    Recebimento: string;
    Pessoa: string;
    Valor: string;
    ValorRecebido: string;
    ValorAberto: string;
    Situacao: string;
    Observacao: string;
    TemBoleto: Boolean;
  end;

  TInfoBoletoReceber = record
    BolContador: Integer;
    NossoNumero: string;
    Numero: string;
    Vencimento: string;
    Valor: string;
    Situacao: string;
    DataPagamento: string;
    NumeroDocumento: string;
    LinhaDigitavel: string;
    CodigoBarras: string;
    Observacao: string;
  end;

  TMapaReceber = class
  private
    class function CondicaoFiltroSituacao(
      AFiltroSituacao: TFiltroReceberLista): string;
    class function CondicaoFiltroBoleto(
      AFiltroBoleto: TFiltroReceberBoleto): string;
  public
    class function MontarSQLLista(const AFiltros: TFiltrosReceberConsulta;
      AFiltroSituacao: TFiltroReceberLista;
      AFiltroBoleto: TFiltroReceberBoleto): string;
    class procedure ConfigurarParametrosLista(AQuery: TFDQuery;
      const AFiltros: TFiltrosReceberConsulta);
    class function CarregarDetalhe(AEmpCodigo, ACrNumero: Integer): TDetalheReceber;
    class function TemBoleto(AEmpCodigo, ACrNumero: Integer): Boolean;
    class function CarregarBoletos(AEmpCodigo, ACrNumero: Integer): TArray<TInfoBoletoReceber>;
    class function DescricaoSituacaoBoleto(ASituacao: Integer): string;
  end;

implementation

uses
  Data.DB, UFormatacaoMoeda;

function DescricaoSituacaoReceber(ASituacao: Integer): string;
begin
  case ASituacao of
    0: Result := 'Em aberto';
    1: Result := 'Recebido';
    2: Result := 'Cancelado';
  else
    Result := IntToStr(ASituacao);
  end;
end;

class function TMapaReceber.DescricaoSituacaoBoleto(ASituacao: Integer): string;
begin
  case ASituacao of
    0: Result := 'Em aberto';
    1: Result := 'Liquidado';
    2: Result := 'Cancelado';
  else
    Result := IntToStr(ASituacao);
  end;
end;

class function TMapaReceber.CondicaoFiltroSituacao(
  AFiltroSituacao: TFiltroReceberLista): string;
begin
  case AFiltroSituacao of
    frRecebidas:
      Exit('CR.CRSITUACAO = 1');
    frEmAberto:
      Exit('(CR.CRSITUACAO = 0 AND CR.CRVALORABERTO > 0)');
    frAtrasadas:
      Exit('(CR.CRSITUACAO = 0 AND CR.CRVALORABERTO > 0 AND CR.CRDTVENCTO < CURRENT_DATE)');
  else
    Result := '';
  end;
end;

class function TMapaReceber.CondicaoFiltroBoleto(
  AFiltroBoleto: TFiltroReceberBoleto): string;
begin
  case AFiltroBoleto of
    fbBoletoCom:
      Exit(
        'EXISTS (SELECT 1 FROM CRBOLETO CB ' +
        'WHERE CB.EMPCODIGO = CR.EMPCODIGO AND CB.CRNUMERO = CR.CRNUMERO)');
    fbBoletoSem:
      Exit(
        'NOT EXISTS (SELECT 1 FROM CRBOLETO CB ' +
        'WHERE CB.EMPCODIGO = CR.EMPCODIGO AND CB.CRNUMERO = CR.CRNUMERO)');
  else
    Result := '';
  end;
end;

class function TMapaReceber.MontarSQLLista(const AFiltros: TFiltrosReceberConsulta;
  AFiltroSituacao: TFiltroReceberLista;
  AFiltroBoleto: TFiltroReceberBoleto): string;
var
  Filtro, CodigoCliente, NossoNumero, CondSituacao, CondBoleto, CondTexto,
  CondCodigoCliente, CondNossoNumero, CondEmissao, CondVencimento, CondRecebimento,
  Where: string;
  TemWhere: Boolean;

  procedure AdicionarCondicao(const ACondicao: string);
  begin
    if ACondicao = '' then
      Exit;
    if TemWhere then
      Where := Where + ' AND ' + ACondicao
    else
    begin
      Where := 'WHERE ' + ACondicao;
      TemWhere := True;
    end;
  end;

begin
  Filtro := Trim(AFiltros.Texto);
  CodigoCliente := Trim(AFiltros.CodigoCliente);
  NossoNumero := Trim(AFiltros.NossoNumero);
  CondSituacao := TMapaReceber.CondicaoFiltroSituacao(AFiltroSituacao);
  CondBoleto := TMapaReceber.CondicaoFiltroBoleto(AFiltroBoleto);
  CondTexto := '';
  CondCodigoCliente := '';
  CondNossoNumero := '';

  if Filtro <> '' then
  begin
    if FiltroSomenteDigitos(Filtro) then
      CondTexto := 'CR.CRNUMERO = :DOCNUMERO'
    else
      CondTexto :=
        '(COALESCE(NULLIF(TRIM(P.PESNOME), ''''), NULLIF(TRIM(PC.PCDESCRICAO), '''')) ' +
        'CONTAINING :FILTRO_TEXTO OR CR.CRDOCUMENTO CONTAINING :FILTRO_TEXTO)';
  end;

  if CodigoCliente <> '' then
    CondCodigoCliente := 'COALESCE(C.CLICODIGO, CR.PCCODIGO) = :CODIGO_CLIENTE';

  if NossoNumero <> '' then
    CondNossoNumero :=
      'EXISTS (SELECT 1 FROM CRBOLETO CB ' +
      'JOIN BOLETO B ON B.EMPCODIGO = CB.EMPCODIGO AND B.BOLCONTADOR = CB.BOLCONTADOR ' +
      'WHERE CB.EMPCODIGO = CR.EMPCODIGO AND CB.CRNUMERO = CR.CRNUMERO ' +
      'AND B.BOLNOSSONUMERO CONTAINING :NOSSO_NUMERO)';

  CondEmissao := MontarCondicaoPeriodo('CR.CRDTEMISSAO', 'EMI_INICIO', 'EMI_FIM',
    AFiltros.PeriodoEmissao);
  CondVencimento := MontarCondicaoPeriodo('CR.CRDTVENCTO', 'VEN_INICIO', 'VEN_FIM',
    AFiltros.PeriodoVencimento);
  CondRecebimento := MontarCondicaoPeriodo('CR.CRDTRECEBIMENTO', 'REC_INICIO', 'REC_FIM',
    AFiltros.PeriodoRecebimento);

  TemWhere := False;
  Where := '';
  AdicionarCondicao(CondSituacao);
  AdicionarCondicao(CondBoleto);
  AdicionarCondicao(CondTexto);
  AdicionarCondicao(CondCodigoCliente);
  AdicionarCondicao(CondNossoNumero);
  AdicionarCondicao(CondEmissao);
  AdicionarCondicao(CondVencimento);
  AdicionarCondicao(CondRecebimento);

  Result :=
    'SELECT FIRST 2000 ' +
    'CR.EMPCODIGO, CR.CRNUMERO, ' +
    'REPLACE(CAST(CR.CRDOCUMENTO AS VARCHAR(40) CHARACTER SET WIN1252), ' +
    '''/'', ''-'') AS CRDOCUMENTO, ' +
    'CR.CRDTEMISSAO, CR.CRDTVENCTO, ' +
    'CR.CRDTRECEBIMENTO, ' +
    'COALESCE(C.CLICODIGO, CR.PCCODIGO) AS CODIGO_CLIENTE, ' +
    'CAST(TRIM(COALESCE(NULLIF(TRIM(P.PESNOME), ''''), NULLIF(TRIM(PC.PCDESCRICAO), ''''), '''')) ' +
    'AS VARCHAR(250) CHARACTER SET WIN1252) AS NOME_PESSOA, ' +
    'CAST(TRIM(COALESCE(P.PESCNPJCPF, '''')) AS VARCHAR(20) CHARACTER SET WIN1252) AS CPF_CNPJ, ' +
    'CR.CRVALOR, CR.CRVALORRECEBIDO, CR.CRVALORABERTO, CR.CRSITUACAO, ' +
    'CASE WHEN EXISTS (SELECT 1 FROM CRBOLETO CB ' +
    'WHERE CB.EMPCODIGO = CR.EMPCODIGO AND CB.CRNUMERO = CR.CRNUMERO) ' +
    'THEN 1 ELSE 0 END AS TEM_BOLETO ' +
    'FROM CONTASRECEBER CR ' +
    'LEFT JOIN PESSOA P ON P.PESCODIGO = CR.PCCODIGO ' +
    'LEFT JOIN CLIENTE C ON C.PESCODIGO = P.PESCODIGO AND C.EMPCODIGO = CR.EMPCODIGO ' +
    'LEFT JOIN PLANOCONTAS PC ON PC.PCCODIGO = CR.PCCODIGO AND PC.EMPCODIGO = CR.EMPCODIGO ' +
    Where + ' ' +
    'ORDER BY CR.CRDTVENCTO DESC, CR.CRNUMERO DESC';
end;

class procedure TMapaReceber.ConfigurarParametrosLista(AQuery: TFDQuery;
  const AFiltros: TFiltrosReceberConsulta);
var
  F, CodigoCliente, NossoNumero: string;
begin
  F := Trim(AFiltros.Texto);
  if F <> '' then
  begin
    if FiltroSomenteDigitos(F) then
      AQuery.ParamByName('DOCNUMERO').AsInteger := StrToIntDef(F, 0)
    else
      AQuery.ParamByName('FILTRO_TEXTO').AsString := F;
  end;

  CodigoCliente := Trim(AFiltros.CodigoCliente);
  if CodigoCliente <> '' then
    AQuery.ParamByName('CODIGO_CLIENTE').AsInteger := StrToIntDef(CodigoCliente, 0);

  NossoNumero := Trim(AFiltros.NossoNumero);
  if NossoNumero <> '' then
    AQuery.ParamByName('NOSSO_NUMERO').AsString := NossoNumero;

  ConfigurarParametrosPeriodo(AQuery, 'EMI_INICIO', 'EMI_FIM', AFiltros.PeriodoEmissao);
  ConfigurarParametrosPeriodo(AQuery, 'VEN_INICIO', 'VEN_FIM', AFiltros.PeriodoVencimento);
  ConfigurarParametrosPeriodo(AQuery, 'REC_INICIO', 'REC_FIM', AFiltros.PeriodoRecebimento);
end;

class function TMapaReceber.TemBoleto(AEmpCodigo, ACrNumero: Integer): Boolean;
var
  Q: TFDQuery;
begin
  Result := False;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT FIRST 1 1 AS TEM FROM CRBOLETO CB ' +
      'WHERE CB.EMPCODIGO = :EMPCODIGO AND CB.CRNUMERO = :CRNUMERO';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('CRNUMERO').AsInteger := ACrNumero;
    Q.Open;
    Result := not Q.IsEmpty;
  finally
    Q.Free;
  end;
end;

class function TMapaReceber.CarregarBoletos(AEmpCodigo, ACrNumero: Integer): TArray<TInfoBoletoReceber>;
var
  Q: TFDQuery;
  Lista: TArray<TInfoBoletoReceber>;
  Item: TInfoBoletoReceber;
  I: Integer;
begin
  SetLength(Lista, 0);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT B.BOLCONTADOR, B.BOLNOSSONUMERO, B.BOLNUMERO, B.BOLVENCIMENTO, B.BOLVALOR, ' +
      'B.BOLSITUACAO, B.BOLDATAPAGAMENTO, B.BOLNUMERODOCUMENTO, B.BOLLINHADIGITAVEL, ' +
      'B.BOLCODBARRAS, B.BOLOBSERVACAO ' +
      'FROM CRBOLETO CB ' +
      'JOIN BOLETO B ON B.EMPCODIGO = CB.EMPCODIGO AND B.BOLCONTADOR = CB.BOLCONTADOR ' +
      'WHERE CB.EMPCODIGO = :EMPCODIGO AND CB.CRNUMERO = :CRNUMERO ' +
      'ORDER BY B.BOLVENCIMENTO DESC, B.BOLCONTADOR DESC';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('CRNUMERO').AsInteger := ACrNumero;
    Q.Open;
    I := 0;
    while not Q.Eof do
    begin
      Item.BolContador := Q.FieldByName('BOLCONTADOR').AsInteger;
      Item.NossoNumero := Trim(Q.FieldByName('BOLNOSSONUMERO').AsString);
      Item.Numero := Trim(Q.FieldByName('BOLNUMERO').AsString);
      if not Q.FieldByName('BOLVENCIMENTO').IsNull then
        Item.Vencimento := FormatDateTime('dd/mm/yyyy', Q.FieldByName('BOLVENCIMENTO').AsDateTime)
      else
        Item.Vencimento := '';
      Item.Valor := FormatarMoedaBRL(Q.FieldByName('BOLVALOR').AsFloat);
      Item.Situacao := DescricaoSituacaoBoleto(Q.FieldByName('BOLSITUACAO').AsInteger);
      if not Q.FieldByName('BOLDATAPAGAMENTO').IsNull then
        Item.DataPagamento := FormatDateTime('dd/mm/yyyy', Q.FieldByName('BOLDATAPAGAMENTO').AsDateTime)
      else
        Item.DataPagamento := '';
      Item.NumeroDocumento := Trim(Q.FieldByName('BOLNUMERODOCUMENTO').AsString);
      Item.LinhaDigitavel := Trim(Q.FieldByName('BOLLINHADIGITAVEL').AsString);
      Item.CodigoBarras := Trim(Q.FieldByName('BOLCODBARRAS').AsString);
      Item.Observacao := Trim(Q.FieldByName('BOLOBSERVACAO').AsString);
      SetLength(Lista, I + 1);
      Lista[I] := Item;
      Inc(I);
      Q.Next;
    end;
    Result := Lista;
  finally
    Q.Free;
  end;
end;

class function TMapaReceber.CarregarDetalhe(AEmpCodigo, ACrNumero: Integer): TDetalheReceber;
var
  Q: TFDQuery;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.EmpCodigo := AEmpCodigo;
  Result.Numero := ACrNumero;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT FIRST 1 CR.*, ' +
      'CAST(TRIM(COALESCE(NULLIF(TRIM(P.PESNOME), ''''), NULLIF(TRIM(PC.PCDESCRICAO), ''''), '''')) ' +
      'AS VARCHAR(250) CHARACTER SET WIN1252) AS PESNOME ' +
      'FROM CONTASRECEBER CR ' +
      'LEFT JOIN PESSOA P ON P.PESCODIGO = CR.PCCODIGO ' +
      'LEFT JOIN PLANOCONTAS PC ON PC.PCCODIGO = CR.PCCODIGO AND PC.EMPCODIGO = CR.EMPCODIGO ' +
      'WHERE CR.EMPCODIGO = :EMPCODIGO AND CR.CRNUMERO = :CRNUMERO';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('CRNUMERO').AsInteger := ACrNumero;
    Q.Open;
    if Q.IsEmpty then
      Exit;

    Result.Encontrado := True;
    Result.Documento := FormatarDocumentoConsulta(Q.FieldByName('CRDOCUMENTO').AsString);
    if not Q.FieldByName('CRDTEMISSAO').IsNull then
      Result.Emissao := FormatDateTime('dd/mm/yyyy', Q.FieldByName('CRDTEMISSAO').AsDateTime);
    if not Q.FieldByName('CRDTVENCTO').IsNull then
      Result.Vencimento := FormatDateTime('dd/mm/yyyy', Q.FieldByName('CRDTVENCTO').AsDateTime);
    if not Q.FieldByName('CRDTRECEBIMENTO').IsNull then
      Result.Recebimento := FormatDateTime('dd/mm/yyyy', Q.FieldByName('CRDTRECEBIMENTO').AsDateTime);
    Result.Pessoa := Trim(Q.FieldByName('PESNOME').AsString);
    Result.Valor := FormatarMoedaBRL(Q.FieldByName('CRVALOR').AsFloat);
    Result.ValorRecebido := FormatarMoedaBRL(Q.FieldByName('CRVALORRECEBIDO').AsFloat);
    Result.ValorAberto := FormatarMoedaBRL(Q.FieldByName('CRVALORABERTO').AsFloat);
    Result.Situacao := DescricaoSituacaoReceber(Q.FieldByName('CRSITUACAO').AsInteger);
    Result.Observacao := Trim(Q.FieldByName('CROBSERVACAO').AsString);
    Result.TemBoleto := TemBoleto(AEmpCodigo, ACrNumero);
  finally
    Q.Free;
  end;
end;

end.
