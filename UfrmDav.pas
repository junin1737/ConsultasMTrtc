unit UfrmDav;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Buttons, Vcl.Grids, Vcl.DBGrids,
  Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Param, FireDAC.DApt,
  UfrmConsultaBase, UdmConexao, UConsultaCampos, UConsultaLayout, UMapaDav, UfrmDavDetalhe, UFormatacaoMoeda,
  UConsultaDialogs, UFiltroPeriodoConsulta;

type
  TfrmDav = class(TfrmConsultaBase)
    procedure FormCreate(Sender: TObject);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: Char);
  private
    FDQueryDav: TFDQuery;
    DataSourceDav: TDataSource;
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
  frmDav: TfrmDav;

implementation

{$R *.dfm}

const
  LARGURA_BASE = 1350;
  ALTURA_BASE = 900;
  FATOR_TAMANHO = 0.70;

procedure TfrmDav.ConfigurarJanela;
begin
  AjustarJanelaConsulta(Self, LARGURA_BASE, ALTURA_BASE, FATOR_TAMANHO);
end;

function TfrmDav.ObterDataSet: TDataSet;
begin
  Result := FDQueryDav;
end;

function TfrmDav.ResolverTituloCampo(const ANomeCampo: string): string;
begin
  if SameText(ANomeCampo, 'DAVNUMERO') then
    Exit('N'#250'mero DAV');
  if SameText(ANomeCampo, 'DAVEMISSAO') then
    Exit('Data emiss'#227'o');
  if SameText(ANomeCampo, 'NOME_CLIENTE') then
    Exit('Cliente');
  if SameText(ANomeCampo, 'DAVDATAENTREGA') then
    Exit('Vencimento');
  if SameText(ANomeCampo, 'DAVTOTALLIQUIDO') then
    Exit('Valor total');
  Result := TituloAmigavelCampoDav(ANomeCampo);
end;

procedure TfrmDav.ConfigurarFiltroPeriodo;
begin
  FFiltroPeriodo := TControlesFiltroPeriodo.Create(Self, PanelTopo, 'Per'#237'odo emiss'#227'o:', False);
  FFiltroPeriodo.ConfigurarPanelTopo(PanelTopo);
  FFiltroPeriodo.OnAlteracao := PeriodoAlterado;
end;

procedure TfrmDav.PeriodoAlterado(Sender: TObject);
begin
  CarregarDados(edtPesquisa.Text);
end;

procedure TfrmDav.ConfigurarDados;
begin
  FDQueryDav := TFDQuery.Create(Self);
  FDQueryDav.ResourceOptions.SilentMode := True;
  DataSourceDav := TDataSource.Create(Self);
  DataSourceDav.DataSet := FDQueryDav;
  DBGrid1.DataSource := DataSourceDav;
  edtPesquisa.OnKeyPress := edtPesquisaKeyPress;
end;

procedure TfrmDav.CampoDataGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatDateTime('dd/mm/yyyy', Sender.AsDateTime);
end;

procedure TfrmDav.CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  TConsultaMoedaHandlers.MoedaGetText(Sender, Text, DisplayText);
end;

procedure TfrmDav.OcultarCamposInternos;
var
  Campo: TField;
begin
  Campo := FDQueryDav.FindField('EMPCODIGO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryDav.FindField('DAVCONTADOR');
  if Campo <> nil then
    Campo.Visible := False;
end;

procedure TfrmDav.AplicarTitulosGrid;
var
  I: Integer;
  Campo: TField;
  Nome: string;
begin
  for I := 0 to FDQueryDav.FieldCount - 1 do
  begin
    Campo := FDQueryDav.Fields[I];
    Campo.DisplayLabel := ResolverTituloCampo(Campo.FieldName);
    Nome := UpperCase(Campo.FieldName);
    if (Nome = 'DAVEMISSAO') or (Nome = 'DAVDATAENTREGA') then
      Campo.OnGetText := CampoDataGetText
    else if Nome = 'DAVTOTALLIQUIDO' then
      Campo.OnGetText := CampoMoedaGetText;
  end;
  OcultarCamposInternos;
  ConfigurarLargurasGrid;
end;

procedure TfrmDav.ConfigurarLargurasGrid;
var
  Campo: TField;
begin
  Campo := FDQueryDav.FindField('DAVNUMERO');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryDav.FindField('DAVEMISSAO');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryDav.FindField('NOME_CLIENTE');
  if Campo <> nil then
    Campo.DisplayWidth := 42;
  Campo := FDQueryDav.FindField('DAVDATAENTREGA');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryDav.FindField('DAVTOTALLIQUIDO');
  if Campo <> nil then
    Campo.DisplayWidth := 14;
end;

procedure TfrmDav.AbrirDetalheRegistro;
var
  DS: TDataSet;
  Form: TfrmDavDetalhe;
  EmpCodigo, DavContador: Integer;
begin
  DS := ObterDataSet;
  if (DS = nil) or (not DS.Active) or DS.IsEmpty then
    Exit;

  EmpCodigo := DS.FieldByName('EMPCODIGO').AsInteger;
  DavContador := DS.FieldByName('DAVCONTADOR').AsInteger;

  Form := TfrmDavDetalhe.Create(Application);
  try
    Form.Exibir(EmpCodigo, DavContador);
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TfrmDav.FormCreate(Sender: TObject);
begin
  inherited;
  ConfigurarJanela;
  DefinirTitulo('DAV');
  DefinirLegendaPesquisa(
    'Pesquisar por n'#250'mero do DAV ou nome do cliente ' +
    '(Enter pesquisa; duplo clique abre itens):');
  ConfigurarDados;
  ConfigurarFiltroPeriodo;
end;

procedure TfrmDav.CarregarDados(const AFiltro: string);
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
  FDQueryDav.Close;
  try
    try
      TMapaDav.GarantirMapa;
      SQL := TMapaDav.MontarSQLLista(Filtro, Periodo);
    except
      on E: Exception do
      begin
        ErroConsulta(Self, 'Erro ao montar consulta DAV:', E.Message);
        Exit;
      end;
    end;

    FDQueryDav.Connection := dmConexao.FDConnection1;
    FDQueryDav.SQL.Text := SQL;
    TMapaDav.ConfigurarParametrosLista(FDQueryDav, Filtro, Periodo);

    FDQueryDav.Open;
    AplicarTitulosGrid;
  except
    on E: Exception do
    begin
      FDQueryDav.Close;
      ErroConsulta(Self, 'Erro ao consultar DAV:', E.Message);
    end;
  end;
end;

procedure TfrmDav.edtPesquisaKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    CarregarDados(edtPesquisa.Text);
  end;
end;

end.
