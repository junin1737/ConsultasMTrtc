unit UfrmPagarDetalhe;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  UMapaPagar, UConsultaCampos, UConfirmarFechar;

type
  TfrmPagarDetalhe = class(TForm)
    pnlCabecalho: TPanel;
    lblDocumento: TLabel;
    edtDocumento: TEdit;
    lblPessoa: TLabel;
    edtPessoa: TEdit;
    lblEmissao: TLabel;
    edtEmissao: TEdit;
    lblVencimento: TLabel;
    edtVencimento: TEdit;
    lblPagamento: TLabel;
    edtPagamento: TEdit;
    lblSituacao: TLabel;
    edtSituacao: TEdit;
    lblValor: TLabel;
    edtValor: TEdit;
    lblValorAberto: TLabel;
    edtValorAberto: TEdit;
    lblValorPago: TLabel;
    edtValorPago: TEdit;
    lblObservacao: TLabel;
    memObservacao: TMemo;
    pnlRodape: TPanel;
    btnFechar: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    procedure ConfigurarCampos;
    procedure ConfigurarEditLeitura(AEdit: TEdit);
  public
    function Exibir(AEmpCodigo, ACpNumero: Integer): Boolean;
    class procedure Abrir(AEmpCodigo, ACpNumero: Integer; const ATitulo: string = '');
  end;

implementation

{$R *.dfm}

procedure TfrmPagarDetalhe.FormCreate(Sender: TObject);
begin
  // AplicarConfirmacaoEsc(Self);
  Position := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  ConfigurarCampos;
end;

procedure TfrmPagarDetalhe.ConfigurarEditLeitura(AEdit: TEdit);
begin
  AEdit.ReadOnly := True;
  AEdit.Color := clWindow;
end;

procedure TfrmPagarDetalhe.ConfigurarCampos;
begin
  AplicarEstiloTituloCampo(lblDocumento);
  AplicarEstiloTituloCampo(lblPessoa);
  AplicarEstiloTituloCampo(lblEmissao);
  AplicarEstiloTituloCampo(lblVencimento);
  AplicarEstiloTituloCampo(lblPagamento);
  AplicarEstiloTituloCampo(lblSituacao);
  AplicarEstiloTituloCampo(lblValor);
  AplicarEstiloTituloCampo(lblValorAberto);
  AplicarEstiloTituloCampo(lblValorPago);
  AplicarEstiloTituloCampo(lblObservacao);

  lblPessoa.Caption := 'Fornecedor';

  ConfigurarEditLeitura(edtDocumento);
  ConfigurarEditLeitura(edtPessoa);
  ConfigurarEditLeitura(edtEmissao);
  ConfigurarEditLeitura(edtVencimento);
  ConfigurarEditLeitura(edtPagamento);
  ConfigurarEditLeitura(edtSituacao);
  ConfigurarEditLeitura(edtValor);
  ConfigurarEditLeitura(edtValorAberto);
  ConfigurarEditLeitura(edtValorPago);

  memObservacao.ReadOnly := True;
  memObservacao.Color := clWindow;
  memObservacao.BorderStyle := bsNone;
end;

function TfrmPagarDetalhe.Exibir(AEmpCodigo, ACpNumero: Integer): Boolean;
var
  D: TDetalhePagar;
begin
  Result := False;
  D := TMapaPagar.CarregarDetalhe(AEmpCodigo, ACpNumero);
  if not D.Encontrado then
    Exit;

  edtDocumento.Text := D.Documento;
  edtPessoa.Text := D.Pessoa;
  edtEmissao.Text := D.Emissao;
  edtVencimento.Text := D.Vencimento;
  edtPagamento.Text := D.Pagamento;
  edtSituacao.Text := D.Situacao;
  edtValor.Text := D.Valor;
  edtValorAberto.Text := D.ValorAberto;
  edtValorPago.Text := D.ValorPago;
  memObservacao.Lines.Text := D.Observacao;
  Result := True;
end;

class procedure TfrmPagarDetalhe.Abrir(AEmpCodigo, ACpNumero: Integer; const ATitulo: string);
var
  Form: TfrmPagarDetalhe;
begin
  Form := TfrmPagarDetalhe.Create(Application);
  try
    if not Form.Exibir(AEmpCodigo, ACpNumero) then
    begin
      MessageDlg('T'#237'tulo a pagar n'#227'o encontrado.', mtInformation, [mbOK], 0);
      Exit;
    end;
    if ATitulo <> '' then
      Form.Caption := ATitulo;
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TfrmPagarDetalhe.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
