unit UNfceCupomImpressao;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Types,
  Vcl.Graphics, UImpressaoUtil, UMapaNfce, UMapaNotaFiscal;

type
  TNfceCupomItem = record
    Descricao: string;
    Qtde: Double;
    Unitario: Double;
    Total: Double;
  end;

  TNfceCupomDados = class
  public
    EmpresaNome: string;
    EmpresaCnpj: string;
    EmpresaEndereco: string;
    EmpresaTelefone: string;
    NumeroNfce: string;
    NumeroCupom: string;
    Emissao: string;
    Transmissao: string;
    Cliente: string;
    Chave: string;
    Protocolo: string;
    Situacao: string;
    Observacao: string;
    Total: Double;
    Itens: TList<TNfceCupomItem>;
    constructor Create;
    destructor Destroy; override;
  end;

  TNfceCupomImpressao = class
  public
    class function CarregarDados(AEmpCodigo, AVenNumero, ATerNumero,
      ANfceNumero: Integer): TNfceCupomDados;
    class procedure Visualizar(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero: Integer);
    class procedure ImprimirFisico(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero: Integer);
  end;

implementation

uses
  Winapi.Windows, System.Math, System.StrUtils, Data.DB, FireDAC.Comp.Client,
  UdmConexao, UFormatacaoMoeda, Vcl.Printers, Vcl.Dialogs;

const
  NFCe_CUPOM_LARGURA = 302;
  NFCe_CUPOM_ALTURA_INICIAL = 1800;

type
  TRenderNfceCupom = class
  private
    FCanvas: TCanvas;
    FPageWidth: Integer;
    FPageHeight: Integer;
    FMargemEsq: Integer;
    FMargemDir: Integer;
    FY: Integer;
    FBmp: Vcl.Graphics.TBitmap;
    procedure DefinirFonte(ATamanho: Integer; ANegrito: Boolean);
    function AlturaLinha: Integer;
    procedure Avancar(APixels: Integer);
    procedure LinhaSeparadora;
    procedure Texto(const AX, AY: Integer; const ATexto: string);
    procedure TextoCentro(AY: Integer; const ATexto: string);
    procedure TextoDireita(AXDireita, AY: Integer; const ATexto: string);
    procedure TextoQuebrado(const ATexto: string; AIndent: Integer);
    procedure Renderizar(const ADados: TNfceCupomDados);
    function FinalizarBitmap: Vcl.Graphics.TBitmap;
  public
    constructor Create;
    destructor Destroy; override;
    class function GerarPaginas(const ADados: TNfceCupomDados): TListaPaginasImpressao;
  end;

function CampoStr(AQuery: TFDQuery; const ANome: string): string;
var
  F: TField;
begin
  Result := '';
  F := AQuery.FindField(ANome);
  if (F = nil) or F.IsNull then
    Exit;
  Result := Trim(F.AsString);
end;

function CampoFloat(AQuery: TFDQuery; const ANome: string): Double;
var
  F: TField;
begin
  Result := 0;
  F := AQuery.FindField(ANome);
  if (F = nil) or F.IsNull then
    Exit;
  Result := F.AsFloat;
end;

function ValorPorCampos(AQuery: TFDQuery; const ANomes: array of string): string;
var
  Nome: string;
begin
  Result := '';
  for Nome in ANomes do
  begin
    Result := CampoStr(AQuery, Nome);
    if Result <> '' then
      Exit;
  end;
end;

function TextoSituacaoNfce(const ASituacaoDoc: string): string;
var
  Cod: string;
begin
  Cod := Trim(ASituacaoDoc);
  if (Cod = '04') or (Cod = '05') then
    Exit('INUTILIZADA');
  if Cod = '02' then
    Exit('CANCELADA');
  if Cod = '00' then
    Exit('AUTORIZADA');
  if Cod = '' then
    Exit('AUTORIZADA');
  Result := UpperCase(DescricaoSituacaoNotaFiscalDoc(Cod));
end;

function FormatarChaveCupom(const AChave: string): string;
var
  S: string;
  I: Integer;
begin
  S := Trim(AChave);
  Result := '';
  for I := 1 to Length(S) do
  begin
    if (I > 1) and ((I - 1) mod 4 = 0) then
      Result := Result + ' ';
    Result := Result + S[I];
  end;
