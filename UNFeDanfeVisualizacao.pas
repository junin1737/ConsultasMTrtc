unit UNFeDanfeVisualizacao;

interface

uses
  System.SysUtils;

type
  TNFeDanfeVisualizacao = class
  public
    class function ObterXmlNotaFiscal(AEmpCodigo, ANfContador: Integer): string;
    class function ObterXmlCompra(AEmpCodigo, AEntcContador: Integer): string;
    class function GerarPdfDanfe(const AXml, ATitulo: string): string;
    class procedure VisualizarDanfe(const AXml, ATitulo: string);
    class procedure ImprimirDanfe(const AXml, ATitulo: string);
  end;

implementation

uses
  System.IOUtils, System.Classes, Data.DB, FireDAC.Comp.Client, UdmConexao,
  Vcl.Forms, Winapi.Windows, Winapi.ShellAPI, UImpressaoUtil,
  ACBrNFe, ACBrNFeDANFeFPDF;

function CaminhoPastaDanfe: string;
begin
  Result := IncludeTrailingPathDelimiter(TPath.GetTempPath) + 'ConsultasDanfe' + PathDelim;
  ForceDirectories(Result);
end;

function LerCampoXml(AField: TField): string;
var
  Blob: TBlobField;
begin
  Result := '';
  if (AField = nil) or AField.IsNull then
    Exit;

  if AField is TBlobField then
  begin
    Blob := TBlobField(AField);
    if Blob.BlobSize = 0 then
      Exit;
    Result := Blob.AsString;
  end
  else
    Result := AField.AsString;

  Result := Trim(Result);
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

class function TNFeDanfeVisualizacao.ObterXmlNotaFiscal(AEmpCodigo,
  ANfContador: Integer): string;
var
  Q: TFDQuery;
begin
  Result := '';
  if not dmConexao.Conectado then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT FIRST 1 NF.NFNFEESTRUTURAXML FROM NOTAFISCALNFE NF ' +
      'WHERE NF.EMPCODIGO = :EMPCODIGO AND NF.NFCONTADOR = :NFCONTADOR';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('NFCONTADOR').AsInteger := ANfContador;
    Q.Open;
    if not Q.IsEmpty then
      Result := LerCampoXml(Q.Fields[0]);
  finally
    Q.Free;
  end;
end;

class function TNFeDanfeVisualizacao.ObterXmlCompra(AEmpCodigo,
  AEntcContador: Integer): string;
var
  Q: TFDQuery;
begin
  Result := '';
  if not dmConexao.Conectado then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT FIRST 1 E.ENTCXMLCORPO FROM ENTRADACOMPRA E ' +
      'WHERE E.EMPCODIGO = :EMPCODIGO AND E.ENTCCONTADOR = :ENTCCONTADOR';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('ENTCCONTADOR').AsInteger := AEntcContador;
    Q.Open;
    if not Q.IsEmpty then
      Result := LerCampoXml(Q.Fields[0]);
  finally
    Q.Free;
  end;
end;

class function TNFeDanfeVisualizacao.GerarPdfDanfe(const AXml, ATitulo: string): string;
var
  ACBrNFe: TACBrNFe;
  DANFe: TACBrNFeDANFeFPDF;
  Xml: string;
begin
  Xml := AXml;
  NormalizarXml(Xml);
  if Xml = '' then
    raise Exception.Create('XML da NFe nao encontrado para gerar o DANFE.');

  ACBrNFe := TACBrNFe.Create(Application);
  DANFe := TACBrNFeDANFeFPDF.Create(Application);
  try
    ACBrNFe.DANFE := DANFe;
    DANFe.PathPDF := CaminhoPastaDanfe;
    DANFe.MostraStatus := False;
    if ATitulo <> '' then
      DANFe.NomeDocumento := SanitizarNomeArquivoPdf(ATitulo)
    else
      DANFe.NomeDocumento := 'DANFE';

    ACBrNFe.NotasFiscais.Clear;
    if not ACBrNFe.NotasFiscais.LoadFromString(Xml) then
      raise Exception.Create('Nao foi possivel interpretar o XML da NFe.');

    ACBrNFe.NotasFiscais.ImprimirPDF;
    Result := DANFe.ArquivoPDF;
    if (Result = '') or (not TFile.Exists(Result)) or (TFile.GetSize(Result) = 0) then
      raise Exception.Create('Nao foi possivel gerar o PDF do DANFE.');
  finally
    DANFe.Free;
    ACBrNFe.Free;
  end;
end;

procedure AbrirPdfNoVisualizadorPadrao(const APdfPath: string);
begin
  TImpressaoPagina.AbrirPdfNoVisualizadorPadrao(APdfPath);
end;

class procedure TNFeDanfeVisualizacao.VisualizarDanfe(const AXml, ATitulo: string);
var
  PdfPath: string;
begin
  PdfPath := GerarPdfDanfe(AXml, ATitulo);
  AbrirPdfNoVisualizadorPadrao(PdfPath);
end;

class procedure TNFeDanfeVisualizacao.ImprimirDanfe(const AXml, ATitulo: string);
var
  PdfPath: string;
begin
  PdfPath := GerarPdfDanfe(AXml, ATitulo);
  if ShellExecute(Application.Handle, 'print', PChar(PdfPath), nil, nil, SW_HIDE) <= 32 then
    raise Exception.Create('Nao foi possivel enviar o DANFE para a impressora.');
end;

end.
