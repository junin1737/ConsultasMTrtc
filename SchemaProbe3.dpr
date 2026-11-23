program SchemaProbe3;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.IniFiles,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Def,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.FB, FireDAC.Phys.FBDef,
  FireDAC.Comp.Client, FireDAC.DApt;

procedure ListarCampos(AConn: TFDConnection; const ATabela: string);
var
  Q: TFDQuery;
begin
  Writeln('=== ' + ATabela + ' ===');
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := AConn;
    Q.SQL.Text :=
      'SELECT TRIM(R.RDB$FIELD_NAME) AS CAMPO ' +
      'FROM RDB$RELATION_FIELDS R ' +
      'WHERE R.RDB$RELATION_NAME = :TABELA ' +
      'ORDER BY R.RDB$FIELD_POSITION';
    Q.ParamByName('TABELA').AsString := UpperCase(ATabela);
    Q.Open;
    while not Q.Eof do
    begin
      Writeln('  ' + Trim(Q.FieldByName('CAMPO').AsString));
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Writeln;
end;

procedure ListarTabelasXml(AConn: TFDConnection);
var
  Q: TFDQuery;
begin
  Writeln('=== Tabelas com XML ou NFE no nome ===');
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := AConn;
    Q.SQL.Text :=
      'SELECT TRIM(RDB$RELATION_NAME) AS NOME ' +
      'FROM RDB$RELATIONS ' +
      'WHERE RDB$SYSTEM_FLAG = 0 AND ' +
      '(RDB$RELATION_NAME CONTAINING ''XML'' OR RDB$RELATION_NAME CONTAINING ''NFE'') ' +
      'ORDER BY 1';
    Q.Open;
    while not Q.Eof do
    begin
      Writeln('  ' + Trim(Q.FieldByName('NOME').AsString));
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Writeln;
end;

var
  Conn: TFDConnection;
  Driver: TFDPhysFBDriverLink;
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
  try
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

    Driver := TFDPhysFBDriverLink.Create(nil);
    Conn := TFDConnection.Create(nil);
    try
      for I := Low(CAMINHOS_FB) to High(CAMINHOS_FB) do
        if FileExists(CAMINHOS_FB[I]) then
        begin
          Driver.VendorLib := CAMINHOS_FB[I];
          Break;
        end;

      Conn.Params.DriverID := 'FB';
      Conn.Params.Database := Db;
      Conn.Params.UserName := User;
      Conn.Params.Password := Pass;
      Conn.Params.Add('CharacterSet=' + Charset);
      if Server <> '' then
        Conn.Params.Add('Server=' + Server);
      if Port <> '' then
        Conn.Params.Add('Port=' + Port);
      Conn.Connected := True;

      ListarTabelasXml(Conn);
      ListarCampos(Conn, 'NOTAFISCALNFE');
      ListarCampos(Conn, 'ENTRADACOMPRA');
      ListarCampos(Conn, 'NOTAFISCALNFEXML');
      ListarCampos(Conn, 'NFXML');
      ListarCampos(Conn, 'NFEXML');
      ListarCampos(Conn, 'DOCUMENTONFEXML');
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
