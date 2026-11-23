unit UMapaPessoas;

interface

uses
  System.SysUtils, System.Classes, Data.DB, FireDAC.Comp.Client, FireDAC.DApt, UdmConexao;

type
  TEnderecoPessoa = record
    Logradouro: string;
    Numero: string;
    Complemento: string;
    Bairro: string;
    Cidade: string;
    Uf: string;
    Cep: string;
  end;

  TDetalhePessoa = record
    Codigo: string;
    Nome: string;
    CpfCnpj: string;
    InscricaoEstadual: string;
    Endereco: string;
    Numero: string;
    Bairro: string;
    Cidade: string;
    Uf: string;
    Cep: string;
    Telefone: string;
    Celular: string;
  end;

  TMapaPessoas = class
  private
    class var FInicializado: Boolean;
    class var FCampoChave: string;
    class var FCampoNome: string;
    class var FCampoCpfCnpj: string;
    class var FCampoRg: string;
    class var FCampoIE: string;
    class var FCampoEndereco: string;
    class var FCampoNumero: string;
    class var FCampoBairro: string;
    class var FCampoCidade: string;
    class var FCampoUf: string;
    class var FCampoCep: string;
    class var FCampoTelefone: string;
    class var FCampoCelular: string;
    class var FCampoFax: string;
    class var FCampoEmail: string;
    class var FCampoLimite: string;
    class var FCampoObs: string;
    class procedure Inicializar;
    class function ValorCampo(AQuery: TFDQuery; const ACampo: string): string;
  public
    class procedure GarantirMapa;
    class function CampoChave: string;
    class function CampoPesquisa: string;
    class function CarregarEndereco(AEmpCodigo, APesCodigo: Integer): TEnderecoPessoa;
    class function CarregarDetalhe(const AValorChave: string; AEmpCodigo: Integer = 0): TDetalhePessoa;
  end;

implementation

uses
  UFormatacaoMoeda;

class procedure TMapaPessoas.Inicializar;
var
  Q: TFDQuery;
  Campos: TStringList;
  I: Integer;
  Nome: string;

  function Contem(const ALista: array of string): Boolean;
  var
    Item: string;
  begin
    Result := False;
    for Item in ALista do
      if Nome = UpperCase(Item) then
        Exit(True);
  end;

