program SchemaProbe;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.IniFiles, System.Classes,
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

procedure ListarTabelas(AConn: TFDConnection; const AFiltro: string);
var
  Q: TFDQuery;
begin
  Writeln('=== Tabelas contendo "' + AFiltro + '" ===');
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := AConn;
    Q.SQL.Text :=
      'SELECT TRIM(RDB$RELATION_NAME) AS NOME ' +
      'FROM RDB$RELATIONS ' +
      'WHERE RDB$SYSTEM_FLAG = 0 AND RDB$RELATION_NAME CONTAINING :FILTRO ' +
      'ORDER BY 1';
    Q.ParamByName('FILTRO').AsString := UpperCase(AFiltro);
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
  Q: TFDQuery;
  Db, Server, Port, User, Pass, Charset, ClientLib: string;
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
      ClientLib := Ini.ReadString('Banco', 'ClientLibrary', '');
    finally
      Ini.Free;
    end;

    if (Charset = '') or SameText(Charset, 'UTF8') then
      Charset := 'WIN1252';

    Driver := TFDPhysFBDriverLink.Create(nil);
    Conn := TFDConnection.Create(nil);
    try
      if ClientLib = '' then
        for I := Low(CAMINHOS_FB) to High(CAMINHOS_FB) do
          if FileExists(CAMINHOS_FB[I]) then
          begin
            ClientLib := CAMINHOS_FB[I];
            Break;
          end;
      if ClientLib <> '' then
        Driver.VendorLib := ClientLib;

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

      ListarTabelas(Conn, 'COMPRA');
      ListarTabelas(Conn, 'NOTAFISCAL');
      ListarTabelas(Conn, 'NOTA');
      ListarCampos(Conn, 'ENTRADACOMPRA');
      ListarCampos(Conn, 'ENTRADACOMPRAITEM');
      ListarCampos(Conn, 'NOTAFISCAL');
      ListarCampos(Conn, 'NOTAFISCALITEM');
      ListarCampos(Conn, 'ENTRADACOMPRAITEMSERVICO');
      ListarCampos(Conn, 'NOTAFISCALITEMSERVICO');

      Writeln('=== Teste joins ===');
      Q := TFDQuery.Create(nil);
      try
        Q.Connection := Conn;
        Q.SQL.Text :=
          'SELECT FIRST 1 E.ENTCNUMERO, P.PESNOME ' +
          'FROM ENTRADACOMPRA E ' +
          'LEFT JOIN FORNECEDOR F ON F.FORCODIGO = E.FORCODIGO AND F.EMPCODIGO = E.EMPCODIGO ' +
          'LEFT JOIN PESSOA P ON P.PESCODIGO = F.PESCODIGO';
        Q.Open;
        Writeln('ENTRADACOMPRA join OK');
        Q.Close;
        Q.SQL.Text :=
          'SELECT FIRST 1 N.NFNUMEROFISCAL, P.PESNOME ' +
          'FROM NOTAFISCAL N LEFT JOIN PESSOA P ON P.PESCODIGO = N.PESCODIGO';
        Q.Open;
        Writeln('NOTAFISCAL join OK');
        Q.Close;
        Q.SQL.Text :=
          'SELECT FIRST 1 NF.NFECHAVEACESSO FROM NOTAFISCALNFE NF';
        Q.Open;
        Writeln('NOTAFISCALNFE fields OK');
      finally
        Q.Free;
      end;
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
