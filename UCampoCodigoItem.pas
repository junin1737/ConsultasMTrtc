unit UCampoCodigoItem;

interface

function MontarSelectCodigoProduto: string;
function MontarSelectCodigoServico: string;

implementation

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, UdmConexao;

var
  GCacheTabela: string = '';
  GCacheCampo: string = '';
  GCachePronto: Boolean = False;

function CarregarCamposTabela(const ANomeTabela: string): TStringList;
var
  Q: TFDQuery;
  Nome: string;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  if not dmConexao.Conectado then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT TRIM(R.RDB$FIELD_NAME) AS CAMPO ' +
      'FROM RDB$RELATION_FIELDS R ' +
      'WHERE R.RDB$RELATION_NAME = :TABELA ' +
      'ORDER BY R.RDB$FIELD_POSITION';
    Q.ParamByName('TABELA').AsString := UpperCase(ANomeTabela);
    Q.Open;
    while not Q.Eof do
    begin
      Nome := Trim(Q.FieldByName('CAMPO').AsString);
      if Nome <> '' then
        Result.Add(Nome);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function DescobrirCampoPorLista(const ANomeTabela: string;
  const ACandidatos, AEvitar: array of string): string;
var
  Campos: TStringList;
  I, J: Integer;
  Nome, Evitar: string;
  Ok: Boolean;
begin
  Result := '';
  if not dmConexao.Conectado then
    Exit;

  if GCachePronto and SameText(GCacheTabela, UpperCase(ANomeTabela)) then
    Exit(GCacheCampo);

  Campos := CarregarCamposTabela(ANomeTabela);
  try
    for I := Low(ACandidatos) to High(ACandidatos) do
    begin
      Nome := UpperCase(ACandidatos[I]);
      if Campos.IndexOf(Nome) < 0 then
        Continue;

      Ok := True;
      for J := Low(AEvitar) to High(AEvitar) do
      begin
        Evitar := UpperCase(AEvitar[J]);
        if Nome = Evitar then
        begin
          Ok := False;
          Break;
        end;
      end;

      if Ok then
      begin
        Result := Campos.Strings[Campos.IndexOf(Nome)];
        Break;
      end;
    end;

    if Result = '' then
    begin
      for I := 0 to Campos.Count - 1 do
      begin
        Nome := UpperCase(Campos[I]);
        if (Pos('COD', Nome) > 0) or (Pos('REFER', Nome) > 0) then
        begin
          Ok := True;
          for J := Low(AEvitar) to High(AEvitar) do
            if Nome = UpperCase(AEvitar[J]) then
              Ok := False;
          if Ok then
          begin
            Result := Campos.Strings[I];
            Break;
          end;
        end;
      end;
    end;
  finally
    Campos.Free;
  end;

  GCacheTabela := UpperCase(ANomeTabela);
  GCacheCampo := Result;
  GCachePronto := True;
end;

function DescobrirCampoCodigoProduto: string;
const
  CANDIDATOS: array[0..6] of string = (
    'PRODCODIGO', 'PRODCOD', 'PRODREFERENCIA', 'REFERENCIA', 'CODPROD', 'CODIGO', 'COD');
  EVITAR: array[0..4] of string = (
    'PRODCONTADOR', 'PRODDESCRICAO', 'PRODNOME', 'EMPCODIGO', 'PRODUNIDADE');
begin
  Result := DescobrirCampoPorLista('PRODUTO', CANDIDATOS, EVITAR);
end;

function DescobrirCampoCodigoServico: string;
const
  CANDIDATOS: array[0..4] of string = (
    'SERVCODIGO', 'SERVCOD', 'CODIGO', 'COD', 'REFERENCIA');
  EVITAR: array[0..3] of string = (
    'SERVCONTADOR', 'SERVDESCRICAO', 'SERVNOME', 'EMPCODIGO');
begin
  Result := DescobrirCampoPorLista('SERVICO', CANDIDATOS, EVITAR);
end;

function MontarSelectCodigoProduto: string;
var
  Campo: string;
begin
  Campo := DescobrirCampoCodigoProduto;
  if Campo = '' then
    Exit('');
  Result := 'P.' + Campo + ' AS CODIGO_ITEM, ';
end;

function MontarSelectCodigoServico: string;
var
  Campo: string;
begin
  Campo := DescobrirCampoCodigoServico;
  if Campo = '' then
    Exit('');
  Result := 'S.' + Campo + ' AS CODIGO_ITEM, ';
end;

end.
