unit UdmConexao;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.IniFiles, Vcl.Forms,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.FB, FireDAC.Phys.FBDef,
  Data.DB, FireDAC.Comp.Client, FireDAC.DApt;

const
  FB_USUARIO_PADRAO = 'SYSDBA';
  FB_SENHA_PADRAO = 'masterkey';
  FB_PORTA_PADRAO = '3050';
  FB_CHARSET_PADRAO = 'WIN1252';
  FB_SERVIDOR_LOCAL = '127.0.0.1';

type
  TInfoServicoFirebird = record
    PastaInstalacao: string;
    FbClientDll: string;
    Porta: string;
    WireCrypt: string;
    NomeServico: string;
    Encontrado: Boolean;
  end;

  TListaServicosFirebird = array of TInfoServicoFirebird;

  TConfigBanco = record
    Database: string;
    Server: string;
    Port: string;
    UserName: string;
    Password: string;
    CharacterSet: string;
    ClientLibrary: string;
    WireCrypt: string;
  end;

  TdmConexao = class(TDataModule)
    FDConnection1: TFDConnection;
    FDPhysFBDriverLink1: TFDPhysFBDriverLink;
    procedure DataModuleCreate(Sender: TObject);
  private
    FConfig: TConfigBanco;
    FServicos: TListaServicosFirebird;
    function ArquivoConfig: string;
    procedure CarregarIni(out AConfig: TConfigBanco);
    procedure SalvarIni(const AConfig: TConfigBanco);
    procedure ConfigurarClienteFirebird(const AClientLibrary: string);
    function ResolverClienteFB(const ACaminhoIni: string): string;
    procedure AplicarParametros(const AConfig: TConfigBanco);
    function PrecisaConfigurar: Boolean;
    function SolicitarConfiguracao: Boolean;
    function ErroArquivoEmUso(const AMensagem: string): Boolean;
    function ErroOdsIncompativel(const AMensagem: string): Boolean;
    function CharsetConexaoEfetivo(const ACharset: string): string;
    function ServidorEfetivo(const AConfig: TConfigBanco): string;
    function DonoDialogo: TComponent;
    function PerguntarSimNao(const AMensagem: string): Boolean;
    function TentarConectarComServico(const AServico: TInfoServicoFirebird): Boolean;
  public
    function Conectar: Boolean;
    procedure Desconectar;
    function Conectado: Boolean;
  end;

var
  dmConexao: TdmConexao;

function DetectarServicosFirebird: TListaServicosFirebird;
function DetectarServicoFirebird5: TInfoServicoFirebird;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

uses
  System.UITypes, Vcl.Dialogs, Winapi.WinSvc, System.Win.Registry,
  UfrmConfigBanco;

{$R *.dfm}

function LerValorConfFirebird(const AArquivoConf, AChave: string): string;
var
  Linhas: TStringList;
  I, P: Integer;
  Linha, Chave, Valor: string;
begin
  Result := '';
  if not FileExists(AArquivoConf) then
    Exit;
  Linhas := TStringList.Create;
  try
    Linhas.LoadFromFile(AArquivoConf);
    for I := 0 to Linhas.Count - 1 do
    begin
      Linha := Trim(Linhas[I]);
      if (Linha = '') or (Linha[1] = '#') then
        Continue;
      P := Pos('=', Linha);
      if P = 0 then
        Continue;
      Chave := Trim(Copy(Linha, 1, P - 1));
      Valor := Trim(Copy(Linha, P + 1, MaxInt));
      if SameText(Chave, AChave) then
        Result := Valor;
    end;
  finally
    Linhas.Free;
  end;
end;

function ExtrairPastaDoImagePath(const AImagePath: string): string;
var
  S: string;
  P: Integer;
begin
  S := Trim(AImagePath);
  if (S <> '') and (S[1] = '"') then
  begin
    Delete(S, 1, 1);
    P := Pos('"', S);
    if P > 0 then
      S := Copy(S, 1, P - 1);
  end
  else
  begin
    P := Pos(' -', S);
    if P > 0 then
      S := Trim(Copy(S, 1, P - 1));
  end;
  Result := ExtractFilePath(S);
