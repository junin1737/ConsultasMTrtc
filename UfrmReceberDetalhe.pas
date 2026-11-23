unit UfrmReceberDetalhe;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  UMapaReceber, UConsultaCampos, UConfirmarFechar, UfrmReceberBoletoDetalhe, UConsultaLayout;

type
  TfrmReceberDetalhe = class(TForm)
    pnlCabecalho: TPanel;
    lblDocumento: TLabel;
    edtDocumento: TEdit;
    lblPessoa: TLabel;
    edtPessoa: TEdit;
    lblEmissao: TLabel;
    edtEmissao: TEdit;
    lblVencimento: TLabel;
    edtVencimento: TEdit;
    lblRecebimento: TLabel;
    edtRecebimento: TEdit;
    lblSituacao: TLabel;
    edtSituacao: TEdit;
    lblValor: TLabel;
    edtValor: TEdit;
    lblValorAberto: TLabel;
    edtValorAberto: TEdit;
    lblValorRecebido: TLabel;
    edtValorRecebido: TEdit;
    lblObservacao: TLabel;
    memObservacao: TMemo;
    pnlRodape: TPanel;
    btnVerBoleto: TButton;
    btnFechar: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure btnVerBoletoClick(Sender: TObject);
  private
    FEmpCodigo: Integer;
    FCrNumero: Integer;
    FTemBoleto: Boolean;
    FDocumento: string;
    FCliente: string;
    procedure ConfigurarCampos;
    procedure ConfigurarEditLeitura(AEdit: TEdit);
  public
    function Exibir(AEmpCodigo, ACrNumero: Integer): Boolean;
    class procedure Abrir(AEmpCodigo, ACrNumero: Integer; const ATitulo: string = '');
  end;

implementation

{$R *.dfm}

procedure TfrmReceberDetalhe.FormCreate(Sender: TObject);
begin
  // AplicarConfirmacaoEsc(Self);
  Position := poScreenCenter;
  AplicarFonteConsultaForm(Self);
  ConfigurarCampos;
  AjustarBotoesRodapeDireita(pnlRodape, [btnVerBoleto, btnFechar]);
end;

procedure TfrmReceberDetalhe.ConfigurarEditLeitura(AEdit: TEdit);
begin
  AEdit.ReadOnly := True;
  AEdit.Color := clWindow;
  AplicarFonteSegoeUISemiBold(AEdit.Font, 9);
end;

procedure TfrmReceberDetalhe.ConfigurarCampos;
begin
  AplicarEstiloTituloCampo(lblDocumento);
  AplicarEstiloTituloCampo(lblPessoa);
  AplicarEstiloTituloCampo(lblEmissao);
  AplicarEstiloTituloCampo(lblVencimento);
  AplicarEstiloTituloCampo(lblRecebimento);
  AplicarEstiloTituloCampo(lblSituacao);
  AplicarEstiloTituloCampo(lblValor);
  AplicarEstiloTituloCampo(lblValorAberto);
  AplicarEstiloTituloCampo(lblValorRecebido);
  AplicarEstiloTituloCampo(lblObservacao);

  ConfigurarEditLeitura(edtDocumento);
  ConfigurarEditLeitura(edtPessoa);
  ConfigurarEditLeitura(edtEmissao);
  ConfigurarEditLeitura(edtVencimento);
  ConfigurarEditLeitura(edtRecebimento);
  ConfigurarEditLeitura(edtSituacao);
  ConfigurarEditLeitura(edtValor);
  ConfigurarEditLeitura(edtValorAberto);
  ConfigurarEditLeitura(edtValorRecebido);

  memObservacao.ReadOnly := True;
  memObservacao.Color := clWindow;
  memObservacao.BorderStyle := bsNone;

  btnVerBoleto.Enabled := False;
end;

function TfrmReceberDetalhe.Exibir(AEmpCodigo, ACrNumero: Integer): Boolean;
var
  D: TDetalheReceber;
begin
  Result := False;
  D := TMapaReceber.CarregarDetalhe(AEmpCodigo, ACrNumero);
  if not D.Encontrado then
    Exit;

  edtDocumento.Text := D.Documento;
  edtPessoa.Text := D.Pessoa;
  edtEmissao.Text := D.Emissao;
  edtVencimento.Text := D.Vencimento;
  edtRecebimento.Text := D.Recebimento;
  edtSituacao.Text := D.Situacao;
  edtValor.Text := D.Valor;
  edtValorAberto.Text := D.ValorAberto;
  edtValorRecebido.Text := D.ValorRecebido;
  memObservacao.Lines.Text := D.Observacao;

  FEmpCodigo := AEmpCodigo;
  FCrNumero := ACrNumero;
  FTemBoleto := D.TemBoleto;
  FDocumento := D.Documento;
  FCliente := D.Pessoa;
  btnVerBoleto.Enabled := FTemBoleto;
  Result := True;
end;

class procedure TfrmReceberDetalhe.Abrir(AEmpCodigo, ACrNumero: Integer; const ATitulo: string);
var
  Form: TfrmReceberDetalhe;
begin
  Form := TfrmReceberDetalhe.Create(Application);
  try
    if not Form.Exibir(AEmpCodigo, ACrNumero) then
    begin
      MessageDlg('T'#237'tulo a receber n'#227'o encontrado.', mtInformation, [mbOK], 0);
      Exit;
    end;
    if ATitulo <> '' then
      Form.Caption := ATitulo;
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TfrmReceberDetalhe.btnFecharClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmReceberDetalhe.btnVerBoletoClick(Sender: TObject);
begin
  if not FTemBoleto then
    Exit;
  TfrmReceberBoletoDetalhe.Abrir(FEmpCodigo, FCrNumero, FDocumento, FCliente, 'Boleto');
end;

end.
