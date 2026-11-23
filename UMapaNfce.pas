unit UMapaNfce;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao, UFiltroPeriodoConsulta,
  UFiltroSituacaoNotaFiscal;

type
  TMapaNfce = class
  public
    class function MontarSQLLista(const AFiltro: string;
      const APeriodo: TFiltroPeriodoConsulta;
      const ASituacao: TFiltroSituacaoNotaFiscalConsulta): string;
    class procedure ConfigurarParametrosLista(AQuery: TFDQuery; const AFiltro: string;
      const APeriodo: TFiltroPeriodoConsulta);
    class function MontarSQLProdutos: string;
    class function MontarSQLCabecalho: string;
    class function MontarSelectNomeClienteLista: string;
  end;

const
  NFCe_NOME_CLIENTE_FINAL = 'Consumidor final';

implementation

uses
  UFormatacaoMoeda, UCampoCodigoItem, USituacaoNotaConsulta;

class function TMapaNfce.MontarSelectNomeClienteLista: string;
begin
  Result :=
    'CAST(CASE ' +
    'WHEN VC.CLICODIGO IS NULL OR C.PESCODIGO IS NULL OR C.PESCODIGO = 0 THEN ''Consumidor final'' ' +
    'ELSE COALESCE(NULLIF(TRIM(P.PESNOME), ''''), ''Consumidor final'') END ' +
    'AS VARCHAR(120) CHARACTER SET WIN1252) AS NOME_CLIENTE';
end;

class function TMapaNfce.MontarSQLLista(const AFiltro: string;
  const APeriodo: TFiltroPeriodoConsulta;
  const ASituacao: TFiltroSituacaoNotaFiscalConsulta): string;
var
  Filtro: string;
  Where: TWhereBuilder;
begin
  Filtro := Trim(AFiltro);

  Result :=
    'SELECT FIRST 2000 ' +
    'N.EMPCODIGO, V.VENNUMERO, V.TERNUMERO, N.VENRNFCENUMEROFISCAL AS NFCONTADOR, ' +
    'N.VENRNFCENUMEROFISCAL AS NFNUMEROFISCAL, V.VENNUMEROCUPOM AS DOCFNUMERO, ' +
    'V.VENDTEMISSAO AS NFDTEMISSAO, N.VENRNFCEDTTRANSMISSAO AS NFDTSAIDA, ' +
    MontarSelectNomeClienteLista + ', V.VENVALORLIQUIDO AS NFTOTALNOTA, ' +
    'N.VENRNFCESITUACAO AS NFSITUACAO, N.VENRNFCESITUACAODOC AS NFSITUACAODOC, ' +
    'N.VENRNFCECHAVE AS CHAVE_NFE, ' +
    MontarSelectSituacaoNfceLista + ' ' +
    'FROM VENDARAPIDANFCE N ' +
    'JOIN VENDARAPIDA V ON V.EMPCODIGO = N.EMPCODIGO AND V.VENNUMERO = N.VENNUMERO ' +
    'AND V.TERNUMERO = N.TERNUMERO ' +
    'LEFT JOIN VENDARAPIDACLIENTE VC ON VC.EMPCODIGO = V.EMPCODIGO ' +
    'AND VC.VENNUMERO = V.VENNUMERO AND VC.TERNUMERO = V.TERNUMERO ' +
    'LEFT JOIN CLIENTE C ON C.EMPCODIGO = VC.EMPCODIGO AND C.CLICODIGO = VC.CLICODIGO ' +
    'LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO ';

  Where.TemWhere := False;
  Where.Text := '';

  if Filtro <> '' then
  begin
    if FiltroSomenteDigitos(Filtro) then
      Where.Adicionar(
        '(N.VENRNFCENUMEROFISCAL = :DOCNUMERO OR V.VENNUMEROCUPOM = :DOCNUMERO)')
    else
      Where.Adicionar(
        '(P.PESNOME CONTAINING :FILTRO_TEXTO OR ''Consumidor final'' CONTAINING :FILTRO_TEXTO)');
  end;

  Where.Adicionar(
    MontarCondicaoPeriodo('COALESCE(V.VENDTEMISSAO, N.VENRNFCEDTTRANSMISSAO)', APeriodo));
  Where.Adicionar(MontarCondicaoSituacaoNfce(ASituacao));

  Result := Result + Where.Montar +
    ' ORDER BY V.VENDTEMISSAO DESC, N.VENRNFCENUMEROFISCAL DESC';
end;

class procedure TMapaNfce.ConfigurarParametrosLista(AQuery: TFDQuery; const AFiltro: string;
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

class function TMapaNfce.MontarSQLProdutos: string;
begin
  Result :=
    'SELECT I.ITEMNUMEROITEM AS NFITEMCONTADOR, ' + MontarSelectCodigoProduto +
    'P.PRODDESCRICAO, I.ITEMQTDE AS NFITEMQTDE, ' +
    'I.ITEMUNITARIO AS NFITEMUNITARIO, I.ITEMTOTALLIQUIDO AS NFITEMTOTALLIQUIDO ' +
    'FROM ITEMVENDARAPIDA I ' +
    'LEFT JOIN PRODUTO P ON P.PRODCONTADOR = I.PRODCONTADOR AND P.EMPCODIGO = I.EMPCODIGO ' +
    'WHERE I.EMPCODIGO = :EMPCODIGO AND I.VENNUMERO = :VENNUMERO AND I.TERNUMERO = :TERNUMERO ' +
    'ORDER BY I.ITEMNUMEROITEM';
end;

class function TMapaNfce.MontarSQLCabecalho: string;
begin
  Result :=
    'SELECT N.VENRNFCENUMEROFISCAL, V.VENDTEMISSAO, N.VENRNFCEDTTRANSMISSAO, ' +
    'V.VENVALORLIQUIDO, N.VENRNFCEADICIONAIS, ' +
    MontarSelectNomeClienteLista + ', N.VENRNFCECHAVE, C.PESCODIGO ' +
    'FROM VENDARAPIDANFCE N ' +
    'JOIN VENDARAPIDA V ON V.EMPCODIGO = N.EMPCODIGO AND V.VENNUMERO = N.VENNUMERO ' +
    'AND V.TERNUMERO = N.TERNUMERO ' +
    'LEFT JOIN VENDARAPIDACLIENTE VC ON VC.EMPCODIGO = V.EMPCODIGO ' +
    'AND VC.VENNUMERO = V.VENNUMERO AND VC.TERNUMERO = V.TERNUMERO ' +
    'LEFT JOIN CLIENTE C ON C.EMPCODIGO = VC.EMPCODIGO AND C.CLICODIGO = VC.CLICODIGO ' +
    'LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO ' +
    'WHERE N.EMPCODIGO = :EMPCODIGO AND N.VENNUMERO = :VENNUMERO ' +
    'AND N.TERNUMERO = :TERNUMERO AND N.VENRNFCENUMEROFISCAL = :VENRNFCENUMEROFISCAL';
end;

end.
