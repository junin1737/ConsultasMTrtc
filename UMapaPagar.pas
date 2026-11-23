unit UMapaPagar;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao;

type
  TFiltroPagarLista = (fpTodas, fpPagas, fpEmAberto, fpAtrasadas);

  TDetalhePagar = record
    Encontrado: Boolean;
    EmpCodigo: Integer;
    Numero: Integer;
    Documento: string;
    Emissao: string;
    Vencimento: string;
    Pagamento: string;
    Pessoa: string;
    Valor: string;
    ValorPago: string;
    ValorAberto: string;
    Situacao: string;
    Observacao: string;
  end;

  TMapaPagar = class
  private
    class function CondicaoFiltroSituacao(
      AFiltroSituacao: TFiltroPagarLista): string;
  public
    class function MontarSQLLista(const AFiltro: string;
      AFiltroSituacao: TFiltroPagarLista): string;
    class procedure ConfigurarParametrosLista(AQuery: TFDQuery; const AFiltro: string);
    class function CarregarDetalhe(AEmpCodigo, ACpNumero: Integer): TDetalhePagar;
  end;

implementation

uses
  Data.DB, UFormatacaoMoeda;

function DescricaoSituacaoPagar(ASituacao: Integer): string;
begin
  case ASituacao of
    0: Result := 'Em aberto';
    1: Result := 'Pago';
    2: Result := 'Cancelado';
  else
    Result := IntToStr(ASituacao);
  end;
end;

class function TMapaPagar.CondicaoFiltroSituacao(
  AFiltroSituacao: TFiltroPagarLista): string;
begin
  case AFiltroSituacao of
    fpPagas:
      Exit('CP.CPSITUACAO = 1');
    fpEmAberto:
      Exit('(CP.CPSITUACAO = 0 AND CP.CPVALORABERTO > 0)');
    fpAtrasadas:
      Exit('(CP.CPSITUACAO = 0 AND CP.CPVALORABERTO > 0 AND CP.CPDTVENCTO < CURRENT_DATE)');
  else
    Result := '';
  end;
end;

class function TMapaPagar.MontarSQLLista(const AFiltro: string;
  AFiltroSituacao: TFiltroPagarLista): string;
var
  Filtro, CondSituacao, CondTexto, Where: string;
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
  Filtro := Trim(AFiltro);
  CondSituacao := TMapaPagar.CondicaoFiltroSituacao(AFiltroSituacao);
  CondTexto := '';

  if Filtro <> '' then
  begin
    if FiltroSomenteDigitos(Filtro) then
      CondTexto := 'CP.CPNUMERO = :DOCNUMERO'
    else
      CondTexto :=
        '(COALESCE(NULLIF(TRIM(P.PESNOME), ''''), NULLIF(TRIM(PC.PCDESCRICAO), '''')) ' +
        'CONTAINING :FILTRO_TEXTO OR CP.CPDOCUMENTO CONTAINING :FILTRO_TEXTO)';
  end;

  TemWhere := False;
  Where := '';
  AdicionarCondicao(CondSituacao);
  AdicionarCondicao(CondTexto);

  Result :=
    'SELECT FIRST 2000 ' +
    'CP.EMPCODIGO, CP.CPNUMERO, ' +
    'REPLACE(CAST(CP.CPDOCUMENTO AS VARCHAR(40) CHARACTER SET WIN1252), ' +
    '''/'', ''-'') AS CPDOCUMENTO, ' +
    'CP.CPDTEMISSAO, CP.CPDTVENCTO, ' +
    'CP.CPDTPAGTO, ' +
    'CAST(TRIM(COALESCE(NULLIF(TRIM(P.PESNOME), ''''), NULLIF(TRIM(PC.PCDESCRICAO), ''''), '''')) ' +
    'AS VARCHAR(250) CHARACTER SET WIN1252) AS NOME_PESSOA, ' +
    'CP.CPVALOR, CP.CPVALORPAGO, CP.CPVALORABERTO, CP.CPSITUACAO ' +
    'FROM CONTASPAGAR CP ' +
    'LEFT JOIN PESSOA P ON P.PESCODIGO = CP.PCCODIGO ' +
    'LEFT JOIN PLANOCONTAS PC ON PC.PCCODIGO = CP.PCCODIGO AND PC.EMPCODIGO = CP.EMPCODIGO ' +
    Where + ' ' +
    'ORDER BY CP.CPDTVENCTO DESC, CP.CPNUMERO DESC';
end;

class procedure TMapaPagar.ConfigurarParametrosLista(AQuery: TFDQuery;
  const AFiltro: string);
var
  F: string;
begin
  F := Trim(AFiltro);
  if F = '' then
    Exit;

  if FiltroSomenteDigitos(F) then
    AQuery.ParamByName('DOCNUMERO').AsInteger := StrToIntDef(F, 0)
  else
    AQuery.ParamByName('FILTRO_TEXTO').AsString := F;
end;

class function TMapaPagar.CarregarDetalhe(AEmpCodigo, ACpNumero: Integer): TDetalhePagar;
var
  Q: TFDQuery;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.EmpCodigo := AEmpCodigo;
  Result.Numero := ACpNumero;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT FIRST 1 CP.*, ' +
      'CAST(TRIM(COALESCE(NULLIF(TRIM(P.PESNOME), ''''), NULLIF(TRIM(PC.PCDESCRICAO), ''''), '''')) ' +
      'AS VARCHAR(250) CHARACTER SET WIN1252) AS PESNOME ' +
      'FROM CONTASPAGAR CP ' +
      'LEFT JOIN PESSOA P ON P.PESCODIGO = CP.PCCODIGO ' +
      'LEFT JOIN PLANOCONTAS PC ON PC.PCCODIGO = CP.PCCODIGO AND PC.EMPCODIGO = CP.EMPCODIGO ' +
      'WHERE CP.EMPCODIGO = :EMPCODIGO AND CP.CPNUMERO = :CPNUMERO';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('CPNUMERO').AsInteger := ACpNumero;
    Q.Open;
    if Q.IsEmpty then
      Exit;

    Result.Encontrado := True;
    Result.Documento := FormatarDocumentoConsulta(Q.FieldByName('CPDOCUMENTO').AsString);
    if not Q.FieldByName('CPDTEMISSAO').IsNull then
      Result.Emissao := FormatDateTime('dd/mm/yyyy', Q.FieldByName('CPDTEMISSAO').AsDateTime);
    if not Q.FieldByName('CPDTVENCTO').IsNull then
      Result.Vencimento := FormatDateTime('dd/mm/yyyy', Q.FieldByName('CPDTVENCTO').AsDateTime);
    if not Q.FieldByName('CPDTPAGTO').IsNull then
      Result.Pagamento := FormatDateTime('dd/mm/yyyy', Q.FieldByName('CPDTPAGTO').AsDateTime);
    Result.Pessoa := Trim(Q.FieldByName('PESNOME').AsString);
    Result.Valor := FormatarMoedaBRL(Q.FieldByName('CPVALOR').AsFloat);
    Result.ValorPago := FormatarMoedaBRL(Q.FieldByName('CPVALORPAGO').AsFloat);
    Result.ValorAberto := FormatarMoedaBRL(Q.FieldByName('CPVALORABERTO').AsFloat);
    Result.Situacao := DescricaoSituacaoPagar(Q.FieldByName('CPSITUACAO').AsInteger);
    Result.Observacao := Trim(Q.FieldByName('CPOBSERVACAO').AsString);
  finally
    Q.Free;
  end;
end;

end.
