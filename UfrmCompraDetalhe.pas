unit UfrmCompraDetalhe;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids,
  Vcl.DBGrids, Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.DApt,
  UConfirmarFechar, UConsultaCampos, UConsultaLayout, UCompraImpressao, UMapaCompra, UdmConexao,
  UFormatacaoMoeda;

type
  TfrmCompraDetalhe = class(TForm)
    pnlCabecalho: TPanel;
    lblNumero: TLabel;
    edtNumero: TEdit;
    lblSerie: TLabel;
    edtSerie: TEdit;
    lblEmissao: TLabel;
    edtEmissao: TEdit;
    lblEntrada: TLabel;
    edtEntrada: TEdit;
    lblFornecedor: TLabel;
    edtFornecedor: TEdit;
    lblValorTotal: TLabel;
    edtValorTotal: TEdit;
    pnlGrids: TPanel;
    grpProdutos: TGroupBox;
    gridProdutos: TDBGrid;
    pnlTotalProdutos: TPanel;
    lblTotalProdutos: TLabel;
    edtTotalProdutos: TEdit;
    pnlRodape: TPanel;
    btnImprimir: TButton;
    btnFechar: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure btnImprimirClick(Sender: TObject);
  private
    FEmpCodigo: Integer;
    FEntcContador: Integer;
    lblObservacao: TLabel;
    memObservacao: TMemo;
    lblChaveNfe: TLabel;
    edtChaveNfe: TEdit;
    FDQueryProdutos: TFDQuery;
    FDSProdutos: TDataSource;
    procedure ConfigurarCampoObservacao;
    procedure ConfigurarGrids;
    procedure AplicarTitulosGrid(AQuery: TFDQuery);
    procedure CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoQtdeGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure AtualizarTotalProdutos;
  public
    procedure Exibir(AEmpCodigo, AEntcContador: Integer);
  end;

implementation

{$R *.dfm}

procedure TfrmCompraDetalhe.FormCreate(Sender: TObject);
begin
  // AplicarConfirmacaoEsc(Self);
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  Position := poScreenCenter;

  AplicarEstiloTituloCampo(lblNumero);
  AplicarEstiloTituloCampo(lblSerie);
  AplicarEstiloTituloCampo(lblEmissao);
  AplicarEstiloTituloCampo(lblEntrada);
  AplicarEstiloTituloCampo(lblFornecedor);
  AplicarEstiloTituloCampo(lblValorTotal);
  AplicarEstiloTituloCampo(lblTotalProdutos);

  lblNumero.Caption := 'N'#250'mero';
  lblSerie.Caption := 'S'#233'rie';
  lblEmissao.Caption := 'Emiss'#227'o';
  lblEntrada.Caption := 'Entrada';
  lblFornecedor.Caption := 'Fornecedor';
  lblValorTotal.Caption := 'Valor total';
  lblTotalProdutos.Caption := 'Total produtos';

  edtNumero.ReadOnly := True;
  edtSerie.ReadOnly := True;
  edtEmissao.ReadOnly := True;
  edtEntrada.ReadOnly := True;
  edtFornecedor.ReadOnly := True;
  ConfigurarEditMoedaLeitura(edtValorTotal);
  ConfigurarEditMoedaLeitura(edtTotalProdutos);

  FDQueryProdutos := TFDQuery.Create(Self);
  FDSProdutos := TDataSource.Create(Self);
  FDSProdutos.DataSet := FDQueryProdutos;
  gridProdutos.DataSource := FDSProdutos;

  AjustarJanelaDetalhe(Self, 740);
  AjustarBotoesRodapeDireita(pnlRodape, [btnImprimir, btnFechar]);

  ConfigurarCampoObservacao;
  ConfigurarGrids;
end;

procedure TfrmCompraDetalhe.ConfigurarCampoObservacao;
begin
  pnlCabecalho.Height := 220;

  lblChaveNfe := TLabel.Create(Self);
  lblChaveNfe.Parent := pnlCabecalho;
  lblChaveNfe.Left := 16;
  lblChaveNfe.Top := 118;
  lblChaveNfe.Caption := 'Chave NFe';
  AplicarEstiloTituloCampo(lblChaveNfe);

  edtChaveNfe := TEdit.Create(Self);
  edtChaveNfe.Parent := pnlCabecalho;
  edtChaveNfe.Left := 16;
  edtChaveNfe.Top := 137;
  edtChaveNfe.Width := pnlCabecalho.Width - 32;
  edtChaveNfe.Anchors := [akLeft, akTop, akRight];
  edtChaveNfe.ReadOnly := True;

  lblObservacao := TLabel.Create(Self);
  lblObservacao.Parent := pnlCabecalho;
  lblObservacao.Left := 16;
  lblObservacao.Top := 168;
  lblObservacao.Caption := 'Observa'#231#227'o';
  AplicarEstiloTituloCampo(lblObservacao);

  memObservacao := TMemo.Create(Self);
  memObservacao.Parent := pnlCabecalho;
  memObservacao.Left := 16;
  memObservacao.Top := 187;
  memObservacao.Width := pnlCabecalho.Width - 32;
  memObservacao.Anchors := [akLeft, akTop, akRight];
  memObservacao.Height := 28;
  memObservacao.ReadOnly := True;
  memObservacao.ScrollBars := ssVertical;
  memObservacao.BorderStyle := bsNone;
  memObservacao.Color := clWindow;
