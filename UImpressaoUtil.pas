unit UImpressaoUtil;

interface

uses
  System.SysUtils, System.Types, System.Classes, Vcl.Graphics, Data.DB,
  FireDAC.Comp.Client, UFormatacaoMoeda;

const
  IMPRESSAO_PREVIEW_LARGURA = 794;
  IMPRESSAO_PREVIEW_ALTURA = 1123;
  IMPRESSAO_MEIA_A4_ALTURA = 562;

type
  TListaPaginasImpressao = class(TObject)
  private
    FItens: TList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(APagina: Vcl.Graphics.TBitmap);
    function Count: Integer;
    function Pagina(AIndice: Integer): Vcl.Graphics.TBitmap;
  end;

  TCabecalhoImpressao = record
    TituloDocumento: string;
    Numero: string;
    Emissao: string;
    Cliente: string;
    Vencimento: string;
    ValorTotal: string;
  end;

  TImpressaoPagina = class
  private
    FCanvas: TCanvas;
    FPageWidth: Integer;
    FPageHeight: Integer;
    FY: Integer;
    FMargemEsq: Integer;
    FMargemDir: Integer;
    FPageBottom: Integer;
    FColItem: Integer;
    FColDesc: Integer;
    FColQtde: Integer;
    FColUnit: Integer;
    FColTotal: Integer;
    FModoPreview: Boolean;
    FPaginasPreview: TListaPaginasImpressao;
    procedure QuebrarPaginaImpressora;
    procedure QuebrarPaginaPreview;
    procedure NovaPagina;
    procedure AvancarAposTexto(const ATexto: string; AExtra: Integer = 6);
    procedure AvancarLinhas(ALinhas: Integer);
    procedure DefinirFonte(ATamanho: Integer; ANegrito: Boolean);
    procedure Texto(const AX, AY: Integer; const ATexto: string);
    procedure TextoDireita(AXDireita, AY: Integer; const ATexto: string);
    procedure LinhaCampo(const ALabel, AValor: string);
    procedure LinhaHorizontal;
    procedure CabecalhoTabelaItens;
    procedure LinhaItem(const AOrdem, ADescricao: string; AQtde: Double;
      AUnitario, ATotal: Double);
    procedure Secao(const ATitulo: string);
    procedure ItensQuery(AQuery: TFDQuery; const AMensagemVazio, AOrdem, ADescricao,
      AQtde, AUnitario, ATotal: string);
    procedure TextoQuebrado(const AX: Integer; const ATexto: string);
    procedure ConfigurarLayout(APageWidth, APageHeight: Integer);
  public
    class procedure PrepararBitmapPagina(ABitmap: Vcl.Graphics.TBitmap;
      ALargura, AAltura: Integer); overload;
    class procedure PrepararBitmapPagina(ABitmap: Vcl.Graphics.TBitmap); overload;
    class procedure FinalizarPaginaBitmap(ABitmap: Vcl.Graphics.TBitmap);
    constructor Create(ACanvas: TCanvas; APageWidth, APageHeight: Integer);
    class function GerarPaginasPreview(const ACab: TCabecalhoImpressao;
      AQueryProdutos, AQueryServicos: TFDQuery; const APrefixoItem: string): TListaPaginasImpressao;
    class procedure ImprimirPaginasPreview(APaginas: TListaPaginasImpressao);
    class function CaminhoPastaPdfImpressao: string;
    class function SanitizarNomeArquivoPdf(const AValor: string): string;
    class function GerarPdfDePaginas(APaginas: TListaPaginasImpressao;
      const ANomeBase: string): string;
    class procedure AbrirPdfNoVisualizadorPadrao(const APdfPath: string);
    class procedure GerarPdfEAbrir(APaginas: TListaPaginasImpressao; const ANomeBase: string);
    procedure Imprimir(const ACab: TCabecalhoImpressao; AQueryProdutos,
      AQueryServicos: TFDQuery; const APrefixoItem: string);
  end;

implementation

uses
  System.Math, System.IOUtils, System.Generics.Collections,
  Vcl.Imaging.jpeg, Vcl.Printers, Winapi.Windows, Winapi.ShellAPI;

const
  PDF_PAGE_WIDTH_PT = 595;

