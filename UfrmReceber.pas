unit UfrmReceber;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Buttons, Vcl.Grids, Vcl.DBGrids,
  Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Param, FireDAC.DApt,
  UfrmConsultaBase, UdmConexao, UConsultaCampos, UConsultaLayout, UMapaReceber, UfrmReceberDetalhe,
  UfrmReceberBoletoDetalhe, UFormatacaoMoeda, UConsultaDialogs, UFiltroPeriodoConsulta;

type
  TfrmReceber = class(TfrmConsultaBase)
    procedure FormCreate(Sender: TObject);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: Char);
  private
    FDQueryReceber: TFDQuery;
    DataSourceReceber: TDataSource;
    btnFiltroTodas: TSpeedButton;
    btnFiltroRecebidas: TSpeedButton;
    btnFiltroEmAberto: TSpeedButton;
    btnFiltroAtrasadas: TSpeedButton;
    btnFiltroBoletoTodos: TSpeedButton;
    btnFiltroBoletoCom: TSpeedButton;
    btnFiltroBoletoSem: TSpeedButton;
    btnVerBoleto: TButton;
    pnlFiltros: TPanel;
    lblCodigoCliente: TLabel;
    edtCodigoCliente: TEdit;
    lblNossoNumero: TLabel;
    edtNossoNumero: TEdit;
    FFiltroPeriodoEmissao: TControlesFiltroPeriodo;
    FFiltroPeriodoVencimento: TControlesFiltroPeriodo;
    FFiltroPeriodoRecebimento: TControlesFiltroPeriodo;
    FFiltroAtual: TFiltroReceberLista;
    FFiltroBoletoAtual: TFiltroReceberBoleto;
    procedure ConfigurarJanela;
    procedure ConfigurarDados;
    procedure ConfigurarPainelFiltros;
    procedure ConfigurarBotoesRodape;
    procedure ConfigurarFontes;
    procedure AjustarLayoutReceber;
    procedure AplicarTitulosGrid;
    procedure CampoDataGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoDocumentoGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoCpfCnpjGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoSituacaoGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoBoletoGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure DataSourceReceberDataChange(Sender: TObject; Field: TField);
    procedure OcultarCamposInternos;
    procedure ConfigurarLargurasGrid;
    procedure DefinirFiltroAtivo(AFiltro: TFiltroReceberLista);
    procedure DefinirFiltroBoletoAtivo(AFiltro: TFiltroReceberBoleto);
    procedure FiltroClick(Sender: TObject);
    procedure FiltroBoletoClick(Sender: TObject);
    procedure FiltroAvancadoAlterado(Sender: TObject);
    procedure btnVerBoletoClick(Sender: TObject);
    procedure DBGrid1CellClick(Column: TColumn);
    procedure DBGrid1DrawColumnCell(Sender: TObject; const Rect: TRect; DataCol: Integer;
      Column: TColumn; State: TGridDrawState);
    function CorFonteLinha: TColor;
    function LinhaTemBoleto: Boolean;
    function ObterFiltrosConsulta: TFiltrosReceberConsulta;
    procedure AbrirBoletoSelecionado;
  protected
    function ObterDataSet: TDataSet; override;
    function ResolverTituloCampo(const ANomeCampo: string): string; override;
    procedure AbrirDetalheRegistro; override;
  public
    procedure CarregarDados(const AFiltro: string = '');
  end;

var
  frmReceber: TfrmReceber;

implementation

{$R *.dfm}

const
  LARGURA_BASE = 1620;
  ALTURA_BASE = 900;
  FATOR_TAMANHO = 0.70;
  COR_RECEBIDA = TColor($00008800);
  COR_BOLETO_SIM = TColor($000066CC);
  ALTURA_BUSCA = 50;
  ALTURA_PNL_FILTROS = 188;
  ALTURA_PANEL_TOPO = ALTURA_BUSCA + ALTURA_PNL_FILTROS;
  GRUPO_SITUACAO = 10;
  GRUPO_BOLETO = 11;

