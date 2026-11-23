unit UfrmClientes;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Buttons, Vcl.Grids, Vcl.DBGrids,
  Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.Stan.Param, FireDAC.DApt,
  UfrmConsultaBase, UdmConexao, UConsultaCampos, UConsultaLayout, UFormatacaoMoeda;

type
  TfrmClientes = class(TfrmConsultaBase)
    procedure FormCreate(Sender: TObject);
    procedure edtPesquisaKeyPress(Sender: TObject; var Key: Char);
  private
    FDQueryPessoas: TFDQuery;
    DataSourcePessoas: TDataSource;
    procedure ConfigurarJanela;
    procedure ConfigurarDados;
    procedure AplicarTitulosGrid;
    procedure CampoCpfCnpjGetText(Sender: TField; var Text: string; DisplayText: Boolean);
  protected
    function ObterDataSet: TDataSet; override;
    function ResolverTituloCampo(const ANomeCampo: string): string; override;
    procedure AbrirDetalheRegistro; override;
  public
    procedure CarregarDados(const AFiltro: string = '');
  end;

var
  frmClientes: TfrmClientes;

implementation

{$R *.dfm}

uses
  UfrmPessoaDetalhe;

const
  LARGURA_BASE = 1350;
  ALTURA_BASE = 900;
  FATOR_TAMANHO = 0.70;

procedure TfrmClientes.ConfigurarJanela;
begin
  AjustarJanelaConsulta(Self, LARGURA_BASE, ALTURA_BASE, FATOR_TAMANHO);
end;

function TfrmClientes.ObterDataSet: TDataSet;
begin
  Result := FDQueryPessoas;
end;

function TfrmClientes.ResolverTituloCampo(const ANomeCampo: string): string;
var
  Nome: string;
begin
  Nome := UpperCase(ANomeCampo);
  if SameText(Nome, 'PESCODIGO') then
    Exit('C'#243'digo');
  if SameText(Nome, 'PESNOME') then
    Exit('Nome');
  if SameText(Nome, 'PESCNPJCPF') then
    Exit('CPF/CNPJ');
  if SameText(Nome, 'PESIE') then
    Exit('Inscri'#231#227'o estadual');
  Result := TituloAmigavelCampo(ANomeCampo);
end;

procedure TfrmClientes.ConfigurarDados;
begin
  FDQueryPessoas := TFDQuery.Create(Self);
  FDQueryPessoas.ResourceOptions.SilentMode := True;
  DataSourcePessoas := TDataSource.Create(Self);
  DataSourcePessoas.DataSet := FDQueryPessoas;
  DBGrid1.DataSource := DataSourcePessoas;
  edtPesquisa.OnKeyPress := edtPesquisaKeyPress;
end;

procedure TfrmClientes.CampoCpfCnpjGetText(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  if Sender.IsNull then
    Text := ''
  else
    Text := FormatarCpfCnpj(Sender.AsString);
end;

procedure TfrmClientes.AplicarTitulosGrid;
var
  I: Integer;
  CampoCpf: TField;
begin
  for I := 0 to FDQueryPessoas.FieldCount - 1 do
    FDQueryPessoas.Fields[I].DisplayLabel := ResolverTituloCampo(FDQueryPessoas.Fields[I].FieldName);

  CampoCpf := FDQueryPessoas.FindField('PESCNPJCPF');
  if CampoCpf <> nil then
    CampoCpf.OnGetText := CampoCpfCnpjGetText;
end;

procedure TfrmClientes.AbrirDetalheRegistro;
var
  DS: TDataSet;
  Codigo: string;
begin
  DS := ObterDataSet;
  if (DS = nil) or (not DS.Active) or DS.IsEmpty then
    Exit;

  Codigo := DS.FieldByName('PESCODIGO').AsString;
  TfrmPessoaDetalhe.Abrir(Codigo, 'Detalhes - ' + Caption);
end;

procedure TfrmClientes.FormCreate(Sender: TObject);
begin
  inherited;
  ConfigurarJanela;
  DefinirTitulo('Clientes');
  ConfigurarDados;
end;

procedure TfrmClientes.CarregarDados(const AFiltro: string);
var
  SQL, Filtro: string;
begin
  if not dmConexao.Conectado then
  begin
    ShowMessage('Banco de dados nao conectado.');
    Exit;
  end;

  Filtro := Trim(AFiltro);
  SQL :=
    'SELECT FIRST 2000 PESCODIGO, PESNOME, PESCNPJCPF, PESIE FROM PESSOA';

  if Filtro <> '' then
    SQL := SQL + ' WHERE PESNOME CONTAINING :FILTRO';

  SQL := SQL + ' ORDER BY PESNOME';

  FDQueryPessoas.Close;
  FDQueryPessoas.Connection := dmConexao.FDConnection1;
  FDQueryPessoas.SQL.Text := SQL;

  if Filtro <> '' then
    FDQueryPessoas.ParamByName('FILTRO').AsString := Filtro;

  try
    FDQueryPessoas.Open;
    AplicarTitulosGrid;
  except
    on E: Exception do
      ShowMessage('Erro ao consultar a tabela PESSOA:' + sLineBreak + sLineBreak + E.Message);
  end;
end;

procedure TfrmClientes.edtPesquisaKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    CarregarDados(edtPesquisa.Text);
  end;
end;

end.