end;

constructor TNfceCupomDados.Create;
begin
  inherited Create;
  Itens := TList<TNfceCupomItem>.Create;
end;

destructor TNfceCupomDados.Destroy;
begin
  Itens.Free;
  inherited Destroy;
end;

class function TNfceCupomImpressao.CarregarDados(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer): TNfceCupomDados;
var
  Q, QEmp, QProd: TFDQuery;
  Item: TNfceCupomItem;
begin
  Result := TNfceCupomDados.Create;
  if not dmConexao.Conectado then
    Exit;

  Q := TFDQuery.Create(nil);
  QEmp := TFDQuery.Create(nil);
  QProd := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT N.VENRNFCENUMEROFISCAL, N.VENRNFCECHAVE, N.VENRNFCEPROTOCOLO, ' +
      'N.VENRNFCESITUACAODOC, N.VENRNFCEADICIONAIS, N.VENRNFCEDTTRANSMISSAO, ' +
      'V.VENNUMEROCUPOM, V.VENDTEMISSAO, V.VENVALORLIQUIDO, V.USUCODIGO, ' +
      TMapaNfce.MontarSelectNomeClienteLista + ' ' +
      'FROM VENDARAPIDANFCE N ' +
      'JOIN VENDARAPIDA V ON V.EMPCODIGO = N.EMPCODIGO AND V.VENNUMERO = N.VENNUMERO ' +
      'AND V.TERNUMERO = N.TERNUMERO ' +
      'LEFT JOIN VENDARAPIDACLIENTE VC ON VC.EMPCODIGO = V.EMPCODIGO ' +
      'AND VC.VENNUMERO = V.VENNUMERO AND VC.TERNUMERO = V.TERNUMERO ' +
      'LEFT JOIN CLIENTE C ON C.EMPCODIGO = VC.EMPCODIGO AND C.CLICODIGO = VC.CLICODIGO ' +
      'LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO ' +
      'WHERE N.EMPCODIGO = :EMPCODIGO AND N.VENNUMERO = :VENNUMERO ' +
      'AND N.TERNUMERO = :TERNUMERO AND N.VENRNFCENUMEROFISCAL = :VENRNFCENUMEROFISCAL';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('VENNUMERO').AsInteger := AVenNumero;
    Q.ParamByName('TERNUMERO').AsInteger := ATerNumero;
    Q.ParamByName('VENRNFCENUMEROFISCAL').AsInteger := ANfceNumero;
    Q.Open;
    if Q.IsEmpty then
      Exit;

    Result.NumeroNfce := CampoStr(Q, 'VENRNFCENUMEROFISCAL');
    Result.NumeroCupom := CampoStr(Q, 'VENNUMEROCUPOM');
    if not Q.FieldByName('VENDTEMISSAO').IsNull then
      Result.Emissao := FormatDateTime('dd/mm/yyyy hh:nn', Q.FieldByName('VENDTEMISSAO').AsDateTime);
    if not Q.FieldByName('VENRNFCEDTTRANSMISSAO').IsNull then
      Result.Transmissao := FormatDateTime('dd/mm/yyyy hh:nn',
        Q.FieldByName('VENRNFCEDTTRANSMISSAO').AsDateTime);
    Result.Cliente := CampoStr(Q, 'NOME_CLIENTE');
    if Result.Cliente = '' then
      Result.Cliente := NFCe_NOME_CLIENTE_FINAL;
    Result.Chave := CampoStr(Q, 'VENRNFCECHAVE');
    Result.Protocolo := CampoStr(Q, 'VENRNFCEPROTOCOLO');
    Result.Situacao := TextoSituacaoNfce(CampoStr(Q, 'VENRNFCESITUACAODOC'));
    Result.Observacao := CampoStr(Q, 'VENRNFCEADICIONAIS');
    Result.Total := CampoFloat(Q, 'VENVALORLIQUIDO');

    try
      QEmp.Connection := dmConexao.FDConnection1;
      QEmp.SQL.Text :=
        'SELECT FIRST 1 P.PESNOME, P.PESCNPJCPF, P.PESFONE, P.PESLOGRADOURO, P.PESNUMERO, ' +
        'P.PESBAIRRO, P.PESCIDADE, P.PESUF ' +
        'FROM EMPRESAPESSOA EP JOIN PESSOA P ON P.PESCODIGO = EP.PESCODIGO ' +
        'WHERE EP.EMPCODIGO = :EMPCODIGO';
      QEmp.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
      QEmp.Open;
      if not QEmp.IsEmpty then
      begin
        Result.EmpresaNome := CampoStr(QEmp, 'PESNOME');
        Result.EmpresaCnpj := CampoStr(QEmp, 'PESCNPJCPF');
        Result.EmpresaTelefone := ValorPorCampos(QEmp, ['PESFONE', 'PESTELEFONE', 'PESCELULAR']);
        Result.EmpresaEndereco := Trim(ValorPorCampos(QEmp, ['PESLOGRADOURO', 'PESENDERECO']));
        if CampoStr(QEmp, 'PESNUMERO') <> '' then
          Result.EmpresaEndereco := Trim(Result.EmpresaEndereco + ', ' + CampoStr(QEmp, 'PESNUMERO'));
        if CampoStr(QEmp, 'PESBAIRRO') <> '' then
          Result.EmpresaEndereco := Trim(Result.EmpresaEndereco + ' - ' + CampoStr(QEmp, 'PESBAIRRO'));
        if CampoStr(QEmp, 'PESCIDADE') <> '' then
          Result.EmpresaEndereco := Trim(Result.EmpresaEndereco + ' - ' + CampoStr(QEmp, 'PESCIDADE') +
            IfThen(CampoStr(QEmp, 'PESUF') <> '', '/' + CampoStr(QEmp, 'PESUF'), ''));
      end;
    except
    end;

    QProd.Connection := dmConexao.FDConnection1;
    QProd.SQL.Text := TMapaNfce.MontarSQLProdutos;
    QProd.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    QProd.ParamByName('VENNUMERO').AsInteger := AVenNumero;
    QProd.ParamByName('TERNUMERO').AsInteger := ATerNumero;
    QProd.Open;
    while not QProd.Eof do
    begin
      Item.Descricao := CampoStr(QProd, 'PRODDESCRICAO');
      Item.Qtde := CampoFloat(QProd, 'NFITEMQTDE');
      Item.Unitario := CampoFloat(QProd, 'NFITEMUNITARIO');
      Item.Total := CampoFloat(QProd, 'NFITEMTOTALLIQUIDO');
      Result.Itens.Add(Item);
      QProd.Next;
    end;
  finally
    QProd.Free;
    QEmp.Free;
    Q.Free;
  end;
