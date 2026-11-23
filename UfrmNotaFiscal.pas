unit UfrmNotaFiscal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Buttons, Vcl.Grids, Vcl.DBGrids, Vcl.ComCtrls,
  Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Param, FireDAC.DApt,
  UfrmConsultaBase, UdmConexao, UConsultaCampos, UConsultaLayout, UMapaNotaFiscal, UMapaNfce,
  UfrmNotaFiscalDetalhe, UFormatacaoMoeda, UConsultaDialogs, UFiltroPeriodoConsulta,
  UFiltroSituacaoNotaFiscal, USituacaoNotaConsulta;

type
  TTipoAbaNotaVenda = (abaNotaNFe, abaNotaNFCe);

  TfrmNotaFiscal = class(TfrmConsultaBase)
    procedure FormCreate(Sender: TObject);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: Char);
  private
    FDQueryNota: TFDQuery;
    DataSourceNota: TDataSource;
    FFiltroPeriodo: TControlesFiltroPeriodo;
    FFiltroSituacao: TControlesFiltroSituacaoNotaFiscal;
    FPanelAbas: TPanel;
    FPageControl: TPageControl;
    FAbaAtual: TTipoAbaNotaVenda;
    procedure ConfigurarJanela;
    procedure ConfigurarDados;
    procedure ConfigurarAbas;
    procedure ConfigurarFiltroPeriodo;
    procedure ConfigurarFiltroSituacao;
    procedure FiltroAlterado(Sender: TObject);
    procedure AbaAlterada(Sender: TObject);
    function AbaAtualNfce: Boolean;
    procedure AplicarTitulosGrid;
    procedure CampoDataGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure OcultarCamposInternos;
    procedure ConfigurarLargurasGrid;
    procedure DBGrid1DrawColumnCell(Sender: TObject; const Rect: TRect; DataCol: Integer;
      Column: TColumn; State: TGridDrawState);
  protected
    function ObterDataSet: TDataSet; override;
    function ResolverTituloCampo(const ANomeCampo: string): string; override;
    procedure AbrirDetalheRegistro; override;
  public
    procedure CarregarDados(const AFiltro: string = '');
  end;

var
  frmNotaFiscal: TfrmNotaFiscal;

implementation

{$R *.dfm}

const
  LARGURA_BASE = 1350;
  ALTURA_BASE = 900;
  FATOR_TAMANHO = 0.70;

procedure TfrmNotaFiscal.ConfigurarJanela;
begin
  AjustarJanelaConsulta(Self, LARGURA_BASE, ALTURA_BASE, FATOR_TAMANHO);
end;

function TfrmNotaFiscal.ObterDataSet: TDataSet;
begin
  Result := FDQueryNota;
end;

function TfrmNotaFiscal.AbaAtualNfce: Boolean;
begin
  Result := FAbaAtual = abaNotaNFCe;
end;

