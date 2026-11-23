unit UFiltroSituacaoNotaFiscal;

interface

uses
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, UConsultaCampos;

type
  TFiltroSituacaoNotaFiscalConsulta = record
    Todas: Boolean;
    Transmitidas: Boolean;
    Canceladas: Boolean;
    Inutilizadas: Boolean;
  end;

  TControlesFiltroSituacaoNotaFiscal = class(TComponent)
  private
    FPanel: TPanel;
    FLblSituacao: TLabel;
    FChkTodas: TCheckBox;
    FChkTransmitidas: TCheckBox;
    FChkCanceladas: TCheckBox;
    FChkInutilizadas: TCheckBox;
    FOnAlteracao: TNotifyEvent;
    FAtualizando: Boolean;
    procedure ControleAlterado(Sender: TObject);
    procedure ChkTodasClick(Sender: TObject);
    procedure ChkEspecificaClick(Sender: TObject);
    procedure CriarCheckBox(var AChk: TCheckBox; const ACaption: string; ALeft, AWidth: Integer);
  public
    constructor Create(AOwner: TComponent; AParent: TPanel);
    function ObterFiltro: TFiltroSituacaoNotaFiscalConsulta;
    property OnAlteracao: TNotifyEvent read FOnAlteracao write FOnAlteracao;
  end;

function FiltroSituacaoNotaFiscalVazio(const AFiltro: TFiltroSituacaoNotaFiscalConsulta): Boolean;
function MontarCondicaoSituacaoNotaFiscal(const AFiltro: TFiltroSituacaoNotaFiscalConsulta): string;
function MontarCondicaoSituacaoNfce(const AFiltro: TFiltroSituacaoNotaFiscalConsulta): string;

const
  ALTURA_PANEL_TOPO_COM_FILTROS_NF = 142;

procedure AjustarAlturaPanelTopoNotaFiscal(APanel: TPanel);

implementation

function FiltroSituacaoNotaFiscalVazio(const AFiltro: TFiltroSituacaoNotaFiscalConsulta): Boolean;
begin
  Result := AFiltro.Todas or
    (not AFiltro.Transmitidas and not AFiltro.Canceladas and not AFiltro.Inutilizadas);
end;

function MontarCondicaoSituacaoNotaFiscal(const AFiltro: TFiltroSituacaoNotaFiscalConsulta): string;
var
  Partes: TArray<string>;
  I: Integer;