end;

function DetectarServicosFirebird: TListaServicosFirebird;
const
  SERVICOS_KEY = 'SYSTEM\CurrentControlSet\Services';
var
  Reg: TRegistry;
  Nomes: TStringList;
  I, Cnt: Integer;
  Nome, ImagePath, Pasta, ConfPath, Porta, WC, FbClient: string;
  Info: TInfoServicoFirebird;
begin
  SetLength(Result, 0);
  Cnt := 0;

  Reg := TRegistry.Create(KEY_READ);
  Nomes := TStringList.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if not Reg.OpenKeyReadOnly(SERVICOS_KEY) then
      Exit;
    Reg.GetKeyNames(Nomes);
    Reg.CloseKey;

    for I := 0 to Nomes.Count - 1 do
    begin
      Nome := Nomes[I];
      if (Pos('Firebird', Nome) = 0) or (Pos('Guardian', Nome) > 0) then
        Continue;
      if not Reg.OpenKeyReadOnly(SERVICOS_KEY + '\' + Nome) then
        Continue;
      try
        if not Reg.ValueExists('ImagePath') then
          Continue;
        ImagePath := Reg.ReadString('ImagePath');
      finally
        Reg.CloseKey;
      end;

      Pasta := ExtrairPastaDoImagePath(ImagePath);
      if Pasta = '' then
        Continue;
      Pasta := IncludeTrailingPathDelimiter(Pasta);

      FbClient := Pasta + 'fbclient.dll';
      if not FileExists(FbClient) then
        Continue;

      ConfPath := Pasta + 'firebird.conf';
      Porta := LerValorConfFirebird(ConfPath, 'RemoteServicePort');
      if Porta = '' then
        Porta := FB_PORTA_PADRAO;
      WC := LerValorConfFirebird(ConfPath, 'WireCrypt');
      if WC = '' then
        WC := 'Disabled';

      FillChar(Info, SizeOf(Info), 0);
      Info.PastaInstalacao := Pasta;
      Info.FbClientDll := FbClient;
      Info.Porta := Porta;
      Info.WireCrypt := WC;
      Info.NomeServico := Nome;
      Info.Encontrado := True;

      SetLength(Result, Cnt + 1);
      Result[Cnt] := Info;
      Inc(Cnt);
    end;
  finally
    Nomes.Free;
    Reg.Free;
  end;
end;

function DetectarServicoFirebird5: TInfoServicoFirebird;
var
  Lista: TListaServicosFirebird;
  I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Encontrado := False;
  Lista := DetectarServicosFirebird;
  for I := 0 to High(Lista) do
  begin
    if Pos('firebird.exe', LowerCase(Lista[I].FbClientDll + Lista[I].PastaInstalacao)) > 0 then
    begin
      Result := Lista[I];
      Exit;
    end;
  end;
  if Length(Lista) > 0 then
    Result := Lista[0];
end;

function TdmConexao.DonoDialogo: TComponent;
begin
  if Assigned(Application.MainForm) then
    Result := Application.MainForm
  else
    Result := Application;
end;

function TdmConexao.PerguntarSimNao(const AMensagem: string): Boolean;
var
  Resposta: Integer;
  Handle: HWND;
begin
  if Assigned(Application.MainForm) then
    Handle := Application.MainForm.Handle
  else
    Handle := 0;
  Resposta := MessageBox(Handle, PChar(AMensagem), PChar(Application.Title),
    MB_ICONERROR or MB_YESNO or MB_TOPMOST);
  Result := Resposta = IDYES;
end;

function TdmConexao.ArquivoConfig: string;
begin
  Result := ChangeFileExt(ParamStr(0), '.ini');
end;

procedure TdmConexao.DataModuleCreate(Sender: TObject);
begin
  FDConnection1.ResourceOptions.SilentMode := True;
  FServicos := DetectarServicosFirebird;
  CarregarIni(FConfig);
  ConfigurarClienteFirebird(FConfig.ClientLibrary);
end;

function TdmConexao.ResolverClienteFB(const ACaminhoIni: string): string;

  function CaminhoSeExistir(const ACaminho: string): string;
  begin
    if (ACaminho <> '') and FileExists(ACaminho) then
      Result := ACaminho
    else
      Result := '';
  end;

const
  CAMINHOS_FIXOS: array[0..4] of string = (
    'C:\Program Files\Firebird\Firebird_5_0\fbclient.dll',
    'C:\Program Files\Firebird\Firebird_5_0\WOW64\fbclient.dll',
    'C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll',
    'C:\Program Files\Firebird\Firebird_4_0\fbclient.dll',
    'C:\Program Files\Firebird\Firebird_3_0\fbclient.dll');
var
  PastaApp, Caminho: string;
  I: Integer;
begin
  Result := CaminhoSeExistir(Trim(ACaminhoIni));
  if Result <> '' then
    Exit;

  for I := 0 to High(FServicos) do
  begin
    Result := CaminhoSeExistir(FServicos[I].FbClientDll);
    if Result <> '' then
      Exit;
  end;

  PastaApp := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Result := CaminhoSeExistir(PastaApp + 'fbclient.dll');
  if Result <> '' then Exit;
  Result := CaminhoSeExistir(PastaApp + 'dll\fbclient.dll');
  if Result <> '' then Exit;
  Result := CaminhoSeExistir(PastaApp + 'Firebird\fbclient.dll');
  if Result <> '' then Exit;

  for Caminho in CAMINHOS_FIXOS do
  begin
    Result := CaminhoSeExistir(Caminho);
    if Result <> '' then
      Exit;
  end;

  Result := CaminhoSeExistir('C:\Windows\System32\fbclient.dll');
end;

procedure TdmConexao.ConfigurarClienteFirebird(const AClientLibrary: string);
var
  Lib: string;
begin
  Lib := ResolverClienteFB(AClientLibrary);
  if Lib <> '' then
    FDPhysFBDriverLink1.VendorLib := Lib;
end;

procedure TdmConexao.CarregarIni(out AConfig: TConfigBanco);
var
  Ini: TIniFile;
  PortaPadrao, WireCryptPadrao: string;
begin
  if Length(FServicos) > 0 then
  begin
    PortaPadrao := FServicos[0].Porta;
    WireCryptPadrao := FServicos[0].WireCrypt;
  end
  else
  begin
    PortaPadrao := FB_PORTA_PADRAO;
    WireCryptPadrao := 'Disabled';
  end;

  FillChar(AConfig, SizeOf(AConfig), 0);
  AConfig.UserName := FB_USUARIO_PADRAO;
  AConfig.Password := FB_SENHA_PADRAO;
  AConfig.Port := PortaPadrao;
  AConfig.CharacterSet := FB_CHARSET_PADRAO;
  AConfig.Server := FB_SERVIDOR_LOCAL;
  AConfig.WireCrypt := WireCryptPadrao;

  if not FileExists(ArquivoConfig) then
    Exit;

  Ini := TIniFile.Create(ArquivoConfig);
  try
    AConfig.Database := Trim(Ini.ReadString('Banco', 'Database', ''));
    AConfig.Server := Trim(Ini.ReadString('Banco', 'Server', FB_SERVIDOR_LOCAL));
    if AConfig.Server = '' then
      AConfig.Server := FB_SERVIDOR_LOCAL;
    AConfig.Port := Trim(Ini.ReadString('Banco', 'Port', PortaPadrao));
    if AConfig.Port = '' then
      AConfig.Port := PortaPadrao;
    AConfig.UserName := Ini.ReadString('Banco', 'User_Name', FB_USUARIO_PADRAO);
    AConfig.Password := Ini.ReadString('Banco', 'Password', FB_SENHA_PADRAO);
    AConfig.CharacterSet := Trim(Ini.ReadString('Banco', 'CharacterSet', FB_CHARSET_PADRAO));
    if AConfig.CharacterSet = '' then
      AConfig.CharacterSet := FB_CHARSET_PADRAO;
    AConfig.ClientLibrary := Trim(Ini.ReadString('Banco', 'ClientLibrary', ''));
    AConfig.WireCrypt := Trim(Ini.ReadString('Banco', 'WireCrypt', WireCryptPadrao));
    if AConfig.WireCrypt = '' then
      AConfig.WireCrypt := WireCryptPadrao;
  finally
    Ini.Free;
  end;
end;

procedure TdmConexao.SalvarIni(const AConfig: TConfigBanco);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ArquivoConfig);
  try
    Ini.WriteString('Banco', 'DriverID', 'FB');
    Ini.WriteString('Banco', 'Database', AConfig.Database);
    Ini.WriteString('Banco', 'Server', AConfig.Server);
    Ini.WriteString('Banco', 'Port', AConfig.Port);
    Ini.WriteString('Banco', 'User_Name', AConfig.UserName);
    Ini.WriteString('Banco', 'Password', AConfig.Password);
    Ini.WriteString('Banco', 'CharacterSet', AConfig.CharacterSet);
    Ini.WriteString('Banco', 'ClientLibrary', AConfig.ClientLibrary);
    Ini.WriteString('Banco', 'WireCrypt', AConfig.WireCrypt);
    Ini.WriteString('Banco', 'FirebirdVersion', '5.0');
  finally
    Ini.Free;
  end;
