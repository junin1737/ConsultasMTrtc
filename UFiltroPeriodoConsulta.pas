unit UFiltroPeriodoConsulta;

interface

uses
  System.SysUtils, System.Classes, System.DateUtils,
  Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  FireDAC.Comp.Client, UConsultaCampos;

type
  TFiltroPeriodoConsulta = record
    Ativo: Boolean;
    DataInicio: TDateTime;
    DataFim: TDateTime;
  end;

  TWhereBuilder = record
    Text: string;
    TemWhere: Boolean;
    procedure Adicionar(const ACondicao: string);
    function Montar: string;
  end;

  TControlesFiltroPeriodo = class(TComponent)
  private
    FPanel: TWinControl;
    FLblPeriodo: TLabel;
    FLblDe: TLabel;
    FLblAte: TLabel;
    FChkAtivo: TCheckBox;
    FDtpInicio: TDateTimePicker;
    FDtpFim: TDateTimePicker;
    FOnAlteracao: TNotifyEvent;
    procedure ControleAlterado(Sender: TObject);
    procedure AtualizarControlesAtivo;
  public
    constructor Create(AOwner: TComponent; AParent: TWinControl; const ATextoPeriodo: string;
      AAtivoPorPadrao: Boolean = True; ATop: Integer = 68; ALeft: Integer = 12);
    procedure ConfigurarPanelTopo(APanel: TPanel);
    function ObterFiltro: TFiltroPeriodoConsulta;
    function LarguraOcupada: Integer;
    property OnAlteracao: TNotifyEvent read FOnAlteracao write FOnAlteracao;
  end;

function FiltroPeriodoVazio(const APeriodo: TFiltroPeriodoConsulta): Boolean;
procedure FiltroPeriodoMesAtual(out APeriodo: TFiltroPeriodoConsulta);
function MontarCondicaoPeriodo(const ACampoData: string;
  const APeriodo: TFiltroPeriodoConsulta): string; overload;
function MontarCondicaoPeriodo(const ACampoData: string;
  const AParamInicio, AParamFim: string; const APeriodo: TFiltroPeriodoConsulta): string; overload;
procedure ConfigurarParametrosPeriodo(AQuery: TFDQuery;
  const APeriodo: TFiltroPeriodoConsulta); overload;
procedure ConfigurarParametrosPeriodo(AQuery: TFDQuery;
  const AParamInicio, AParamFim: string; const APeriodo: TFiltroPeriodoConsulta); overload;

const
  ALTURA_PANEL_TOPO_COM_PERIODO = 108;
  FILTRO_PERIODO_LARGURA_ROTULO = 72;
  FILTRO_PERIODO_LARGURA_DATA = 100;

implementation

function FiltroPeriodoVazio(const APeriodo: TFiltroPeriodoConsulta): Boolean;
begin
  Result := not APeriodo.Ativo;
end;

procedure FiltroPeriodoMesAtual(out APeriodo: TFiltroPeriodoConsulta);
var
  Hoje: TDateTime;
begin
  Hoje := Date;
  APeriodo.Ativo := True;
  APeriodo.DataInicio := StartOfTheMonth(Hoje);
  APeriodo.DataFim := Hoje;
end;

function MontarCondicaoPeriodo(const ACampoData: string;
  const APeriodo: TFiltroPeriodoConsulta): string;
begin
  Result := MontarCondicaoPeriodo(ACampoData, 'DATA_INICIO', 'DATA_FIM', APeriodo);
end;

function MontarCondicaoPeriodo(const ACampoData: string;
  const AParamInicio, AParamFim: string; const APeriodo: TFiltroPeriodoConsulta): string;
begin
  if FiltroPeriodoVazio(APeriodo) then
    Exit('');

  Result := Format('CAST(%s AS DATE) BETWEEN :%s AND :%s',
    [ACampoData, AParamInicio, AParamFim]);
end;

procedure ConfigurarParametrosPeriodo(AQuery: TFDQuery;
  const APeriodo: TFiltroPeriodoConsulta);
begin
  ConfigurarParametrosPeriodo(AQuery, 'DATA_INICIO', 'DATA_FIM', APeriodo);
end;

procedure ConfigurarParametrosPeriodo(AQuery: TFDQuery;
  const AParamInicio, AParamFim: string; const APeriodo: TFiltroPeriodoConsulta);
begin
  if FiltroPeriodoVazio(APeriodo) then
    Exit;

  AQuery.ParamByName(AParamInicio).AsDate := DateOf(APeriodo.DataInicio);
  AQuery.ParamByName(AParamFim).AsDate := DateOf(APeriodo.DataFim);
end;

procedure TWhereBuilder.Adicionar(const ACondicao: string);
begin
  if Trim(ACondicao) = '' then
    Exit;

  if TemWhere then
    Text := Text + ' AND ' + ACondicao
  else
  begin
    Text := 'WHERE ' + ACondicao;
    TemWhere := True;
  end;
end;

function TWhereBuilder.Montar: string;
begin
  Result := Text;
end;

