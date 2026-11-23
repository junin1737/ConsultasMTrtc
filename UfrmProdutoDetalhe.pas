unit UfrmProdutoDetalhe;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  UMapaEstoque, UConsultaCampos, UConfirmarFechar;

type
  TfrmProdutoDetalhe = class(TForm)
    pnlCabecalho: TPanel;
    lblCodigo: TLabel;
    edtCodigo: TEdit;
    lblDescricao: TLabel;
    edtDescricao: TEdit;
    lblEstoque: TLabel;
    edtEstoque: TEdit;
    lblEstoqueMinimo: TLabel;
    edtEstoqueMinimo: TEdit;
    lblPrecoVarejo: TLabel;
    edtPrecoVarejo: TEdit;
    lblPrecoAtacado: TLabel;
    edtPrecoAtacado: TEdit;
    pnlRodape: TPanel;
    btnFechar: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
  private
    procedure ConfigurarCampos;
    procedure ConfigurarEditLeitura(AEdit: TEdit);
  public
    function Exibir(AEmpCodigo, AProdContador: Integer): Boolean;
    class procedure Abrir(AEmpCodigo, AProdContador: Integer; const ATitulo: string = '');
  end;

implementation

{$R *.dfm}

procedure TfrmProdutoDetalhe.FormCreate(Sender: TObject);
begin
  // AplicarConfirmacaoEsc(Self);
  Position := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  ConfigurarCampos;
end;

procedure TfrmProdutoDetalhe.ConfigurarEditLeitura(AEdit: TEdit);
begin
  AEdit.ReadOnly := True;
  AEdit.Color := clWindow;
end;

procedure TfrmProdutoDetalhe.ConfigurarCampos;
begin
  AplicarEstiloTituloCampo(lblCodigo);
  AplicarEstiloTituloCampo(lblDescricao);
  AplicarEstiloTituloCampo(lblEstoque);
  AplicarEstiloTituloCampo(lblEstoqueMinimo);
  AplicarEstiloTituloCampo(lblPrecoVarejo);
  AplicarEstiloTituloCampo(lblPrecoAtacado);

  lblCodigo.Caption := 'Cod.Fabricante';

  ConfigurarEditLeitura(edtCodigo);
  ConfigurarEditLeitura(edtDescricao);
  ConfigurarEditLeitura(edtEstoque);
  ConfigurarEditLeitura(edtEstoqueMinimo);
  ConfigurarEditLeitura(edtPrecoVarejo);
  ConfigurarEditLeitura(edtPrecoAtacado);
end;

function TfrmProdutoDetalhe.Exibir(AEmpCodigo, AProdContador: Integer): Boolean;
var
  D: TDetalheProduto;
begin
  Result := False;
  D := TMapaEstoque.CarregarDetalhe(AEmpCodigo, AProdContador);
  if not D.Encontrado then
    Exit;

  edtCodigo.Text := D.Codigo;
  edtDescricao.Text := D.Descricao;
  edtEstoque.Text := D.Estoque;
  edtEstoqueMinimo.Text := D.EstoqueMinimo;
  edtPrecoVarejo.Text := D.PrecoVarejo;
  edtPrecoAtacado.Text := D.PrecoAtacado;
  Result := True;
end;

class procedure TfrmProdutoDetalhe.Abrir(AEmpCodigo, AProdContador: Integer; const ATitulo: string);
var
  Form: TfrmProdutoDetalhe;
begin
  Form := TfrmProdutoDetalhe.Create(Application);
  try
    if not Form.Exibir(AEmpCodigo, AProdContador) then
    begin
      MessageDlg('Produto n'#227'o encontrado.', mtInformation, [mbOK], 0);
      Exit;
    end;
    if ATitulo <> '' then
      Form.Caption := ATitulo;
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TfrmProdutoDetalhe.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