function TfrmNotaFiscal.ResolverTituloCampo(const ANomeCampo: string): string;
begin
  if SameText(ANomeCampo, 'NFNUMEROFISCAL') then
  begin
    if AbaAtualNfce then
      Exit('N'#250'mero NFC-e')
    else
      Exit('N'#250'mero NF');
  end;
  if SameText(ANomeCampo, 'DOCFNUMERO') then
    Exit('Doc. fiscal');
  if SameText(ANomeCampo, 'NFDTEMISSAO') then
    Exit('Emiss'#227'o');
  if SameText(ANomeCampo, 'NFDTSAIDA') then
    Exit('Sa'#237'da');
  if SameText(ANomeCampo, 'NOME_CLIENTE') then
    Exit('Cliente');
  if SameText(ANomeCampo, 'NFTOTALNOTA') then
    Exit('Valor total');
  if SameText(ANomeCampo, 'SITUACAO_NOTA') then
    Exit('Situa'#231#227'o');
  if SameText(ANomeCampo, 'NFSITUACAO') then
    Exit('Situa'#231#227'o');
  if SameText(ANomeCampo, 'CHAVE_NFE') then
  begin
    if AbaAtualNfce then
      Exit('Chave NFC-e')
    else
      Exit('Chave NFe');
  end;
  Result := ANomeCampo;
end;

procedure TfrmNotaFiscal.ConfigurarAbas;
var
  TabNFe, TabNFCe: TTabSheet;
begin
  FAbaAtual := abaNotaNFe;

  FPanelAbas := TPanel.Create(Self);
  FPanelAbas.Parent := Self;
  FPanelAbas.Align := alTop;
  FPanelAbas.Height := 32;
  FPanelAbas.BevelOuter := bvNone;
  FPanelAbas.ParentBackground := False;
  FPanelAbas.Color := clBtnFace;
  FPanelAbas.TabOrder := 1;

  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := FPanelAbas;
  FPageControl.Align := alClient;
  FPageControl.TabHeight := 26;

  TabNFe := TTabSheet.Create(FPageControl);
  TabNFe.PageControl := FPageControl;
  TabNFe.Caption := 'NF-e';

  TabNFCe := TTabSheet.Create(FPageControl);
  TabNFCe.PageControl := FPageControl;
  TabNFCe.Caption := 'NFC-e';

  FPageControl.ActivePage := TabNFe;
end;

procedure TfrmNotaFiscal.AbaAlterada(Sender: TObject);
begin
  if FPageControl.ActivePageIndex = 0 then
  begin
    FAbaAtual := abaNotaNFe;
    DefinirLegendaPesquisa(
      'Pesquisar por n'#250'mero da NF ou nome do cliente ' +
      '(Enter pesquisa; duplo clique abre itens):');
  end
  else
  begin
    FAbaAtual := abaNotaNFCe;
    DefinirLegendaPesquisa(
      'Pesquisar por n'#250'mero da NFC-e/cupom ou nome do cliente ' +
      '(Enter pesquisa; duplo clique abre itens):');
  end;

  CarregarDados(edtPesquisa.Text);
end;

procedure TfrmNotaFiscal.ConfigurarFiltroPeriodo;
begin
  FFiltroPeriodo := TControlesFiltroPeriodo.Create(Self, PanelTopo,
    'Per'#237'odo emiss'#227'o/sa'#237'da:', False);
  FFiltroPeriodo.OnAlteracao := FiltroAlterado;
end;

procedure TfrmNotaFiscal.ConfigurarFiltroSituacao;
begin
  FFiltroSituacao := TControlesFiltroSituacaoNotaFiscal.Create(Self, PanelTopo);
  FFiltroSituacao.OnAlteracao := FiltroAlterado;
  AjustarAlturaPanelTopoNotaFiscal(PanelTopo);
end;

procedure TfrmNotaFiscal.FiltroAlterado(Sender: TObject);
begin
  CarregarDados(edtPesquisa.Text);
end;

procedure TfrmNotaFiscal.ConfigurarDados;
begin
  FDQueryNota := TFDQuery.Create(Self);
  FDQueryNota.ResourceOptions.SilentMode := True;
  DataSourceNota := TDataSource.Create(Self);
  DataSourceNota.DataSet := FDQueryNota;
  DBGrid1.DataSource := DataSourceNota;
  edtPesquisa.OnKeyPress := edtPesquisaKeyPress;
  DBGrid1.OnDrawColumnCell := DBGrid1DrawColumnCell;
  DBGrid1.DefaultDrawing := False;
end;

procedure TfrmNotaFiscal.CampoDataGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatDateTime('dd/mm/yyyy', Sender.AsDateTime);
end;

procedure TfrmNotaFiscal.CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  TConsultaMoedaHandlers.MoedaGetText(Sender, Text, DisplayText);
end;

procedure TfrmNotaFiscal.OcultarCamposInternos;
var
  Campo: TField;
begin
  Campo := FDQueryNota.FindField('EMPCODIGO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryNota.FindField('NFCONTADOR');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryNota.FindField('VENNUMERO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryNota.FindField('TERNUMERO');
  if Campo <> nil then
    Campo.Visible := False;
end;

procedure TfrmNotaFiscal.AplicarTitulosGrid;
var
  I: Integer;
  Campo: TField;
  Nome: string;
begin
  for I := 0 to FDQueryNota.FieldCount - 1 do
  begin
    Campo := FDQueryNota.Fields[I];
    Campo.DisplayLabel := ResolverTituloCampo(Campo.FieldName);
    Nome := UpperCase(Campo.FieldName);
    if (Nome = 'NFDTEMISSAO') or (Nome = 'NFDTSAIDA') then
      Campo.OnGetText := CampoDataGetText
    else if Nome = 'NFTOTALNOTA' then
      Campo.OnGetText := CampoMoedaGetText;
  end;
  OcultarCamposInternos;
  ConfigurarLargurasGrid;
end;

procedure TfrmNotaFiscal.DBGrid1DrawColumnCell(Sender: TObject; const Rect: TRect;
  DataCol: Integer; Column: TColumn; State: TGridDrawState);
begin
  DesenharCelulaGridNotaLista(TDBGrid(Sender), Rect, DataCol, Column, State);
end;

procedure TfrmNotaFiscal.ConfigurarLargurasGrid;
var
  Campo: TField;
begin
  Campo := FDQueryNota.FindField('NFNUMEROFISCAL');
  if Campo <> nil then
    Campo.DisplayWidth := 10;
  Campo := FDQueryNota.FindField('DOCFNUMERO');
  if Campo <> nil then
    Campo.DisplayWidth := 10;
  Campo := FDQueryNota.FindField('NFDTEMISSAO');
  if Campo <> nil then
    Campo.DisplayWidth := 11;
  Campo := FDQueryNota.FindField('NFDTSAIDA');
  if Campo <> nil then
    Campo.DisplayWidth := 11;
  Campo := FDQueryNota.FindField('NOME_CLIENTE');
  if Campo <> nil then
    Campo.DisplayWidth := 32;
  Campo := FDQueryNota.FindField('NFTOTALNOTA');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryNota.FindField('SITUACAO_NOTA');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryNota.FindField('NFSITUACAO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryNota.FindField('NFSITUACAODOC');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryNota.FindField('CHAVE_NFE');
  if Campo <> nil then
    Campo.Visible := False;

  AplicarLargurasColunasGridNotaVenda(DBGrid1);
end;

procedure TfrmNotaFiscal.AbrirDetalheRegistro;
var
  DS: TDataSet;
  Form: TfrmNotaFiscalDetalhe;
  EmpCodigo, NfContador, VenNumero, TerNumero: Integer;
begin
  DS := ObterDataSet;
  if (DS = nil) or (not DS.Active) or DS.IsEmpty then
    Exit;

  EmpCodigo := DS.FieldByName('EMPCODIGO').AsInteger;

  Form := TfrmNotaFiscalDetalhe.Create(Application);
  try
    if AbaAtualNfce then
    begin
      VenNumero := DS.FieldByName('VENNUMERO').AsInteger;
      TerNumero := DS.FieldByName('TERNUMERO').AsInteger;
      NfContador := DS.FieldByName('NFNUMEROFISCAL').AsInteger;
      Form.ExibirNfce(EmpCodigo, VenNumero, TerNumero, NfContador);
    end
    else
    begin
      NfContador := DS.FieldByName('NFCONTADOR').AsInteger;
      Form.Exibir(EmpCodigo, NfContador);
    end;
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TfrmNotaFiscal.FormCreate(Sender: TObject);
begin
  inherited;
  ConfigurarJanela;
  DefinirTitulo('Notas de Venda');
  ConfigurarDados;
  ConfigurarAbas;
  ConfigurarFiltroPeriodo;
  ConfigurarFiltroSituacao;
  FPageControl.OnChange := AbaAlterada;
  DefinirLegendaPesquisa(
    'Pesquisar por n'#250'mero da NF ou nome do cliente ' +
    '(Enter pesquisa; duplo clique abre itens):');
end;

procedure TfrmNotaFiscal.CarregarDados(const AFiltro: string);
var
  SQL, Filtro: string;
  Periodo: TFiltroPeriodoConsulta;
  Situacao: TFiltroSituacaoNotaFiscalConsulta;
begin
  if not dmConexao.Conectado then
  begin
    ErroConsulta(Self, 'Banco de dados não conectado.', '');
    Exit;
  end;

  Filtro := Trim(AFiltro);
  Periodo := FFiltroPeriodo.ObterFiltro;
  Situacao := FFiltroSituacao.ObterFiltro;
  FDQueryNota.Close;
  try
    try
      if AbaAtualNfce then
        SQL := TMapaNfce.MontarSQLLista(Filtro, Periodo, Situacao)
      else
      begin
        TMapaNotaFiscal.GarantirMapa;
        SQL := TMapaNotaFiscal.MontarSQLLista(Filtro, Periodo, Situacao);
      end;
    except
      on E: Exception do
      begin
        ErroConsulta(Self, 'Erro ao montar consulta de notas fiscais:', E.Message);
        Exit;
      end;
    end;

    FDQueryNota.Connection := dmConexao.FDConnection1;
    FDQueryNota.SQL.Text := SQL;
    if AbaAtualNfce then
      TMapaNfce.ConfigurarParametrosLista(FDQueryNota, Filtro, Periodo)
    else
      TMapaNotaFiscal.ConfigurarParametrosLista(FDQueryNota, Filtro, Periodo);

    FDQueryNota.Open;
    AplicarTitulosGrid;
  except
    on E: Exception do
    begin
      FDQueryNota.Close;
      ErroConsulta(Self, 'Erro ao consultar notas fiscais:', E.Message);
    end;
  end;
end;

procedure TfrmNotaFiscal.edtPesquisaKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    CarregarDados(edtPesquisa.Text);
  end;
end;

end.
