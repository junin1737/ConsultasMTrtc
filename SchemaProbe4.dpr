program SchemaProbe4;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.IniFiles,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Def,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.FB, FireDAC.Phys.FBDef,
  FireDAC.Comp.Client, FireDAC.DApt;

procedure Conectar(out AConn: TFDConnection; out ADriver: TFDPhysFBDriverLink);
var
  Ini: TIniFile;
  Db, Server, Port, User, Pass, Charset: string;
  I: Integer;
const
  CAMINHOS_FB: array[0..5] of string = (
    'C:\Program Files\Firebird\Firebird_5_0\fbclient.dll',
    'C:\Program Files\Firebird\Firebird_5_0\WOW64\fbclient.dll',
    'C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll',
    'C:\Program Files\Firebird\Firebird_4_0\fbclient.dll',
    'C:\Program Files\Firebird\Firebird_3_0\fbclient.dll',
    'C:\Program Files (x86)\Firebird\Firebird_3_0\fbclient.dll'
  );
begin
  Ini := TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Consultas.ini');
  try
    Db := Ini.ReadString('Banco', 'Database', 'C:\Work\Realtec.FDB');
    Server := Ini.ReadString('Banco', 'Server', '127.0.0.1');
    Port := Ini.ReadString('Banco', 'Port', '3052');
    User := Ini.ReadString('Banco', 'User_Name', 'SYSDBA');
    Pass := Ini.ReadString('Banco', 'Password', 'masterkey');
    Charset := Ini.ReadString('Banco', 'CharacterSet', 'WIN1252');
  finally
    Ini.Free;
  end;

  if (Charset = '') or SameText(Charset, 'UTF8') then
    Charset := 'WIN1252';

  ADriver := TFDPhysFBDriverLink.Create(nil);
  AConn := TFDConnection.Create(nil);
  for I := Low(CAMINHOS_FB) to High(CAMINHOS_FB) do
    if FileExists(CAMINHOS_FB[I]) then
    begin
      ADriver.VendorLib := CAMINHOS_FB[I];
      Break;
    end;

  AConn.Params.DriverID := 'FB';
  AConn.Params.Database := Db;
  AConn.Params.UserName := User;
  AConn.Params.Password := Pass;
  AConn.Params.Add('CharacterSet=' + Charset);
  if Server <> '' then
    AConn.Params.Add('Server=' + Server);
  if Port <> '' then
    AConn.Params.Add('Port=' + Port);
  AConn.Connected := True;
end;

procedure TestarCampoXml(AConn: TFDConnection; const ASQL, ALabel: string);
var
  Q: TFDQuery;
  S: string;
begin
  Writeln('--- ' + ALabel + ' ---');
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := AConn;
    Q.SQL.Text := ASQL;
    Q.Open;
    if Q.IsEmpty then
    begin
      Writeln('  (vazio)');
      Exit;
    end;
    S := Trim(Q.Fields[0].AsString);
    if S = '' then
      Writeln('  campo NULL/vazio')
    else
    begin
      Writeln('  tamanho: ' + IntToStr(Length(S)));
      if Length(S) > 200 then
        Writeln('  inicio: ' + Copy(S, 1, 200))
      else
        Writeln('  conteudo: ' + S);
    end;
  except
    on E: Exception do
      Writeln('  ERRO: ' + E.Message);
  end;
  Q.Free;
end;

var
  Conn: TFDConnection;
  Driver: TFDPhysFBDriverLink;
begin
  try
    Conectar(Conn, Driver);
    try
      TestarCampoXml(Conn,
        'SELECT FIRST 1 NF.NFNFEESTRUTURAXML FROM NOTAFISCALNFE NF ' +
        'WHERE NF.NFNFEESTRUTURAXML IS NOT NULL AND NF.NFNFEESTRUTURAXML <> ''''',
        'NOTAFISCALNFE.NFNFEESTRUTURAXML');
      TestarCampoXml(Conn,
        'SELECT FIRST 1 E.ENTCXMLCORPO FROM ENTRADACOMPRA E ' +
        'WHERE E.ENTCXMLCORPO IS NOT NULL AND E.ENTCXMLCORPO <> ''''',
        'ENTRADACOMPRA.ENTCXMLCORPO');
      TestarCampoXml(Conn,
        'SELECT FIRST 1 R.* FROM REPOSITORIOXML R',
        'REPOSITORIOXML first row');
    finally
      Conn.Free;
      Driver.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln('ERRO: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
