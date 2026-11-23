unit UfrmPagar;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Buttons, Vcl.Grids, Vcl.DBGrids,
  Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Param, FireDAC.DApt,
  UfrmConsultaBase, UdmConexao, UConsultaCampos, UConsultaLayout, UMapaPagar, UfrmPagarDetalhe,
  UFormatacaoMoeda, UConsultaDialogs;

type
  TfrmPagar = class(TfrmConsultaBase)
    procedure FormCreate(Sender: TObject);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: Char);
  private
    FDQueryPagar: TFDQuery;
    DataSourcePagar: TDataSource;
    btnFiltroTodas: TSpeedButton;
    btnFiltroPagas: TSpeedButton;
    btnFiltroEmAberto: TSpeedButton;
    btnFiltroAtrasadas: TSpeedButton;
    FFiltroAtual: TFiltroPagarLista;
    procedure ConfigurarJanela;
    procedure ConfigurarDados;
    procedure ConfigurarFiltros;
    procedure ConfigurarFontes;
    procedure AjustarLayoutPagar;
    procedure AplicarTitulosGrid;
    procedure CampoDataGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoDocumentoGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoSituacaoGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure OcultarCamposInternos;
    procedure ConfigurarLargurasGrid;
    procedure DefinirFiltroAtivo(AFiltro: TFiltroPagarLista);
    procedure FiltroClick(Sender: TObject);
    procedure DBGrid1DrawColumnCell(Sender: TObject; const Rect: TRect; DataCol: Integer;
      Column: TColumn; State: TGridDrawState);
    function CorFonteLinha: TColor;
  protected
    function ObterDataSet: TDataSet; override;
    function ResolverTituloCampo(const ANomeCampo: string): string; override;
    procedure AbrirDetalheRegistro; override;
  public
    procedure CarregarDados(const AFiltro: string = '');
  end;

var
  frmPagar: TfrmPagar;

implementation

{$R *.dfm}

const
  LARGURA_BASE = 1540;
  ALTURA_BASE = 900;
  FATOR_TAMANHO = 0.70;
  COR_PAGA = TColor($00008800);
  ALTURA_PANEL_TOPO = 108;

procedure TfrmPagar.ConfigurarJanela;
begin
  AjustarJanelaConsulta(Self, LARGURA_BASE, ALTURA_BASE, FATOR_TAMANHO);
end;

function TfrmPagar.ObterDataSet: TDataSet;
begin
  Result := FDQueryPagar;
end;

function TfrmPagar.ResolverTituloCampo(const ANomeCampo: string): string;
var
  Nome: string;