constructor TControlesFiltroPeriodo.Create(AOwner: TComponent; AParent: TWinControl;
  const ATextoPeriodo: string; AAtivoPorPadrao: Boolean; ATop, ALeft: Integer);
var
  Padrao: TFiltroPeriodoConsulta;
  PosRotulo, PosDe, PosInicio, PosAte, PosFim: Integer;
begin
  inherited Create(AOwner);
  FPanel := AParent;

  FChkAtivo := TCheckBox.Create(Self);
  FChkAtivo.Parent := FPanel;
  FChkAtivo.Left := ALeft;
  FChkAtivo.Top := ATop;
  FChkAtivo.Width := 16;
  FChkAtivo.Height := 17;
  FChkAtivo.Checked := AAtivoPorPadrao;
  FChkAtivo.OnClick := ControleAlterado;

  FLblPeriodo := TLabel.Create(Self);
  FLblPeriodo.Parent := FPanel;
  FLblPeriodo.AutoSize := False;
  PosRotulo := ALeft + 18;
  FLblPeriodo.Left := PosRotulo;
  FLblPeriodo.Top := ATop + 1;
  FLblPeriodo.Width := FILTRO_PERIODO_LARGURA_ROTULO;
  FLblPeriodo.Caption := ATextoPeriodo;
  AplicarFonteSegoeUISemiBold(FLblPeriodo.Font, 9);

  FLblDe := TLabel.Create(Self);
  FLblDe.Parent := FPanel;
  FLblDe.AutoSize := True;
  FLblDe.Caption := 'De:';
  AplicarFonteSegoeUISemiBold(FLblDe.Font, 9);

  FDtpInicio := TDateTimePicker.Create(Self);
  FDtpInicio.Parent := FPanel;
  FDtpInicio.Width := FILTRO_PERIODO_LARGURA_DATA;
  FDtpInicio.DateMode := dmUpDown;
  FDtpInicio.Format := 'dd/MM/yyyy';
  FDtpInicio.OnChange := ControleAlterado;
  AplicarFonteSegoeUISemiBold(FDtpInicio.Font, 9);

  FLblAte := TLabel.Create(Self);
  FLblAte.Parent := FPanel;
  FLblAte.AutoSize := True;
  FLblAte.Caption := 'At'#233':';
  AplicarFonteSegoeUISemiBold(FLblAte.Font, 9);

  FDtpFim := TDateTimePicker.Create(Self);
  FDtpFim.Parent := FPanel;
  FDtpFim.Width := FILTRO_PERIODO_LARGURA_DATA;
  FDtpFim.DateMode := dmUpDown;
  FDtpFim.Format := 'dd/MM/yyyy';
  FDtpFim.OnChange := ControleAlterado;
  AplicarFonteSegoeUISemiBold(FDtpFim.Font, 9);

  FiltroPeriodoMesAtual(Padrao);
  FDtpInicio.Date := Padrao.DataInicio;
  FDtpFim.Date := Padrao.DataFim;

  PosDe := PosRotulo + FILTRO_PERIODO_LARGURA_ROTULO + 6;
  PosInicio := PosDe + FLblDe.Width + 4;
  PosAte := PosInicio + FDtpInicio.Width + 8;
  PosFim := PosAte + FLblAte.Width + 4;

  FLblDe.Left := PosDe;
  FLblDe.Top := ATop + 3;
  FDtpInicio.Left := PosInicio;
  FDtpInicio.Top := ATop - 1;
  FLblAte.Left := PosAte;
  FLblAte.Top := ATop + 3;
  FDtpFim.Left := PosFim;
  FDtpFim.Top := ATop - 1;

  AtualizarControlesAtivo;
end;

procedure TControlesFiltroPeriodo.AtualizarControlesAtivo;
var
  Ativo: Boolean;
begin
  Ativo := FChkAtivo.Checked;
  FLblDe.Enabled := Ativo;
  FLblAte.Enabled := Ativo;
  FDtpInicio.Enabled := Ativo;
  FDtpFim.Enabled := Ativo;
end;

procedure TControlesFiltroPeriodo.ConfigurarPanelTopo(APanel: TPanel);
begin
  if APanel <> nil then
    APanel.Height := ALTURA_PANEL_TOPO_COM_PERIODO;
end;

function TControlesFiltroPeriodo.LarguraOcupada: Integer;
begin
  Result := (FDtpFim.Left + FDtpFim.Width) - FChkAtivo.Left + 4;
end;

function TControlesFiltroPeriodo.ObterFiltro: TFiltroPeriodoConsulta;
begin
  Result.Ativo := FChkAtivo.Checked;
  Result.DataInicio := FDtpInicio.Date;
  Result.DataFim := FDtpFim.Date;

  if Result.Ativo and (Result.DataInicio > Result.DataFim) then
  begin
    Result.DataInicio := Result.DataFim;
    FDtpInicio.Date := Result.DataInicio;
  end;
end;

procedure TControlesFiltroPeriodo.ControleAlterado(Sender: TObject);
begin
  if Sender = FChkAtivo then
    AtualizarControlesAtivo;
  if Assigned(FOnAlteracao) then
    FOnAlteracao(Self);
end;

end.