end;

constructor TRenderNfceCupom.Create;
begin
  FBmp := Vcl.Graphics.TBitmap.Create;
  FPageWidth := NFCe_CUPOM_LARGURA;
  FPageHeight := NFCe_CUPOM_ALTURA_INICIAL;
  TImpressaoPagina.PrepararBitmapPagina(FBmp, FPageWidth, FPageHeight);
  FCanvas := FBmp.Canvas;
  FMargemEsq := 8;
  FMargemDir := FPageWidth - 8;
  FY := 12;
  SetBkMode(FCanvas.Handle, TRANSPARENT);
end;

destructor TRenderNfceCupom.Destroy;
begin
  FBmp.Free;
  inherited Destroy;
end;

procedure TRenderNfceCupom.DefinirFonte(ATamanho: Integer; ANegrito: Boolean);
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

function TRenderNfceCupom.AlturaLinha: Integer;
begin
  Result := FCanvas.TextHeight('Ag') + 2;
end;

procedure TRenderNfceCupom.Avancar(APixels: Integer);
begin
  Inc(FY, APixels);
end;

procedure TRenderNfceCupom.Texto(const AX, AY: Integer; const ATexto: string);
begin
  if ATexto = '' then
    Exit;
  FCanvas.TextOut(AX, AY, ATexto);
end;

procedure TRenderNfceCupom.TextoCentro(AY: Integer; const ATexto: string);
var
  Largura: Integer;
begin
  if ATexto = '' then
    Exit;
  Largura := FCanvas.TextWidth(ATexto);
  Texto(FMargemEsq + Max(0, (FMargemDir - FMargemEsq - Largura) div 2), AY, ATexto);
end;

procedure TRenderNfceCupom.TextoDireita(AXDireita, AY: Integer; const ATexto: string);
begin
  if ATexto = '' then
    Exit;
  Texto(AXDireita - FCanvas.TextWidth(ATexto), AY, ATexto);
