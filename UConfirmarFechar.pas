unit UConfirmarFechar;

interface

uses
  Vcl.Forms, System.Classes, System.UITypes, Winapi.Windows, Vcl.Controls;

const
  MSG_FECHAR_TELA = 'Deseja fechar esta tela?';
  MSG_SAIR_SISTEMA = 'Deseja sair do sistema?';

procedure AplicarConfirmacaoEsc(AForm: TForm; const AMensagem: string = MSG_FECHAR_TELA);
procedure ConfirmarFecharForm(AForm: TForm; const AMensagem: string = MSG_FECHAR_TELA);

implementation

uses
  Winapi.Messages, Vcl.Dialogs, System.SysUtils, Vcl.ExtCtrls;

type
  TFecharConfirmacaoTask = class
  private
    FForm: TForm;
    FMensagem: string;
    FTimer: TTimer;
    procedure Executar(Sender: TObject);
  public
    constructor Create(AForm: TForm; const AMensagem: string);
  end;

  TFormEscHandler = class(TComponent)
  private
    FMensagem: string;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  public
    constructor Create(AOwner: TForm; const AMensagem: string); reintroduce;
    procedure SolicitarFechar;
  end;

  TApplicationEscHook = class
  private
    FAnterior: TMessageEvent;
    FInstalado: Boolean;
    FTemAnterior: Boolean;
    procedure MessageHandler(var Msg: TMsg; var Handled: Boolean);
  public
    procedure Instalar;
  end;

var
  GFecharAutorizado: TForm = nil;
  GFormConfirmacaoPendente: TForm = nil;
  FApplicationEscHook: TApplicationEscHook = nil;

function ObterHandlerEsc(AForm: TForm): TFormEscHandler;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(AForm) then
    Exit;

  for I := 0 to AForm.ComponentCount - 1 do
    if AForm.Components[I] is TFormEscHandler then
      Exit(TFormEscHandler(AForm.Components[I]));
end;

procedure FecharFormDefinitivo(AForm: TForm);
begin
  if not Assigned(AForm) then
    Exit;

  if csDestroying in AForm.ComponentState then
    Exit;

  if GFormConfirmacaoPendente = AForm then
    GFormConfirmacaoPendente := nil;
  GFecharAutorizado := AForm;
  AForm.Close;
end;

procedure InstalarHookEsc;
begin
  if FApplicationEscHook = nil then
    FApplicationEscHook := TApplicationEscHook.Create;
  FApplicationEscHook.Instalar;
end;

procedure TApplicationEscHook.Instalar;
begin
  if FInstalado then
    Exit;

  FInstalado := True;
  FTemAnterior := Assigned(Application.OnMessage);
  FAnterior := Application.OnMessage;
  Application.OnMessage := MessageHandler;
end;

procedure TApplicationEscHook.MessageHandler(var Msg: TMsg; var Handled: Boolean);
var
  Handler: TFormEscHandler;
  FormAtivo: TForm;
begin
  if (Msg.message = WM_KEYDOWN) and (Msg.wParam = VK_ESCAPE) and (not Handled) then
  begin
    FormAtivo := Screen.ActiveForm;
    Handler := ObterHandlerEsc(FormAtivo);
    if Handler <> nil then
    begin
      Handler.SolicitarFechar;
      Handled := True;
    end;
  end;

  if (not Handled) and FTemAnterior then
    FAnterior(Msg, Handled);
end;

constructor TFecharConfirmacaoTask.Create(AForm: TForm; const AMensagem: string);
begin
  inherited Create;
  FForm := AForm;
  FMensagem := AMensagem;
  if FMensagem = '' then
    FMensagem := MSG_FECHAR_TELA;

  FTimer := TTimer.Create(nil);
  FTimer.Interval := 1;
  FTimer.OnTimer := Executar;
  FTimer.Enabled := True;
end;

procedure TFecharConfirmacaoTask.Executar(Sender: TObject);
var
  Dono: HWND;
  Resposta: Integer;
begin
  FTimer.Enabled := False;
  FTimer.Free;
  FTimer := nil;

  if not Assigned(FForm) then
  begin
    GFormConfirmacaoPendente := nil;
    Free;
    Exit;
  end;

  if csDestroying in FForm.ComponentState then
  begin
    if GFormConfirmacaoPendente = FForm then
      GFormConfirmacaoPendente := nil;
    Free;
    Exit;
  end;

  GFormConfirmacaoPendente := nil;

  Dono := 0;
  if FForm.HandleAllocated then
  begin
    FForm.BringToFront;
    SetForegroundWindow(FForm.Handle);
    Dono := FForm.Handle;
  end
  else if Assigned(Application.MainForm) and Application.MainForm.HandleAllocated then
    Dono := Application.MainForm.Handle;

  if Dono <> 0 then
    Resposta := MessageBox(Dono, PChar(FMensagem), PChar(Application.Title),
      MB_YESNO or MB_ICONQUESTION or MB_DEFBUTTON2)
  else
    Resposta := MessageDlg(FMensagem, mtConfirmation, [mbYes, mbNo], 0);

  if Resposta = IDYES then
    FecharFormDefinitivo(FForm);

  Free;
end;

procedure AgendarConfirmacaoFechamento(AForm: TForm; const AMensagem: string);
begin
  if not Assigned(AForm) then
    Exit;

  if GFormConfirmacaoPendente = AForm then
    Exit;

  GFormConfirmacaoPendente := AForm;
  TFecharConfirmacaoTask.Create(AForm, AMensagem);
end;

constructor TFormEscHandler.Create(AOwner: TForm; const AMensagem: string);
begin
  inherited Create(AOwner);
  FMensagem := AMensagem;
  if FMensagem = '' then
    FMensagem := MSG_FECHAR_TELA;

  AOwner.OnCloseQuery := FormCloseQuery;
  AOwner.OnClose := FormClose;
end;

procedure TFormEscHandler.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure TFormEscHandler.SolicitarFechar;
begin
  ConfirmarFecharForm(TForm(Owner), FMensagem);
end;

procedure TFormEscHandler.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  F: TForm;
begin
  F := TForm(Sender);

  if F = GFecharAutorizado then
  begin
    GFecharAutorizado := nil;
    CanClose := True;
    Exit;
  end;

  CanClose := False;
  AgendarConfirmacaoFechamento(F, FMensagem);
end;

procedure ConfirmarFecharForm(AForm: TForm; const AMensagem: string);
var
  Msg: string;
begin
  if not Assigned(AForm) then
    Exit;

  Msg := AMensagem;
  if Msg = '' then
    Msg := MSG_FECHAR_TELA;

  AgendarConfirmacaoFechamento(AForm, Msg);
end;

procedure RegistrarConfirmacaoEsc(AForm: TForm; const AMensagem: string);
var
  I: Integer;
  Msg: string;
begin
  for I := 0 to AForm.ComponentCount - 1 do
    if AForm.Components[I] is TFormEscHandler then
      Exit;

  Msg := AMensagem;
  if Msg = '' then
    Msg := MSG_FECHAR_TELA;

  TFormEscHandler.Create(AForm, Msg);
  InstalarHookEsc;
end;

procedure AplicarConfirmacaoEsc(AForm: TForm; const AMensagem: string);
begin
  RegistrarConfirmacaoEsc(AForm, AMensagem);
end;

end.
