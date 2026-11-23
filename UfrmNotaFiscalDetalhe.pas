unit UfrmNotaFiscalDetalhe;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids,
  Vcl.DBGrids, Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.DApt,
  UConfirmarFechar, UConsultaCampos, UConsultaLayout, UNotaFiscalImpressao, UNfceImpressao,
  UMapaNotaFiscal,
  UMapaNfce, UdmConexao, UFormatacaoMoeda;

type
  TfrmNotaFiscalDetalhe = class(TForm)
    pnlCabecalho: TPanel;
    lblNumero: TLabel;
    edtNumero: TEdit;
    lblEmissao: TLabel;
    edtEmissao: TEdit;
    lblSaida: TLabel;
    edtSaida: TEdit;
    lblCliente: TLabel;
    edtCliente: TEdit;
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
    FNfContador: Integer;
    FModoNfce: Boolean;
    FVenNumero: Integer;
    FTerNumero: Integer;
    FNfceNumero: Integer;
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
    procedure Exibir(AEmpCodigo, ANfContador: Integer);
    procedure ExibirNfce(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero: Integer);
  end;

implementation

{$R *.dfm}

procedure TfrmNotaFiscalDetalhe.FormCreate(Sender: TObject);
begin
  // AplicarConfirmacaoEsc(Self);
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  Position := poScreenCenter;

  AplicarEstiloTituloCampo(lblNumero);
  AplicarEstiloTituloCampo(lblEmissao);
  AplicarEstiloTituloCampo(lblSaida);
  AplicarEstiloTituloCampo(lblCliente);
  AplicarEstiloTituloCampo(lblValorTotal);
  AplicarEstiloTituloCampo(lblTotalProdutos);

  lblNumero.Caption := 'N'#250'mero NF';
  lblEmissao.Caption := 'Emiss'#227'o';
  lblSaida.Caption := 'Sa'#237'da';
  lblCliente.Caption := 'Cliente';
  lblValorTotal.Caption := 'Valor total';
  lblTotalProdutos.Caption := 'Total produtos';

  edtNumero.ReadOnly := True;
  edtEmissao.ReadOnly := True;
  edtSaida.ReadOnly := True;
  edtCliente.ReadOnly := True;
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

procedure TfrmNotaFiscalDetalhe.ConfigurarCampoObservacao;
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
  lblObservacao.Caption := 'Informa'#231#245'es adicionais';
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

procedure TfrmNotaFiscalDetalhe.ConfigurarGrids;
begin
  gridProdutos.ReadOnly := True;
  gridProdutos.TitleFont.Name := 'Segoe UI';
  gridProdutos.TitleFont.Size := 10;
  gridProdutos.TitleFont.Style := [fsBold];
  ConfigurarOrdenacaoGrid(gridProdutos);
end;

procedure TfrmNotaFiscalDetalhe.CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  TConsultaMoedaHandlers.MoedaGetText(Sender, Text, DisplayText);
end;

procedure TfrmNotaFiscalDetalhe.CampoQtdeGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatarQuantidade(Sender.AsFloat);
end;

procedure TfrmNotaFiscalDetalhe.AtualizarTotalProdutos;
begin
  edtTotalProdutos.Text := FormatarMoedaBRL(
    SomarCampoTotal(FDQueryProdutos, 'NFITEMTOTALLIQUIDO'));
end;

procedure TfrmNotaFiscalDetalhe.AplicarTitulosGrid(AQuery: TFDQuery);
var
  I: Integer;
  Campo: TField;
  Nome: string;
begin
  for I := 0 to AQuery.FieldCount - 1 do
  begin
    Campo := AQuery.Fields[I];
    Nome := UpperCase(Campo.FieldName);

    if SameText(Nome, 'NFITEMCONTADOR') then
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

procedure TfrmNotaFiscalDetalhe.Exibir(AEmpCodigo, ANfContador: Integer);
var
  Cab: TNotaFiscalCabecalho;
