unit UConsultaLayout;

interface

uses
  System.SysUtils, System.Math, System.Types, Winapi.Windows, Vcl.Forms, Vcl.Controls,
  Vcl.ExtCtrls, Vcl.StdCtrls;

function ObterAreaTrabalhoTela: TRect;
function LimitarDimensao(AValor, AMaximo: Integer): Integer;
procedure AjustarJanelaConsulta(AForm: TForm; ABaseLargura, ABaseAltura: Integer;
  AFator: Double = 0.70);
procedure AjustarJanelaDetalhe(AForm: TForm; ABaseLargura: Integer = 740;
  ABaseAltura: Integer = 0);
procedure AjustarBotoesRodapeDireita(APanel: TPanel; ABotoes: array of TButton;
  AMargem: Integer = 16);
procedure AjustarJanelaPrincipal(AForm: TForm);
function CalcularEscalaHorizontal(AConteudoLargura, AMargem: Integer): Double;

implementation

const
  MARGEM_TELA = 16;
  CONSULTA_FATOR_PADRAO = 0.70;
  CONSULTA_LARGURA_MIN = 720;
  CONSULTA_ALTURA_MIN = 480;
  DETALHE_LARGURA_MIN = 640;
  DETALHE_ALTURA_MIN = 460;

function ObterAreaTrabalhoTela: TRect;
begin
  Result := Rect(0, 0, Screen.Width, Screen.Height);
  SystemParametersInfo(SPI_GETWORKAREA, 0, @Result, 0);
end;

function LimitarDimensao(AValor, AMaximo: Integer): Integer;
begin
  Result := AValor;
  if (AMaximo > 0) and (Result > AMaximo) then
    Result := AMaximo;
end;

function CalcularEscalaHorizontal(AConteudoLargura, AMargem: Integer): Double;
var
  Area: TRect;
  Disponivel: Integer;
begin
  Area := ObterAreaTrabalhoTela;
  Disponivel := Area.Width - (AMargem * 2);
  if (AConteudoLargura <= 0) or (Disponivel <= 0) then
    Exit(1.0);
  Result := Disponivel / AConteudoLargura;
  if Result > 1.0 then
    Result := 1.0;
  if Result < 0.55 then
    Result := 0.55;
end;

procedure AjustarJanelaConsulta(AForm: TForm; ABaseLargura, ABaseAltura: Integer;
  AFator: Double);
var
  Area: TRect;
  Largura, Altura, MaxLargura, MaxAltura: Integer;
begin
  if AForm = nil then
    Exit;
  if AFator <= 0 then
    AFator := CONSULTA_FATOR_PADRAO;

  Area := ObterAreaTrabalhoTela;
  MaxLargura := Area.Width - MARGEM_TELA;
  MaxAltura := Area.Height - MARGEM_TELA;

  Largura := Round(ABaseLargura * AFator);
  Altura := Round(ABaseAltura * AFator);

  Largura := LimitarDimensao(Largura, MaxLargura);
  Altura := LimitarDimensao(Altura, MaxAltura);

  if Largura < CONSULTA_LARGURA_MIN then
    Largura := Min(CONSULTA_LARGURA_MIN, MaxLargura);
  if Altura < CONSULTA_ALTURA_MIN then
    Altura := Min(CONSULTA_ALTURA_MIN, MaxAltura);

  AForm.BorderStyle := bsSizeable;
  AForm.BorderIcons := [biSystemMenu];
  AForm.Position := poScreenCenter;
  AForm.ClientWidth := Largura;
  AForm.ClientHeight := Altura;

  AForm.Constraints.MinWidth := Min(CONSULTA_LARGURA_MIN, MaxLargura);
  AForm.Constraints.MinHeight := Min(CONSULTA_ALTURA_MIN, MaxAltura);
  AForm.Constraints.MaxWidth := 0;
  AForm.Constraints.MaxHeight := 0;
end;

procedure AjustarBotoesRodapeDireita(APanel: TPanel; ABotoes: array of TButton;
  AMargem: Integer);
var
  I, LeftPos: Integer;
begin
  if APanel = nil then
    Exit;

  LeftPos := APanel.ClientWidth - AMargem;
  for I := High(ABotoes) downto Low(ABotoes) do
  begin
    if ABotoes[I] = nil then
      Continue;
    ABotoes[I].Anchors := [akTop, akRight];
    LeftPos := LeftPos - ABotoes[I].Width;
    ABotoes[I].Left := LeftPos;
    LeftPos := LeftPos - 12;
  end;
end;

procedure AjustarJanelaDetalhe(AForm: TForm; ABaseLargura: Integer;
  ABaseAltura: Integer);
var
  Area: TRect;
  Largura, Altura, MaxLargura, MaxAltura: Integer;
begin
  if AForm = nil then
    Exit;

  Area := ObterAreaTrabalhoTela;
  MaxLargura := Area.Width - MARGEM_TELA;
  MaxAltura := Area.Height - MARGEM_TELA;

  Largura := ABaseLargura;
  if Largura <= 0 then
    Largura := 740;

  Largura := LimitarDimensao(Largura, MaxLargura);
  if Largura < DETALHE_LARGURA_MIN then
    Largura := Min(DETALHE_LARGURA_MIN, MaxLargura);

  AForm.BorderStyle := bsSizeable;
  AForm.Position := poScreenCenter;
  AForm.ClientWidth := Largura;

  if ABaseAltura > 0 then
  begin
    Altura := LimitarDimensao(ABaseAltura, MaxAltura);
    if Altura < DETALHE_ALTURA_MIN then
      Altura := Min(DETALHE_ALTURA_MIN, MaxAltura);
    AForm.ClientHeight := Altura;
  end;

  AForm.Constraints.MinWidth := Min(DETALHE_LARGURA_MIN, MaxLargura);
  AForm.Constraints.MinHeight := Min(DETALHE_ALTURA_MIN, MaxAltura);
  AForm.Constraints.MaxWidth := 0;
  AForm.Constraints.MaxHeight := 0;
end;

procedure AjustarJanelaPrincipal(AForm: TForm);
var
  Area: TRect;
begin
  if AForm = nil then
    Exit;

  Area := ObterAreaTrabalhoTela;
  AForm.Position := poScreenCenter;

  if AForm.Width > Area.Width then
    AForm.Width := Area.Width;
  if AForm.Height > Area.Height then
    AForm.Height := Area.Height;

  AForm.Constraints.MaxWidth := Area.Width;
  AForm.Constraints.MaxHeight := Area.Height;
end;

end.
