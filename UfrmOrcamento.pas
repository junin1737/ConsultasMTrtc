unit UfrmOrcamento;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Buttons, Vcl.Grids, Vcl.DBGrids,
  Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Param, FireDAC.DApt,
  UfrmConsultaBase, UdmConexao, UConsultaCampos, UConsultaLayout, UMapaOrcamento, UfrmOrcamentoDetalhe,
  UFormatacaoMoeda, UConsultaDialogs, UFiltroPeriodoConsulta;

type
  TfrmOrcamento = class(TfrmConsultaBase)
    procedure FormCreate(Sender: TObject);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: Char);
  private
    FDQueryOrcamento: TFDQuery;
    DataSourceOrcamento: TDataSource;
    FFiltroPeriodo: TControlesFiltroPeriodo;
    procedure ConfigurarJanela;
    procedure ConfigurarDados;
    procedure ConfigurarFiltroPeriodo;
    procedure PeriodoAlterado(Sender: TObject);
    procedure AplicarTitulosGrid;
    procedure CampoDataGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure OcultarCamposInternos;
    procedure ConfigurarLargurasGrid;
  protected
    function ObterDataSet: TDataSet; override;
    function ResolverTituloCampo(const ANomeCampo: string): string; override;
    procedure AbrirDetalheRegistro; override;
  public
    procedure CarregarDados(const AFiltro: string = '');
  end;

var
  frmOrcamento: TfrmOrcamento;

implementation

{$R *.dfm}

const
  LARGURA_BASE = 1350;
  ALTURA_BASE = 900;
  FATOR_TAMANHO = 0.70;

procedure TfrmOrcamento.ConfigurarJanela;
begin
  AjustarJanelaConsulta(Self, LARGURA_BASE, ALTURA_BASE, FATOR_TAMANHO);
end;

function TfrmOrcamento.ObterDataSet: TDataSet;
begin
  Result := FDQueryOrcamento;
end;