end;

function TdmConexao.CharsetConexaoEfetivo(const ACharset: string): string;
var
  C: string;
begin
  C := Trim(ACharset);
  if (C = '') or SameText(C, 'UTF8') then
    Result := 'WIN1252'
  else
    Result := C;
end;

function TdmConexao.ServidorEfetivo(const AConfig: TConfigBanco): string;
begin
  Result := Trim(AConfig.Server);
  if Result = '' then
    Result := FB_SERVIDOR_LOCAL;
end;

function TdmConexao.ErroArquivoEmUso(const AMensagem: string): Boolean;
var
  Msg: string;
begin
  Msg := LowerCase(AMensagem);
  Result := (Pos('createfile', Msg) > 0) or
    (Pos('já está sendo usado', Msg) > 0) or
    (Pos('ja esta sendo usado', Msg) > 0) or
    (Pos('being used by another process', Msg) > 0) or
    (Pos('file in use', Msg) > 0);
end;

function TdmConexao.ErroOdsIncompativel(const AMensagem: string): Boolean;
var
  Msg: string;
begin
  Msg := LowerCase(AMensagem);
  Result := (Pos('unsupported on-disk structure', Msg) > 0) or
    (Pos('ods', Msg) > 0);
end;

function TdmConexao.TentarConectarComServico(const AServico: TInfoServicoFirebird): Boolean;
begin
  Result := False;
  try
    Desconectar;
    FConfig.Port := AServico.Porta;
    FConfig.WireCrypt := AServico.WireCrypt;
    FConfig.ClientLibrary := AServico.FbClientDll;
    FDPhysFBDriverLink1.VendorLib := AServico.FbClientDll;
    AplicarParametros(FConfig);
    FDConnection1.Connected := True;
    SalvarIni(FConfig);
    Result := True;
  except
    Desconectar;
  end;