begin
  if FInicializado then
    Exit;

  Campos := TStringList.Create;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT TRIM(R.RDB$FIELD_NAME) AS CAMPO ' +
      'FROM RDB$RELATION_FIELDS R ' +
      'WHERE R.RDB$RELATION_NAME = ''PESSOA'' ' +
      'ORDER BY R.RDB$FIELD_POSITION';
    Q.Open;
    while not Q.Eof do
    begin
      Campos.Add(UpperCase(Trim(Q.FieldByName('CAMPO').AsString)));
      Q.Next;
    end;

    for I := 0 to Campos.Count - 1 do
    begin
      Nome := Campos[I];
      if (FCampoChave = '') and ((Nome = 'CODIGO') or (Pos('CODIGO', Nome) > 0)) then
        FCampoChave := Campos[I];
      if (FCampoNome = '') and (Pos('NOME', Nome) > 0) and (Pos('FANTASIA', Nome) = 0) then
        FCampoNome := Campos[I];
      if (FCampoCpfCnpj = '') and Contem(['PESCNPJCPF', 'CNPJ_CPF', 'CPF_CNPJ', 'CGC', 'CNPJ', 'CPF']) then
        FCampoCpfCnpj := Campos[I];
      if (FCampoRg = '') and Contem(['RG', 'PES_RG', 'DOC_RG']) then
        FCampoRg := Campos[I];
      if (FCampoIE = '') and Contem(['INSCRICAO_ESTADUAL', 'IE', 'PES_IE', 'INSC_ESTADUAL', 'INSC_EST']) then
        FCampoIE := Campos[I];
      if (FCampoEndereco = '') and Contem(['PESENDERECO', 'ENDERECO', 'ENDER', 'LOGRADOURO', 'RUA', 'PES_ENDERECO']) then
        FCampoEndereco := Campos[I];
      if (FCampoNumero = '') and Contem(['PESNUMERO', 'NUMERO', 'NUM', 'NRO', 'NUM_END']) then
        FCampoNumero := Campos[I];
      if (FCampoBairro = '') and Contem(['PESBAIRRO', 'BAIRRO', 'PES_BAIRRO']) then
        FCampoBairro := Campos[I];
      if (FCampoCidade = '') and Contem(['PESCIDADE', 'CIDADE', 'MUNICIPIO', 'PES_CIDADE']) then
        FCampoCidade := Campos[I];
      if (FCampoUf = '') and Contem(['PESUF', 'UF', 'ESTADO', 'PES_UF']) then
        FCampoUf := Campos[I];
      if (FCampoCep = '') and Contem(['PESCEP', 'CEP', 'PES_CEP']) then
        FCampoCep := Campos[I];
      if (FCampoTelefone = '') and Contem(['PESFONE', 'PESTELEFONE', 'TELEFONE', 'FONE', 'TEL', 'FONE1', 'PES_FONE']) then
        FCampoTelefone := Campos[I];
      if (FCampoCelular = '') and Contem(['PESCELULAR', 'CELULAR', 'CEL', 'FONE2', 'PES_CELULAR']) then
        FCampoCelular := Campos[I];
      if (FCampoFax = '') and Contem(['FAX', 'PES_FAX']) then
        FCampoFax := Campos[I];
      if (FCampoEmail = '') and Contem(['EMAIL', 'E_MAIL', 'PES_EMAIL']) then
        FCampoEmail := Campos[I];
      if (FCampoLimite = '') and
         ((Pos('LIMITE', Nome) > 0) and (Pos('CRED', Nome) > 0)) then
        FCampoLimite := Campos[I];
      if (FCampoObs = '') and Contem(['OBSERVACAO', 'OBSERVACOES', 'OBS', 'PES_OBS', 'OBSERV']) then
        FCampoObs := Campos[I];
    end;

    if Campos.IndexOf('PESCODIGO') >= 0 then
      FCampoChave := 'PESCODIGO';
    if Campos.IndexOf('PESNOME') >= 0 then
      FCampoNome := 'PESNOME';
    if Campos.IndexOf('PESCNPJCPF') >= 0 then
      FCampoCpfCnpj := 'PESCNPJCPF';
    if Campos.IndexOf('PESIE') >= 0 then
      FCampoIE := 'PESIE';
    if Campos.IndexOf('PESFONE') >= 0 then
      FCampoTelefone := 'PESFONE';
    if Campos.IndexOf('PESCELULAR') >= 0 then
      FCampoCelular := 'PESCELULAR';
    if Campos.IndexOf('PESENDERECO') >= 0 then
      FCampoEndereco := 'PESENDERECO';
    if Campos.IndexOf('PESNUMERO') >= 0 then
      FCampoNumero := 'PESNUMERO';
    if Campos.IndexOf('PESBAIRRO') >= 0 then
      FCampoBairro := 'PESBAIRRO';
    if Campos.IndexOf('PESCIDADE') >= 0 then
      FCampoCidade := 'PESCIDADE';
    if Campos.IndexOf('PESUF') >= 0 then
      FCampoUf := 'PESUF';
    if Campos.IndexOf('PESCEP') >= 0 then
      FCampoCep := 'PESCEP';

    if FCampoChave = '' then
    begin
      if Campos.Count > 0 then
        FCampoChave := Campos[0];
    end;
    if FCampoNome = '' then
    begin
      for I := 0 to Campos.Count - 1 do
        if (Campos[I] = 'RAZAO_SOCIAL') or (Campos[I] = 'PES_NOME') or (Campos[I] = 'NOME') then
        begin
          FCampoNome := Campos[I];
          Break;
        end;
    end;
    if FCampoLimite = '' then
    begin
      for I := 0 to Campos.Count - 1 do
        if (Pos('LIMITE', Campos[I]) > 0) or
           ((Pos('CRED', Campos[I]) > 0) and (Pos('LIM', Campos[I]) > 0)) then
        begin
          FCampoLimite := Campos[I];
          Break;
        end;
    end;
  finally
    Q.Free;
    Campos.Free;
  end;

  FInicializado := True;
end;

class procedure TMapaPessoas.GarantirMapa;
begin
  if not dmConexao.Conectado then
    raise Exception.Create('Banco de dados não conectado.');
  Inicializar;
end;

class function TMapaPessoas.CampoChave: string;
begin
  GarantirMapa;
  Result := FCampoChave;
end;

class function TMapaPessoas.CampoPesquisa: string;
begin
  GarantirMapa;
  Result := FCampoNome;
end;

class function TMapaPessoas.ValorCampo(AQuery: TFDQuery; const ACampo: string): string;
var
  F: TField;
begin
  Result := '';
  if ACampo = '' then
    Exit;
  F := AQuery.FindField(ACampo);
  if F = nil then
    F := AQuery.FindField(UpperCase(ACampo));
  if (F <> nil) and not F.IsNull then
    Result := Trim(F.AsString);
end;

class function TMapaPessoas.CarregarEndereco(AEmpCodigo, APesCodigo: Integer): TEnderecoPessoa;

  procedure PreencherEndereco(AQuery: TFDQuery);
  begin
    Result.Logradouro := ValorCampo(AQuery, 'LOGRLOGRADOURO');
    Result.Numero := ValorCampo(AQuery, 'PESENDNUMERO');
    Result.Complemento := ValorCampo(AQuery, 'PESENDCOMPLEMENTO');
    Result.Bairro := ValorCampo(AQuery, 'BAIBAIRRO');
    Result.Cidade := ValorCampo(AQuery, 'MUNMUNICIPIO');
    Result.Uf := ValorCampo(AQuery, 'MUNUF');
    Result.Cep := FormatarCep(ValorCampo(AQuery, 'PESENDCEP'));
  end;

var
  Q: TFDQuery;