function TfrmOrcamento.ResolverTituloCampo(const ANomeCampo: string): string;
begin
  if SameText(ANomeCampo, 'ORCNUMERO') then
    Exit('N'#250'mero or'#231'amento');
  if SameText(ANomeCampo, 'ORCEMISSAO') then
    Exit('Data emiss'#227'o');
  if SameText(ANomeCampo, 'PESNOME') then
    Exit('Cliente');
  if SameText(ANomeCampo, 'DATA_VENCIMENTO') then
    Exit('Vencimento');
  if SameText(ANomeCampo, 'ORCTOTALLIQUIDO') then
    Exit('Valor total');
  Result := TituloAmigavelCampoOrcamento(ANomeCampo);
end;

procedure TfrmOrcamento.ConfigurarFiltroPeriodo;
begin
  FFiltroPeriodo := TControlesFiltroPeriodo.Create(Self, PanelTopo, 'Per'#237'odo emiss'#227'o:');
  FFiltroPeriodo.ConfigurarPanelTopo(PanelTopo);
  FFiltroPeriodo.OnAlteracao := PeriodoAlterado;
end;

procedure TfrmOrcamento.PeriodoAlterado(Sender: TObject);
begin
  CarregarDados(edtPesquisa.Text);
end;

procedure TfrmOrcamento.ConfigurarDados;
begin
  FDQueryOrcamento := TFDQuery.Create(Self);
  FDQueryOrcamento.ResourceOptions.SilentMode := True;
  DataSourceOrcamento := TDataSource.Create(Self);
  DataSourceOrcamento.DataSet := FDQueryOrcamento;
  DBGrid1.DataSource := DataSourceOrcamento;
  edtPesquisa.OnKeyPress := edtPesquisaKeyPress;
end;

procedure TfrmOrcamento.CampoDataGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatDateTime('dd/mm/yyyy', Sender.AsDateTime);
end;

procedure TfrmOrcamento.CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  TConsultaMoedaHandlers.MoedaGetText(Sender, Text, DisplayText);
end;

procedure TfrmOrcamento.OcultarCamposInternos;
var
  Campo: TField;
begin
  Campo := FDQueryOrcamento.FindField('EMPCODIGO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryOrcamento.FindField('ORCCONTADOR');
  if Campo <> nil then
    Campo.Visible := False;
end;

procedure TfrmOrcamento.AplicarTitulosGrid;
var
  I: Integer;
  Campo: TField;
  Nome: string;
begin
  for I := 0 to FDQueryOrcamento.FieldCount - 1 do
  begin
    Campo := FDQueryOrcamento.Fields[I];
    Campo.DisplayLabel := ResolverTituloCampo(Campo.FieldName);
    Nome := UpperCase(Campo.FieldName);
    if (Nome = 'ORCEMISSAO') or (Nome = 'DATA_VENCIMENTO') then
      Campo.OnGetText := CampoDataGetText
    else if Nome = 'ORCTOTALLIQUIDO' then
      Campo.OnGetText := CampoMoedaGetText;
  end;
  OcultarCamposInternos;
  ConfigurarLargurasGrid;
end;

procedure TfrmOrcamento.ConfigurarLargurasGrid;
var
  Campo: TField;
begin
  Campo := FDQueryOrcamento.FindField('ORCNUMERO');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryOrcamento.FindField('ORCEMISSAO');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryOrcamento.FindField('PESNOME');
  if Campo <> nil then
    Campo.DisplayWidth := 42;
  Campo := FDQueryOrcamento.FindField('DATA_VENCIMENTO');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryOrcamento.FindField('ORCTOTALLIQUIDO');
  if Campo <> nil then
    Campo.DisplayWidth := 14;
end;

procedure TfrmOrcamento.AbrirDetalheRegistro;
var
  DS: TDataSet;
  Form: TfrmOrcamentoDetalhe;
  EmpCodigo, OrcContador: Integer;
begin
  DS := ObterDataSet;
  if (DS = nil) or (not DS.Active) or DS.IsEmpty then
    Exit;

  EmpCodigo := DS.FieldByName('EMPCODIGO').AsInteger;
  OrcContador := DS.FieldByName('ORCCONTADOR').AsInteger;

  Form := TfrmOrcamentoDetalhe.Create(Application);
  try
    if Form.Exibir(EmpCodigo, OrcContador) then
      Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TfrmOrcamento.FormCreate(Sender: TObject);
begin
  inherited;
  ConfigurarJanela;
  DefinirTitulo('Or'#231'amento');
  DefinirLegendaPesquisa(
    'Pesquisar por n'#250'mero do or'#231'amento ou nome do cliente ' +
    '(Enter pesquisa; duplo clique abre itens):');
  ConfigurarDados;
  ConfigurarFiltroPeriodo;
end;

procedure TfrmOrcamento.CarregarDados(const AFiltro: string);
var
  SQL, Filtro: string;
  Periodo: TFiltroPeriodoConsulta;
begin
  if not dmConexao.Conectado then
  begin
    ErroConsulta(Self, 'Banco de dados não conectado.', '');
    Exit;
  end;

  Filtro := Trim(AFiltro);
  Periodo := FFiltroPeriodo.ObterFiltro;
  FDQueryOrcamento.Close;
  try
    try
      TMapaOrcamento.GarantirMapa;
      SQL := TMapaOrcamento.MontarSQLLista(Filtro, Periodo);
    except
      on E: Exception do
      begin
        ErroConsulta(Self, 'Erro ao montar consulta de or'#231'amento:', E.Message);
        Exit;
      end;
    end;

    FDQueryOrcamento.Connection := dmConexao.FDConnection1;
    FDQueryOrcamento.SQL.Text := SQL;
    TMapaOrcamento.ConfigurarParametrosLista(FDQueryOrcamento, Filtro, Periodo);

    FDQueryOrcamento.Open;
    AplicarTitulosGrid;
  except
    on E: Exception do
    begin
      FDQueryOrcamento.Close;
      ErroConsulta(Self, 'Erro ao consultar or'#231'amentos:', E.Message);
    end;
  end;
end;

procedure TfrmOrcamento.edtPesquisaKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    CarregarDados(edtPesquisa.Text);
  end;
end;

end.
