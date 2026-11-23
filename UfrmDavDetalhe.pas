unit UfrmDavDetalhe;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Grids,
  Vcl.DBGrids, Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.DApt,
  UConfirmarFechar, UConsultaCampos, UConsultaLayout, UDavImpressao, UMapaDav, UdmConexao,
  UFormatacaoMoeda, UCampoObservacao;

type
  TfrmDavDetalhe = class(TForm)
    pnlCabecalho: TPanel;
    lblNumero: TLabel;
    edtNumero: TEdit;
    lblEmissao: TLabel;
    edtEmissao: TEdit;
    lblCliente: TLabel;
    edtCliente: TEdit;
    lblVencimento: TLabel;
    edtVencimento: TEdit;
    lblValorTotal: TLabel;
    edtValorTotal: TEdit;
    pnlGrids: TPanel;
    grpServicos: TGroupBox;
    gridServicos: TDBGrid;
    pnlTotalServicos: TPanel;
    lblTotalServicos: TLabel;
    edtTotalServicos: TEdit;
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
    FDavContador: Integer;
    lblObservacao: TLabel;
    memObservacao: TMemo;
    lblUsuario: TLabel;
    edtUsuario: TEdit;
    FDQueryProdutos: TFDQuery;
    FDQueryServicos: TFDQuery;
    FDSProdutos: TDataSource;
    FDSServicos: TDataSource;
    procedure ConfigurarCampoObservacao;
    procedure ConfigurarCampoUsuario;
    procedure ConfigurarGrids;
    procedure AplicarTitulosGrid(AQuery: TFDQuery);
    procedure CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoQtdeGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure AtualizarTotaisCategoria;
  public
    procedure Exibir(AEmpCodigo, ADavContador: Integer);
  end;

implementation

{$R *.dfm}

procedure TfrmDavDetalhe.FormCreate(Sender: TObject);
begin
  // AplicarConfirmacaoEsc(Self);
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  Position := poScreenCenter;

  AplicarEstiloTituloCampo(lblNumero);
  AplicarEstiloTituloCampo(lblEmissao);
  AplicarEstiloTituloCampo(lblCliente);
  AplicarEstiloTituloCampo(lblVencimento);
  AplicarEstiloTituloCampo(lblValorTotal);
  AplicarEstiloTituloCampo(lblTotalServicos);
  AplicarEstiloTituloCampo(lblTotalProdutos);

  lblNumero.Caption := 'N'#250'mero DAV';
  lblEmissao.Caption := 'Data emiss'#227'o';
  lblCliente.Caption := 'Cliente';
  lblVencimento.Caption := 'Vencimento';
  lblValorTotal.Caption := 'Valor total';
  lblTotalServicos.Caption := 'Total servi'#231'os';
  lblTotalProdutos.Caption := 'Total produtos';

  edtNumero.ReadOnly := True;
  edtEmissao.ReadOnly := True;
  edtCliente.ReadOnly := True;
  edtVencimento.ReadOnly := True;
  ConfigurarEditMoedaLeitura(edtValorTotal);
  ConfigurarEditMoedaLeitura(edtTotalServicos);
  ConfigurarEditMoedaLeitura(edtTotalProdutos);

  FDQueryProdutos := TFDQuery.Create(Self);
  FDQueryServicos := TFDQuery.Create(Self);
  FDSProdutos := TDataSource.Create(Self);
  FDSServicos := TDataSource.Create(Self);
  FDSProdutos.DataSet := FDQueryProdutos;
  FDSServicos.DataSet := FDQueryServicos;
  gridProdutos.DataSource := FDSProdutos;
  gridServicos.DataSource := FDSServicos;

  AjustarJanelaDetalhe(Self, 740);
  AjustarBotoesRodapeDireita(pnlRodape, [btnImprimir, btnFechar]);

  ConfigurarCampoObservacao;
  ConfigurarCampoUsuario;
  ConfigurarGrids;
end;

procedure TfrmDavDetalhe.ConfigurarCampoObservacao;
begin
  pnlCabecalho.Height := 190;
  lblObservacao := TLabel.Create(Self);
  lblObservacao.Parent := pnlCabecalho;
  lblObservacao.Left := 16;
  lblObservacao.Top := 118;
  lblObservacao.Caption := 'Observa'#231#227'o';
  AplicarEstiloTituloCampo(lblObservacao);

  memObservacao := TMemo.Create(Self);
  memObservacao.Parent := pnlCabecalho;
  memObservacao.Left := 16;
  memObservacao.Top := 137;
  memObservacao.Width := pnlCabecalho.Width - 32;
  memObservacao.Anchors := [akLeft, akTop, akRight];
  memObservacao.Height := 44;
  memObservacao.ReadOnly := True;
  memObservacao.ScrollBars := ssVertical;
  memObservacao.BorderStyle := bsNone;
  memObservacao.Color := clWindow;
end;

