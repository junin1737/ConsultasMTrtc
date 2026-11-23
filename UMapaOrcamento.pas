unit UMapaOrcamento;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao, UFiltroPeriodoConsulta;

type
  TMapaOrcamento = class
  private
    class var FInicializado: Boolean;
    class var FCampoChave: string;
    class procedure Inicializar;
  public
    class procedure GarantirMapa;
    class function CampoChave: string;
    class function MontarSQLLista(const AFiltro: string;
      const APeriodo: TFiltroPeriodoConsulta): string;
    class procedure ConfigurarParametrosLista(AQuery: TFDQuery; const AFiltro: string;
      const APeriodo: TFiltroPeriodoConsulta);
    class function MontarSQLProdutos: string;
    class function MontarSQLServicos: string;
    class function MontarSQLCabecalho: string;
  end;

implementation

uses
  UFormatacaoMoeda, UCampoCodigoItem;

class procedure TMapaOrcamento.Inicializar;
begin
  if FInicializado then
    Exit;

  FCampoChave := 'ORCCONTADOR';
  FInicializado := True;
end;

class procedure TMapaOrcamento.GarantirMapa;
begin
  if not FInicializado then
    Inicializar;
end;

class function TMapaOrcamento.CampoChave: string;
begin
  GarantirMapa;
  Result := FCampoChave;
end;

class function TMapaOrcamento.MontarSQLLista(const AFiltro: string;
  const APeriodo: TFiltroPeriodoConsulta): string;
var
  Filtro: string;
  Where: TWhereBuilder;
begin
  GarantirMapa;
  Filtro := Trim(AFiltro);

  Result :=
    'SELECT FIRST 2000 ' +
    'O.EMPCODIGO, O.ORCCONTADOR, O.ORCNUMERO, O.ORCEMISSAO, O.PESNOME, ' +
    'CASE ' +
    '  WHEN O.ORCEMISSAO IS NOT NULL THEN O.ORCEMISSAO + 30 ' +
    '  WHEN O.ORCDATAENTREGA IS NOT NULL THEN O.ORCDATAENTREGA ' +
    '  WHEN O.ORCPRAZOVALIDADE > 0 AND O.ORCEMISSAO IS NOT NULL ' +
    '    THEN O.ORCEMISSAO + O.ORCPRAZOVALIDADE ' +
    '  ELSE NULL ' +
    'END AS DATA_VENCIMENTO, ' +
    'O.ORCTOTALLIQUIDO ' +
    'FROM ORCAMENTO O ';

  Where.TemWhere := False;
  Where.Text := '';

  if Filtro <> '' then
  begin
    if FiltroSomenteDigitos(Filtro) then
      Where.Adicionar('O.ORCNUMERO = :DOCNUMERO')
    else
      Where.Adicionar('O.PESNOME CONTAINING :FILTRO_TEXTO');
  end;

  Where.Adicionar(MontarCondicaoPeriodo('O.ORCEMISSAO', APeriodo));

  Result := Result + Where.Montar + ' ORDER BY O.ORCEMISSAO DESC, O.ORCNUMERO DESC';
end;

class procedure TMapaOrcamento.ConfigurarParametrosLista(AQuery: TFDQuery; const AFiltro: string;
  const APeriodo: TFiltroPeriodoConsulta);
var
  F: string;
begin
  F := Trim(AFiltro);
  if F <> '' then
  begin
    if FiltroSomenteDigitos(F) then
      AQuery.ParamByName('DOCNUMERO').AsInteger := StrToIntDef(F, 0)
    else
      AQuery.ParamByName('FILTRO_TEXTO').AsString := F;
  end;

  ConfigurarParametrosPeriodo(AQuery, APeriodo);
end;

class function TMapaOrcamento.MontarSQLCabecalho: string;
begin
  Result :=
    'SELECT O.*, O.PESNOME, ' +
    'COALESCE(PU.PESNOME, U.USUNOME, U.USULOGIN) AS USUARIO_NOME ' +
    'FROM ORCAMENTO O ' +
    'LEFT JOIN USUARIO U ON U.USUCODIGO = O.USUCODIGO AND U.EMPCODIGO = O.EMPCODIGO ' +
    'LEFT JOIN PESSOA PU ON PU.PESCODIGO = U.PESCODIGO ' +
    'WHERE O.EMPCODIGO = :EMPCODIGO AND O.ORCCONTADOR = :ORCCONTADOR';
end;

class function TMapaOrcamento.MontarSQLProdutos: string;
begin
  Result :=
    'SELECT DI.ORCITEMORDEM, ' + MontarSelectCodigoProduto +
    'P.PRODDESCRICAO, DI.ORCITEMQTDE, ' +
    'DI.ORCITEMUNITARIO, DI.ORCITEMTOTALLIQUIDO ' +
    'FROM ORCAMENTOITEM DI ' +
    'LEFT JOIN PRODUTO P ON P.PRODCONTADOR = DI.PRODCONTADOR AND P.EMPCODIGO = DI.EMPCODIGO ' +
    'WHERE DI.EMPCODIGO = :EMPCODIGO AND DI.ORCCONTADOR = :ORCCONTADOR ' +
    'ORDER BY DI.ORCITEMORDEM';
end;

class function TMapaOrcamento.MontarSQLServicos: string;
begin
  Result :=
    'SELECT DS.ORCITEMSERVORDEM, ' + MontarSelectCodigoServico +
    'S.SERVDESCRICAO, DS.ORCITEMSERVQTDE, ' +
    'DS.ORCITEMSERVUNITARIO, DS.ORCITEMSERVTOTALLIQUIDO ' +
    'FROM ORCAMENTOITEMSERVICO DS ' +
    'LEFT JOIN SERVICO S ON S.SERVCONTADOR = DS.SERVCONTADOR AND S.EMPCODIGO = DS.EMPCODIGO ' +
    'WHERE DS.EMPCODIGO = :EMPCODIGO AND DS.ORCCONTADOR = :ORCCONTADOR ' +
    'ORDER BY DS.ORCITEMSERVORDEM';
end;

end.
