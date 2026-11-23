unit UMapaDav;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao, UFiltroPeriodoConsulta;

type
  TMapaDav = class
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
  end;

implementation

uses
  UFormatacaoMoeda, UCampoCodigoItem;

class procedure TMapaDav.Inicializar;
begin
  if FInicializado then
    Exit;

  FCampoChave := 'DAVCONTADOR';
  FInicializado := True;
end;

class procedure TMapaDav.GarantirMapa;
begin
  if not FInicializado then
    Inicializar;
end;

class function TMapaDav.CampoChave: string;
begin
  GarantirMapa;
  Result := FCampoChave;
end;

class function TMapaDav.MontarSQLLista(const AFiltro: string;
  const APeriodo: TFiltroPeriodoConsulta): string;
var
  Filtro: string;
  Where: TWhereBuilder;
begin
  GarantirMapa;
  Filtro := Trim(AFiltro);

  Result :=
    'SELECT FIRST 2000 ' +
    'D.EMPCODIGO, D.DAVCONTADOR, D.DAVNUMERO, D.DAVEMISSAO, ' +
    'P.PESNOME AS NOME_CLIENTE, ' +
    'CASE WHEN D.DAVEMISSAO IS NOT NULL THEN D.DAVEMISSAO + 30 ELSE D.DAVDATAENTREGA END AS DAVDATAENTREGA, ' +
    'D.DAVTOTALLIQUIDO ' +
    'FROM DAV D ' +
    'LEFT JOIN CLIENTE C ON C.CLICODIGO = D.CLICODIGO AND C.EMPCODIGO = D.EMPCODIGO ' +
    'LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO ';

  Where.TemWhere := False;
  Where.Text := '';

  if Filtro <> '' then
  begin
    if FiltroSomenteDigitos(Filtro) then
      Where.Adicionar('D.DAVNUMERO = :DOCNUMERO')
    else
      Where.Adicionar('P.PESNOME CONTAINING :FILTRO_TEXTO');
  end;

  Where.Adicionar(MontarCondicaoPeriodo('D.DAVEMISSAO', APeriodo));

  Result := Result + Where.Montar + ' ORDER BY D.DAVEMISSAO DESC, D.DAVNUMERO DESC';
end;

class procedure TMapaDav.ConfigurarParametrosLista(AQuery: TFDQuery; const AFiltro: string;
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

class function TMapaDav.MontarSQLProdutos: string;
begin
  Result :=
    'SELECT DI.DAVITEMORDEM, ' + MontarSelectCodigoProduto +
    'P.PRODDESCRICAO, DI.DAVITEMQTDE, ' +
    'DI.DAVITEMUNITARIO, DI.DAVITEMTOTALLIQUIDO ' +
    'FROM DAVITEM DI ' +
    'LEFT JOIN PRODUTO P ON P.PRODCONTADOR = DI.PRODCONTADOR AND P.EMPCODIGO = DI.EMPCODIGO ' +
    'WHERE DI.EMPCODIGO = :EMPCODIGO AND DI.DAVCONTADOR = :DAVCONTADOR ' +
    'ORDER BY DI.DAVITEMORDEM';
end;

class function TMapaDav.MontarSQLServicos: string;
begin
  Result :=
    'SELECT DS.DAVITEMSERVORDEM, ' + MontarSelectCodigoServico +
    'S.SERVDESCRICAO, DS.DAVITEMSERVQTDE, ' +
    'DS.DAVITEMSERVUNITARIO, DS.DAVITEMSERVTOTALLIQUIDO ' +
    'FROM DAVITEMSERVICO DS ' +
    'LEFT JOIN SERVICO S ON S.SERVCONTADOR = DS.SERVCONTADOR AND S.EMPCODIGO = DS.EMPCODIGO ' +
    'WHERE DS.EMPCODIGO = :EMPCODIGO AND DS.DAVCONTADOR = :DAVCONTADOR ' +
    'ORDER BY DS.DAVITEMSERVORDEM';
end;

end.
