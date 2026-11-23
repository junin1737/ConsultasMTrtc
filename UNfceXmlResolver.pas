unit UNfceXmlResolver;

interface

uses
  System.SysUtils;

type
  TNfceXmlResolver = class
  public
    class function ObterXmlSomenteBanco(AEmpCodigo, AVenNumero, ATerNumero,
      ANfceNumero: Integer): string;
    class function ObterXml(AEmpCodigo, AVenNumero, ATerNumero,
      ANfceNumero: Integer): string;
  end;

implementation

uses
  System.Classes, System.IOUtils, System.IniFiles, System.Types,
  Data.DB, FireDAC.Comp.Client, FireDAC.Phys.FB, FireDAC.Phys.FBDef,
  UdmConexao;

function ArquivoConfig: string;
begin
  Result := ChangeFileExt(ParamStr(0), '.ini');
end;

function LerCampoXml(AField: TField): string;
var
  Blob: TBlobField;
  Stream: TStringStream;
  Texto: string;
begin
  Result := '';
  if (AField = nil) or AField.IsNull then
    Exit;

  if AField is TBlobField then
  begin
    Blob := TBlobField(AField);
    if Blob.BlobSize = 0 then
      Exit;
    Stream := TStringStream.Create('', TEncoding.UTF8);
    try
      Blob.SaveToStream(Stream);
      Texto := Stream.DataString;
    finally
      Stream.Free;
    end;
    if Trim(Texto) = '' then
    begin
      Stream := TStringStream.Create('', TEncoding.ANSI);
      try
        Blob.SaveToStream(Stream);
        Texto := Stream.DataString;
      finally
        Stream.Free;
      end;
    end;
    Result := Trim(Texto);
  end
  else
    Result := Trim(AField.AsString);
end;

function XmlValido(const AXml: string): Boolean;
begin
  Result := (Trim(AXml) <> '') and
    (Pos('<NFe', AXml) > 0) and
    ((Pos('</NFe>', AXml) > 0) or (Pos('<nfeProc', AXml) > 0));
end;

function SepararHostPath(const ACaminho: string; out AHostPart, ADatabase: string): Boolean;
var
  S, UpperS: string;
  I: Integer;