function PdfAlturaPaginaPt(AAlturaBmp, ALarguraBmp: Integer): Integer;
begin
  if ALarguraBmp <= 0 then
    Exit(Round(PDF_PAGE_WIDTH_PT * IMPRESSAO_PREVIEW_ALTURA / IMPRESSAO_PREVIEW_LARGURA));
  Result := Round(AAlturaBmp * PDF_PAGE_WIDTH_PT / ALarguraBmp);
  if Result <= 0 then
    Result := Round(PDF_PAGE_WIDTH_PT * IMPRESSAO_PREVIEW_ALTURA / IMPRESSAO_PREVIEW_LARGURA);
end;

procedure EscreverAnsi(AStream: TStream; const AText: AnsiString);
begin
  if AText <> '' then
    AStream.WriteBuffer(AText[1], Length(AText));
end;

function MinDouble(const A, B: Double): Double;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

class function TImpressaoPagina.CaminhoPastaPdfImpressao: string;
begin
  Result := IncludeTrailingPathDelimiter(TPath.GetTempPath) + 'ConsultasImpressao' + PathDelim;
  ForceDirectories(Result);
end;

class function TImpressaoPagina.SanitizarNomeArquivoPdf(const AValor: string): string;
const
  CARACTERES_INVALIDOS = ['\', '/', ':', '*', '?', '"', '<', '>', '|'];
var
  I: Integer;
begin
  Result := Trim(AValor);
  for I := 1 to Length(Result) do
    if CharInSet(Result[I], CARACTERES_INVALIDOS) then
      Result[I] := '_';
  Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
  if Result = '' then
    Result := 'Documento';
  if Length(Result) > 120 then
    SetLength(Result, 120);
end;

function CopiarBitmapRaster(ABmp: Vcl.Graphics.TBitmap): Vcl.Graphics.TBitmap;
begin
  if (ABmp.Height > 0) and (ABmp.Width > 0) then
    PByte(ABmp.ScanLine[ABmp.Height - 1])^ := PByte(ABmp.ScanLine[ABmp.Height - 1])^;

  Result := Vcl.Graphics.TBitmap.Create;
  Result.HandleType := bmDIB;
  Result.SetSize(ABmp.Width, ABmp.Height);
  Result.PixelFormat := pf24bit;
  Result.Canvas.Brush.Color := clWhite;
  Result.Canvas.FillRect(Rect(0, 0, Result.Width, Result.Height));
  Result.Canvas.Draw(0, 0, ABmp);
end;

function BitmapParaJpegBytes(ABmp: Vcl.Graphics.TBitmap): TBytes;
var
  Raster: Vcl.Graphics.TBitmap;
  Jpeg: TJPEGImage;
  Mem: TMemoryStream;
begin
  if (ABmp.Width <= 0) or (ABmp.Height <= 0) then
    raise Exception.Create('Pagina de impressao com tamanho invalido.');

  Raster := CopiarBitmapRaster(ABmp);
  Jpeg := TJPEGImage.Create;
  Mem := TMemoryStream.Create;
  try
    Jpeg.CompressionQuality := 92;
    Jpeg.ProgressiveEncoding := False;
    Jpeg.Assign(Raster);
    Jpeg.SaveToStream(Mem);
    if Mem.Size = 0 then
      raise Exception.Create('Nao foi possivel converter a pagina para JPEG.');

    SetLength(Result, Mem.Size);
    Mem.Position := 0;
    Mem.ReadBuffer(Result[0], Mem.Size);
  finally
    Mem.Free;
    Jpeg.Free;
    Raster.Free;
  end;
end;

function BitmapTemConteudo(ABmp: Vcl.Graphics.TBitmap): Boolean;
var
  Raster: Vcl.Graphics.TBitmap;
  Y, X, W, H, BytesPerPixel, Offset: Integer;
  SrcLine: PByte;
begin
  Result := False;
  W := ABmp.Width;
  H := ABmp.Height;
  if (W <= 0) or (H <= 0) then
    Exit;

  Raster := CopiarBitmapRaster(ABmp);
  try
    BytesPerPixel := 3;
    for Y := 0 to H - 1 do
    begin
      SrcLine := PByte(Raster.ScanLine[Y]);
      for X := 0 to W - 1 do
      begin
        Offset := X * BytesPerPixel;
        if (SrcLine[Offset] < $F0) or (SrcLine[Offset + 1] < $F0) or (SrcLine[Offset + 2] < $F0) then
          Exit(True);
      end;
    end;
  finally
    Raster.Free;
  end;
end;

class function TImpressaoPagina.GerarPdfDePaginas(APaginas: TListaPaginasImpressao;
  const ANomeBase: string): string;
var
  PdfStream: TFileStream;
  ObjOffsets: TArray<Int64>;
  Imagens: array of TBytes;
  Kids, Catalog, PagesObj, PageObj, ContentsObj: AnsiString;
  ContentData: AnsiString;
  I, PageObjNum, ImageObjNum, ContentObjNum, StartXRef, PdfH, MaxObjNum: Integer;
  Bmp: Vcl.Graphics.TBitmap;
  NomeArquivo: string;

  procedure MarcarOffsetObjeto(AObjNum: Integer);
  begin
    if (AObjNum < 1) or (AObjNum > MaxObjNum) then
      raise Exception.Create('Numero de objeto PDF invalido: ' + IntToStr(AObjNum));
    ObjOffsets[AObjNum - 1] := PdfStream.Position;
  end;

  procedure RegistrarObjetoNumerado(AObjNum: Integer; const AConteudo: AnsiString);
  begin
    MarcarOffsetObjeto(AObjNum);
    EscreverAnsi(PdfStream, AnsiString(IntToStr(AObjNum) + ' 0 obj' + #10));
    EscreverAnsi(PdfStream, AConteudo);
    EscreverAnsi(PdfStream, #10'endobj'#10);
  end;

begin
  if (APaginas = nil) or (APaginas.Count = 0) then
    raise Exception.Create('Nenhuma pagina para gerar o PDF.');

  NomeArquivo := SanitizarNomeArquivoPdf(ANomeBase) + '.pdf';
  Result := CaminhoPastaPdfImpressao + NomeArquivo;

  MaxObjNum := 2 + (APaginas.Count * 3);
  SetLength(ObjOffsets, MaxObjNum);
  for I := 0 to MaxObjNum - 1 do
    ObjOffsets[I] := 0;

  SetLength(Imagens, APaginas.Count);
  for I := 0 to APaginas.Count - 1 do
  begin
    Bmp := APaginas.Pagina(I);
    FinalizarPaginaBitmap(Bmp);
    if not BitmapTemConteudo(Bmp) then
      raise Exception.Create('A pagina ' + IntToStr(I + 1) + ' da impressao ficou em branco.');
    Imagens[I] := BitmapParaJpegBytes(Bmp);
  end;

  PdfStream := TFileStream.Create(Result, fmCreate);
  try
    EscreverAnsi(PdfStream, '%PDF-1.4'#10'%'#$E2#$E3#$CF#$D3#10);

    Kids := '';
    for I := 0 to APaginas.Count - 1 do
    begin
      PageObjNum := 3 + (I * 3);
      if Kids <> '' then
        Kids := Kids + ' ';
      Kids := Kids + AnsiString(IntToStr(PageObjNum) + ' 0 R');
    end;

    Catalog := '<< /Type /Catalog /Pages 2 0 R >>';
    RegistrarObjetoNumerado(1, Catalog);

    PagesObj := '<< /Type /Pages /Count ' + AnsiString(IntToStr(APaginas.Count)) +
      ' /Kids [' + Kids + '] >>';
    RegistrarObjetoNumerado(2, PagesObj);

    for I := 0 to APaginas.Count - 1 do
    begin
      Bmp := APaginas.Pagina(I);
      PageObjNum := 3 + (I * 3);
      ImageObjNum := PageObjNum + 1;
      ContentObjNum := PageObjNum + 2;
      PdfH := PdfAlturaPaginaPt(Bmp.Height, Bmp.Width);

      MarcarOffsetObjeto(ImageObjNum);
      EscreverAnsi(PdfStream, AnsiString(IntToStr(ImageObjNum) + ' 0 obj' + #10));
      EscreverAnsi(PdfStream,
        '<< /Type /XObject /Subtype /Image /Width ' + AnsiString(IntToStr(Bmp.Width)) +
        ' /Height ' + AnsiString(IntToStr(Bmp.Height)) +
        ' /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ' +
        AnsiString(IntToStr(Length(Imagens[I]))) + ' >>' + #10'stream' + #10);
      if Length(Imagens[I]) > 0 then
        PdfStream.WriteBuffer(Imagens[I][0], Length(Imagens[I]));
      EscreverAnsi(PdfStream, #10'endstream'#10'endobj'#10);

      ContentData := 'q ' + AnsiString(IntToStr(PDF_PAGE_WIDTH_PT)) + ' 0 0 ' +
        AnsiString(IntToStr(PdfH)) + ' 0 0 cm /Im1 Do Q';
      ContentsObj := '<< /Length ' + AnsiString(IntToStr(Length(ContentData))) + ' >>' +
        #10'stream'#10 + ContentData + #10'endstream';
      RegistrarObjetoNumerado(ContentObjNum, ContentsObj);

      PageObj := '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ' +
        AnsiString(IntToStr(PDF_PAGE_WIDTH_PT)) + ' ' +
        AnsiString(IntToStr(PdfH)) +
        '] /Contents ' + AnsiString(IntToStr(ContentObjNum)) +
        ' 0 R /Resources << /XObject << /Im1 ' +
        AnsiString(IntToStr(ImageObjNum)) + ' 0 R >> >> >>';
      RegistrarObjetoNumerado(PageObjNum, PageObj);
    end;

    StartXRef := PdfStream.Position;
    EscreverAnsi(PdfStream, 'xref'#10'0 ' + AnsiString(IntToStr(MaxObjNum + 1)) + #10);
    EscreverAnsi(PdfStream, '0000000000 65535 f '#10);
    for I := 1 to MaxObjNum do
    begin
      if ObjOffsets[I - 1] <= 0 then
        raise Exception.Create('Offset PDF ausente para o objeto ' + IntToStr(I) + '.');
      EscreverAnsi(PdfStream, AnsiString(Format('%.10d 00000 n ', [ObjOffsets[I - 1]])) + #10);
    end;
    EscreverAnsi(PdfStream, 'trailer'#10'<< /Size ' +
      AnsiString(IntToStr(MaxObjNum + 1)) + ' /Root 1 0 R >>'#10'startxref'#10 +
      AnsiString(IntToStr(StartXRef)) + #10'%%EOF');
  finally
    PdfStream.Free;
  end;

  if (Result = '') or (not TFile.Exists(Result)) or (TFile.GetSize(Result) = 0) then
    raise Exception.Create('Nao foi possivel gerar o PDF.');
end;

class procedure TImpressaoPagina.AbrirPdfNoVisualizadorPadrao(const APdfPath: string);
var
  Ret: HINST;
begin
  if (APdfPath = '') or (not TFile.Exists(APdfPath)) then
    raise Exception.Create('Arquivo PDF nao encontrado.');

  Ret := ShellExecute(0, 'open', PChar(APdfPath), nil, nil, SW_SHOWDEFAULT);
  if Ret <= 32 then
    raise Exception.Create('Nao foi possivel abrir o PDF no visualizador padrao do Windows.');
end;

class procedure TImpressaoPagina.GerarPdfEAbrir(APaginas: TListaPaginasImpressao;
  const ANomeBase: string);
var
  PdfPath: string;
begin
  PdfPath := GerarPdfDePaginas(APaginas, ANomeBase);
  AbrirPdfNoVisualizadorPadrao(PdfPath);
end;

class procedure TImpressaoPagina.ImprimirPaginasPreview(APaginas: TListaPaginasImpressao);
var
  I: Integer;
  Bmp: Vcl.Graphics.TBitmap;
  Margem, LarguraDest, AlturaDest, X, Y: Integer;
  Escala, AreaW, AreaH: Double;
  Destino: TRect;
begin
  if (APaginas = nil) or (APaginas.Count = 0) then
    raise Exception.Create('Nenhuma pagina para impressao.');

  Printer.BeginDoc;
  try
    for I := 0 to APaginas.Count - 1 do
    begin
      if I > 0 then
        Printer.NewPage;

      Bmp := APaginas.Pagina(I);
      Margem := Max(10, Round(Printer.PageWidth * 0.02));
      AreaW := Printer.PageWidth - (2 * Margem);
      AreaH := Printer.PageHeight - (2 * Margem);
      Escala := MinDouble(AreaW / Bmp.Width, AreaH / Bmp.Height);
      if Escala <= 0 then
        Escala := 1;

      LarguraDest := Round(Bmp.Width * Escala);
      AlturaDest := Round(Bmp.Height * Escala);
      X := Margem + (Round(AreaW) - LarguraDest) div 2;
      Y := Margem + (Round(AreaH) - AlturaDest) div 2;
      Destino := Rect(X, Y, X + LarguraDest, Y + AlturaDest);

      Printer.Canvas.StretchDraw(Destino, Bmp);
    end;
  finally
    Printer.EndDoc;
  end;
end;

constructor TListaPaginasImpressao.Create;
begin
  inherited Create;
  FItens := TList.Create;
end;

destructor TListaPaginasImpressao.Destroy;
var
  I: Integer;
begin
  for I := 0 to FItens.Count - 1 do
    Vcl.Graphics.TBitmap(FItens[I]).Free;
  FItens.Free;
  inherited Destroy;
end;

procedure TListaPaginasImpressao.Add(APagina: Vcl.Graphics.TBitmap);
begin
  FItens.Add(APagina);
end;

function TListaPaginasImpressao.Count: Integer;
begin
  Result := FItens.Count;
end;

function TListaPaginasImpressao.Pagina(AIndice: Integer): Vcl.Graphics.TBitmap;
begin
  Result := Vcl.Graphics.TBitmap(FItens[AIndice]);
end;

class procedure TImpressaoPagina.PrepararBitmapPagina(ABitmap: Vcl.Graphics.TBitmap;
  ALargura, AAltura: Integer);
begin
  if ALargura <= 0 then
    ALargura := IMPRESSAO_PREVIEW_LARGURA;
  if AAltura <= 0 then
    AAltura := IMPRESSAO_PREVIEW_ALTURA;

  ABitmap.HandleType := bmDIB;
  ABitmap.PixelFormat := pf32bit;
  ABitmap.AlphaFormat := afIgnored;
  ABitmap.SetSize(ALargura, AAltura);
  with ABitmap.Canvas do
  begin
    SetBkMode(Handle, TRANSPARENT);
    Brush.Color := clWhite;
    FillRect(Rect(0, 0, ABitmap.Width, ABitmap.Height));
    Pen.Color := clBlack;
    Font.Name := 'Arial';
    Font.Charset := DEFAULT_CHARSET;
    Font.Quality := fqNonAntialiased;
    Font.Size := 10;
    Font.Color := clBlack;
    Font.Style := [];
  end;
end;

class procedure TImpressaoPagina.FinalizarPaginaBitmap(ABitmap: Vcl.Graphics.TBitmap);
var
  Raster: Vcl.Graphics.TBitmap;
begin
  Raster := CopiarBitmapRaster(ABitmap);
  try
    ABitmap.HandleType := bmDIB;
    ABitmap.PixelFormat := pf32bit;
    ABitmap.AlphaFormat := afIgnored;
    ABitmap.SetSize(Raster.Width, Raster.Height);
    ABitmap.Canvas.Draw(0, 0, Raster);
  finally
    Raster.Free;
  end;
end;

class procedure TImpressaoPagina.PrepararBitmapPagina(ABitmap: Vcl.Graphics.TBitmap);
begin
  PrepararBitmapPagina(ABitmap, IMPRESSAO_PREVIEW_LARGURA, IMPRESSAO_PREVIEW_ALTURA);
end;

constructor TImpressaoPagina.Create(ACanvas: TCanvas; APageWidth, APageHeight: Integer);
begin
  FCanvas := ACanvas;
  FModoPreview := False;
  FPaginasPreview := nil;
  ConfigurarLayout(APageWidth, APageHeight);
  DefinirFonte(10, False);
end;

procedure TImpressaoPagina.ConfigurarLayout(APageWidth, APageHeight: Integer);
var
  LarguraUtil: Integer;
begin
  FPageWidth := APageWidth;
  FPageHeight := APageHeight;
  if FPageWidth < 200 then
    FPageWidth := IMPRESSAO_PREVIEW_LARGURA;
  if FPageHeight < 200 then
    FPageHeight := IMPRESSAO_PREVIEW_ALTURA;

  FMargemEsq := Round(FPageWidth * 0.06);
  FMargemDir := Round(FPageWidth * 0.94);
  FPageBottom := Round(FPageHeight * 0.92);
  FY := Round(FPageHeight * 0.05);

  LarguraUtil := FMargemDir - FMargemEsq;
  FColItem := FMargemEsq;
  FColDesc := FMargemEsq + Round(LarguraUtil * 0.10);
  FColQtde := FMargemDir - Round(LarguraUtil * 0.34);
  FColUnit := FMargemDir - Round(LarguraUtil * 0.20);
  FColTotal := FMargemDir;
end;

class function TImpressaoPagina.GerarPaginasPreview(const ACab: TCabecalhoImpressao;
  AQueryProdutos, AQueryServicos: TFDQuery; const APrefixoItem: string): TListaPaginasImpressao;
var
  Pagina: TImpressaoPagina;
  Bitmap: Vcl.Graphics.TBitmap;
begin
  Result := TListaPaginasImpressao.Create;
  Bitmap := Vcl.Graphics.TBitmap.Create;
  PrepararBitmapPagina(Bitmap);
  Result.Add(Bitmap);

  Pagina := TImpressaoPagina.Create(Bitmap.Canvas, IMPRESSAO_PREVIEW_LARGURA,
    IMPRESSAO_PREVIEW_ALTURA);
  try
    Pagina.FModoPreview := True;
    Pagina.FPaginasPreview := Result;
    if AQueryProdutos.Active then
      AQueryProdutos.First;
    if AQueryServicos.Active then
      AQueryServicos.First;
    Pagina.Imprimir(ACab, AQueryProdutos, AQueryServicos, APrefixoItem);
    Pagina.FPaginasPreview := nil;
  finally
    Pagina.Free;
  end;
end;

procedure TImpressaoPagina.QuebrarPaginaImpressora;
begin
  Printer.NewPage;
  FY := Round(FPageHeight * 0.05);
  DefinirFonte(10, False);
end;

procedure TImpressaoPagina.QuebrarPaginaPreview;
var
  Bitmap: Vcl.Graphics.TBitmap;
begin
  Bitmap := Vcl.Graphics.TBitmap.Create;
  PrepararBitmapPagina(Bitmap);
  FPaginasPreview.Add(Bitmap);
  FCanvas := Bitmap.Canvas;
  FY := Round(FPageHeight * 0.05);
  DefinirFonte(10, False);
end;

procedure TImpressaoPagina.NovaPagina;
begin
  if FModoPreview then
    QuebrarPaginaPreview
  else
    QuebrarPaginaImpressora;
end;

procedure TImpressaoPagina.DefinirFonte(ATamanho: Integer; ANegrito: Boolean);
begin
  FCanvas.Font.Name := 'Arial';
  FCanvas.Font.Charset := DEFAULT_CHARSET;
  FCanvas.Font.Quality := fqNonAntialiased;
  FCanvas.Font.Size := ATamanho;
  if ANegrito then
    FCanvas.Font.Style := [fsBold]
  else
    FCanvas.Font.Style := [];
end;

procedure TImpressaoPagina.AvancarAposTexto(const ATexto: string; AExtra: Integer);
begin
  Inc(FY, FCanvas.TextHeight(ATexto) + AExtra);
  if FY > FPageBottom then
    NovaPagina;
end;

procedure TImpressaoPagina.AvancarLinhas(ALinhas: Integer);
var
  H: Integer;
begin
  H := FCanvas.TextHeight('Ag');
  Inc(FY, (H + 4) * ALinhas);
  if FY > FPageBottom then
    NovaPagina;
end;

procedure TImpressaoPagina.Texto(const AX, AY: Integer; const ATexto: string);
begin
  FCanvas.TextOut(AX, AY, ATexto);
end;

procedure TImpressaoPagina.TextoDireita(AXDireita, AY: Integer; const ATexto: string);
begin
  FCanvas.TextOut(AXDireita - FCanvas.TextWidth(ATexto), AY, ATexto);
end;

procedure TImpressaoPagina.TextoQuebrado(const AX: Integer; const ATexto: string);
var
  R: TRect;
  H: Integer;
  S: string;
begin
  S := ATexto;
  R := Rect(AX, FY, FMargemDir, FY + 400);
  H := DrawText(FCanvas.Handle, PChar(S), Length(S), R,
    DT_LEFT or DT_WORDBREAK or DT_CALCRECT or DT_NOPREFIX);
  R.Bottom := FY + H;
  DrawText(FCanvas.Handle, PChar(S), Length(S), R,
    DT_LEFT or DT_WORDBREAK or DT_NOPREFIX);
  Inc(FY, H + 8);
  if FY > FPageBottom then
    NovaPagina;
end;

procedure TImpressaoPagina.LinhaCampo(const ALabel, AValor: string);
var
  Linha: string;
begin
  DefinirFonte(10, False);
  Linha := ALabel + AValor;
  Texto(FMargemEsq, FY, Linha);
  AvancarAposTexto(Linha);
end;

procedure TImpressaoPagina.LinhaHorizontal;
begin
  FCanvas.Pen.Color := clSilver;
  FCanvas.MoveTo(FMargemEsq, FY + 4);
  FCanvas.LineTo(FMargemDir, FY + 4);
  AvancarLinhas(2);
end;

procedure TImpressaoPagina.Secao(const ATitulo: string);
begin
  AvancarLinhas(1);
  DefinirFonte(11, True);
  Texto(FMargemEsq, FY, ATitulo);
  AvancarAposTexto(ATitulo);
end;

procedure TImpressaoPagina.CabecalhoTabelaItens;
begin
  DefinirFonte(9, True);
  Texto(FColItem, FY, 'Item');
  Texto(FColDesc, FY, 'Descricao');
  TextoDireita(FColQtde, FY, 'Qtde');
  TextoDireita(FColUnit, FY, 'Unitario');
  TextoDireita(FColTotal, FY, 'Total');
  AvancarAposTexto('Total');
  LinhaHorizontal;
end;

procedure TImpressaoPagina.LinhaItem(const AOrdem, ADescricao: string; AQtde: Double;
  AUnitario, ATotal: Double);
var
  Descricao: string;
  Linha: string;
begin
  DefinirFonte(9, False);
  Descricao := ADescricao;
  if Length(Descricao) > 70 then
    Descricao := Copy(Descricao, 1, 70) + '...';

  Texto(FColItem, FY, AOrdem);
  Texto(FColDesc, FY, Descricao);
  Linha := FormatarQuantidade(AQtde);
  TextoDireita(FColQtde, FY, Linha);
  Linha := FormatarMoedaBRL(AUnitario);
  TextoDireita(FColUnit, FY, Linha);
  Linha := FormatarMoedaBRL(ATotal);
  TextoDireita(FColTotal, FY, Linha);
  AvancarAposTexto(Descricao);
end;

procedure TImpressaoPagina.ItensQuery(AQuery: TFDQuery; const AMensagemVazio,
  AOrdem, ADescricao, AQtde, AUnitario, ATotal: string);
begin
  if AQuery.IsEmpty then
  begin
    DefinirFonte(9, False);
    Texto(FMargemEsq + 12, FY, AMensagemVazio);
    AvancarAposTexto(AMensagemVazio);
    Exit;
  end;

  CabecalhoTabelaItens;
  while not AQuery.Eof do
  begin
    LinhaItem(
      AQuery.FieldByName(AOrdem).AsString,
      AQuery.FieldByName(ADescricao).AsString,
      AQuery.FieldByName(AQtde).AsFloat,
      AQuery.FieldByName(AUnitario).AsFloat,
      AQuery.FieldByName(ATotal).AsFloat);
    AQuery.Next;
  end;
  AvancarLinhas(1);
end;

procedure TImpressaoPagina.Imprimir(const ACab: TCabecalhoImpressao;
  AQueryProdutos, AQueryServicos: TFDQuery; const APrefixoItem: string);
begin
  DefinirFonte(14, True);
  Texto(FMargemEsq, FY, ACab.TituloDocumento);
  AvancarAposTexto(ACab.TituloDocumento, 12);

  LinhaCampo('Numero: ', ACab.Numero);
  LinhaCampo('Emissao: ', ACab.Emissao);
  if Trim(ACab.Cliente) <> '' then
    TextoQuebrado(FMargemEsq, 'Cliente: ' + ACab.Cliente)
  else
    LinhaCampo('Cliente: ', '');
  LinhaCampo('Vencimento: ', ACab.Vencimento);

  DefinirFonte(11, True);
  Texto(FMargemEsq, FY, 'Valor total: ' + ACab.ValorTotal);
  AvancarAposTexto('Valor total: ' + ACab.ValorTotal, 10);
  LinhaHorizontal;

  Secao('PRODUTOS');
  ItensQuery(AQueryProdutos, '(nenhum produto)',
    APrefixoItem + 'ITEMORDEM', 'PRODDESCRICAO',
    APrefixoItem + 'ITEMQTDE', APrefixoItem + 'ITEMUNITARIO',
    APrefixoItem + 'ITEMTOTALLIQUIDO');

  Secao('SERVICOS');
  ItensQuery(AQueryServicos, '(nenhum servico)',
    APrefixoItem + 'ITEMSERVORDEM', 'SERVDESCRICAO',
    APrefixoItem + 'ITEMSERVQTDE', APrefixoItem + 'ITEMSERVUNITARIO',
    APrefixoItem + 'ITEMSERVTOTALLIQUIDO');
end;

end.