end;

procedure TRenderNfceCupom.LinhaSeparadora;
begin
  DefinirFonte(7, False);
  TextoCentro(FY, StringOfChar('-', 42));
  Avancar(AlturaLinha);
end;

procedure TRenderNfceCupom.TextoQuebrado(const ATexto: string; AIndent: Integer);
var
  Palavras: TArray<string>;
  Linha, Palavra: string;
  LarguraMax, X: Integer;
begin
  if Trim(ATexto) = '' then
    Exit;
  X := FMargemEsq + AIndent;
  LarguraMax := FMargemDir - X;
  Linha := '';
  Palavras := ATexto.Split([' ']);
  for Palavra in Palavras do
  begin
    if (Linha <> '') and (FCanvas.TextWidth(Linha + ' ' + Palavra) > LarguraMax) then
    begin
      Texto(X, FY, Linha);
      Avancar(AlturaLinha);
      Linha := Palavra;
    end
    else if Linha = '' then
      Linha := Palavra
    else
      Linha := Linha + ' ' + Palavra;
  end;
  if Linha <> '' then
  begin
    Texto(X, FY, Linha);
    Avancar(AlturaLinha);
  end;
end;

procedure TRenderNfceCupom.Renderizar(const ADados: TNfceCupomDados);
var
  I: Integer;
  Item: TNfceCupomItem;
  LinhaItem: string;
begin
  DefinirFonte(8, True);
  TextoCentro(FY, ADados.EmpresaNome);
  Avancar(AlturaLinha);
  DefinirFonte(7, False);
  if ADados.EmpresaCnpj <> '' then
  begin
    TextoCentro(FY, 'CNPJ: ' + ADados.EmpresaCnpj);
    Avancar(AlturaLinha);
  end;
  if ADados.EmpresaEndereco <> '' then
    TextoQuebrado(ADados.EmpresaEndereco, 0);
  if ADados.EmpresaTelefone <> '' then
  begin
    TextoCentro(FY, 'Fone: ' + ADados.EmpresaTelefone);
    Avancar(AlturaLinha);
  end;

  Avancar(4);
  LinhaSeparadora;
  DefinirFonte(8, True);
  TextoCentro(FY, 'DANFE NFC-e');
  Avancar(AlturaLinha);
  DefinirFonte(7, False);
  TextoCentro(FY, 'Documento Auxiliar da Nota Fiscal');
  Avancar(AlturaLinha);
  TextoCentro(FY, 'de Consumidor Eletronica');
  Avancar(AlturaLinha);
  TextoCentro(FY, '(Cupom informativo - sem QR Code)');
  Avancar(AlturaLinha);
  LinhaSeparadora;

  DefinirFonte(7, False);
  Texto(FMargemEsq, FY, 'NFC-e n.: ' + ADados.NumeroNfce);
  Avancar(AlturaLinha);
  if ADados.NumeroCupom <> '' then
  begin
    Texto(FMargemEsq, FY, 'Cupom n.: ' + ADados.NumeroCupom);
    Avancar(AlturaLinha);
  end;
  if ADados.Emissao <> '' then
  begin
    Texto(FMargemEsq, FY, 'Emissao: ' + ADados.Emissao);
    Avancar(AlturaLinha);
  end;
  if ADados.Transmissao <> '' then
  begin
    Texto(FMargemEsq, FY, 'Transmissao: ' + ADados.Transmissao);
    Avancar(AlturaLinha);
  end;
  Texto(FMargemEsq, FY, 'Situacao: ' + ADados.Situacao);
  Avancar(AlturaLinha);
  TextoQuebrado('Consumidor: ' + ADados.Cliente, 0);
  LinhaSeparadora;

  DefinirFonte(7, True);
  Texto(FMargemEsq, FY, 'ITEM  DESCRICAO');
  Avancar(AlturaLinha);
  LinhaSeparadora;
  DefinirFonte(7, False);

  for I := 0 to ADados.Itens.Count - 1 do
  begin
    Item := ADados.Itens[I];
    TextoQuebrado(Format('%d  %s', [I + 1, Item.Descricao]), 0);
    LinhaItem := Format('      %s x %s',
      [FormatarQuantidade(Item.Qtde), FormatarMoedaBRL(Item.Unitario)]);
    Texto(FMargemEsq, FY, LinhaItem);
    TextoDireita(FMargemDir, FY, FormatarMoedaBRL(Item.Total));
    Avancar(AlturaLinha + 2);
  end;

  LinhaSeparadora;
  DefinirFonte(8, True);
  Texto(FMargemEsq, FY, 'TOTAL R$');
  TextoDireita(FMargemDir, FY, FormatarMoedaBRL(ADados.Total));
  Avancar(AlturaLinha + 4);
  LinhaSeparadora;

  if ADados.Chave <> '' then
  begin
    DefinirFonte(7, True);
    TextoCentro(FY, 'CHAVE DE ACESSO');
    Avancar(AlturaLinha);
    DefinirFonte(6, False);
    TextoQuebrado(FormatarChaveCupom(ADados.Chave), 0);
    Avancar(2);
  end;

  if ADados.Protocolo <> '' then
  begin
    DefinirFonte(7, False);
    TextoQuebrado('Protocolo: ' + ADados.Protocolo, 0);
  end;

  if ADados.Observacao <> '' then
  begin
    LinhaSeparadora;
    DefinirFonte(7, True);
    TextoCentro(FY, 'INFORMACOES COMPLEMENTARES');
    Avancar(AlturaLinha);
    DefinirFonte(6, False);
    TextoQuebrado(ADados.Observacao, 0);
  end;

  Avancar(8);
  DefinirFonte(6, False);
  TextoCentro(FY, 'Consulta Realtec - cupom gerado sem XML');