procedure TfrmDavDetalhe.ConfigurarCampoUsuario;
begin
  lblUsuario := TLabel.Create(Self);
  lblUsuario.Parent := pnlCabecalho;
  lblUsuario.Left := 580;
  lblUsuario.Top := 16;
  lblUsuario.Caption := 'Usu'#225'rio';
  AplicarEstiloTituloCampo(lblUsuario);

  edtUsuario := TEdit.Create(Self);
  edtUsuario.Parent := pnlCabecalho;
  edtUsuario.Left := 580;
  edtUsuario.Top := 35;
  edtUsuario.Width := 140;
  edtUsuario.ReadOnly := True;
  edtUsuario.TabStop := False;
end;

procedure TfrmDavDetalhe.ConfigurarGrids;
begin
  gridProdutos.ReadOnly := True;
  gridServicos.ReadOnly := True;
  gridProdutos.TitleFont.Name := 'Segoe UI';
  gridProdutos.TitleFont.Size := 10;
  gridProdutos.TitleFont.Style := [fsBold];
  gridServicos.TitleFont.Name := 'Segoe UI';
  gridServicos.TitleFont.Size := 10;
  gridServicos.TitleFont.Style := [fsBold];
  ConfigurarOrdenacaoGrid(gridProdutos);
  ConfigurarOrdenacaoGrid(gridServicos);
end;

procedure TfrmDavDetalhe.CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  TConsultaMoedaHandlers.MoedaGetText(Sender, Text, DisplayText);
end;

procedure TfrmDavDetalhe.CampoQtdeGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatarQuantidade(Sender.AsFloat);
end;

procedure TfrmDavDetalhe.AtualizarTotaisCategoria;
begin
  edtTotalProdutos.Text := FormatarMoedaBRL(
    SomarCampoTotal(FDQueryProdutos, 'DAVITEMTOTALLIQUIDO'));
  edtTotalServicos.Text := FormatarMoedaBRL(
    SomarCampoTotal(FDQueryServicos, 'DAVITEMSERVTOTALLIQUIDO'));
end;

procedure TfrmDavDetalhe.AplicarTitulosGrid(AQuery: TFDQuery);
var
  I: Integer;
  Campo: TField;
  Nome: string;
begin
  for I := 0 to AQuery.FieldCount - 1 do
  begin
    Campo := AQuery.Fields[I];
    Nome := UpperCase(Campo.FieldName);

    if SameText(Nome, 'DAVITEMORDEM') or SameText(Nome, 'DAVITEMSERVORDEM') then
      Campo.DisplayLabel := 'Item'
    else if SameText(Nome, 'CODIGO_ITEM') then
      Campo.DisplayLabel := 'C'#243'digoFab'
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

procedure TfrmDavDetalhe.Exibir(AEmpCodigo, ADavContador: Integer);
var
  Cab: TDavCabecalho;
begin
  FEmpCodigo := AEmpCodigo;
  FDavContador := ADavContador;
  Caption := 'DAV - detalhes';

  Cab := TDavImpressao.CarregarCabecalho(AEmpCodigo, ADavContador);
  edtNumero.Text := Cab.Numero;
  edtEmissao.Text := Cab.Emissao;
  edtCliente.Width := 680;
  edtCliente.Text := Cab.Cliente;
  edtVencimento.Text := Cab.Vencimento;
  edtValorTotal.Text := Cab.ValorTotal;
  edtUsuario.Text := Cab.Usuario;
  memObservacao.Lines.Text := CarregarObservacaoDocumento(nil,
    ['DAVOBS', 'DAVINFORMACOESADICIONAIS', 'DAVOBSERVACAO', 'OBSERVACAO', 'OBS'],
    'DAV', 'DAVCONTADOR', AEmpCodigo, ADavContador);
  if memObservacao.Lines.Text = '' then
    memObservacao.Lines.Text := Cab.Observacao;

  FDQueryProdutos.Close;
  FDQueryProdutos.Connection := dmConexao.FDConnection1;
  FDQueryProdutos.SQL.Text := TMapaDav.MontarSQLProdutos;
  FDQueryProdutos.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
  FDQueryProdutos.ParamByName('DAVCONTADOR').AsInteger := ADavContador;
  FDQueryProdutos.Open;
  AplicarTitulosGrid(FDQueryProdutos);
  AjustarLargurasGridDetalhe(gridProdutos);

  FDQueryServicos.Close;
  FDQueryServicos.Connection := dmConexao.FDConnection1;
  FDQueryServicos.SQL.Text := TMapaDav.MontarSQLServicos;
  FDQueryServicos.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
  FDQueryServicos.ParamByName('DAVCONTADOR').AsInteger := ADavContador;
  FDQueryServicos.Open;
  AplicarTitulosGrid(FDQueryServicos);
  AjustarLargurasGridDetalhe(gridServicos);
  AtualizarTotaisCategoria;

  Caption := 'DAV ' + Cab.Numero + ' - detalhes';
end;

procedure TfrmDavDetalhe.btnFecharClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmDavDetalhe.btnImprimirClick(Sender: TObject);
begin
  try
    TDavImpressao.Visualizar(FEmpCodigo, FDavContador);
  except
    on E: Exception do
      MessageDlg('Erro ao imprimir DAV:' + sLineBreak + sLineBreak + E.Message, mtError, [mbOK], 0);
  end;
end;

end.
