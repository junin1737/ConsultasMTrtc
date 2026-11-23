unit UfrmVisualizarDanfe;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.OleCtrls, SHDocVw, UConfirmarFechar;

type
  TfrmVisualizarDanfe = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    pnlRodape: TPanel;
    btnSalvarPdf: TButton;
    btnImprimir: TButton;
    btnFechar: TButton;
    webPdf: TWebBrowser;
    dlgSalvarPdf: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnFecharClick(Sender: TObject);
    procedure btnImprimirClick(Sender: TObject);
    procedure btnSalvarPdfClick(Sender: TObject);
  private
    FPdfPath: string;
    procedure CarregarPdf;
    procedure ImprimirPdfExterno;
    procedure ImprimirWebBrowser;
    procedure AtualizarBotoes;
  public
    procedure Configurar(const ATitulo, APdfPath: string);
  end;

implementation

uses
  System.IOUtils, Winapi.ShellAPI, ActiveX;

{$R *.dfm}

procedure TfrmVisualizarDanfe.FormCreate(Sender: TObject);
begin
  // AplicarConfirmacaoEsc(Self);
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  Position := poScreenCenter;
  WindowState := wsMaximized;
  FPdfPath := '';
end;

procedure TfrmVisualizarDanfe.AtualizarBotoes;
var
  PdfOk: Boolean;
begin
  PdfOk := (FPdfPath <> '') and FileExists(FPdfPath);
  btnSalvarPdf.Enabled := PdfOk;
  btnImprimir.Enabled := PdfOk;
end;

procedure TfrmVisualizarDanfe.Configurar(const ATitulo, APdfPath: string);
begin
  Caption := ATitulo;
  lblTitulo.Caption := ATitulo;
  FPdfPath := APdfPath;
  AtualizarBotoes;
end;

procedure TfrmVisualizarDanfe.FormShow(Sender: TObject);
begin
  CarregarPdf;
end;

procedure TfrmVisualizarDanfe.CarregarPdf;
begin
  if (FPdfPath = '') or (not FileExists(FPdfPath)) then
    Exit;
  webPdf.Navigate(PWideChar(ExpandFileName(FPdfPath)));
end;

procedure TfrmVisualizarDanfe.btnSalvarPdfClick(Sender: TObject);
var
  NomeSugerido: string;
begin
  if (FPdfPath = '') or (not FileExists(FPdfPath)) then
    Exit;

  NomeSugerido := ChangeFileExt(ExtractFileName(FPdfPath), '.pdf');
  if NomeSugerido = '' then
    NomeSugerido := 'DANFE.pdf';

  dlgSalvarPdf.FileName := NomeSugerido;
  if not dlgSalvarPdf.Execute then
    Exit;

  if SameText(FPdfPath, dlgSalvarPdf.FileName) then
    Exit;

  if not CopyFile(PChar(FPdfPath), PChar(dlgSalvarPdf.FileName), False) then
    raise Exception.Create('Nao foi possivel salvar o PDF em:' + sLineBreak +
      dlgSalvarPdf.FileName);
end;

procedure TfrmVisualizarDanfe.ImprimirPdfExterno;
var
  Ret: HINST;
begin
  Ret := ShellExecute(Handle, 'print', PChar(FPdfPath), nil, nil, SW_HIDE);
  if Ret <= 32 then
    raise Exception.Create('Nao foi possivel enviar o DANFE para a impressora.');
end;

procedure TfrmVisualizarDanfe.ImprimirWebBrowser;
var
  VaIn, VaOut: OleVariant;
begin
  try
    webPdf.ControlInterface.ExecWB(OLECMDID_PRINT, OLECMDEXECOPT_PROMPTUSER, VaIn, VaOut);
  except
    ImprimirPdfExterno;
  end;
end;

procedure TfrmVisualizarDanfe.btnImprimirClick(Sender: TObject);
begin
  if (FPdfPath = '') or (not FileExists(FPdfPath)) then
    Exit;
  ImprimirWebBrowser;
end;

procedure TfrmVisualizarDanfe.btnFecharClick(Sender: TObject);
begin
  Close;
  // ConfirmarFecharForm(Self);
end;

end.