begin
  Nome := UpperCase(ANomeCampo);
  if SameText(Nome, 'CPDOCUMENTO') then
    Exit('Documento');
  if SameText(Nome, 'CPDTEMISSAO') then
    Exit('Emiss'#227'o');
  if SameText(Nome, 'CPDTVENCTO') then
    Exit('Vencimento');
  if SameText(Nome, 'CPDTPAGTO') then
    Exit('Pagamento');
  if SameText(Nome, 'NOME_PESSOA') then
    Exit('Fornecedor');
  if SameText(Nome, 'CPVALOR') then
    Exit('Valor');
  if SameText(Nome, 'CPVALORPAGO') then
    Exit('Valor pago');
  if SameText(Nome, 'CPVALORABERTO') then
    Exit('Restante');
  if SameText(Nome, 'CPSITUACAO') then
    Exit('Situa'#231#227'o');
  Result := TituloAmigavelCampo(ANomeCampo);
end;

procedure TfrmPagar.ConfigurarDados;
begin
  FDQueryPagar := TFDQuery.Create(Self);
  FDQueryPagar.ResourceOptions.SilentMode := True;
  DataSourcePagar := TDataSource.Create(Self);
  DataSourcePagar.DataSet := FDQueryPagar;
  DBGrid1.DataSource := DataSourcePagar;
  edtPesquisa.OnKeyPress := edtPesquisaKeyPress;
  DBGrid1.OnDrawColumnCell := DBGrid1DrawColumnCell;
  DBGrid1.DefaultDrawing := False;
end;

procedure TfrmPagar.ConfigurarFiltros;
const
  BTN_LARGURA = 118;
  BTN_ALTURA = 28;
  BTN_ESPACO = 8;
  BTN_TOP = 68;
  BTN_LEFT_INICIO = 12;

  procedure CriarBotao(var ABtn: TSpeedButton; const ACaption: string; AFiltro: TFiltroPagarLista);
  begin
    ABtn := TSpeedButton.Create(Self);
    ABtn.Parent := PanelTopo;
    ABtn.Flat := True;
    ABtn.ShowHint := True;
    ABtn.Hint := ACaption;
    ABtn.Caption := ACaption;
    ABtn.Tag := Ord(AFiltro);
    ABtn.Height := BTN_ALTURA;
    ABtn.Width := BTN_LARGURA;
    ABtn.Top := BTN_TOP;
    ABtn.OnClick := FiltroClick;
    AplicarFonteSegoeUISemiBold(ABtn.Font, 9);
  end;

begin
  CriarBotao(btnFiltroTodas, 'Todas', fpTodas);
  CriarBotao(btnFiltroPagas, 'Pagas', fpPagas);
  CriarBotao(btnFiltroEmAberto, 'Em aberto', fpEmAberto);
  CriarBotao(btnFiltroAtrasadas, 'Atrasadas', fpAtrasadas);

  btnFiltroTodas.Left := BTN_LEFT_INICIO;
  btnFiltroPagas.Left := btnFiltroTodas.Left + BTN_LARGURA + BTN_ESPACO;
  btnFiltroEmAberto.Left := btnFiltroPagas.Left + BTN_LARGURA + BTN_ESPACO;
  btnFiltroAtrasadas.Left := btnFiltroEmAberto.Left + BTN_LARGURA + BTN_ESPACO;

  FFiltroAtual := fpTodas;
  DefinirFiltroAtivo(fpTodas);
end;

procedure TfrmPagar.ConfigurarFontes;
begin
  AplicarFonteConsultaForm(Self);
end;

procedure TfrmPagar.AjustarLayoutPagar;
begin
  PanelTopo.Height := ALTURA_PANEL_TOPO;
  DefinirLegendaPesquisa(
    'Pesquisar por n'#250'mero, documento ou fornecedor (Enter pesquisa):');
  AjustarLayoutPesquisaConsulta(PanelTopo, lblPesquisa, edtPesquisa);
end;

procedure TfrmPagar.DefinirFiltroAtivo(AFiltro: TFiltroPagarLista);

  procedure EstiloBotao(ABtn: TSpeedButton; AAtivo: Boolean);
  begin
    AplicarFonteSegoeUISemiBold(ABtn.Font, 9);
    if AAtivo then
      ABtn.Font.Color := clNavy
    else
      ABtn.Font.Color := clWindowText;
  end;

begin
  FFiltroAtual := AFiltro;
  EstiloBotao(btnFiltroTodas, AFiltro = fpTodas);
  EstiloBotao(btnFiltroPagas, AFiltro = fpPagas);
  EstiloBotao(btnFiltroEmAberto, AFiltro = fpEmAberto);
  EstiloBotao(btnFiltroAtrasadas, AFiltro = fpAtrasadas);
end;

procedure TfrmPagar.FiltroClick(Sender: TObject);
begin
  if not (Sender is TSpeedButton) then
    Exit;
  DefinirFiltroAtivo(TFiltroPagarLista(TSpeedButton(Sender).Tag));
  CarregarDados(edtPesquisa.Text);
end;

function TfrmPagar.CorFonteLinha: TColor;
var
  Situacao: Integer;
  Vencimento: TDateTime;
begin
  Result := clWindowText;
  if (FDQueryPagar = nil) or (not FDQueryPagar.Active) or FDQueryPagar.IsEmpty then
    Exit;

  Situacao := FDQueryPagar.FieldByName('CPSITUACAO').AsInteger;
  if Situacao = 1 then
    Exit(COR_PAGA);
  if Situacao = 2 then
    Exit(clGrayText);
  if Situacao = 0 then
  begin
    if FDQueryPagar.FieldByName('CPVALORABERTO').AsFloat <= 0 then
      Exit(COR_PAGA);
    if not FDQueryPagar.FieldByName('CPDTVENCTO').IsNull then
    begin
      Vencimento := FDQueryPagar.FieldByName('CPDTVENCTO').AsDateTime;
      if Trunc(Vencimento) < Date then
        Exit(clRed);
    end;
    Exit(clWindowText);
  end;
end;

procedure TfrmPagar.DBGrid1DrawColumnCell(Sender: TObject; const Rect: TRect;
  DataCol: Integer; Column: TColumn; State: TGridDrawState);
var
  Grid: TDBGrid;
  R: TRect;
  Texto: string;
  CorFonte: TColor;
  AlinharDireita: Boolean;
begin
  Grid := Sender as TDBGrid;
  R := Rect;

  if (gdSelected in State) or (gdFocused in State) then
  begin
    Grid.Canvas.Brush.Color := clHighlight;
    Grid.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    Grid.Canvas.Brush.Color := clWindow;
    CorFonte := CorFonteLinha;
    Grid.Canvas.Font.Color := CorFonte;
  end;

  Grid.Canvas.FillRect(R);

  if Column.Field <> nil then
    Texto := Column.Field.DisplayText
  else
    Texto := '';

  Grid.Canvas.Font := Grid.Font;
  if not ((gdSelected in State) or (gdFocused in State)) then
    Grid.Canvas.Font.Color := CorFonteLinha;

  AlinharDireita := (Column.Field <> nil) and
    (Column.Field.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd]);
  DesenharTextoCelulaGrid(Grid.Canvas, R, Texto, AlinharDireita);
end;

procedure TfrmPagar.CampoDataGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatDateTime('dd/mm/yyyy', Sender.AsDateTime);
end;

procedure TfrmPagar.CampoDocumentoGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatarDocumentoConsulta(Sender.AsString);
end;

procedure TfrmPagar.CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  TConsultaMoedaHandlers.MoedaGetText(Sender, Text, DisplayText);
end;

procedure TfrmPagar.CampoSituacaoGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    case Sender.AsInteger of
      0: Text := 'Em aberto';
      1: Text := 'Pago';
      2: Text := 'Cancelado';
    else
      Text := Sender.AsString;
    end;
end;

procedure TfrmPagar.OcultarCamposInternos;
var
  Campo: TField;
begin
  Campo := FDQueryPagar.FindField('EMPCODIGO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryPagar.FindField('CPNUMERO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryPagar.FindField('CPSITUACAO');
  if Campo <> nil then
    Campo.Visible := False;
end;

procedure TfrmPagar.AplicarTitulosGrid;
var
  I: Integer;
  Campo: TField;
  Nome: string;
begin
  for I := 0 to FDQueryPagar.FieldCount - 1 do
  begin
    Campo := FDQueryPagar.Fields[I];
    Campo.DisplayLabel := ResolverTituloCampo(Campo.FieldName);
    Nome := UpperCase(Campo.FieldName);
    if (Nome = 'CPDTEMISSAO') or (Nome = 'CPDTVENCTO') or (Nome = 'CPDTPAGTO') then
      Campo.OnGetText := CampoDataGetText
    else if Nome = 'CPDOCUMENTO' then
      Campo.OnGetText := CampoDocumentoGetText
    else if (Nome = 'CPVALOR') or (Nome = 'CPVALORPAGO') or (Nome = 'CPVALORABERTO') then
      Campo.OnGetText := CampoMoedaGetText
    else if Nome = 'CPSITUACAO' then
      Campo.OnGetText := CampoSituacaoGetText;
  end;
  OcultarCamposInternos;
  ConfigurarLargurasGrid;
end;

procedure TfrmPagar.ConfigurarLargurasGrid;
var
  I: Integer;
  Col: TColumn;
  Campo: TField;
  Nome: string;
const
  LARGURA_COL_MOEDA = 118;
begin
  Campo := FDQueryPagar.FindField('CPDOCUMENTO');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryPagar.FindField('NOME_PESSOA');
  if Campo <> nil then
    Campo.DisplayWidth := 24;
  Campo := FDQueryPagar.FindField('CPDTVENCTO');
  if Campo <> nil then
    Campo.DisplayWidth := 11;
  Campo := FDQueryPagar.FindField('CPVALOR');
  if Campo <> nil then
    Campo.DisplayWidth := 18;
  Campo := FDQueryPagar.FindField('CPVALORPAGO');
  if Campo <> nil then
    Campo.DisplayWidth := 18;
  Campo := FDQueryPagar.FindField('CPVALORABERTO');
  if Campo <> nil then
    Campo.DisplayWidth := 18;

  for I := 0 to DBGrid1.Columns.Count - 1 do
  begin
    Col := DBGrid1.Columns[I];
    if (Col.Field = nil) or (not Col.Visible) then
      Continue;
    Nome := UpperCase(Col.Field.FieldName);
    if (Nome = 'CPVALOR') or (Nome = 'CPVALORPAGO') or (Nome = 'CPVALORABERTO') then
      Col.Width := LARGURA_COL_MOEDA
    else if Nome = 'NOME_PESSOA' then
      Col.Width := 210;
  end;
end;

procedure TfrmPagar.AbrirDetalheRegistro;
var
  DS: TDataSet;
begin
  DS := ObterDataSet;
  if (DS = nil) or (not DS.Active) or DS.IsEmpty then
    Exit;

  TfrmPagarDetalhe.Abrir(
    DS.FieldByName('EMPCODIGO').AsInteger,
    DS.FieldByName('CPNUMERO').AsInteger,
    'Detalhes - ' + Caption);
end;

procedure TfrmPagar.FormCreate(Sender: TObject);
begin
  inherited;
  ConfigurarJanela;
  DefinirTitulo('Contas a Pagar');
  ConfigurarDados;
  ConfigurarFiltros;
  ConfigurarFontes;
  AjustarLayoutPagar;
end;

procedure TfrmPagar.CarregarDados(const AFiltro: string);
var
  SQL, Filtro: string;
begin
  if not dmConexao.Conectado then
  begin
    ErroConsulta(Self, 'Banco de dados n'#227'o conectado.', '');
    Exit;
  end;

  Filtro := Trim(AFiltro);
  FDQueryPagar.Close;
  try
    SQL := TMapaPagar.MontarSQLLista(Filtro, FFiltroAtual);
    FDQueryPagar.Connection := dmConexao.FDConnection1;
    FDQueryPagar.SQL.Text := SQL;
    if Filtro <> '' then
      TMapaPagar.ConfigurarParametrosLista(FDQueryPagar, Filtro);
    FDQueryPagar.Open;
    AplicarTitulosGrid;
  except
    on E: Exception do
    begin
      FDQueryPagar.Close;
      ErroConsulta(Self, 'Erro ao consultar contas a pagar:', E.Message);
    end;
  end;
end;

procedure TfrmPagar.edtPesquisaKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    CarregarDados(edtPesquisa.Text);
  end;
end;

end.