begin
  FModoNfce := False;
  FEmpCodigo := AEmpCodigo;
  FNfContador := ANfContador;
  Caption := 'Nota fiscal - detalhes';
  lblNumero.Caption := 'N'#250'mero NF';
  lblChaveNfe.Caption := 'Chave NFe';

  Cab := TNotaFiscalImpressao.CarregarCabecalho(AEmpCodigo, ANfContador);
  edtNumero.Text := Cab.Numero;
  edtEmissao.Text := Cab.Emissao;
  edtSaida.Text := Cab.Saida;
  edtCliente.Text := Cab.Cliente;
  edtValorTotal.Text := Cab.ValorTotal;
  edtChaveNfe.Text := Cab.ChaveNfe;
  memObservacao.Lines.Text := Cab.Observacao;

  FDQueryProdutos.Close;
  FDQueryProdutos.Connection := dmConexao.FDConnection1;
  FDQueryProdutos.SQL.Text := TMapaNotaFiscal.MontarSQLProdutos;
  FDQueryProdutos.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
  FDQueryProdutos.ParamByName('NFCONTADOR').AsInteger := ANfContador;
  FDQueryProdutos.Open;
  AplicarTitulosGrid(FDQueryProdutos);
  AjustarLargurasGridDetalhe(gridProdutos);
  AtualizarTotalProdutos;

  Caption := 'NF ' + Cab.Numero + ' - detalhes';
end;

procedure TfrmNotaFiscalDetalhe.ExibirNfce(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer);
var
  Cab: TNfceCabecalho;
begin
  FModoNfce := True;
  FEmpCodigo := AEmpCodigo;
  FVenNumero := AVenNumero;
  FTerNumero := ATerNumero;
  FNfceNumero := ANfceNumero;
  Caption := 'NFC-e - detalhes';
  lblNumero.Caption := 'N'#250'mero NFC-e';
  lblChaveNfe.Caption := 'Chave NFC-e';

  Cab := TNfceImpressao.CarregarCabecalho(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  edtNumero.Text := Cab.Numero;
  edtEmissao.Text := Cab.Emissao;
  edtSaida.Text := Cab.Saida;
  edtCliente.Text := Cab.Cliente;
  edtValorTotal.Text := Cab.ValorTotal;
  edtChaveNfe.Text := Cab.ChaveNfe;
  memObservacao.Lines.Text := Cab.Observacao;

  FDQueryProdutos.Close;
  FDQueryProdutos.Connection := dmConexao.FDConnection1;
  FDQueryProdutos.SQL.Text := TMapaNfce.MontarSQLProdutos;
  FDQueryProdutos.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
  FDQueryProdutos.ParamByName('VENNUMERO').AsInteger := AVenNumero;
  FDQueryProdutos.ParamByName('TERNUMERO').AsInteger := ATerNumero;
  FDQueryProdutos.Open;
  AplicarTitulosGrid(FDQueryProdutos);
  AjustarLargurasGridDetalhe(gridProdutos);
  AtualizarTotalProdutos;

  Caption := 'NFC-e ' + Cab.Numero + ' - detalhes';
end;

procedure TfrmNotaFiscalDetalhe.btnFecharClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmNotaFiscalDetalhe.btnImprimirClick(Sender: TObject);
begin
  try
    if FModoNfce then
      TNfceImpressao.Visualizar(FEmpCodigo, FVenNumero, FTerNumero, FNfceNumero)
    else
      TNotaFiscalImpressao.Visualizar(FEmpCodigo, FNfContador);
  except
    on E: Exception do
    begin
      if FModoNfce then
        MessageDlg('Erro ao imprimir NFC-e:' + sLineBreak + sLineBreak + E.Message, mtError, [mbOK], 0)
      else
        MessageDlg('Erro ao imprimir nota fiscal:' + sLineBreak + sLineBreak + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

end.