begin
  if FiltroSituacaoNotaFiscalVazio(AFiltro) then
    Exit('');

  I := 0;
  SetLength(Partes, 3);
  if AFiltro.Transmitidas then
  begin
    Partes[I] :=
      '(TRIM(COALESCE(N.NFSITUACAODOC, '''')) NOT IN (''02'', ''04'', ''05''))';
    Inc(I);
  end;
  if AFiltro.Canceladas then
  begin
    Partes[I] := 'TRIM(COALESCE(N.NFSITUACAODOC, '''')) = ''02''';
    Inc(I);
  end;
  if AFiltro.Inutilizadas then
  begin
    Partes[I] := 'TRIM(COALESCE(N.NFSITUACAODOC, '''')) IN (''04'', ''05'')';
    Inc(I);
  end;

  SetLength(Partes, I);
  if I = 0 then
    Exit('1 = 0');

  Result := '(' + string.Join(' OR ', Partes) + ')';
end;

function MontarCondicaoSituacaoNfce(const AFiltro: TFiltroSituacaoNotaFiscalConsulta): string;
var
  Partes: TArray<string>;
  I: Integer;
begin
  if FiltroSituacaoNotaFiscalVazio(AFiltro) then
    Exit('');

  I := 0;
  SetLength(Partes, 3);
  if AFiltro.Transmitidas then
  begin
    Partes[I] :=
      '(TRIM(COALESCE(N.VENRNFCESITUACAODOC, '''')) NOT IN (''02'', ''04'', ''05''))';
    Inc(I);
  end;
  if AFiltro.Canceladas then
  begin
    Partes[I] := 'TRIM(COALESCE(N.VENRNFCESITUACAODOC, '''')) = ''02''';
    Inc(I);
  end;
  if AFiltro.Inutilizadas then
  begin
    Partes[I] := 'TRIM(COALESCE(N.VENRNFCESITUACAODOC, '''')) IN (''04'', ''05'')';
    Inc(I);
  end;

  SetLength(Partes, I);
  if I = 0 then
    Exit('1 = 0');

  Result := '(' + string.Join(' OR ', Partes) + ')';
end;

procedure AjustarAlturaPanelTopoNotaFiscal(APanel: TPanel);
begin
  if APanel <> nil then
    APanel.Height := ALTURA_PANEL_TOPO_COM_FILTROS_NF;
end;

procedure TControlesFiltroSituacaoNotaFiscal.CriarCheckBox(var AChk: TCheckBox;
  const ACaption: string; ALeft, AWidth: Integer);
begin
  AChk := TCheckBox.Create(Self);
  AChk.Parent := FPanel;
  AChk.Left := ALeft;
  AChk.Top := 96;
  AChk.Width := AWidth;
  AChk.Height := 17;
  AChk.Caption := ACaption;
  AplicarFonteSegoeUISemiBold(AChk.Font, 9);
end;

constructor TControlesFiltroSituacaoNotaFiscal.Create(AOwner: TComponent; AParent: TPanel);
begin
  inherited Create(AOwner);
  FPanel := AParent;

  FLblSituacao := TLabel.Create(Self);
  FLblSituacao.Parent := FPanel;
  FLblSituacao.AutoSize := True;
  FLblSituacao.Left := 12;
  FLblSituacao.Top := 98;
  FLblSituacao.Caption := 'Situa'#231#227'o:';
  AplicarFonteSegoeUISemiBold(FLblSituacao.Font, 9);

  CriarCheckBox(FChkTodas, 'Todas', 88, 72);
  FChkTodas.Checked := True;
  FChkTodas.OnClick := ChkTodasClick;

  CriarCheckBox(FChkTransmitidas, 'Transmitidas', 168, 100);
  FChkTransmitidas.OnClick := ChkEspecificaClick;

  CriarCheckBox(FChkCanceladas, 'Canceladas', 276, 96);
  FChkCanceladas.OnClick := ChkEspecificaClick;

  CriarCheckBox(FChkInutilizadas, 'Inutilizadas', 380, 104);
  FChkInutilizadas.OnClick := ChkEspecificaClick;
end;

function TControlesFiltroSituacaoNotaFiscal.ObterFiltro: TFiltroSituacaoNotaFiscalConsulta;
begin
  Result.Todas := FChkTodas.Checked;
  Result.Transmitidas := FChkTransmitidas.Checked;
  Result.Canceladas := FChkCanceladas.Checked;
  Result.Inutilizadas := FChkInutilizadas.Checked;
end;

procedure TControlesFiltroSituacaoNotaFiscal.ControleAlterado(Sender: TObject);
begin
  if FAtualizando then
    Exit;
  if Assigned(FOnAlteracao) then
    FOnAlteracao(Self);
end;

procedure TControlesFiltroSituacaoNotaFiscal.ChkTodasClick(Sender: TObject);
begin
  FAtualizando := True;
  try
    if FChkTodas.Checked then
    begin
      FChkTransmitidas.Checked := False;
      FChkCanceladas.Checked := False;
      FChkInutilizadas.Checked := False;
    end
    else if not FChkTransmitidas.Checked and not FChkCanceladas.Checked and
      not FChkInutilizadas.Checked then
      FChkTodas.Checked := True;
  finally
    FAtualizando := False;
  end;
  ControleAlterado(Sender);
end;

procedure TControlesFiltroSituacaoNotaFiscal.ChkEspecificaClick(Sender: TObject);
begin
  FAtualizando := True;
  try
    if FChkTransmitidas.Checked or FChkCanceladas.Checked or FChkInutilizadas.Checked then
      FChkTodas.Checked := False
    else
      FChkTodas.Checked := True;
  finally
    FAtualizando := False;
  end;
  ControleAlterado(Sender);
end;

end.
