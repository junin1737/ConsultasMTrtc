unit UNfceDanfeVisualizacao;

interface

uses
  System.SysUtils;

type
  TNfceDanfeVisualizacao = class
  public
    class function ObterXmlNfce(AEmpCodigo, AVenNumero, ATerNumero,
      ANfceNumero: Integer): string;
    class function GerarPdfDanfe(const AXml, ATitulo: string): string;
    class procedure VisualizarDanfe(const AXml, ATitulo: string);
    class procedure ImprimirDanfe(const AXml, ATitulo: string);
  end;

implementation

uses
  System.IOUtils, System.Classes, Data.DB, FireDAC.Comp.Client, UdmConexao,
  Vcl.Forms, Winapi.Windows, Winapi.ShellAPI, UImpressaoUtil,
  ACBrNFe, ACBrNFCeDANFeFPDF, UNfceXmlResolver;

function CaminhoPastaDanfeNfce: string;
begin
  Result := IncludeTrailingPathDelimiter(TPath.GetTempPath) + 'ConsultasDanfeNfce' + PathDelim;
  ForceDirectories(Result);
end;

procedure NormalizarXml(var AXml: string);
begin
  AXml := Trim(AXml);
  if AXml = '' then
    Exit;
  if not SameText(Copy(AXml, 1, 5), '<?xml') then
    AXml := '<?xml version="1.0" encoding="UTF-8"?>' + sLineBreak + AXml;
end;

function SanitizarNomeArquivoPdf(const AValor: string): string;
begin
  Result := TImpressaoPagina.SanitizarNomeArquivoPdf(AValor);
end;

class function TNfceDanfeVisualizacao.ObterXmlNfce(AEmpCodigo, AVenNumero,
  ATerNumero, ANfceNumero: Integer): string;
begin
  Result := TNfceXmlResolver.ObterXmlSomenteBanco(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
end;

class function TNfceDanfeVisualizacao.GerarPdfDanfe(const AXml, ATitulo: string): string;
var
  ACBrNFe: TACBrNFe;
  DANFe: TACBrNFCeDANFeFPDF;
  Xml: string;
begin
  Xml := AXml;
  NormalizarXml(Xml);
  if Xml = '' then
    raise Exception.Create('XML da NFC-e nao encontrado para gerar o DANFE.');

  ACBrNFe := TACBrNFe.Create(Application);
  DANFe := TACBrNFCeDANFeFPDF.Create(Application);
  try
    ACBrNFe.DANFE := DANFe;
    DANFe.PathPDF := CaminhoPastaDanfeNfce;
    DANFe.MostraStatus := False;
    if ATitulo <> '' then
      DANFe.NomeDocumento := SanitizarNomeArquivoPdf(ATitulo)
    else
      DANFe.NomeDocumento := 'DANFE-NFCe';

    ACBrNFe.NotasFiscais.Clear;
    if not ACBrNFe.NotasFiscais.LoadFromString(Xml) then
      raise Exception.Create('Nao foi possivel interpretar o XML da NFC-e.');

    if (ACBrNFe.NotasFiscais.Count > 0) and
      (ACBrNFe.NotasFiscais[0].NFe.Ide.modelo <> 65) then
      raise Exception.Create('O XML informado nao e de NFC-e (modelo 65).');

    ACBrNFe.NotasFiscais.ImprimirPDF;
    Result := DANFe.ArquivoPDF;
    if (Result = '') or (not TFile.Exists(Result)) or (TFile.GetSize(Result) = 0) then
      raise Exception.Create('Nao foi possivel gerar o PDF do DANFE NFC-e.');
  finally
    DANFe.Free;
    ACBrNFe.Free;
  end;
end;

class procedure TNfceDanfeVisualizacao.VisualizarDanfe(const AXml, ATitulo: string);
var
  PdfPath: string;
begin
  PdfPath := GerarPdfDanfe(AXml, ATitulo);
  TImpressaoPagina.AbrirPdfNoVisualizadorPadrao(PdfPath);
end;

class procedure TNfceDanfeVisualizacao.ImprimirDanfe(const AXml, ATitulo: string);
var
  PdfPath: string;
begin
  PdfPath := GerarPdfDanfe(AXml, ATitulo);
  if ShellExecute(Application.Handle, 'print', PChar(PdfPath), nil, nil, SW_HIDE) <= 32 then
    raise Exception.Create('Nao foi possivel enviar o DANFE NFC-e para a impressora.');
end;

end.
