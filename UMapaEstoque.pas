unit UMapaEstoque;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao;

type
  TDetalheProduto = record
    Encontrado: Boolean;
    EmpCodigo: Integer;
    ProdContador: Integer;
    Codigo: string;
    Descricao: string;
    Estoque: string;
    PrecoVarejo: string;
    PrecoAtacado: string;
    EstoqueMinimo: string;
  end;

  TMapaEstoque = class
  public
    class function MontarSQLLista(const AFiltro: string): string;
    class procedure ConfigurarParametrosLista(AQuery: TFDQuery; const AFiltro: string);
    class function CarregarDetalhe(AEmpCodigo, AProdContador: Integer): TDetalheProduto;
  end;

implementation

uses
  Data.DB, UFormatacaoMoeda, UCampoCodigoItem;

class function TMapaEstoque.MontarSQLLista(const AFiltro: string): string;
var
  Filtro, CampoCodigo: string;
begin
  Filtro := Trim(AFiltro);
  CampoCodigo := MontarSelectCodigoProduto;
  if CampoCodigo = '' then
    CampoCodigo := 'P.PRODCODFABRICANTE AS CODIGO_ITEM, ';

  Result :=
    'SELECT FIRST 2000 ' +
    'P.EMPCODIGO, P.PRODCONTADOR, ' + CampoCodigo +
    'P.PRODDESCRICAO, P.PRODESTOQUE, P.PRODPRECOVAREJO ' +
    'FROM PRODUTO P ';

  if Filtro <> '' then
  begin
    if FiltroSomenteDigitos(Filtro) then
      Result := Result + 'WHERE P.PRODCONTADOR = :DOCNUMERO '
    else
      Result := Result +
        'WHERE (P.PRODDESCRICAO CONTAINING :FILTRO_TEXTO ' +
        'OR P.PRODCODFABRICANTE CONTAINING :FILTRO_TEXTO) ';
  end;

  Result := Result + 'ORDER BY P.PRODDESCRICAO';
end;

class procedure TMapaEstoque.ConfigurarParametrosLista(AQuery: TFDQuery; const AFiltro: string);
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

class function TMapaEstoque.CarregarDetalhe(AEmpCodigo, AProdContador: Integer): TDetalheProduto;
var
  Q: TFDQuery;
  CampoCodigo: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.EmpCodigo := AEmpCodigo;
  Result.ProdContador := AProdContador;

  CampoCodigo := MontarSelectCodigoProduto;
  if CampoCodigo = '' then
    CampoCodigo := 'P.PRODCODFABRICANTE AS CODIGO_ITEM, ';

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT FIRST 1 P.EMPCODIGO, P.PRODCONTADOR, ' + CampoCodigo +
      'P.PRODDESCRICAO, P.PRODESTOQUE, P.PRODPRECOVAREJO, P.PRODPRECOATACADO, ' +
      'P.PRODESTOQUESEGURANCA ' +
      'FROM PRODUTO P ' +
      'WHERE P.EMPCODIGO = :EMPCODIGO AND P.PRODCONTADOR = :PRODCONTADOR';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('PRODCONTADOR').AsInteger := AProdContador;
    Q.Open;
    if Q.IsEmpty then
      Exit;

    Result.Encontrado := True;
    if Q.FindField('CODIGO_ITEM') <> nil then
      Result.Codigo := Trim(Q.FieldByName('CODIGO_ITEM').AsString)
    else
      Result.Codigo := Trim(Q.FieldByName('PRODCODFABRICANTE').AsString);
    Result.Descricao := Trim(Q.FieldByName('PRODDESCRICAO').AsString);
    Result.Estoque := FormatarQuantidade(Q.FieldByName('PRODESTOQUE').AsFloat);
    Result.PrecoVarejo := FormatarMoedaBRL(Q.FieldByName('PRODPRECOVAREJO').AsFloat);
    Result.PrecoAtacado := FormatarMoedaBRL(Q.FieldByName('PRODPRECOATACADO').AsFloat);
    Result.EstoqueMinimo := FormatarQuantidade(Q.FieldByName('PRODESTOQUESEGURANCA').AsFloat);
  finally
    Q.Free;
  end;
end;

end.
