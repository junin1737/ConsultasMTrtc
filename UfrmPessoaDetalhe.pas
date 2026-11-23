unit UfrmPessoaDetalhe;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  UMapaPessoas, UConsultaCampos;

type
  TfrmPessoaDetalhe = class(TForm)
    pnlCabecalho: TPanel;
    lblCodigo: TLabel;
    edtCodigo: TEdit;
    lblNome: TLabel;
    edtNome: TEdit;
    pnlDados: TPanel;
    lblCpfCnpj: TLabel;
    edtCpfCnpj: TEdit;
    lblIE: TLabel;
    edtIE: TEdit;
    lblEndereco: TLabel;
    edtEndereco: TEdit;
    lblNumero: TLabel;
    edtNumero: TEdit;
    lblBairro: TLabel;
    edtBairro: TEdit;
    lblCidade: TLabel;
    edtCidade: TEdit;
    lblUf: TLabel;
    edtUf: TEdit;
    lblCep: TLabel;
    edtCep: TEdit;
    lblTelefone: TLabel;
    edtTelefone: TEdit;
    lblCelular: TLabel;
    edtCelular: TEdit;
    pnlRodape: TPanel;
    btnFechar: TButton;
    procedure btnFecharClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure ConfigurarCampos;
    procedure ConfigurarEditLeitura(AEdit: TEdit);
  public
    procedure Exibir(const ADetalhe: TDetalhePessoa; const ATitulo: string = '');
    class procedure Abrir(const AValorChave, ATitulo: string);
  end;

implementation

{$R *.dfm}

uses
  UConfirmarFechar;

procedure TfrmPessoaDetalhe.FormCreate(Sender: TObject);
begin
  // AplicarConfirmacaoEsc(Self);
  Position := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  ConfigurarCampos;
end;

procedure TfrmPessoaDetalhe.ConfigurarEditLeitura(AEdit: TEdit);
begin
  AEdit.ReadOnly := True;
  AEdit.Color := clWindow;
end;

procedure TfrmPessoaDetalhe.ConfigurarCampos;
begin
  AplicarEstiloTituloCampo(lblCodigo);
  AplicarEstiloTituloCampo(lblNome);
  AplicarEstiloTituloCampo(lblCpfCnpj);
  AplicarEstiloTituloCampo(lblIE);
  AplicarEstiloTituloCampo(lblEndereco);
  AplicarEstiloTituloCampo(lblNumero);
  AplicarEstiloTituloCampo(lblBairro);
  AplicarEstiloTituloCampo(lblCidade);
  AplicarEstiloTituloCampo(lblUf);
  AplicarEstiloTituloCampo(lblCep);
  AplicarEstiloTituloCampo(lblTelefone);
  AplicarEstiloTituloCampo(lblCelular);

  ConfigurarEditLeitura(edtCodigo);
  ConfigurarEditLeitura(edtNome);
  ConfigurarEditLeitura(edtCpfCnpj);
  ConfigurarEditLeitura(edtIE);
  ConfigurarEditLeitura(edtEndereco);
  ConfigurarEditLeitura(edtNumero);
  ConfigurarEditLeitura(edtBairro);
  ConfigurarEditLeitura(edtCidade);
  ConfigurarEditLeitura(edtUf);
  ConfigurarEditLeitura(edtCep);
  ConfigurarEditLeitura(edtTelefone);
  ConfigurarEditLeitura(edtCelular);
end;

procedure TfrmPessoaDetalhe.Exibir(const ADetalhe: TDetalhePessoa; const ATitulo: string);
begin
  if ATitulo <> '' then
    Caption := ATitulo;

  edtCodigo.Text := ADetalhe.Codigo;
  edtNome.Text := ADetalhe.Nome;
  edtCpfCnpj.Text := ADetalhe.CpfCnpj;
  edtIE.Text := ADetalhe.InscricaoEstadual;
  edtEndereco.Text := ADetalhe.Endereco;
  edtNumero.Text := ADetalhe.Numero;
  edtBairro.Text := ADetalhe.Bairro;
  edtCidade.Text := ADetalhe.Cidade;
  edtUf.Text := ADetalhe.Uf;
  edtCep.Text := ADetalhe.Cep;
  edtTelefone.Text := ADetalhe.Telefone;
  edtCelular.Text := ADetalhe.Celular;
end;

class procedure TfrmPessoaDetalhe.Abrir(const AValorChave, ATitulo: string);
var
  Form: TfrmPessoaDetalhe;
  Detalhe: TDetalhePessoa;
begin
  Detalhe := TMapaPessoas.CarregarDetalhe(AValorChave);
  Form := TfrmPessoaDetalhe.Create(Application);
  try
    Form.Exibir(Detalhe, ATitulo);
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TfrmPessoaDetalhe.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
