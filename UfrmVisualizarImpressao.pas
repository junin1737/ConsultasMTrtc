unit UfrmVisualizarImpressao;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.StdCtrls, UConfirmarFechar, UImpressaoUtil;

type
  TfrmVisualizarImpressao = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlZoom: TPanel;
    btnZoomMenos: TButton;
    btnZoomMais: TButton;
    btnZoomAjustar: TButton;
    btnZoom100: TButton;
    lblZoom: TLabel;
    scrollVisual: TScrollBox;
    paintPagina: TPaintBox;
    pnlRodape: TPanel;
    btnPrimeira: TButton;
    btnAnterior: TButton;
    lblPagina: TLabel;
    btnProxima: TButton;
    btnUltima: TButton;
    btnImprimir: TButton;
    btnFechar: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure paintPaginaPaint(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure btnImprimirClick(Sender: TObject);
    procedure btnPrimeiraClick(Sender: TObject);
    procedure btnAnteriorClick(Sender: TObject);
    procedure btnProximaClick(Sender: TObject);
    procedure btnUltimaClick(Sender: TObject);
    procedure btnZoomMenosClick(Sender: TObject);
    procedure btnZoomMaisClick(Sender: TObject);
    procedure btnZoomAjustarClick(Sender: TObject);
    procedure btnZoom100Click(Sender: TObject);
  private
    FPaginas: TListaPaginasImpressao;
    FIndicePagina: Integer;
    FOnImprimir: TNotifyEvent;
    FZoomPercent: Integer;
    FAjustarTela: Boolean;
    procedure AtualizarNavegacao;
    procedure IrParaPagina(AIndice: Integer);
    procedure AtualizarLabelZoom;
    procedure AtualizarTamanhoVisual;
    procedure CentralizarPaginaVisual;
    procedure Redesenhar;
  public
    procedure Configurar(const ATitulo: string; APaginas: TListaPaginasImpressao;
      AOnImprimir: TNotifyEvent);
  end;

implementation

{$R *.dfm}

const
  ZOOM_MIN = 25;
  ZOOM_MAX = 300;
  ZOOM_PASSO = 10;

procedure TfrmVisualizarImpressao.FormCreate(Sender: TObject);
begin
  // AplicarConfirmacaoEsc(Self);
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  Position := poScreenCenter;
  WindowState := wsMaximized;
  FPaginas := nil;
  FIndicePagina := 0;
  FZoomPercent := 100;
  FAjustarTela := True;
  paintPagina.OnPaint := paintPaginaPaint;
end;

procedure TfrmVisualizarImpressao.FormShow(Sender: TObject);
begin
  AtualizarLabelZoom;
  AtualizarTamanhoVisual;
end;

procedure TfrmVisualizarImpressao.FormDestroy(Sender: TObject);
begin
  FPaginas.Free;
end;

procedure TfrmVisualizarImpressao.Configurar(const ATitulo: string;
  APaginas: TListaPaginasImpressao; AOnImprimir: TNotifyEvent);
begin
  Caption := ATitulo;
  lblTitulo.Caption := ATitulo;
  FPaginas := APaginas;
  FOnImprimir := AOnImprimir;
  FIndicePagina := 0;
  FZoomPercent := 100;
  FAjustarTela := True;
  btnImprimir.Enabled := Assigned(FOnImprimir);
  AtualizarNavegacao;
  AtualizarLabelZoom;
  AtualizarTamanhoVisual;
end;

procedure TfrmVisualizarImpressao.AtualizarLabelZoom;
begin
  if FAjustarTela then
    lblZoom.Caption := Format('Zoom: %d%% (ajustado a tela)', [FZoomPercent])
  else
    lblZoom.Caption := Format('Zoom: %d%%', [FZoomPercent]);
end;

procedure TfrmVisualizarImpressao.AtualizarTamanhoVisual;
var
  Pagina: Vcl.Graphics.TBitmap;
  Escala: Double;
begin
  if (FPaginas = nil) or (FPaginas.Count = 0) then
    Exit;

  Pagina := FPaginas.Pagina(FIndicePagina);
  Escala := FZoomPercent / 100.0;

  if FAjustarTela then
  begin
    if (scrollVisual.ClientWidth > 40) and (scrollVisual.ClientHeight > 40) then
      Escala := Min(
        (scrollVisual.ClientWidth - 32) / Pagina.Width,
        (scrollVisual.ClientHeight - 32) / Pagina.Height) * (FZoomPercent / 100.0);
    if Escala <= 0 then
      Escala := 0.25;
  end;

  paintPagina.Width := Max(80, Round(Pagina.Width * Escala));
  paintPagina.Height := Max(80, Round(Pagina.Height * Escala));
  CentralizarPaginaVisual;
  Redesenhar;
end;

procedure TfrmVisualizarImpressao.CentralizarPaginaVisual;
const
  MARGEM = 12;
begin
  if scrollVisual.ClientWidth > paintPagina.Width + (MARGEM * 2) then
    paintPagina.Left := (scrollVisual.ClientWidth - paintPagina.Width) div 2
  else
    paintPagina.Left := MARGEM;

  if scrollVisual.ClientHeight > paintPagina.Height + (MARGEM * 2) then
    paintPagina.Top := (scrollVisual.ClientHeight - paintPagina.Height) div 2
  else
    paintPagina.Top := MARGEM;
end;

procedure TfrmVisualizarImpressao.Redesenhar;
begin
  paintPagina.Invalidate;
  Update;
end;

procedure TfrmVisualizarImpressao.FormResize(Sender: TObject);
begin
  if (FPaginas = nil) or (FPaginas.Count = 0) then
    Exit;

  if FAjustarTela then
    AtualizarTamanhoVisual
  else
    CentralizarPaginaVisual;
end;

procedure TfrmVisualizarImpressao.AtualizarNavegacao;
var
  Total: Integer;
begin
  if FPaginas = nil then
    Total := 0
  else
    Total := FPaginas.Count;

  if Total = 0 then
  begin
    lblPagina.Caption := 'Nenhuma pagina';
    btnPrimeira.Enabled := False;
    btnAnterior.Enabled := False;
    btnProxima.Enabled := False;
    btnUltima.Enabled := False;
    Exit;
  end;

  if FIndicePagina < 0 then
    FIndicePagina := 0;
  if FIndicePagina >= Total then
    FIndicePagina := Total - 1;

  lblPagina.Caption := Format('Pagina %d de %d', [FIndicePagina + 1, Total]);
  btnPrimeira.Enabled := FIndicePagina > 0;
  btnAnterior.Enabled := FIndicePagina > 0;
  btnProxima.Enabled := FIndicePagina < (Total - 1);
  btnUltima.Enabled := FIndicePagina < (Total - 1);
end;

procedure TfrmVisualizarImpressao.IrParaPagina(AIndice: Integer);
begin
  if (FPaginas = nil) or (FPaginas.Count = 0) then
    Exit;

  if AIndice < 0 then
    AIndice := 0;
  if AIndice >= FPaginas.Count then
    AIndice := FPaginas.Count - 1;

  FIndicePagina := AIndice;
  AtualizarNavegacao;
  AtualizarTamanhoVisual;
end;

procedure TfrmVisualizarImpressao.paintPaginaPaint(Sender: TObject);
var
  Pagina: Vcl.Graphics.TBitmap;
  Destino: TRect;
  ModoAnterior: Integer;
begin
  paintPagina.Canvas.Brush.Color := $00E8E8E8;
  paintPagina.Canvas.FillRect(paintPagina.ClientRect);

  if (FPaginas = nil) or (FPaginas.Count = 0) then
    Exit;

  Pagina := FPaginas.Pagina(FIndicePagina);
  Destino := Rect(0, 0, paintPagina.Width, paintPagina.Height);

  if (paintPagina.Width = Pagina.Width) and (paintPagina.Height = Pagina.Height) then
    paintPagina.Canvas.Draw(0, 0, Pagina)
  else
  begin
    ModoAnterior := SetStretchBltMode(paintPagina.Canvas.Handle, HALFTONE);
    try
      SetBrushOrgEx(paintPagina.Canvas.Handle, 0, 0, nil);
      paintPagina.Canvas.StretchDraw(Destino, Pagina);
    finally
      SetStretchBltMode(paintPagina.Canvas.Handle, ModoAnterior);
    end;
  end;

  paintPagina.Canvas.Brush.Color := clBtnShadow;
  paintPagina.Canvas.FrameRect(Destino);
end;

procedure TfrmVisualizarImpressao.btnZoomMenosClick(Sender: TObject);
begin
  FZoomPercent := FZoomPercent - ZOOM_PASSO;
  if FZoomPercent < ZOOM_MIN then
    FZoomPercent := ZOOM_MIN;
  AtualizarLabelZoom;
  AtualizarTamanhoVisual;
end;

procedure TfrmVisualizarImpressao.btnZoomMaisClick(Sender: TObject);
begin
  FZoomPercent := FZoomPercent + ZOOM_PASSO;
  if FZoomPercent > ZOOM_MAX then
    FZoomPercent := ZOOM_MAX;
  AtualizarLabelZoom;
  AtualizarTamanhoVisual;
end;

procedure TfrmVisualizarImpressao.btnZoomAjustarClick(Sender: TObject);
begin
  FAjustarTela := True;
  FZoomPercent := 100;
  AtualizarLabelZoom;
  AtualizarTamanhoVisual;
end;

procedure TfrmVisualizarImpressao.btnZoom100Click(Sender: TObject);
begin
  FAjustarTela := False;
  FZoomPercent := 100;
  AtualizarLabelZoom;
  AtualizarTamanhoVisual;
end;

procedure TfrmVisualizarImpressao.btnPrimeiraClick(Sender: TObject);
begin
  IrParaPagina(0);
end;

procedure TfrmVisualizarImpressao.btnAnteriorClick(Sender: TObject);
begin
  IrParaPagina(FIndicePagina - 1);
end;

procedure TfrmVisualizarImpressao.btnProximaClick(Sender: TObject);
begin
  IrParaPagina(FIndicePagina + 1);
end;

procedure TfrmVisualizarImpressao.btnUltimaClick(Sender: TObject);
begin
  if FPaginas <> nil then
    IrParaPagina(FPaginas.Count - 1);
end;

procedure TfrmVisualizarImpressao.btnImprimirClick(Sender: TObject);
begin
  if not Assigned(FOnImprimir) then
    Exit;

  try
    FOnImprimir(Self);
  except
    on E: Exception do
      MessageDlg('Erro ao imprimir:' + sLineBreak + sLineBreak + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfrmVisualizarImpressao.btnFecharClick(Sender: TObject);
begin
  Close;
  // ConfirmarFecharForm(Self);
end;

end.
