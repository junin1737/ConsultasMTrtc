unit UfrmConsultaBase;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Data.DB, Vcl.Grids, Vcl.DBGrids,
  Vcl.ExtCtrls, Vcl.StdCtrls, UConsultaCampos;

type
  TConsultaDBGrid = class(TDBGrid)
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  end;

  TfrmConsultaBase = class(TForm)
    PanelTopo: TPanel;
    PanelRodape: TPanel;
    DBGrid1: TConsultaDBGrid;
    lblPesquisa: TLabel;
    edtPesquisa: TEdit;
    btnFechar: TButton;
    procedure btnFecharClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure DBGrid1DblClick(Sender: TObject);
    procedure ControleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    function ConfirmarFecharConsulta: Boolean;
    procedure AjustarLayoutConsulta;
  public
    procedure SolicitarFecharConsulta;
    procedure DefinirLegendaPesquisa(const ALegenda: string);
    function ResolverTituloCampo(const ANomeCampo: string): string; virtual;
  protected
    procedure WndProc(var Message: TMessage); override;
    function ObterDataSet: TDataSet; virtual;
    procedure DefinirTitulo(const ATitulo: string); virtual;
    procedure AbrirDetalheRegistro; virtual;
  end;

implementation

{$R *.dfm}

uses
  UfrmRegistroDetalhe, UConfirmarFechar, UConsultaDialogs, UConsultaManager, UConsultaLayout;

procedure TConsultaDBGrid.KeyDown(var Key: Word; Shift: TShiftState);
var
  FormConsulta: TfrmConsultaBase;
begin
  if Key = VK_ESCAPE then
  begin
    FormConsulta := TfrmConsultaBase(GetParentForm(Self));
    if FormConsulta <> nil then
    begin
      Key := 0;
      FormConsulta.SolicitarFecharConsulta;
      Exit;
    end;
  end;
  inherited KeyDown(Key, Shift);
end;

function TfrmConsultaBase.ConfirmarFecharConsulta: Boolean;
begin
  Result := True;
end;

procedure TfrmConsultaBase.SolicitarFecharConsulta;
begin
  if csDestroying in ComponentState then
    Exit;
  if ConfirmarFecharConsulta then
    ExecutarFecharConsulta(Self);
end;

procedure TfrmConsultaBase.WndProc(var Message: TMessage);
begin
  if Message.Msg = WM_SYSCOMMAND then
  begin
    if (Message.WParam and $FFF0) = SC_CLOSE then
    begin
      SolicitarFecharConsulta;
      Exit;
    end;
  end;
  inherited WndProc(Message);
end;

procedure TfrmConsultaBase.ControleKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    SolicitarFecharConsulta;
  end;
end;

procedure TfrmConsultaBase.AjustarLayoutConsulta;
begin
  AjustarLayoutPesquisaConsulta(PanelTopo, lblPesquisa, edtPesquisa);
  AjustarBotoesRodapeDireita(PanelRodape, [btnFechar]);
end;

procedure TfrmConsultaBase.FormCreate(Sender: TObject);
begin
  BorderIcons := [biSystemMenu];
  KeyPreview := True;
  OnKeyDown := ControleKeyDown;
  OnResize := FormResize;
  Position := poScreenCenter;
  ConfigurarGridConsulta(DBGrid1);
  DBGrid1.OnDblClick := DBGrid1DblClick;
  edtPesquisa.OnKeyDown := ControleKeyDown;
  btnFechar.Anchors := [akTop, akRight];
  AplicarFonteConsultaForm(Self);
  AjustarLayoutConsulta;
end;

procedure TfrmConsultaBase.FormResize(Sender: TObject);
begin
  AjustarLayoutConsulta;
end;

function TfrmConsultaBase.ObterDataSet: TDataSet;
begin
  Result := nil;
  if DBGrid1.DataSource = nil then
    Exit;
  Result := DBGrid1.DataSource.DataSet;
end;

function TfrmConsultaBase.ResolverTituloCampo(const ANomeCampo: string): string;
begin
  Result := TituloAmigavelCampo(ANomeCampo);
end;

procedure TfrmConsultaBase.DefinirLegendaPesquisa(const ALegenda: string);
begin
  lblPesquisa.Caption := ALegenda;
  AjustarLayoutConsulta;
end;

procedure TfrmConsultaBase.DefinirTitulo(const ATitulo: string);
begin
  Caption := ATitulo;
  DefinirLegendaPesquisa(
    'Pesquisar em ' + ATitulo + ' (Enter pesquisa; duplo clique abre detalhes):');
end;

procedure TfrmConsultaBase.AbrirDetalheRegistro;
var
  DS: TDataSet;
  Form: TfrmRegistroDetalhe;
begin
  DS := ObterDataSet;
  if (DS = nil) or (not DS.Active) or DS.IsEmpty then
    Exit;

  Form := TfrmRegistroDetalhe.Create(Application);
  try
    Form.Exibir(DS, 'Detalhes - ' + Caption, Self);
  finally
    Form.Free;
  end;
end;

procedure TfrmConsultaBase.DBGrid1DblClick(Sender: TObject);
begin
  AbrirDetalheRegistro;
end;

procedure TfrmConsultaBase.btnFecharClick(Sender: TObject);
begin
  SolicitarFecharConsulta;
end;

initialization
  RegisterClass(TConsultaDBGrid);

end.
