program SchemaProbe2;
$APPTYPE CONSOLE
uses System.SysUtils, System.IniFiles, FireDAC.Comp.Client, FireDAC.Phys.FB, FireDAC.Phys.FBDef, FireDAC.DApt;
var Conn:TFDConnection; Driver:TFDPhysFBDriverLink; Q:TFDQuery; Ini:TIniFile;
begin
  Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0))+'Consultas.ini');
  Driver:=TFDPhysFBDriverLink.Create(nil);
  Conn:=TFDConnection.Create(nil);
  try
    Driver.VendorLib:='C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll';
    Conn.Params.DriverID:='FB';
    Conn.Params.Database:=Ini.ReadString('Banco','Database','');
    Conn.Params.UserName:=Ini.ReadString('Banco','User_Name','SYSDBA');
    Conn.Params.Password:=Ini.ReadString('Banco','Password','masterkey');
    Conn.Params.Add('Server='+Ini.ReadString('Banco','Server','127.0.0.1'));
    Conn.Params.Add('Port='+Ini.ReadString('Banco','Port','3052'));
    Conn.Params.Add('CharacterSet=WIN1252');
    Conn.Connected:=True;
    Q:=TFDQuery.Create(nil);
    try
      Q.Connection:=Conn;
      Q.SQL.Text:='SELECT FIRST 1 E.*, P.PESNOME FROM ENTRADACOMPRA E LEFT JOIN FORNECEDOR F ON F.FORCODIGO=E.FORCODIGO AND F.EMPCODIGO=E.EMPCODIGO LEFT JOIN PESSOA P ON P.PESCODIGO=F.PESCODIGO';
      Q.Open; Writeln('ENTRADACOMPRA join OK, fields:', Q.FieldCount);
      Q.Close;
      Q.SQL.Text:='SELECT FIRST 1 N.*, P.PESNOME FROM NOTAFISCAL N LEFT JOIN PESSOA P ON P.PESCODIGO=N.PESCODIGO';
      Q.Open; Writeln('NOTAFISCAL join OK');
      Q.Close;
      Q.SQL.Text:='SELECT TRIM(R.RDB$FIELD_NAME) FROM RDB$RELATION_FIELDS R WHERE R.RDB$RELATION_NAME=''FORNECEDOR'' ORDER BY R.RDB$FIELD_POSITION';
      Q.Open; while not Q.Eof do begin Writeln(Q.Fields[0].AsString); Q.Next; end;
    finally Q.Free; end;
  finally Conn.Free; Driver.Free; Ini.Free; end;
end.