end;

procedure TdmConexao.AplicarParametros(const AConfig: TConfigBanco);
var
  CaminhoBanco: string;
begin
  CaminhoBanco := Trim(AConfig.Database);
  if CaminhoBanco = '' then
    raise Exception.Create('Caminho do banco (.fdb) não informado.');

  ConfigurarClienteFirebird(AConfig.ClientLibrary);

  FDConnection1.Params.Clear;
  FDConnection1.Params.DriverID := 'FB';
  FDConnection1.Params.UserName := AConfig.UserName;
  FDConnection1.Params.Password := AConfig.Password;
  FDConnection1.Params.Add('Server=' + ServidorEfetivo(AConfig));
  FDConnection1.Params.Add('Port=' + AConfig.Port);
  FDConnection1.Params.Add('Protocol=TCPIP');
  FDConnection1.Params.Add('Database=' + CaminhoBanco);
  FDConnection1.Params.Add('CharacterSet=' + CharsetConexaoEfetivo(AConfig.CharacterSet));
  FDConnection1.Params.Add('WireCrypt=' + AConfig.WireCrypt);
  FDConnection1.Params.Add('ConnectTimeout=30');

  FDConnection1.LoginPrompt := False;
end;

function TdmConexao.PrecisaConfigurar: Boolean;
begin
  CarregarIni(FConfig);
  Result := Trim(FConfig.Database) = '';