end;

function TRenderNfceCupom.FinalizarBitmap: Vcl.Graphics.TBitmap;
var
  AlturaFinal: Integer;
begin
  AlturaFinal := FY + 24;
  if AlturaFinal < 200 then
    AlturaFinal := 200;
  if AlturaFinal > FPageHeight then
    AlturaFinal := FPageHeight;

  Result := Vcl.Graphics.TBitmap.Create;
  Result.SetSize(FPageWidth, AlturaFinal);
  Result.Canvas.Draw(0, 0, FBmp);
  TImpressaoPagina.FinalizarPaginaBitmap(Result);
end;

class function TRenderNfceCupom.GerarPaginas(const ADados: TNfceCupomDados): TListaPaginasImpressao;
var
  Render: TRenderNfceCupom;
  Bmp: Vcl.Graphics.TBitmap;
begin
  Result := TListaPaginasImpressao.Create;
  Render := TRenderNfceCupom.Create;
  try
    Render.Renderizar(ADados);
    Bmp := Render.FinalizarBitmap;
    Result.Add(Bmp);
  finally
    Render.Free;
  end;
end;

class procedure TNfceCupomImpressao.Visualizar(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer);
var
  Dados: TNfceCupomDados;
  Paginas: TListaPaginasImpressao;
begin
  Dados := CarregarDados(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  try
    if Dados.NumeroNfce = '' then
      raise Exception.Create('NFC-e nao encontrada para impressao.');
    Paginas := TRenderNfceCupom.GerarPaginas(Dados);
    try
      TImpressaoPagina.GerarPdfEAbrir(Paginas, 'NFC-e ' + Dados.NumeroNfce);
    finally
      Paginas.Free;
    end;
  finally
    Dados.Free;
  end;
end;

class procedure TNfceCupomImpressao.ImprimirFisico(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer);
var
  Dados: TNfceCupomDados;
  Paginas: TListaPaginasImpressao;
  Dlg: TPrintDialog;
begin
  if Printer.Printers.Count = 0 then
    raise Exception.Create('Nenhuma impressora instalada no Windows.');

  Dados := CarregarDados(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  Paginas := nil;
  Dlg := TPrintDialog.Create(nil);
  try
    if Dados.NumeroNfce = '' then
      raise Exception.Create('NFC-e nao encontrada para impressao.');
    Paginas := TRenderNfceCupom.GerarPaginas(Dados);
    if Paginas.Count = 0 then
      raise Exception.Create('Nao foi possivel gerar o cupom NFC-e.');
    if not Dlg.Execute then
      Exit;
    TImpressaoPagina.ImprimirPaginasPreview(Paginas);
  finally
    Paginas.Free;
    Dlg.Free;
    Dados.Free;
  end;
end;

end.
