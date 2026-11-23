unit UMapaNotaFiscal;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao, UFiltroPeriodoConsulta,
  UFiltroSituacaoNotaFiscal;

function DescricaoSituacaoNotaFiscal(ASituacao: Integer): string;
function DescricaoSituacaoNotaFiscalDoc(const ASituacaoDoc: string): string;

type
  TMapaNotaFiscal = class
  private
    class var FInicializado: Boolean;
    class var FCampoChave: string;
    class procedure Inicializar;
  public
    class procedure GarantirMapa;
    class function CampoChave: string;
    class function MontarSQLLista(const AFiltro: string;
      const APeriodo: TFiltroPeriodoConsulta;
      const ASituacao: TFiltroSituacaoNotaFiscalConsulta): string;
    class procedure ConfigurarParametrosLista(AQuery: TFDQuery; const AFiltro: string;
      const APeriodo: TFiltroPeriodoConsulta);
    class function MontarSQLProdutos: string;
    class function MontarSQLProdutosImpressao: string;
    class function MontarSQLServicos: string;
  end;

implementation

uses
  UFormatacaoMoeda, UCampoCodigoItem, USituacaoNotaConsulta;

function DescricaoSituacaoNotaFiscal(ASituacao: Integer): string;
begin
  case ASituacao of
    0: Result := 'Normal';
    1: Result := 'Autorizada';
    2: Result := 'Cancelada';
    3: Result := 'Denegada';
  else
    Result := IntToStr(ASituacao);
  end;
end;

function DescricaoSituacaoNotaFiscalDoc(const ASituacaoDoc: string): string;
var
  Cod: string;
begin
  Cod := Trim(ASituacaoDoc);
  if Cod = '00' then
    Exit('Autorizada')
  else if Cod = '02' then
    Exit('Cancelada')
  else if Cod = '03' then
    Exit('Denegada')
  else if (Cod = '04') or (Cod = '05') then
    Exit('Inutilizada')
  else if Cod = '' then
    Exit('')
  else
    Result := Cod;
end;

class procedure TMapaNotaFiscal.Inicializar;
begin
  if FInicializado then
    Exit;

  FCampoChave := 'NFCONTADOR';
  FInicializado := True;
end;

class procedure TMapaNotaFiscal.GarantirMapa;
begin
  if not FInicializado then
    Inicializar;
end;

class function TMapaNotaFiscal.CampoChave: string;
begin
  GarantirMapa;
  Result := FCampoChave;
end;

class function TMapaNotaFiscal.MontarSQLLista(const AFiltro: string;
  const APeriodo: TFiltroPeriodoConsulta;
  const ASituacao: TFiltroSituacaoNotaFiscalConsulta): string;
var
  Filtro: string;
  Where: TWhereBuilder;
begin
  GarantirMapa;
  Filtro := Trim(AFiltro);

  Result :=
    'SELECT FIRST 2000 ' +
    'N.EMPCODIGO, N.NFCONTADOR, N.NFNUMEROFISCAL, N.DOCFNUMERO, ' +
    'N.NFDTEMISSAO, N.NFDTSAIDA, P.PESNOME AS NOME_CLIENTE, ' +
    'N.NFTOTALNOTA, N.NFSITUACAO, N.NFSITUACAODOC, NFEN.NFNFECHAVE AS CHAVE_NFE, ' +
    MontarSelectSituacaoNotaFiscalLista + ' ' +
    'FROM NOTAFISCAL N ' +
    'LEFT JOIN PESSOA P ON P.PESCODIGO = N.PESCODIGO ' +
    'LEFT JOIN NOTAFISCALNFE NFEN ON NFEN.EMPCODIGO = N.EMPCODIGO AND NFEN.NFCONTADOR = N.NFCONTADOR ';

  Where.TemWhere := False;
  Where.Text := '';

  if Filtro <> '' then
  begin
    if FiltroSomenteDigitos(Filtro) then
      Where.Adicionar('N.NFNUMEROFISCAL = :DOCNUMERO')
    else
      Where.Adicionar('P.PESNOME CONTAINING :FILTRO_TEXTO');
  end;

  Where.Adicionar(
    MontarCondicaoPeriodo('COALESCE(N.NFDTEMISSAO, N.NFDTSAIDA)', APeriodo));
  Where.Adicionar(MontarCondicaoSituacaoNotaFiscal(ASituacao));

  Result := Result + Where.Montar + ' ORDER BY N.NFDTEMISSAO DESC, N.NFNUMEROFISCAL DESC';
end;

class procedure TMapaNotaFiscal.ConfigurarParametrosLista(AQuery: TFDQuery; const AFiltro: string;
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

class function TMapaNotaFiscal.MontarSQLProdutos: string;
begin
  Result :=
    'SELECT NI.NFITEMCONTADOR, ' + MontarSelectCodigoProduto +
    'P.PRODDESCRICAO, NI.NFITEMQTDE, ' +
    'NI.NFITEMUNITARIO, NI.NFITEMTOTALLIQUIDO ' +
    'FROM NOTAFISCALITEM NI ' +
    'LEFT JOIN PRODUTO P ON P.PRODCONTADOR = NI.PRODCONTADOR AND P.EMPCODIGO = NI.EMPCODIGO ' +
    'WHERE NI.EMPCODIGO = :EMPCODIGO AND NI.NFCONTADOR = :NFCONTADOR ' +
    'ORDER BY NI.NFITEMCONTADOR';
end;

class function TMapaNotaFiscal.MontarSQLProdutosImpressao: string;
begin
  Result :=
    'SELECT NI.NFITEMCONTADOR, ' + MontarSelectCodigoProduto +
    'P.PRODDESCRICAO, NI.NFITEMQTDE, NI.NFITEMUNITARIO, NI.NFITEMDESCONTO, ' +
    'NI.NFITEMTOTALLIQUIDO, NI.NFITEMBASEICMS, NI.NFITEMVALORICMS, ' +
    'NI.NFITEMBASEICMSST, NI.NFITEMVALORICMSST, NI.NFITEMIPI ' +
    'FROM NOTAFISCALITEM NI ' +
    'LEFT JOIN PRODUTO P ON P.PRODCONTADOR = NI.PRODCONTADOR AND P.EMPCODIGO = NI.EMPCODIGO ' +
    'WHERE NI.EMPCODIGO = :EMPCODIGO AND NI.NFCONTADOR = :NFCONTADOR ' +
    'ORDER BY NI.NFITEMCONTADOR';
end;

class function TMapaNotaFiscal.MontarSQLServicos: string;
begin
  Result :=
    'SELECT NS.NFITEMSERVCONTADOR, ' + MontarSelectCodigoServico +
    'S.SERVDESCRICAO, NS.NFITEMSERVQTDE, ' +
    'NS.NFITEMSERVUNITARIO, NS.NFITEMSERVTOTALLIQUIDO ' +
    'FROM NOTAFISCALITEMSERVICO NS ' +
    'LEFT JOIN SERVICO S ON S.SERVCONTADOR = NS.SERVCONTADOR AND S.EMPCODIGO = NS.EMPCODIGO ' +
    'WHERE NS.EMPCODIGO = :EMPCODIGO AND NS.NFCONTADOR = :NFCONTADOR ' +
    'ORDER BY NS.NFITEMSERVCONTADOR';
end;

end.