end;

function TdmConexao.SolicitarConfiguracao: Boolean;
var
  Form: TfrmConfigBanco;
begin
  Result := False;
  CarregarIni(FConfig);

  Form := TfrmConfigBanco.Create(DonoDialogo);
  try
    Form.edtDatabase.Text := FConfig.Database;
    Form.edtServer.Text := FConfig.Server;
    Form.edtPorta.Text := FConfig.Port;
    Form.edtUsuario.Text := FConfig.UserName;
    Form.edtSenha.Text := FConfig.Password;

    if Form.ShowModal <> mrOk then
      Exit;

    FConfig.Database := Trim(Form.edtDatabase.Text);
    FConfig.Server := Trim(Form.edtServer.Text);
    if FConfig.Server = '' then
      FConfig.Server := FB_SERVIDOR_LOCAL;
    FConfig.Port := Trim(Form.edtPorta.Text);
    if FConfig.Port = '' then
      FConfig.Port := FB_PORTA_PADRAO;
    FConfig.UserName := Trim(Form.edtUsuario.Text);
    if FConfig.UserName = '' then
      FConfig.UserName := FB_USUARIO_PADRAO;
    FConfig.Password := Form.edtSenha.Text;
    if FConfig.Password = '' then
      FConfig.Password := FB_SENHA_PADRAO;
    FConfig.CharacterSet := FB_CHARSET_PADRAO;
    FConfig.WireCrypt := 'Disabled';

    SalvarIni(FConfig);
    ConfigurarClienteFirebird(FConfig.ClientLibrary);
    Result := True;
  finally
    Form.Free;
  end;
end;

function TdmConexao.Conectar: Boolean;
var
  Tentativas, I: Integer;
  TentouOutrosServicos: Boolean;
begin
  Result := False;
  if FDConnection1.Connected then
    Exit(True);

  Tentativas := 0;
  TentouOutrosServicos := False;
  repeat
    Inc(Tentativas);
    if PrecisaConfigurar then
      if not SolicitarConfiguracao then
        Exit;

    try
      CarregarIni(FConfig);
      if Trim(FConfig.Server) = '' then
      begin
        FConfig.Server := FB_SERVIDOR_LOCAL;
        SalvarIni(FConfig);
      end;
      AplicarParametros(FConfig);
      FDConnection1.Connected := True;
      Result := True;
      Break;
    except
      on E: Exception do
      begin
        Desconectar;

        if (not TentouOutrosServicos) and (ErroOdsIncompativel(E.Message) or
           ErroArquivoEmUso(E.Message)) and (Length(FServicos) > 0) then
        begin
          TentouOutrosServicos := True;
          for I := 0 to High(FServicos) do
          begin
            if (FServicos[I].Porta = FConfig.Port) and
               (FServicos[I].FbClientDll = FDPhysFBDriverLink1.VendorLib) then
              Continue;
            if TentarConectarComServico(FServicos[I]) then
            begin
              Result := True;
              Break;
            end;
          end;
          if Result then
            Break;
        end;

        if PerguntarSimNao('Nao foi possivel conectar ao Firebird:' + sLineBreak + sLineBreak +
          E.Message + sLineBreak + sLineBreak +
          'Confirme:' + sLineBreak +
          '- Servico Firebird em execucao' + sLineBreak +
          '- Versao do Firebird compativel com o banco' + sLineBreak +
          '- Caminho do .fdb no servidor' + sLineBreak + sLineBreak +
          'Deseja alterar a configuracao?') then
        begin
          if not SolicitarConfiguracao then
            Exit;
        end
        else
          Exit;
      end;
    end;
  until Tentativas >= 10;
end;

procedure TdmConexao.Desconectar;
begin
  if FDConnection1.Connected then
    FDConnection1.Connected := False;
end;

function TdmConexao.Conectado: Boolean;
begin
  Result := FDConnection1.Connected;
end;

end.