begin
  FillChar(Result, SizeOf(Result), 0);
  if (APesCodigo <= 0) or not dmConexao.Conectado then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT FIRST 1 ' +
      'L.LOGRLOGRADOURO, PE.PESENDNUMERO, PE.PESENDCOMPLEMENTO, ' +
      'B.BAIBAIRRO, M.MUNMUNICIPIO, M.MUNUF, PE.PESENDCEP ' +
      'FROM PESSOAENDERECO PE ' +
      'LEFT JOIN LOGRADOURO L ON L.LOGRCODIGO = PE.LOGRCODIGO ' +
      'LEFT JOIN BAIRRO B ON B.BAICODIGO = PE.BAICODIGO ' +
      'LEFT JOIN MUNICIPIO M ON M.MUNCODIGO = PE.MUNCODIGO ' +
      'WHERE PE.PESCODIGO = :PESCODIGO ' +
      'AND COALESCE(PE.PESENDATIVO, 1) = 1 ' +
      'AND (:EMPCODIGO = 0 OR PE.EMPCODIGO = :EMPCODIGO) ' +
      'ORDER BY PE.PESENDCONTADOR';
    Q.ParamByName('PESCODIGO').AsInteger := APesCodigo;
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.Open;
    if not Q.IsEmpty then
    begin
      PreencherEndereco(Q);
      Exit;
    end;

    Q.Close;
    Q.SQL.Text :=
      'SELECT FIRST 1 ' +
      'L.LOGRLOGRADOURO, PE.PESENDNUMERO, PE.PESENDCOMPLEMENTO, ' +
      'B.BAIBAIRRO, M.MUNMUNICIPIO, M.MUNUF, PE.PESENDCEP ' +
      'FROM PESSOAENDERECO PE ' +
      'LEFT JOIN LOGRADOURO L ON L.LOGRCODIGO = PE.LOGRCODIGO ' +
      'LEFT JOIN BAIRRO B ON B.BAICODIGO = PE.BAICODIGO ' +
      'LEFT JOIN MUNICIPIO M ON M.MUNCODIGO = PE.MUNCODIGO ' +
      'WHERE PE.PESCODIGO = :PESCODIGO ' +
      'AND COALESCE(PE.PESENDATIVO, 1) = 1 ' +
      'ORDER BY PE.PESENDCONTADOR';
    Q.ParamByName('PESCODIGO').AsInteger := APesCodigo;
    Q.Open;
    if not Q.IsEmpty then
      PreencherEndereco(Q);
  finally
    Q.Free;
  end;
end;

class function TMapaPessoas.CarregarDetalhe(const AValorChave: string; AEmpCodigo: Integer): TDetalhePessoa;
var
  Q: TFDQuery;
  SQL, CamposSQL: string;
  Lista: TStringList;
  Endereco: TEnderecoPessoa;
  PesCodigo, EmpCodigo: Integer;

  procedure AdicionarCampo(const ACampo: string);
  begin
    if (ACampo <> '') and (Lista.IndexOf(UpperCase(ACampo)) < 0) then
      Lista.Add(ACampo);
  end;

begin
  FillChar(Result, SizeOf(Result), 0);
  GarantirMapa;

  Lista := TStringList.Create;
  Q := TFDQuery.Create(nil);
  try
    AdicionarCampo(FCampoChave);
    AdicionarCampo(FCampoNome);
    AdicionarCampo(FCampoCpfCnpj);
    AdicionarCampo(FCampoIE);
    AdicionarCampo(FCampoTelefone);
    AdicionarCampo(FCampoCelular);
    AdicionarCampo('EMPCODIGO');

    CamposSQL := Lista.CommaText;
    CamposSQL := StringReplace(CamposSQL, '"', '', [rfReplaceAll]);

    SQL := Format('SELECT FIRST 1 %s FROM PESSOA WHERE %s = :CHAVE',
      [CamposSQL, FCampoChave]);

    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text := SQL;
    Q.ParamByName('CHAVE').Value := AValorChave;
    Q.Open;

    if Q.IsEmpty then
      Exit;

    Result.Codigo := ValorCampo(Q, FCampoChave);
    Result.Nome := ValorCampo(Q, FCampoNome);
    Result.CpfCnpj := FormatarCpfCnpj(ValorCampo(Q, FCampoCpfCnpj));
    Result.InscricaoEstadual := ValorCampo(Q, FCampoIE);
    Result.Telefone := FormatarTelefone(ValorCampo(Q, FCampoTelefone));
    Result.Celular := FormatarTelefone(ValorCampo(Q, FCampoCelular));

    PesCodigo := StrToIntDef(Result.Codigo, 0);
    EmpCodigo := AEmpCodigo;
    if EmpCodigo <= 0 then
      EmpCodigo := StrToIntDef(ValorCampo(Q, 'EMPCODIGO'), 0);

    Endereco := CarregarEndereco(EmpCodigo, PesCodigo);
    Result.Endereco := Endereco.Logradouro;
    Result.Numero := Endereco.Numero;
    Result.Bairro := Endereco.Bairro;
    Result.Cidade := Endereco.Cidade;
    Result.Uf := Endereco.Uf;
    Result.Cep := Endereco.Cep;
  finally
    Q.Free;
    Lista.Free;
  end;
end;

end.