end;

procedure TfrmCompraDetalhe.ConfigurarGrids;
begin
  gridProdutos.ReadOnly := True;
  gridProdutos.TitleFont.Name := 'Segoe UI';
  gridProdutos.TitleFont.Size := 10;
  gridProdutos.TitleFont.Style := [fsBold];
  ConfigurarOrdenacaoGrid(gridProdutos);
end;

procedure TfrmCompraDetalhe.CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  TConsultaMoedaHandlers.MoedaGetText(Sender, Text, DisplayText);
end;

procedure TfrmCompraDetalhe.CampoQtdeGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatarQuantidade(Sender.AsFloat);
end;

procedure TfrmCompraDetalhe.AtualizarTotalProdutos;
begin
  edtTotalProdutos.Text := FormatarMoedaBRL(
    SomarCampoTotal(FDQueryProdutos, 'ENTCIVRTOTALLIQUIDO'));
end;

procedure TfrmCompraDetalhe.AplicarTitulosGrid(AQuery: TFDQuery);
var
  I: Integer;
  Campo: TField;
  Nome: string;
begin
  for I := 0 to AQuery.FieldCount - 1 do
  begin
    Campo := AQuery.Fields[I];
    Nome := UpperCase(Campo.FieldName);

    if SameText(Nome, 'ENTCINUMEROITEM') then
      Campo.DisplayLabel := 'Item'
    else if SameText(Nome, 'CODIGO_ITEM') then
      Campo.DisplayLabel := 'Cod.Fabricante'
    else if Pos('DESCRICAO', Nome) > 0 then
      Campo.DisplayLabel := 'Descri'#231#227'o'
    else if Pos('QTDE', Nome) > 0 then
    begin
      Campo.DisplayLabel := 'Qtde';
      Campo.OnGetText := CampoQtdeGetText;
    end
    else if Pos('UNITARIO', Nome) > 0 then
    begin
      Campo.DisplayLabel := 'Unit'#225'rio';
      Campo.OnGetText := CampoMoedaGetText;
    end
    else if Pos('TOTALLIQUIDO', Nome) > 0 then
    begin
      Campo.DisplayLabel := 'Total';
      Campo.OnGetText := CampoMoedaGetText;
    end
    else
      Campo.DisplayLabel := Campo.FieldName;
  end;
end;

procedure TfrmCompraDetalhe.Exibir(AEmpCodigo, AEntcContador: Integer);
var
  Cab: TCompraCabecalho;
begin
  FEmpCodigo := AEmpCodigo;
  FEntcContador := AEntcContador;
  Caption := 'Compra - detalhes';

  Cab := TCompraImpressao.CarregarCabecalho(AEmpCodigo, AEntcContador);
  edtNumero.Text := Cab.Numero;
  edtSerie.Text := Cab.Serie;
  edtEmissao.Text := Cab.Emissao;
  edtEntrada.Text := Cab.Entrada;
  edtFornecedor.Text := Cab.Fornecedor;
  edtValorTotal.Text := Cab.ValorTotal;
  edtChaveNfe.Text := Cab.ChaveNfe;
  memObservacao.Lines.Text := Cab.Observacao;

  FDQueryProdutos.Close;
  FDQueryProdutos.Connection := dmConexao.FDConnection1;
  FDQueryProdutos.SQL.Text := TMapaCompra.MontarSQLProdutos;
  FDQueryProdutos.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
  FDQueryProdutos.ParamByName('ENTCCONTADOR').AsInteger := AEntcContador;
  FDQueryProdutos.Open;
  AplicarTitulosGrid(FDQueryProdutos);
  AjustarLargurasGridDetalhe(gridProdutos);
  AtualizarTotalProdutos;

  Caption := 'Compra ' + Cab.Numero + ' - detalhes';
end;

procedure TfrmCompraDetalhe.btnFecharClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmCompraDetalhe.btnImprimirClick(Sender: TObject);
begin
  try
    TCompraImpressao.Visualizar(FEmpCodigo, FEntcContador);
  except
    on E: Exception do
      MessageDlg('Erro ao imprimir compra:' + sLineBreak + sLineBreak + E.Message, mtError, [mbOK], 0);
  end;
end;

end.
