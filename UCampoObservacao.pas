unit UCampoObservacao;

interface

uses
  FireDAC.Comp.Client, UdmConexao;

function CarregarObservacaoTabela(const ANomeTabela, ACampoChave: string;
  AEmpCodigo, AContador: Integer): string;

function CarregarObservacaoDocumento(AQuery: TFDQuery;
  const ANomesPreferidos: array of string; const ANomeTabela, ACampoChave: string;
  AEmpCodigo, AContador: Integer): string;

implementation

uses
  System.SysUtils, System.Classes, Data.DB;

var
  GCacheTabela: string = '';
  GCacheCamposObs: TArray<string>;

function CampoPareceObservacao(const ANome: string): Boolean;
var
  N: string;
begin
  N := UpperCase(Trim(ANome));
  if N = '' then
    Exit(False);

  if (Pos('OBSERV', N) > 0) or (N = 'OBS') or (N = 'OBSERVACAO') then
    Exit(True);

  if (Pos('INFORMACOESADICIONAIS', N) > 0) or (Pos('ADICIONAIS', N) > 0) then
    Exit(True);

  Result := (Length(N) > 3) and SameText(Copy(N, Length(N) - 2, 3), 'OBS');
end;

function ListarCamposObservacao(const ANomeTabela: string): TArray<string>;
var
  Q: TFDQuery;
  Lista: TStringList;
  Nome: string;
  I: Integer;
begin
  Result := nil;
  if not dmConexao.Conectado then
    Exit;

  if SameText(GCacheTabela, ANomeTabela) and (Length(GCacheCamposObs) > 0) then
    Exit(GCacheCamposObs);

  Lista := TStringList.Create;
  try
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
        if CampoPareceObservacao(Nome) then
          Lista.Add(Nome);
        Q.Next;
      end;
    finally
      Q.Free;
    end;

    SetLength(Result, Lista.Count);
    for I := 0 to Lista.Count - 1 do
      Result[I] := Lista[I];
  finally
    Lista.Free;
  end;

  GCacheTabela := UpperCase(ANomeTabela);
  GCacheCamposObs := Result;
end;

function ValorCampoTexto(AQuery: TFDQuery; const ANome: string): string;
var
  Campo: TField;
begin
  Result := '';
  if (AQuery = nil) or (not AQuery.Active) then
    Exit;

  Campo := AQuery.FindField(ANome);
  if (Campo = nil) or Campo.IsNull then
    Exit;

  Result := Trim(Campo.AsString);
end;

function CarregarObservacaoTabela(const ANomeTabela, ACampoChave: string;
  AEmpCodigo, AContador: Integer): string;
var
  Q: TFDQuery;
  Campos: TArray<string>;
  CampoObs: string;
begin
  Result := '';
  if not dmConexao.Conectado then
    Exit;

  Campos := ListarCamposObservacao(ANomeTabela);
  if Length(Campos) = 0 then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    for CampoObs in Campos do
    begin
      Q.Close;
      Q.SQL.Text := Format(
        'SELECT %s AS OBS FROM %s WHERE EMPCODIGO = :EMPCODIGO AND %s = :CONTADOR',
        [CampoObs, UpperCase(ANomeTabela), ACampoChave]);
      Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
      Q.ParamByName('CONTADOR').AsInteger := AContador;
      Q.Open;
      if Q.IsEmpty then
        Continue;
      if not Q.FieldByName('OBS').IsNull then
        Result := Trim(Q.FieldByName('OBS').AsString);
      if Result <> '' then
        Break;
    end;
  finally
    Q.Free;
  end;
end;

function CarregarObservacaoDocumento(AQuery: TFDQuery;
  const ANomesPreferidos: array of string; const ANomeTabela, ACampoChave: string;
  AEmpCodigo, AContador: Integer): string;
var
  Nome: string;
begin
  Result := '';
  if (AQuery <> nil) and AQuery.Active then
    for Nome in ANomesPreferidos do
    begin
      Result := ValorCampoTexto(AQuery, Nome);
      if Result <> '' then
        Exit;
    end;

  Result := CarregarObservacaoTabela(ANomeTabela, ACampoChave, AEmpCodigo, AContador);
end;

end.
