unit UMapaCompra;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao, UFiltroPeriodoConsulta;

function DescricaoSituacaoCompra(ASituacao: Integer): string;

type
  TMapaCompra = class
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
    class function MontarSQLProdutosImpressao: string;
    class function MontarSQLServicos: string;
  end;

implementation

uses
  UFormatacaoMoeda, UCampoCodigoItem, USituacaoNotaConsulta;

function DescricaoSituacaoCompra(ASituacao: Integer): string;
begin
  case ASituacao of
    0: Result := 'Normal';
    1: Result := 'Confirmada';
    2: Result := 'Cancelada';
  else
    Result := IntToStr(ASituacao);
  end;
end;

class procedure TMapaCompra.Inicializar;
begin
  if FInicializado then
    Exit;

  FCampoChave := 'ENTCCONTADOR';
  FInicializado := True;
end;

class procedure TMapaCompra.GarantirMapa;
begin
  if not FInicializado then
    Inicializar;
end;

class function TMapaCompra.CampoChave: string;
begin
  GarantirMapa;
  Result := FCampoChave;
end;

class function TMapaCompra.MontarSQLLista(const AFiltro: string;
  const APeriodo: TFiltroPeriodoConsulta): string;
var
  Filtro: string;
  Where: TWhereBuilder;
begin
  GarantirMapa;
  Filtro := Trim(AFiltro);

  Result :=
    'SELECT FIRST 2000 ' +
    'E.EMPCODIGO, E.ENTCCONTADOR, E.ENTCNUMERO, E.ENTCSERIE, ' +
    'E.ENTCDTEMISSAO, E.ENTCDTENTRADA, P.PESNOME AS NOME_FORNECEDOR, ' +
    'E.ENTCVRTOTAL, E.ENTCSITUACAO, E.ENTCSITUACAODOCUMENTO, E.ENTCCHAVENFE, ' +
    MontarSelectSituacaoCompraLista + ' ' +
    'FROM ENTRADACOMPRA E ' +
    'LEFT JOIN FORNECEDOR F ON F.FORCODIGO = E.FORCODIGO AND F.EMPCODIGO = E.EMPCODIGO ' +
    'LEFT JOIN PESSOA P ON P.PESCODIGO = F.PESCODIGO ';

  Where.TemWhere := False;
  Where.Text := '';

  if Filtro <> '' then
  begin
    if FiltroSomenteDigitos(Filtro) then
      Where.Adicionar('E.ENTCNUMERO = :DOCNUMERO')
    else
      Where.Adicionar('P.PESNOME CONTAINING :FILTRO_TEXTO');
  end;

  Where.Adicionar(
    MontarCondicaoPeriodo('COALESCE(E.ENTCDTENTRADA, E.ENTCDTEMISSAO)', APeriodo));

  Result := Result + Where.Montar + ' ORDER BY E.ENTCDTEMISSAO DESC, E.ENTCNUMERO DESC';
end;

class procedure TMapaCompra.ConfigurarParametrosLista(AQuery: TFDQuery; const AFiltro: string;
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

class function TMapaCompra.MontarSQLProdutos: string;
begin
  Result :=
    'SELECT EI.ENTCINUMEROITEM, ' + MontarSelectCodigoProduto +
    'P.PRODDESCRICAO, EI.ENTCIQTDE, ' +
    'EI.ENTCIVRUNITARIO, EI.ENTCIVRTOTALLIQUIDO ' +
    'FROM ENTRADACOMPRAITEM EI ' +
    'LEFT JOIN PRODUTO P ON P.PRODCONTADOR = EI.PRODCONTADOR AND P.EMPCODIGO = EI.EMPCODIGO ' +
    'WHERE EI.EMPCODIGO = :EMPCODIGO AND EI.ENTCCONTADOR = :ENTCCONTADOR ' +
    'ORDER BY EI.ENTCINUMEROITEM';
end;

class function TMapaCompra.MontarSQLProdutosImpressao: string;
begin
  Result :=
    'SELECT EI.ENTCINUMEROITEM, ' + MontarSelectCodigoProduto +
    'P.PRODDESCRICAO, EI.ENTCIQTDE, EI.ENTCIVRUNITARIO, EI.ENTCIVRDESCONTO, ' +
    'EI.ENTCIVRTOTALLIQUIDO, EI.ENTCIVRBASECALCULO, EI.ENTCIVRICMS, ' +
    'EI.ENTCIVRBASECALCULOST, EI.ENTCIVRICMSST, EI.ENTCIIPI ' +
    'FROM ENTRADACOMPRAITEM EI ' +
    'LEFT JOIN PRODUTO P ON P.PRODCONTADOR = EI.PRODCONTADOR AND P.EMPCODIGO = EI.EMPCODIGO ' +
    'WHERE EI.EMPCODIGO = :EMPCODIGO AND EI.ENTCCONTADOR = :ENTCCONTADOR ' +
    'ORDER BY EI.ENTCINUMEROITEM';
end;

class function TMapaCompra.MontarSQLServicos: string;
begin
  Result :=
    'SELECT ES.ENTCISERVITEM, ' + MontarSelectCodigoServico +
    'S.SERVDESCRICAO, ES.ENTCISERVQTDE, ' +
    'ES.ENTCISERVUNITARIO, ES.ENTCISERVTOTALLIQUIDO ' +
    'FROM ENTRADACOMPRAITEMSERVICO ES ' +
    'LEFT JOIN SERVICO S ON S.SERVCONTADOR = ES.SERVCONTADOR AND S.EMPCODIGO = ES.EMPCODIGO ' +
    'WHERE ES.EMPCODIGO = :EMPCODIGO AND ES.ENTCCONTADOR = :ENTCCONTADOR ' +
    'ORDER BY ES.ENTCISERVITEM';
end;

end.
