unit UfrmCompra;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Buttons, Vcl.Grids, Vcl.DBGrids,
  Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Param, FireDAC.DApt,
  UfrmConsultaBase, UdmConexao, UConsultaCampos, UConsultaLayout, UMapaCompra, UfrmCompraDetalhe, UFormatacaoMoeda,
  UConsultaDialogs, UFiltroPeriodoConsulta, USituacaoNotaConsulta;

type
  TfrmCompra = class(TfrmConsultaBase)
    procedure FormCreate(Sender: TObject);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: Char);
  private
    FDQueryCompra: TFDQuery;
    DataSourceCompra: TDataSource;
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
  frmCompra: TfrmCompra;

implementation

{$R *.dfm}

const
  LARGURA_BASE = 1350;
  ALTURA_BASE = 900;
  FATOR_TAMANHO = 0.70;

procedure TfrmCompra.ConfigurarJanela;
begin
  AjustarJanelaConsulta(Self, LARGURA_BASE, ALTURA_BASE, FATOR_TAMANHO);
end;

function TfrmCompra.ObterDataSet: TDataSet;
begin
  Result := FDQueryCompra;
end;

function TfrmCompra.ResolverTituloCampo(const ANomeCampo: string): string;
begin
  if SameText(ANomeCampo, 'ENTCNUMERO') then
    Exit('N'#250'mero');
  if SameText(ANomeCampo, 'ENTCSERIE') then
    Exit('S'#233'rie');
  if SameText(ANomeCampo, 'ENTCDTEMISSAO') then
    Exit('Emiss'#227'o');
  if SameText(ANomeCampo, 'ENTCDTENTRADA') then
    Exit('Entrada');
  if SameText(ANomeCampo, 'NOME_FORNECEDOR') then
    Exit('Fornecedor');
  if SameText(ANomeCampo, 'ENTCVRTOTAL') then
    Exit('Valor total');
  if SameText(ANomeCampo, 'SITUACAO_NOTA') then
    Exit('Situa'#231#227'o');
  if SameText(ANomeCampo, 'ENTCSITUACAO') then
    Exit('Situa'#231#227'o');
  if SameText(ANomeCampo, 'ENTCCHAVENFE') then
    Exit('Chave NFe');
  Result := ANomeCampo;
end;

procedure TfrmCompra.ConfigurarFiltroPeriodo;
begin
  FFiltroPeriodo := TControlesFiltroPeriodo.Create(Self, PanelTopo,
    'Per'#237'odo entrada/emiss'#227'o:', False);
  FFiltroPeriodo.ConfigurarPanelTopo(PanelTopo);
  FFiltroPeriodo.OnAlteracao := PeriodoAlterado;
end;

procedure TfrmCompra.PeriodoAlterado(Sender: TObject);
begin
  CarregarDados(edtPesquisa.Text);
end;

procedure TfrmCompra.ConfigurarDados;
begin
  FDQueryCompra := TFDQuery.Create(Self);
  FDQueryCompra.ResourceOptions.SilentMode := True;
  DataSourceCompra := TDataSource.Create(Self);
  DataSourceCompra.DataSet := FDQueryCompra;
  DBGrid1.DataSource := DataSourceCompra;
  edtPesquisa.OnKeyPress := edtPesquisaKeyPress;
  DBGrid1.OnDrawColumnCell := DBGrid1DrawColumnCell;
  DBGrid1.DefaultDrawing := False;
end;

procedure TfrmCompra.CampoDataGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatDateTime('dd/mm/yyyy', Sender.AsDateTime);
end;

procedure TfrmCompra.CampoMoedaGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  TConsultaMoedaHandlers.MoedaGetText(Sender, Text, DisplayText);
end;

procedure TfrmCompra.OcultarCamposInternos;
var
  Campo: TField;
begin
  Campo := FDQueryCompra.FindField('EMPCODIGO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryCompra.FindField('ENTCCONTADOR');
  if Campo <> nil then
    Campo.Visible := False;
end;

procedure TfrmCompra.AplicarTitulosGrid;
var
  I: Integer;
  Campo: TField;
  Nome: string;
begin
  for I := 0 to FDQueryCompra.FieldCount - 1 do
  begin
    Campo := FDQueryCompra.Fields[I];
    Campo.DisplayLabel := ResolverTituloCampo(Campo.FieldName);
    Nome := UpperCase(Campo.FieldName);
    if (Nome = 'ENTCDTEMISSAO') or (Nome = 'ENTCDTENTRADA') then
      Campo.OnGetText := CampoDataGetText
    else if Nome = 'ENTCVRTOTAL' then
      Campo.OnGetText := CampoMoedaGetText;
  end;
  OcultarCamposInternos;
  ConfigurarLargurasGrid;
end;

procedure TfrmCompra.DBGrid1DrawColumnCell(Sender: TObject; const Rect: TRect;
  DataCol: Integer; Column: TColumn; State: TGridDrawState);
begin
  DesenharCelulaGridNotaLista(TDBGrid(Sender), Rect, DataCol, Column, State);
end;

procedure TfrmCompra.ConfigurarLargurasGrid;
var
  Campo: TField;
begin
  Campo := FDQueryCompra.FindField('ENTCNUMERO');
  if Campo <> nil then
    Campo.DisplayWidth := 10;
  Campo := FDQueryCompra.FindField('ENTCSERIE');
  if Campo <> nil then
    Campo.DisplayWidth := 8;
  Campo := FDQueryCompra.FindField('ENTCDTEMISSAO');
  if Campo <> nil then
    Campo.DisplayWidth := 11;
  Campo := FDQueryCompra.FindField('ENTCDTENTRADA');
  if Campo <> nil then
    Campo.DisplayWidth := 11;
  Campo := FDQueryCompra.FindField('NOME_FORNECEDOR');
  if Campo <> nil then
    Campo.DisplayWidth := 34;
  Campo := FDQueryCompra.FindField('ENTCVRTOTAL');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryCompra.FindField('SITUACAO_NOTA');
  if Campo <> nil then
    Campo.DisplayWidth := 12;
  Campo := FDQueryCompra.FindField('ENTCSITUACAO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryCompra.FindField('ENTCSITUACAODOCUMENTO');
  if Campo <> nil then
    Campo.Visible := False;
  Campo := FDQueryCompra.FindField('ENTCCHAVENFE');
  if Campo <> nil then
    Campo.Visible := False;

  AplicarLargurasColunasGridCompra(DBGrid1);
end;

procedure TfrmCompra.AbrirDetalheRegistro;
var
  DS: TDataSet;
  Form: TfrmCompraDetalhe;
  EmpCodigo, EntcContador: Integer;
begin
  DS := ObterDataSet;
  if (DS = nil) or (not DS.Active) or DS.IsEmpty then
    Exit;

  EmpCodigo := DS.FieldByName('EMPCODIGO').AsInteger;
  EntcContador := DS.FieldByName('ENTCCONTADOR').AsInteger;

  Form := TfrmCompraDetalhe.Create(Application);
  try
    Form.Exibir(EmpCodigo, EntcContador);
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure TfrmCompra.FormCreate(Sender: TObject);
begin
  inherited;
  ConfigurarJanela;
  DefinirTitulo('Compras');
  DefinirLegendaPesquisa(
    'Pesquisar por n'#250'mero da nota ou nome do fornecedor ' +
    '(Enter pesquisa; duplo clique abre itens):');
  ConfigurarDados;
  ConfigurarFiltroPeriodo;
end;

procedure TfrmCompra.CarregarDados(const AFiltro: string);
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
  FDQueryCompra.Close;
  try
    try
      TMapaCompra.GarantirMapa;
      SQL := TMapaCompra.MontarSQLLista(Filtro, Periodo);
    except
      on E: Exception do
      begin
        ErroConsulta(Self, 'Erro ao montar consulta de compras:', E.Message);
        Exit;
      end;
    end;

    FDQueryCompra.Connection := dmConexao.FDConnection1;
    FDQueryCompra.SQL.Text := SQL;
    TMapaCompra.ConfigurarParametrosLista(FDQueryCompra, Filtro, Periodo);

    FDQueryCompra.Open;
    AplicarTitulosGrid;
  except
    on E: Exception do
    begin
      FDQueryCompra.Close;
      ErroConsulta(Self, 'Erro ao consultar compras:', E.Message);
    end;
  end;
end;

procedure TfrmCompra.edtPesquisaKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    CarregarDados(edtPesquisa.Text);
  end;
end;

end.
