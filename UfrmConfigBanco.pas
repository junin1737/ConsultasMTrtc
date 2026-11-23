unit UfrmConfigBanco;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, System.UITypes;

const
  USUARIO_PADRAO = 'SYSDBA';
  SENHA_PADRAO = 'masterkey';
  PORTA_PADRAO = '3050';
  SERVIDOR_PADRAO = '127.0.0.1';

type
  TfrmConfigBanco = class(TForm)
    PanelBotoes: TPanel;
    btnOk: TButton;
    btnCancelar: TButton;
    lblDatabase: TLabel;
    edtDatabase: TEdit;
    btnProcurar: TButton;
    lblServer: TLabel;
    edtServer: TEdit;
    lblPorta: TLabel;
    edtPorta: TEdit;
    lblUsuario: TLabel;
    edtUsuario: TEdit;
    lblSenha: TLabel;
    edtSenha: TEdit;
    lblDeteccao: TLabel;
    OpenDialog1: TOpenDialog;
    procedure btnProcurarClick(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    function ValidarCampos: Boolean;
    procedure AplicarDeteccaoAutomatica;
  public
  end;

implementation

{$R *.dfm}

uses
  UConfirmarFechar, UdmConexao;

procedure TfrmConfigBanco.AplicarDeteccaoAutomatica;
var
  Lista: TListaServicosFirebird;
  I: Integer;
  Texto: string;
begin
  Lista := DetectarServicosFirebird;
  if Length(Lista) = 0 then
  begin
    if Assigned(lblDeteccao) then
      lblDeteccao.Caption := 'Nenhum servico Firebird detectado.';
    Exit;
  end;

  Texto := '';
  for I := 0 to High(Lista) do
  begin
    if Texto <> '' then
      Texto := Texto + ' | ';
    Texto := Texto + Lista[I].NomeServico + ' (porta ' + Lista[I].Porta + ')';
  end;

  if Assigned(lblDeteccao) then
    lblDeteccao.Caption := 'Detectados: ' + Texto;

  if Trim(edtPorta.Text) = '' then
    edtPorta.Text := Lista[0].Porta;
  if Trim(edtServer.Text) = '' then
    edtServer.Text := SERVIDOR_PADRAO;
end;

procedure TfrmConfigBanco.FormCreate(Sender: TObject);
begin
  Caption := 'Configuracao do banco Firebird';
  OpenDialog1.Filter := 'Banco Firebird (*.fdb)|*.fdb|Todos os arquivos (*.*)|*.*';
  OpenDialog1.Title := 'Selecione o arquivo do banco';
  if edtUsuario.Text = '' then
    edtUsuario.Text := USUARIO_PADRAO;
  if edtSenha.Text = '' then
    edtSenha.Text := SENHA_PADRAO;
  if edtPorta.Text = '' then
    edtPorta.Text := PORTA_PADRAO;
  if edtServer.Text = '' then
    edtServer.Text := SERVIDOR_PADRAO;
  AplicarDeteccaoAutomatica;
end;

procedure TfrmConfigBanco.btnProcurarClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    edtDatabase.Text := OpenDialog1.FileName;
end;

function TfrmConfigBanco.ValidarCampos: Boolean;
begin
  Result := False;
  if Trim(edtDatabase.Text) = '' then
  begin
    MessageDlg('Informe o caminho do arquivo .fdb.', mtWarning, [mbOK], 0);
    edtDatabase.SetFocus;
    Exit;
  end;
  if not FileExists(Trim(edtDatabase.Text)) then
  begin
    MessageDlg('Arquivo do banco não encontrado no disco:' + sLineBreak + Trim(edtDatabase.Text) +
      sLineBreak + sLineBreak +
      'Se o Realtec já estiver aberto, mantenha o caminho e use o servidor ' + SERVIDOR_PADRAO + '.',
      mtWarning, [mbOK], 0);
    edtDatabase.SetFocus;
    Exit;
  end;
  Result := True;
end;

procedure TfrmConfigBanco.btnOkClick(Sender: TObject);
begin
  if ValidarCampos then
    ModalResult := mrOk
  else
    ModalResult := mrNone;
end;

end.