procedure TfrmReceber.ConfigurarJanela;
begin
  AjustarJanelaConsulta(Self, LARGURA_BASE, ALTURA_BASE, FATOR_TAMANHO);
end;

function TfrmReceber.ObterDataSet: TDataSet;
begin
  Result := FDQueryReceber;
end;

function TfrmReceber.ResolverTituloCampo(const ANomeCampo: string): string;
var
  Nome: string;
begin
  Nome := UpperCase(ANomeCampo);
  if SameText(Nome, 'CRDOCUMENTO') then
    Exit('Documento');
  if SameText(Nome, 'CRDTEMISSAO') then
    Exit('Emiss'#227'o');
  if SameText(Nome, 'CRDTVENCTO') then
    Exit('Vencimento');
  if SameText(Nome, 'CRDTRECEBIMENTO') then
    Exit('Recebimento');
  if SameText(Nome, 'CODIGO_CLIENTE') then
    Exit('C'#243'digo');
  if SameText(Nome, 'NOME_PESSOA') then
    Exit('Cliente');
  if SameText(Nome, 'CPF_CNPJ') then
    Exit('CPF/CNPJ');
  if SameText(Nome, 'CRVALOR') then
    Exit('Valor');
  if SameText(Nome, 'CRVALORRECEBIDO') then
    Exit('Valor recebido');
  if SameText(Nome, 'CRVALORABERTO') then
    Exit('Restante');
  if SameText(Nome, 'CRSITUACAO') then
    Exit('Situa'#231#227'o');
  if SameText(Nome, 'TEM_BOLETO') then
    Exit('Boleto');
  Result := TituloAmigavelCampo(ANomeCampo);
end;

procedure TfrmReceber.ConfigurarDados;
begin
  FDQueryReceber := TFDQuery.Create(Self);
  FDQueryReceber.ResourceOptions.SilentMode := True;
  DataSourceReceber := TDataSource.Create(Self);
  DataSourceReceber.DataSet := FDQueryReceber;
  DataSourceReceber.OnDataChange := DataSourceReceberDataChange;
  DBGrid1.DataSource := DataSourceReceber;
  edtPesquisa.OnKeyPress := edtPesquisaKeyPress;
  DBGrid1.OnDrawColumnCell := DBGrid1DrawColumnCell;
  DBGrid1.OnCellClick := DBGrid1CellClick;
  DBGrid1.DefaultDrawing := False;
end;

procedure TfrmReceber.ConfigurarBotoesRodape;
begin
  btnVerBoleto := TButton.Create(Self);
  btnVerBoleto.Parent := PanelRodape;
  btnVerBoleto.Caption := 'Ver boleto';
  btnVerBoleto.Width := 110;
  btnVerBoleto.Height := 29;
  btnVerBoleto.Enabled := False;
  btnVerBoleto.OnClick := btnVerBoletoClick;
  AplicarFonteSegoeUISemiBold(btnVerBoleto.Font, 9);
  AjustarBotoesRodapeDireita(PanelRodape, [btnVerBoleto, btnFechar]);
end;

procedure TfrmReceber.ConfigurarPainelFiltros;

  function CriarGrupo(const ACaption: string; ALeft, ATop, AWidth, AHeight: Integer): TGroupBox;
  begin
    Result := TGroupBox.Create(Self);
    Result.Parent := pnlFiltros;
    Result.Caption := ACaption;
    Result.Left := ALeft;
    Result.Top := ATop;
    Result.Width := AWidth;
    Result.Height := AHeight;
    AplicarFonteSegoeUISemiBold(Result.Font, 9);
  end;

  procedure CriarBotaoSituacao(var ABtn: TSpeedButton; AParent: TWinControl;
    const ACaption: string; AFiltro: TFiltroReceberLista; ALeft, ATop, AWidth: Integer);
  begin
    ABtn := TSpeedButton.Create(Self);
    ABtn.Parent := AParent;
    ABtn.Caption := ACaption;
    ABtn.Tag := Ord(AFiltro);
    ABtn.GroupIndex := GRUPO_SITUACAO;
    ABtn.AllowAllUp := False;
    ABtn.Flat := False;
    ABtn.Left := ALeft;
    ABtn.Top := ATop;
    ABtn.Width := AWidth;
    ABtn.Height := 26;
    ABtn.OnClick := FiltroClick;
    AplicarFonteSegoeUISemiBold(ABtn.Font, 9);
  end;

  procedure CriarBotaoBoleto(var ABtn: TSpeedButton; AParent: TWinControl;
    const ACaption: string; AFiltro: TFiltroReceberBoleto; ALeft, ATop, AWidth: Integer);
  begin
    ABtn := TSpeedButton.Create(Self);
    ABtn.Parent := AParent;
    ABtn.Caption := ACaption;
    ABtn.Tag := Ord(AFiltro);
    ABtn.GroupIndex := GRUPO_BOLETO;
    ABtn.AllowAllUp := False;
    ABtn.Flat := False;
    ABtn.Left := ALeft;
    ABtn.Top := ATop;
    ABtn.Width := AWidth;
    ABtn.Height := 26;
    ABtn.OnClick := FiltroBoletoClick;
    AplicarFonteSegoeUISemiBold(ABtn.Font, 9);
  end;

var
  grpSituacao, grpBoleto, grpIdentificacao, grpPeriodos: TGroupBox;
const
  MARGEM = 8;
  BTN_ESPACO = 6;
  BTN_SIT_LARGURA = 96;
  BTN_BOL_LARGURA = 100;
begin
  pnlFiltros := TPanel.Create(Self);
  pnlFiltros.Parent := PanelTopo;
  pnlFiltros.Align := alBottom;
  pnlFiltros.Height := ALTURA_PNL_FILTROS;
  pnlFiltros.BevelOuter := bvNone;
  pnlFiltros.Color := clWindow;
  pnlFiltros.ParentBackground := False;

  grpSituacao := CriarGrupo('Situa'#231#227'o', MARGEM, 4, 428, 54);
  CriarBotaoSituacao(btnFiltroTodas, grpSituacao, 'Todas', frTodas, 10, 22, BTN_SIT_LARGURA);
  CriarBotaoSituacao(btnFiltroRecebidas, grpSituacao, 'Recebidas', frRecebidas,
    btnFiltroTodas.Left + BTN_SIT_LARGURA + BTN_ESPACO, 22, BTN_SIT_LARGURA);
  CriarBotaoSituacao(btnFiltroEmAberto, grpSituacao, 'Em aberto', frEmAberto,
    btnFiltroRecebidas.Left + BTN_SIT_LARGURA + BTN_ESPACO, 22, BTN_SIT_LARGURA);
  CriarBotaoSituacao(btnFiltroAtrasadas, grpSituacao, 'Atrasadas', frAtrasadas,
    btnFiltroEmAberto.Left + BTN_SIT_LARGURA + BTN_ESPACO, 22, BTN_SIT_LARGURA);

  grpBoleto := CriarGrupo('Boleto', grpSituacao.Left + grpSituacao.Width + MARGEM, 4, 324, 54);
  CriarBotaoBoleto(btnFiltroBoletoTodos, grpBoleto, 'Todos', fbBoletoTodos, 10, 22, BTN_BOL_LARGURA);
  CriarBotaoBoleto(btnFiltroBoletoCom, grpBoleto, 'Com boleto', fbBoletoCom,
    btnFiltroBoletoTodos.Left + BTN_BOL_LARGURA + BTN_ESPACO, 22, BTN_BOL_LARGURA);
  CriarBotaoBoleto(btnFiltroBoletoSem, grpBoleto, 'Sem boleto', fbBoletoSem,
    btnFiltroBoletoCom.Left + BTN_BOL_LARGURA + BTN_ESPACO, 22, BTN_BOL_LARGURA);

  grpIdentificacao := CriarGrupo('Identifica'#231#227'o', MARGEM, 62, 744, 48);
  lblCodigoCliente := TLabel.Create(Self);
  lblCodigoCliente.Parent := grpIdentificacao;
  lblCodigoCliente.Left := 10;
  lblCodigoCliente.Top := 22;
  lblCodigoCliente.Caption := 'C'#243'digo cliente:';
  AplicarFonteSegoeUISemiBold(lblCodigoCliente.Font, 9);

  edtCodigoCliente := TEdit.Create(Self);
  edtCodigoCliente.Parent := grpIdentificacao;
  edtCodigoCliente.Left := 112;
  edtCodigoCliente.Top := 19;
  edtCodigoCliente.Width := 88;
  edtCodigoCliente.OnKeyPress := edtPesquisaKeyPress;

  lblNossoNumero := TLabel.Create(Self);
  lblNossoNumero.Parent := grpIdentificacao;
  lblNossoNumero.Left := 220;
  lblNossoNumero.Top := 22;
  lblNossoNumero.Caption := 'Nosso n'#250'mero:';
  AplicarFonteSegoeUISemiBold(lblNossoNumero.Font, 9);

  edtNossoNumero := TEdit.Create(Self);
  edtNossoNumero.Parent := grpIdentificacao;
  edtNossoNumero.Left := 318;
  edtNossoNumero.Top := 19;
  edtNossoNumero.Width := 150;
  edtNossoNumero.OnKeyPress := edtPesquisaKeyPress;

  grpPeriodos := CriarGrupo('Per'#237'odos', MARGEM, 114, 744, 70);
  FFiltroPeriodoEmissao := TControlesFiltroPeriodo.Create(Self, grpPeriodos,
    'Emiss'#227'o', False, 14, 8);
  FFiltroPeriodoEmissao.OnAlteracao := FiltroAvancadoAlterado;

  FFiltroPeriodoVencimento := TControlesFiltroPeriodo.Create(Self, grpPeriodos,
    'Vencimento', False, 14, 8 + FFiltroPeriodoEmissao.LarguraOcupada + 12);
  FFiltroPeriodoVencimento.OnAlteracao := FiltroAvancadoAlterado;

  FFiltroPeriodoRecebimento := TControlesFiltroPeriodo.Create(Self, grpPeriodos,
    'Recebimento', False, 40, 8);
  FFiltroPeriodoRecebimento.OnAlteracao := FiltroAvancadoAlterado;

  FFiltroAtual := frTodas;
  FFiltroBoletoAtual := fbBoletoTodos;
  DefinirFiltroAtivo(frTodas);
  DefinirFiltroBoletoAtivo(fbBoletoTodos);
end;

function TfrmReceber.ObterFiltrosConsulta: TFiltrosReceberConsulta;
begin
  Result.Texto := edtPesquisa.Text;
  Result.CodigoCliente := edtCodigoCliente.Text;
  Result.NossoNumero := edtNossoNumero.Text;
  Result.PeriodoEmissao := FFiltroPeriodoEmissao.ObterFiltro;
  Result.PeriodoVencimento := FFiltroPeriodoVencimento.ObterFiltro;
  Result.PeriodoRecebimento := FFiltroPeriodoRecebimento.ObterFiltro;
end;

procedure TfrmReceber.FiltroAvancadoAlterado(Sender: TObject);
begin
  CarregarDados(edtPesquisa.Text);
end;

procedure TfrmReceber.ConfigurarFontes;
begin
  AplicarFonteConsultaForm(Self);
end;

procedure TfrmReceber.AjustarLayoutReceber;
begin
  PanelTopo.Height := ALTURA_PANEL_TOPO;
  DefinirLegendaPesquisa(
    'Pesquisar por n'#250'mero, documento ou cliente (Enter pesquisa):');
  AjustarLayoutPesquisaConsulta(PanelTopo, lblPesquisa, edtPesquisa);
end;

procedure TfrmReceber.DefinirFiltroAtivo(AFiltro: TFiltroReceberLista);
begin
  FFiltroAtual := AFiltro;
  btnFiltroTodas.Down := AFiltro = frTodas;
  btnFiltroRecebidas.Down := AFiltro = frRecebidas;
  btnFiltroEmAberto.Down := AFiltro = frEmAberto;
  btnFiltroAtrasadas.Down := AFiltro = frAtrasadas;
end;

procedure TfrmReceber.DefinirFiltroBoletoAtivo(AFiltro: TFiltroReceberBoleto);
begin
  FFiltroBoletoAtual := AFiltro;
  btnFiltroBoletoTodos.Down := AFiltro = fbBoletoTodos;
  btnFiltroBoletoCom.Down := AFiltro = fbBoletoCom;
  btnFiltroBoletoSem.Down := AFiltro = fbBoletoSem;
end;

procedure TfrmReceber.FiltroClick(Sender: TObject);
begin
  if not (Sender is TSpeedButton) then
    Exit;
  DefinirFiltroAtivo(TFiltroReceberLista(TSpeedButton(Sender).Tag));
  CarregarDados(edtPesquisa.Text);
end;

procedure TfrmReceber.FiltroBoletoClick(Sender: TObject);
begin
  if not (Sender is TSpeedButton) then
    Exit;
  DefinirFiltroBoletoAtivo(TFiltroReceberBoleto(TSpeedButton(Sender).Tag));
  CarregarDados(edtPesquisa.Text);
end;

function TfrmReceber.LinhaTemBoleto: Boolean;
var
  Campo: TField;
begin
  Result := False;
  if (FDQueryReceber = nil) or (not FDQueryReceber.Active) or FDQueryReceber.IsEmpty then
    Exit;
  Campo := FDQueryReceber.FindField('TEM_BOLETO');
  if Campo = nil then
    Exit;
  Result := Campo.AsInteger = 1;
end;

procedure TfrmReceber.AbrirBoletoSelecionado;
var
  DS: TDataSet;
  Documento, Cliente: string;
begin
  DS := ObterDataSet;
  if (DS = nil) or (not DS.Active) or DS.IsEmpty then
    Exit;
  if not LinhaTemBoleto then
  begin
    MessageDlg('Este t'#237'tulo n'#227'o possui boleto.', mtInformation, [mbOK], 0);
    Exit;
  end;

  Documento := DS.FieldByName('CRDOCUMENTO').AsString;
  Cliente := DS.FieldByName('NOME_PESSOA').AsString;
  TfrmReceberBoletoDetalhe.Abrir(
    DS.FieldByName('EMPCODIGO').AsInteger,
    DS.FieldByName('CRNUMERO').AsInteger,
    Documento,
    Cliente,
    'Boleto - ' + Caption);
end;

procedure TfrmReceber.btnVerBoletoClick(Sender: TObject);
begin
  AbrirBoletoSelecionado;
end;

procedure TfrmReceber.DBGrid1CellClick(Column: TColumn);
begin
  if (Column.Field <> nil) and SameText(Column.Field.FieldName, 'TEM_BOLETO') and LinhaTemBoleto then
    AbrirBoletoSelecionado;
end;

procedure TfrmReceber.DataSourceReceberDataChange(Sender: TObject; Field: TField);
begin
  if btnVerBoleto <> nil then
    btnVerBoleto.Enabled := LinhaTemBoleto;
end;

function TfrmReceber.CorFonteLinha: TColor;
var
  Situacao: Integer;
  Vencimento: TDateTime;
begin
  Result := clWindowText;
  if (FDQueryReceber = nil) or (not FDQueryReceber.Active) or FDQueryReceber.IsEmpty then
    Exit;

  Situacao := FDQueryReceber.FieldByName('CRSITUACAO').AsInteger;
  if Situacao = 1 then
    Exit(COR_RECEBIDA);
  if Situacao = 2 then
    Exit(clGrayText);
  if Situacao = 0 then
  begin
    if FDQueryReceber.FieldByName('CRVALORABERTO').AsFloat <= 0 then
      Exit(COR_RECEBIDA);
    if not FDQueryReceber.FieldByName('CRDTVENCTO').IsNull then
    begin
      Vencimento := FDQueryReceber.FieldByName('CRDTVENCTO').AsDateTime;
      if Trunc(Vencimento) < Date then
        Exit(clRed);
    end;
    Exit(clWindowText);
  end;
end;

procedure TfrmReceber.DBGrid1DrawColumnCell(Sender: TObject; const Rect: TRect;
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
  begin
    Grid.Canvas.Font.Color := CorFonteLinha;
    if (Column.Field <> nil) and SameText(Column.Field.FieldName, 'TEM_BOLETO') and
      (Column.Field.AsInteger = 1) then
      Grid.Canvas.Font.Color := COR_BOLETO_SIM;
  end;

  AlinharDireita := (Column.Field <> nil) and
    (Column.Field.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd]);
  DesenharTextoCelulaGrid(Grid.Canvas, R, Texto, AlinharDireita);
end;

procedure TfrmReceber.CampoDataGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatDateTime('dd/mm/yyyy', Sender.AsDateTime);
end;

procedure TfrmReceber.CampoDocumentoGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatarDocumentoConsulta(Sender.AsString);
end;

procedure TfrmReceber.CampoCpfCnpjGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatarCpfCnpj(Sender.AsString);
end;

procedure TfrmReceber.CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  TConsultaMoedaHandlers.MoedaGetText(Sender, Text, DisplayText);
end;

procedure TfrmReceber.CampoSituacaoGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    case Sender.AsInteger of
      0: Text := 'Em aberto';
      1: Text := 'Recebido';
      2: Text := 'Cancelado';
    else
      Text := Sender.AsString;
    end;
end;

procedure TfrmReceber.CampoBoletoGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else if Sender.AsInteger = 1 then
    Text := 'Sim'
  else
    Text := 'N'#227'o';
end;

procedure TfrmReceber.OcultarCamposInternos;
var
  Campo: TField;
begin
  Campo := FDQueryReceber.FindField('EMPCODIGO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryReceber.FindField('CRNUMERO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryReceber.FindField('CRSITUACAO');
  if Campo <> nil then
    Campo.Visible := False;
end;

procedure TfrmReceber.AplicarTitulosGrid;
var
  I: Integer;
  Campo: TField;
  Nome: string;
begin
  for I := 0 to FDQueryReceber.FieldCount - 1 do
  begin
    Campo := FDQueryReceber.Fields[I];
    Campo.DisplayLabel := ResolverTituloCampo(Campo.FieldName);
    Nome := UpperCase(Campo.FieldName);
    if (Nome = 'CRDTEMISSAO') or (Nome = 'CRDTVENCTO') or (Nome = 'CRDTRECEBIMENTO') then
      Campo.OnGetText := CampoDataGetText
    else if Nome = 'CRDOCUMENTO' then
      Campo.OnGetText := CampoDocumentoGetText
    else if Nome = 'CPF_CNPJ' then
      Campo.OnGetText := CampoCpfCnpjGetText
    else if (Nome = 'CRVALOR') or (Nome = 'CRVALORRECEBIDO') or (Nome = 'CRVALORABERTO') then
      Campo.OnGetText := CampoMoedaGetText
    else if Nome = 'CRSITUACAO' then
      Campo.OnGetText := CampoSituacaoGetText
    else if Nome = 'TEM_BOLETO' then
      Campo.OnGetText := CampoBoletoGetText;
  end;
  OcultarCamposInternos;
  ConfigurarLargurasGrid;
end;

procedure TfrmReceber.ConfigurarLargurasGrid;
var
  I: Integer;
  Col: TColumn;
  Campo: TField;
  Nome: string;
const
  LARGURA_COL_MOEDA = 118;
begin
  Campo := FDQueryReceber.FindField('CRDOCUMENTO');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryReceber.FindField('CODIGO_CLIENTE');
  if Campo <> nil then
    Campo.DisplayWidth := 8;
  Campo := FDQueryReceber.FindField('NOME_PESSOA');
  if Campo <> nil then
    Campo.DisplayWidth := 22;
  Campo := FDQueryReceber.FindField('CPF_CNPJ');
  if Campo <> nil then
    Campo.DisplayWidth := 18;
  Campo := FDQueryReceber.FindField('CRDTVENCTO');
  if Campo <> nil then
    Campo.DisplayWidth := 11;
  Campo := FDQueryReceber.FindField('CRVALOR');
  if Campo <> nil then
    Campo.DisplayWidth := 18;
  Campo := FDQueryReceber.FindField('CRVALORRECEBIDO');
  if Campo <> nil then
    Campo.DisplayWidth := 18;
  Campo := FDQueryReceber.FindField('CRVALORABERTO');
  if Campo <> nil then
    Campo.DisplayWidth := 18;
  Campo := FDQueryReceber.FindField('TEM_BOLETO');
  if Campo <> nil then
    Campo.DisplayWidth := 8;

  for I := 0 to DBGrid1.Columns.Count - 1 do
  begin
    Col := DBGrid1.Columns[I];
    if (Col.Field = nil) or (not Col.Visible) then
      Continue;
    Nome := UpperCase(Col.Field.FieldName);
    if (Nome = 'CRVALOR') or (Nome = 'CRVALORRECEBIDO') or (Nome = 'CRVALORABERTO') then
      Col.Width := LARGURA_COL_MOEDA
    else if Nome = 'CODIGO_CLIENTE' then
      Col.Width := 72
    else if Nome = 'NOME_PESSOA' then
      Col.Width := 190
    else if Nome = 'CPF_CNPJ' then
      Col.Width := 128
    else if Nome = 'TEM_BOLETO' then
      Col.Width := 62;
  end;
end;

procedure TfrmReceber.AbrirDetalheRegistro;
var
  DS: TDataSet;
begin
  DS := ObterDataSet;
  if (DS = nil) or (not DS.Active) or DS.IsEmpty then
    Exit;

  TfrmReceberDetalhe.Abrir(
    DS.FieldByName('EMPCODIGO').AsInteger,
    DS.FieldByName('CRNUMERO').AsInteger,
    'Detalhes - ' + Caption);
end;

procedure TfrmReceber.FormCreate(Sender: TObject);
begin
  inherited;
  ConfigurarJanela;
  DefinirTitulo('Contas a Receber');
  ConfigurarDados;
  ConfigurarPainelFiltros;
  ConfigurarBotoesRodape;
  ConfigurarFontes;
  AjustarLayoutReceber;
end;

procedure TfrmReceber.CarregarDados(const AFiltro: string);
var
  SQL: string;
  Filtros: TFiltrosReceberConsulta;
begin
  if not dmConexao.Conectado then
  begin
    ErroConsulta(Self, 'Banco de dados n'#227'o conectado.', '');
    Exit;
  end;

  Filtros := ObterFiltrosConsulta;
  Filtros.Texto := Trim(AFiltro);
  FDQueryReceber.Close;
  try
    SQL := TMapaReceber.MontarSQLLista(Filtros, FFiltroAtual, FFiltroBoletoAtual);
    FDQueryReceber.Connection := dmConexao.FDConnection1;
    FDQueryReceber.SQL.Text := SQL;
    TMapaReceber.ConfigurarParametrosLista(FDQueryReceber, Filtros);
    FDQueryReceber.Open;
    AplicarTitulosGrid;
  except
    on E: Exception do
    begin
      FDQueryReceber.Close;
      ErroConsulta(Self, 'Erro ao consultar contas a receber:', E.Message);
    end;
  end;
end;

procedure TfrmReceber.edtPesquisaKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    CarregarDados(edtPesquisa.Text);
  end;
end;

end.
