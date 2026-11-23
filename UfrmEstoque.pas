unit UfrmEstoque;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Buttons, Vcl.Grids, Vcl.DBGrids,
  Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Param, FireDAC.DApt,
  UfrmConsultaBase, UdmConexao, UConsultaCampos, UConsultaLayout, UMapaEstoque, UfrmProdutoDetalhe,
  UFormatacaoMoeda, UConsultaDialogs;

type
  TfrmEstoque = class(TfrmConsultaBase)
    procedure FormCreate(Sender: TObject);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: Char);
  private
    FDQueryEstoque: TFDQuery;
    DataSourceEstoque: TDataSource;
    procedure ConfigurarJanela;
    procedure ConfigurarDados;
    procedure AplicarTitulosGrid;
    procedure CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure CampoQtdeGetText(Sender: TField; var Text: string; DisplayText: Boolean);
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
  frmEstoque: TfrmEstoque;

implementation

{$R *.dfm}

const
  LARGURA_BASE = 1350;
  ALTURA_BASE = 900;
  FATOR_TAMANHO = 0.70;

procedure TfrmEstoque.ConfigurarJanela;
begin
  AjustarJanelaConsulta(Self, LARGURA_BASE, ALTURA_BASE, FATOR_TAMANHO);
end;

function TfrmEstoque.ObterDataSet: TDataSet;
begin
  Result := FDQueryEstoque;
end;

function TfrmEstoque.ResolverTituloCampo(const ANomeCampo: string): string;
var
  Nome: string;
begin
  Nome := UpperCase(ANomeCampo);
  if SameText(Nome, 'CODIGO_ITEM') then
    Exit('Cod.Fabricante');
  if SameText(Nome, 'PRODDESCRICAO') then
    Exit('Descri'#231#227'o');
  if SameText(Nome, 'PRODESTOQUE') then
    Exit('Estoque');
  if SameText(Nome, 'PRODPRECOVAREJO') then
    Exit('Pre'#231'o varejo');
  Result := TituloAmigavelCampo(ANomeCampo);
end;

procedure TfrmEstoque.ConfigurarDados;
begin
  FDQueryEstoque := TFDQuery.Create(Self);
  FDQueryEstoque.ResourceOptions.SilentMode := True;
  DataSourceEstoque := TDataSource.Create(Self);
  DataSourceEstoque.DataSet := FDQueryEstoque;
  DBGrid1.DataSource := DataSourceEstoque;
  edtPesquisa.OnKeyPress := edtPesquisaKeyPress;
end;

procedure TfrmEstoque.CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  TConsultaMoedaHandlers.MoedaGetText(Sender, Text, DisplayText);
end;

procedure TfrmEstoque.CampoQtdeGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatarQuantidade(Sender.AsFloat);
end;

procedure TfrmEstoque.OcultarCamposInternos;
var
  Campo: TField;
begin
  Campo := FDQueryEstoque.FindField('EMPCODIGO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryEstoque.FindField('PRODCONTADOR');
  if Campo <> nil then
    Campo.Visible := False;
end;

procedure TfrmEstoque.AplicarTitulosGrid;
var
  I: Integer;
  Campo: TField;
  Nome: string;
begin
  for I := 0 to FDQueryEstoque.FieldCount - 1 do
  begin
    Campo := FDQueryEstoque.Fields[I];
    Campo.DisplayLabel := ResolverTituloCampo(Campo.FieldName);
    Nome := UpperCase(Campo.FieldName);
    if Nome = 'PRODESTOQUE' then
      Campo.OnGetText := CampoQtdeGetText
    else if Nome = 'PRODPRECOVAREJO' then
      Campo.OnGetText := CampoMoedaGetText;
  end;
  OcultarCamposInternos;
  ConfigurarLargurasGrid;
end;

procedure TfrmEstoque.ConfigurarLargurasGrid;
var
  Campo: TField;
begin
  Campo := FDQueryEstoque.FindField('CODIGO_ITEM');
  if Campo <> nil then
    Campo.DisplayWidth := 14;
  Campo := FDQueryEstoque.FindField('PRODDESCRICAO');
  if Campo <> nil then
    Campo.DisplayWidth := 42;
  Campo := FDQueryEstoque.FindField('PRODESTOQUE');
  if Campo <> nil then
    Campo.DisplayWidth := 10;
  Campo := FDQueryEstoque.FindField('PRODPRECOVAREJO');
  if Campo <> nil then
    Campo.DisplayWidth := 14;
end;

procedure TfrmEstoque.AbrirDetalheRegistro;
var
  DS: TDataSet;
begin
  DS := ObterDataSet;
  if (DS = nil) or (not DS.Active) or DS.IsEmpty then
    Exit;

  TfrmProdutoDetalhe.Abrir(
    DS.FieldByName('EMPCODIGO').AsInteger,
    DS.FieldByName('PRODCONTADOR').AsInteger,
    'Detalhes - ' + Caption);
end;

procedure TfrmEstoque.FormCreate(Sender: TObject);
begin
  inherited;
  ConfigurarJanela;
  DefinirTitulo('Estoque');
  DefinirLegendaPesquisa(
    'Pesquisar por c'#243'digo interno, cod. fabricante ou descri'#231#227'o ' +
    '(Enter pesquisa; duplo clique abre detalhes):');
  ConfigurarDados;
end;

procedure TfrmEstoque.CarregarDados(const AFiltro: string);
var
  SQL, Filtro: string;
begin
  if not dmConexao.Conectado then
  begin
    ErroConsulta(Self, 'Banco de dados n'#227'o conectado.', '');
    Exit;
  end;

  Filtro := Trim(AFiltro);
  FDQueryEstoque.Close;
  try
    SQL := TMapaEstoque.MontarSQLLista(Filtro);
    FDQueryEstoque.Connection := dmConexao.FDConnection1;
    FDQueryEstoque.SQL.Text := SQL;
    if Filtro <> '' then
      TMapaEstoque.ConfigurarParametrosLista(FDQueryEstoque, Filtro);
    FDQueryEstoque.Open;
    AplicarTitulosGrid;
  except
    on E: Exception do
    begin
      FDQueryEstoque.Close;
      ErroConsulta(Self, 'Erro ao consultar estoque:', E.Message);
    end;
  end;
end;

procedure TfrmEstoque.edtPesquisaKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    CarregarDados(edtPesquisa.Text);
  end;
end;

end.