begin
  Result := False;
  AHostPart := '';
  ADatabase := '';
  S := Trim(ACaminho);
  if S = '' then
    Exit;

  UpperS := UpperCase(S);
  for I := 1 to Length(S) - 2 do
  begin
    if (S[I] = ':') and (UpperS[I + 1] >= 'A') and (UpperS[I + 1] <= 'Z') and (S[I + 2] = '\') then
    begin
      AHostPart := Trim(Copy(S, 1, I - 1));
      ADatabase := Copy(S, I + 1, MaxInt);
      Result := (AHostPart <> '') and (Trim(ADatabase) <> '');
      Exit;
    end;
  end;
end;

procedure ParseHostPorta(const AHostPart: string; out AServer, APorta: string);
var
  P: Integer;
  Host: string;
begin
  Host := Trim(AHostPart);
  APorta := '';
  P := Pos('/', Host);
  if P > 0 then
  begin
    AServer := Trim(Copy(Host, 1, P - 1));
    APorta := Trim(Copy(Host, P + 1, MaxInt));
  end
  else
    AServer := Host;
end;

function ObterCaminhoTerminal(AEmpCodigo, ATerNumero: Integer): string;
var
  Q: TFDQuery;
begin
  Result := '';
  if not dmConexao.Conectado then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT FIRST 1 T.TERCAMINHO FROM TERMINAL T ' +
      'WHERE T.EMPCODIGO = :EMPCODIGO AND T.TERNUMERO = :TERNUMERO';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('TERNUMERO').AsInteger := ATerNumero;
    Q.Open;
    if not Q.IsEmpty then
      Result := Trim(Q.Fields[0].AsString);
  finally
    Q.Free;
  end;
end;

function ObterChaveNfce(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer): string;
var
  Q: TFDQuery;
begin
  Result := '';
  if not dmConexao.Conectado then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT FIRST 1 N.VENRNFCECHAVE, N.VENRNFCEDTTRANSMISSAO, V.VENDTEMISSAO ' +
      'FROM VENDARAPIDANFCE N ' +
      'JOIN VENDARAPIDA V ON V.EMPCODIGO = N.EMPCODIGO AND V.VENNUMERO = N.VENNUMERO ' +
      'AND V.TERNUMERO = N.TERNUMERO ' +
      'WHERE N.EMPCODIGO = :EMPCODIGO AND N.VENNUMERO = :VENNUMERO ' +
      'AND N.TERNUMERO = :TERNUMERO AND N.VENRNFCENUMEROFISCAL = :VENRNFCENUMEROFISCAL';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('VENNUMERO').AsInteger := AVenNumero;
    Q.ParamByName('TERNUMERO').AsInteger := ATerNumero;
    Q.ParamByName('VENRNFCENUMEROFISCAL').AsInteger := ANfceNumero;
    Q.Open;
    if not Q.IsEmpty then
      Result := Trim(Q.FieldByName('VENRNFCECHAVE').AsString);
  finally
    Q.Free;
  end;
end;

function ConfigurarConexaoAuxiliar(AConn: TFDConnection; const AServer, APorta,
  ADatabase, AUser, APassword, ACharset, AClientLibrary, AWireCrypt: string): Boolean;
var
  Driver: TFDPhysFBDriverLink;
  Porta: string;
begin
  Result := False;
  if (Trim(ADatabase) = '') or (Trim(AServer) = '') then
    Exit;

  Driver := TFDPhysFBDriverLink.Create(nil);
  try
    if Trim(AClientLibrary) <> '' then
      Driver.VendorLib := AClientLibrary
    else if dmConexao.FDPhysFBDriverLink1.VendorLib <> '' then
      Driver.VendorLib := dmConexao.FDPhysFBDriverLink1.VendorLib;

    AConn.DriverName := 'FB';
    AConn.LoginPrompt := False;
    AConn.Params.Clear;
    AConn.Params.UserName := AUser;
    AConn.Params.Password := APassword;
    AConn.Params.Add('Server=' + AServer);
    Porta := Trim(APorta);
    if Porta = '' then
      Porta := dmConexao.FDConnection1.Params.Values['Port'];
    if Porta = '' then
      Porta := '3050';
    AConn.Params.Add('Port=' + Porta);
    AConn.Params.Add('Protocol=TCPIP');
    AConn.Params.Add('Database=' + ADatabase);
    if Trim(ACharset) = '' then
      AConn.Params.Add('CharacterSet=WIN1252')
    else
      AConn.Params.Add('CharacterSet=' + ACharset);
    if Trim(AWireCrypt) = '' then
      AConn.Params.Add('WireCrypt=Disabled')
    else
      AConn.Params.Add('WireCrypt=' + AWireCrypt);
    AConn.Params.Add('ConnectTimeout=15');
    AConn.Connected := True;
    Result := AConn.Connected;
  finally
    Driver.Free;
  end;
end;

function TentarXmlQuery(AConn: TFDConnection; AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer): string;
var
  Q: TFDQuery;
begin
  Result := '';
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := AConn;
    Q.SQL.Text :=
      'SELECT FIRST 1 N.VENRNFCEESTRUTURAXML FROM VENDARAPIDANFCE N ' +
      'WHERE N.EMPCODIGO = :EMPCODIGO AND N.VENNUMERO = :VENNUMERO ' +
      'AND N.TERNUMERO = :TERNUMERO AND N.VENRNFCENUMEROFISCAL = :VENRNFCENUMEROFISCAL';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('VENNUMERO').AsInteger := AVenNumero;
    Q.ParamByName('TERNUMERO').AsInteger := ATerNumero;
    Q.ParamByName('VENRNFCENUMEROFISCAL').AsInteger := ANfceNumero;
    Q.Open;
    if not Q.IsEmpty then
      Result := LerCampoXml(Q.Fields[0]);
  finally
    Q.Free;
  end;
end;

function TentarXmlBancoPrincipal(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer): string;
begin
  if not dmConexao.Conectado then
    Exit('');
  Result := TentarXmlQuery(dmConexao.FDConnection1, AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
end;

function TentarXmlBancoTerminal(AEmpCodigo, ATerNumero, AVenNumero,
  ANfceNumero: Integer): string;
var
  TerCaminho, HostPart, Database, Server, Porta: string;
  Conn: TFDConnection;
begin
  Result := '';
  TerCaminho := ObterCaminhoTerminal(AEmpCodigo, ATerNumero);
  if not SepararHostPath(TerCaminho, HostPart, Database) then
    Exit;

  ParseHostPorta(HostPart, Server, Porta);
  Conn := TFDConnection.Create(nil);
  try
    try
      if not ConfigurarConexaoAuxiliar(Conn, Server, Porta, Database,
        dmConexao.FDConnection1.Params.UserName,
        dmConexao.FDConnection1.Params.Password,
        dmConexao.FDConnection1.Params.Values['CharacterSet'],
        '', dmConexao.FDConnection1.Params.Values['WireCrypt']) then
        Exit;
      Result := TentarXmlQuery(Conn, AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
    except
      Result := '';
    end;
  finally
    if Conn.Connected then
      Conn.Connected := False;
    Conn.Free;
  end;
end;

procedure AdicionarPastaUnica(var APastas: TArray<string>; const APasta: string);
var
  Pasta: string;
  I: Integer;
begin
  Pasta := Trim(APasta);
  if (Pasta = '') or (not TDirectory.Exists(Pasta)) then
    Exit;
  for I := 0 to High(APastas) do
    if SameText(APastas[I], Pasta) then
      Exit;
  APastas := APastas + [Pasta];
end;

procedure AdicionarPastasNeo(var APastas: TArray<string>; const ACaminhoBase: string);
const
  SUBPASTAS: array[0..7] of string = (
    'NFCe\Autorizadas',
    'ArquivosNFe\NFCe\Autorizadas',
    'XML\NFCe\Autorizadas',
    'NFe\NFCe\Autorizadas',
    'Dados\NFCe\Autorizadas',
    'NFCe',
    'XML\NFCe',
    'ArquivosNFe\NFCe');
var
  Base, Sub: string;
begin
  Base := Trim(ACaminhoBase);
  if Base = '' then
    Exit;
  Base := IncludeTrailingPathDelimiter(Base);
  AdicionarPastaUnica(APastas, Base);
  for Sub in SUBPASTAS do
    AdicionarPastaUnica(APastas, Base + Sub);
end;

function PastasXmlConfiguradas: TArray<string>;
var
  Ini: TIniFile;
  Lista: string;
  Partes: TArray<string>;
  Parte: string;
begin
  Result := nil;
  if not FileExists(ArquivoConfig) then
    Exit;

  Ini := TIniFile.Create(ArquivoConfig);
  try
    Lista := Trim(Ini.ReadString('NFCe', 'PastaXml', ''));
    if Lista = '' then
      Exit;
    Partes := Lista.Split([';']);
    for Parte in Partes do
      AdicionarPastaUnica(Result, Parte);
  finally
    Ini.Free;
  end;
end;

function MontarPastasXmlBusca(AEmpCodigo, ATerNumero: Integer;
  const AChave: string): TArray<string>;
var
  TerCaminho, HostPart, Database, NeoBase: string;
begin
  Result := PastasXmlConfiguradas;

  TerCaminho := ObterCaminhoTerminal(AEmpCodigo, ATerNumero);
  if SepararHostPath(TerCaminho, HostPart, Database) then
  begin
    NeoBase := ExtractFilePath(Database);
    if SameText(ExtractFileName(ExcludeTrailingPathDelimiter(NeoBase)), 'Dados') then
      NeoBase := ExtractFilePath(ExcludeTrailingPathDelimiter(NeoBase));
    AdicionarPastasNeo(Result, NeoBase);
  end;

  if dmConexao.Conectado then
  begin
    Database := dmConexao.FDConnection1.Params.Values['Database'];
    NeoBase := ExtractFilePath(Database);
    AdicionarPastasNeo(Result, NeoBase);
    AdicionarPastasNeo(Result, ExtractFilePath(ExcludeTrailingPathDelimiter(NeoBase)));
  end;
end;

function TentarLerArquivoXml(const ACaminho: string): string;
begin
  Result := '';
  if (ACaminho = '') or (not TFile.Exists(ACaminho)) then
    Exit;
  Result := Trim(TFile.ReadAllText(ACaminho, TEncoding.UTF8));
  if not XmlValido(Result) then
  begin
    Result := Trim(TFile.ReadAllText(ACaminho, TEncoding.ANSI));
    if not XmlValido(Result) then
      Result := '';
  end;
end;

function TentarXmlArquivo(AEmpCodigo, ATerNumero: Integer; const AChave: string): string;
const
  SUFIXOS: array[0..2] of string = ('-nfe.xml', '-nfce.xml', '-procNFe.xml');
var
  Pastas, VariantesAnoMes: TArray<string>;
  Pasta, Sufixo, Arquivo: string;
  AnoMesChave, AnoMesData: string;
  Encontrados: TStringDynArray;
begin
  Result := '';
  if Trim(AChave) = '' then
    Exit;

  Pastas := MontarPastasXmlBusca(AEmpCodigo, ATerNumero, AChave);
  if Length(Pastas) = 0 then
    Exit;

  AnoMesChave := '';
  AnoMesData := '';
  if Length(AChave) >= 6 then
  begin
    AnoMesChave := Copy(AChave, 3, 4);
    if (Length(AnoMesChave) = 4) and (AnoMesChave[1] = '2') then
      AnoMesData := '20' + AnoMesChave;
  end;

  SetLength(VariantesAnoMes, 0);
  if AnoMesData <> '' then
    VariantesAnoMes := VariantesAnoMes + [AnoMesData];
  if AnoMesChave <> '' then
    VariantesAnoMes := VariantesAnoMes + [AnoMesChave];

  for Pasta in Pastas do
    for Sufixo in SUFIXOS do
    begin
      Arquivo := IncludeTrailingPathDelimiter(Pasta) + AChave + Sufixo;
      Result := TentarLerArquivoXml(Arquivo);
      if XmlValido(Result) then
        Exit;
    end;

  for Pasta in Pastas do
  begin
    for Arquivo in VariantesAnoMes do
      for Sufixo in SUFIXOS do
      begin
        Result := TentarLerArquivoXml(IncludeTrailingPathDelimiter(Pasta) + Arquivo + PathDelim + AChave + Sufixo);
        if XmlValido(Result) then
          Exit;
      end;

    try
      Encontrados := TDirectory.GetFiles(Pasta, AChave + '*.xml', TSearchOption.soAllDirectories);
      for Arquivo in Encontrados do
      begin
        Result := TentarLerArquivoXml(Arquivo);
        if XmlValido(Result) then
          Exit;
      end;
    except
      // ignora pasta inacessivel
    end;
  end;
end;

class function TNfceXmlResolver.ObterXmlSomenteBanco(AEmpCodigo, AVenNumero,
  ATerNumero, ANfceNumero: Integer): string;
begin
  Result := TentarXmlBancoPrincipal(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  if not XmlValido(Result) then
    Result := '';
end;

class function TNfceXmlResolver.ObterXml(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer): string;
var
  Chave: string;
begin
  Result := TentarXmlBancoPrincipal(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  if XmlValido(Result) then
    Exit;

  Result := TentarXmlBancoTerminal(AEmpCodigo, ATerNumero, AVenNumero, ANfceNumero);
  if XmlValido(Result) then
    Exit;

  Chave := ObterChaveNfce(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  Result := TentarXmlArquivo(AEmpCodigo, ATerNumero, Chave);
  if XmlValido(Result) then
    Exit;

  Result := '';
end;

end.
