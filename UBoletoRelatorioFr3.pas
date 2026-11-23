unit UBoletoRelatorioFr3;

interface

uses
  System.SysUtils;

type
  TBoletoRelatorioFr3 = class
  public
    class procedure VisualizarTitulo(AEmpCodigo, ACrNumero: Integer; const ATitulo: string = '');
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.Math,
  Vcl.Graphics, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  frxClass, frxDBSet, frxExportPDF, frxBarcode,
  ACBrBoleto, ACBrBoletoConversao, ACBrUtil.Strings,
  UdmConexao, UMapaReceber, UBoletoImpressao, UImpressaoUtil;

type
  TBoletoReportContext = class
  private
    FReport: TfrxReport;
    FTitulo: TFDMemTable;
    FNumeroBanco: string;
    procedure CarregarLogo(const ANomeComponente: string);
  public
    procedure OnProgressStart(Sender: TfrxReport; ProgressType: TfrxProgressType;
      Progress: Integer);
    procedure OnBeforePrint(Sender: TfrxReportComponent);
    property Report: TfrxReport read FReport write FReport;
    property Titulo: TFDMemTable read FTitulo write FTitulo;
    property NumeroBanco: string read FNumeroBanco write FNumeroBanco;
  end;

function PastaLogosBoleto: string;
var
  Base: string;
begin
  Base := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  if DirectoryExists(Base + 'Logos') then
    Exit(Base + 'Logos');
  if DirectoryExists(Base + 'Report\Logos') then
    Exit(Base + 'Report\Logos');
  if DirectoryExists(Base + '..\Logos') then
    Exit(IncludeTrailingPathDelimiter(Base + '..\Logos'));
  Result := Base + 'Logos';
end;

function ArquivoLogoBanco(const ANumeroBanco: string): string;
var
  Numero, Pasta, Arquivo: string;
begin
  Numero := OnlyNumber(ANumeroBanco);
  if Numero = '' then
    Numero := '756';
  if Length(Numero) < 3 then
    Numero := FormatFloat('000', StrToIntDef(Numero, 756));
  Pasta := IncludeTrailingPathDelimiter(PastaLogosBoleto);
  Arquivo := Pasta + Numero + '.png';
  if FileExists(Arquivo) then
    Exit(Arquivo);
  Arquivo := Pasta + Numero + '.bmp';
  if FileExists(Arquivo) then
    Exit(Arquivo);
  Result := '';
end;

procedure CarregarLogoBanco(APicture: TPicture; const ANumeroBanco: string);
var
  Arquivo: string;
begin
  if APicture = nil then
    Exit;
  Arquivo := ArquivoLogoBanco(ANumeroBanco);
  if Arquivo = '' then
    Exit;
  APicture.LoadFromFile(Arquivo);
end;

procedure TBoletoReportContext.CarregarLogo(const ANomeComponente: string);
var
  Pict: TfrxPictureView;
begin
  if FReport = nil then
    Exit;
  Pict := TfrxPictureView(FReport.FindObject(ANomeComponente));
  if Assigned(Pict) then
    CarregarLogoBanco(Pict.Picture, FNumeroBanco);
end;

procedure TBoletoReportContext.OnProgressStart(Sender: TfrxReport;
  ProgressType: TfrxProgressType; Progress: Integer);
begin
  CarregarLogo('Logo_1');
  CarregarLogo('Logo_2');
  CarregarLogo('Logo_3');
end;

procedure TBoletoReportContext.OnBeforePrint(Sender: TfrxReportComponent);
var
  Bar: TfrxBarCodeView;
begin
  if (Sender = nil) or (FTitulo = nil) then
    Exit;
  if SameText(Sender.Name, 'BarCode1') then
  begin
    Bar := TfrxBarCodeView(Sender);
    Bar.Expression := '';
    Bar.DataSetName := 'Titulo';
    Bar.DataField := 'CodBarras';
    if not FTitulo.IsEmpty then
      Bar.Text := FTitulo.FieldByName('CodBarras').AsString;
  end;
end;

procedure ConfigurarComponenteCodigoBarras(AReport: TfrxReport);
var
  Bar: TfrxBarCodeView;
begin
  Bar := TfrxBarCodeView(AReport.FindObject('BarCode1'));
  if not Assigned(Bar) then
    Exit;
  Bar.Expression := '';
  Bar.DataSetName := 'Titulo';
  Bar.DataField := 'CodBarras';
end;

const
  BOLETO_FIM_COMPROVANTE = 195;
  BOLETO_OFFSET_MEIA_FOLHA = -195;

procedure ConfigurarLayoutMeiaFolha(AReport: TfrxReport);
var
  Page: TfrxReportPage;
  MD: TfrxMasterData;
  I: Integer;
  Obj: TfrxComponent;
  View: TfrxView;
  AlturaMax, AlturaPaginaMm: Extended;
begin
  if (AReport = nil) or (AReport.PagesCount = 0) then
    Exit;
  if not (AReport.Pages[0] is TfrxReportPage) then
    Exit;

  Page := TfrxReportPage(AReport.Pages[0]);
  MD := TfrxMasterData(AReport.FindObject('MD'));
  if MD = nil then
    Exit;

  Page.TopMargin := 5;
  Page.BottomMargin := 5;
  Page.LeftMargin := 10;
  Page.RightMargin := 10;

  AlturaMax := 0;
  for I := 0 to MD.Objects.Count - 1 do
  begin
    Obj := MD.Objects[I];
    if not (Obj is TfrxView) then
      Continue;
    View := TfrxView(Obj);
    if View.Top < BOLETO_FIM_COMPROVANTE then
    begin
      View.Visible := False;
      Continue;
    end;
    View.Top := View.Top + BOLETO_OFFSET_MEIA_FOLHA;
    if View.Top + View.Height > AlturaMax then
      AlturaMax := View.Top + View.Height;
  end;

  MD.Top := 5;
  MD.Height := AlturaMax + 8;

  AlturaPaginaMm := (MD.Top + AlturaMax + Page.BottomMargin * 3.779527559) / 3.779527559;
  if AlturaPaginaMm < 148.5 then
    AlturaPaginaMm := 148.5;
  Page.PaperHeight := AlturaPaginaMm;
  Page.PaperWidth := 210;
  Page.PaperSize := 256;
end;

procedure AplicarMarcaDaguaVisualizacao(AReport: TfrxReport);
const
  TEXTO_MARCA = 'APENAS VISUALIZA'#199#195'O';
var
  I: Integer;
  Page: TfrxReportPage;
  Marca: TfrxMemoView;

  procedure CriarMarca(const ATop: Extended);
  begin
    Marca := TfrxMemoView.Create(Page);
    Marca.Parent := Page;
    Marca.Name := 'MarcaDaguaVisualizacao' + IntToStr(Trunc(ATop));
    Marca.Left := -40;
    Marca.Top := ATop;
    Marca.Width := 780;
    Marca.Height := 90;
    Marca.Rotation := 45;
    Marca.Clipped := False;
    Marca.Text := TEXTO_MARCA;
    Marca.Font.Name := 'Arial';
    Marca.Font.Height := -36;
    Marca.Font.Style := [fsBold];
    Marca.Font.Color := $00D8D8D8;
    Marca.Color := clNone;
    Marca.HAlign := haCenter;
    Marca.VAlign := vaCenter;
    Marca.WordWrap := False;
    Marca.Frame.Typ := [];
  end;

begin
  if AReport = nil then
    Exit;
  for I := 0 to AReport.PagesCount - 1 do
  begin
    if not (AReport.Pages[I] is TfrxReportPage) then
      Continue;
    Page := TfrxReportPage(AReport.Pages[I]);
    CriarMarca(180);
    CriarMarca(380);
    CriarMarca(580);
  end;
end;

function CaminhoRelatorioBoleto: string;
var
  Base: string;
begin
  Base := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Result := Base + 'Report\Boleto.fr3';
  if FileExists(Result) then
    Exit;
  Result := Base + '..\Report\Boleto.fr3';
  if FileExists(Result) then
    Exit;
  Result := ExtractFilePath(ParamStr(0)) + '..\..\Report\Boleto.fr3';
end;

function SomenteDigitos(const ATexto: string): string;
begin
  Result := OnlyNumber(ATexto);
end;

function DataBRParaDate(const ATexto: string): TDateTime;
begin
  Result := 0;
  if Trim(ATexto) = '' then
    Exit;
  try
    Result := StrToDate(Trim(ATexto));
  except
    Result := 0;
  end;
end;

function TipoCobrancaPorBanco(const ACodigoBanco: string): TACBrTipoCobranca;
var
  Codigo: Integer;
begin
  Codigo := StrToIntDef(SomenteDigitos(ACodigoBanco), 0);
  case Codigo of
    1: Result := cobBancoDoBrasil;
    33: Result := cobSantander;
    104: Result := cobCaixaEconomica;
    237: Result := cobBradesco;
    341: Result := cobItau;
    748: Result := cobSicred;
    756: Result := cobBancoSicoob;
    41: Result := cobBanrisul;
    422: Result := cobSafraBradesco;
  else
    Result := cobBancoSicoob;
  end;
end;

procedure SepararNumeroDigito(const AValor: string; out ANumero, ADigito: string);
var
  P: Integer;
  S: string;
begin
  S := Trim(AValor);
  ANumero := '';
  ADigito := '';
  P := Pos('-', S);
  if P > 0 then
  begin
    ANumero := Trim(Copy(S, 1, P - 1));
    ADigito := Trim(Copy(S, P + 1, MaxInt));
  end
  else
    ANumero := S;
  ANumero := SomenteDigitos(ANumero);
  ADigito := SomenteDigitos(ADigito);
  if ADigito = '' then
    ADigito := '0';
end;

function NormalizarCarteira(const ACarteira: string): string;
var
  C: string;
begin
  C := SomenteDigitos(ACarteira);
  if C = '' then
    Exit('1');
  if (C = '1') or (C = '3') or (C = '9') then
    Exit(C);
  Result := C[1];
  if (Result <> '1') and (Result <> '3') and (Result <> '9') then
    Result := '1';
end;

function FormatarLinhaDigitavelExibicao(const ALinha: string): string;
var
  D: string;
begin
  D := SomenteDigitos(ALinha);
  if Length(D) < 47 then
    Exit(Trim(ALinha));
  Result :=
    Copy(D, 1, 5) + '.' + Copy(D, 6, 5) + ' ' +
    Copy(D, 11, 5) + '.' + Copy(D, 16, 6) + ' ' +
    Copy(D, 22, 5) + '.' + Copy(D, 27, 6) + ' ' +
    Copy(D, 33, 1) + ' ' + Copy(D, 34, 14);
end;

function LinhaDigitavelParaCodigoBarras(const ALinha: string): string;
var
  L: string;
begin
  L := SomenteDigitos(ALinha);
  if Length(L) <> 47 then
    Exit('');
  Result := Copy(L, 1, 4) + Copy(L, 33, 1) + Copy(L, 34, 14) +
    Copy(L, 5, 5) + Copy(L, 11, 10) + Copy(L, 22, 10);
end;

function DigitoBancoExibicao(const ADados: TBoletoImpressaoDados): string;
var
  L: string;
begin
  L := SomenteDigitos(ADados.LinhaDigitavel);
  if Length(L) >= 4 then
    Exit(Copy(L, 4, 1));
  Result := '0';
end;

function NumeroBancoExibicao(const ADados: TBoletoImpressaoDados): string;
var
  Cod: Integer;
begin
  Cod := StrToIntDef(SomenteDigitos(ADados.BancoCodigo), 756);
  Result := FormatFloat('000', Cod);
end;

function AceiteExibicao(const ADados: TBoletoImpressaoDados): string;
begin
  if SameText(ADados.Aceite, 'S') then
    Result := 'S'
  else
    Result := 'N';
end;

procedure ConfigurarCedente(ABoleto: TACBrBoleto; const ADados: TBoletoImpressaoDados);
var
  Cedente: TACBrCedente;
  Documento, Agencia, AgenciaDV, Conta, ContaDV: string;
begin
  Cedente := ABoleto.Cedente;
  Cedente.Nome := ADados.Cedente;
  Cedente.Logradouro := ADados.CedenteEndereco;
  Documento := SomenteDigitos(ADados.CedenteCnpj);
  Cedente.CNPJCPF := Documento;
  if Length(Documento) > 11 then
    Cedente.TipoInscricao := pJuridica
  else
    Cedente.TipoInscricao := pFisica;

  SepararNumeroDigito(ADados.Agencia, Agencia, AgenciaDV);
  SepararNumeroDigito(ADados.Conta, Conta, ContaDV);
  Cedente.Agencia := Agencia;
  Cedente.AgenciaDigito := AgenciaDV;
  Cedente.Conta := Conta;
  Cedente.ContaDigito := ContaDV;
  Cedente.CodigoCedente := SomenteDigitos(ADados.CodigoCedente);
  if Cedente.CodigoCedente = '' then
    Cedente.CodigoCedente := Trim(ADados.CodigoCedente);
  Cedente.Modalidade := '01';
end;

procedure ConfigurarBanco(ABoleto: TACBrBoleto; const ADados: TBoletoImpressaoDados);
begin
  ABoleto.Banco.TipoCobranca := TipoCobrancaPorBanco(ADados.BancoCodigo);
  if Trim(ADados.LocalPagamento) <> '' then
    ABoleto.Banco.LocalPagamento := ADados.LocalPagamento;
end;

procedure PreencherTitulo(ABoleto: TACBrBoleto; const ADados: TBoletoImpressaoDados);
var
  Titulo: TACBrTitulo;
  DocumentoSacado: string;
  Vencimento, Emissao, Processamento: TDateTime;
begin
  Titulo := ABoleto.CriarTituloNaLista;

  Vencimento := DataBRParaDate(ADados.Vencimento);
  Emissao := DataBRParaDate(ADados.Emissao);
  Processamento := DataBRParaDate(ADados.DataProcessamento);
  if Vencimento = 0 then
    Vencimento := Date;
  if Emissao = 0 then
    Emissao := Vencimento;
  if Processamento = 0 then
    Processamento := Emissao;

  Titulo.Vencimento := Vencimento;
  Titulo.DataDocumento := Emissao;
  Titulo.DataProcessamento := Processamento;
  Titulo.NumeroDocumento := ADados.NumeroDocumento;
  Titulo.EspecieDoc := ADados.EspecieDoc;
  if Trim(ADados.EspecieMoeda) <> '' then
    Titulo.EspecieMod := ADados.EspecieMoeda
  else
    Titulo.EspecieMod := 'R$';

  if SameText(ADados.Aceite, 'S') then
    Titulo.Aceite := atSim
  else
    Titulo.Aceite := atNao;

  Titulo.Carteira := NormalizarCarteira(ADados.Carteira);
  Titulo.NossoNumero := SomenteDigitos(ADados.NossoNumero);
  Titulo.ValorDocumento := ADados.ValorNumerico;
  Titulo.LocalPagamento := ADados.LocalPagamento;
  Titulo.Instrucao1 := ADados.Instrucao1;
  Titulo.Instrucao2 := ADados.Instrucao2;

  if Trim(ADados.Observacao) <> '' then
    Titulo.Mensagem.Text := ADados.Observacao;

  Titulo.Sacado.NomeSacado := ADados.Sacado;
  DocumentoSacado := SomenteDigitos(ADados.SacadoCpfCnpj);
  Titulo.Sacado.CNPJCPF := DocumentoSacado;
  Titulo.Sacado.Logradouro := ADados.SacadoEndereco;
end;

function MontarBoletoAcBr(const ADados: TArray<TBoletoImpressaoDados>): TACBrBoleto;
var
  I: Integer;
begin
  Result := TACBrBoleto.Create(nil);
  Result.ListadeBoletos.Clear;
  ConfigurarCedente(Result, ADados[0]);
  ConfigurarBanco(Result, ADados[0]);
  for I := 0 to High(ADados) do
    PreencherTitulo(Result, ADados[I]);
end;

function ResolverCodigoBarras(ABoleto: TACBrBoleto; AIndice: Integer;
  const ADados: TBoletoImpressaoDados): string;
begin
  Result := SomenteDigitos(ADados.CodigoBarras);
  if Length(Result) = 44 then
    Exit;
  Result := LinhaDigitavelParaCodigoBarras(ADados.LinhaDigitavel);
  if Length(Result) = 44 then
    Exit;
  Result := SomenteDigitos(ABoleto.Banco.MontarCodigoBarras(ABoleto.ListadeBoletos[AIndice]));
  if Length(Result) <> 44 then
    raise Exception.CreateFmt(
      'Codigo de barras invalido para o boleto (%d digitos). Verifique linha digitavel, ' +
      'codigo de barras ou nosso numero no cadastro.', [Length(Result)]);
end;

function ResolverLinhaDigitavel(ABoleto: TACBrBoleto; AIndice: Integer;
  const ADados: TBoletoImpressaoDados; const ACodigoBarras: string): string;
begin
  if Trim(ADados.LinhaDigitavel) <> '' then
    Exit(FormatarLinhaDigitavelExibicao(ADados.LinhaDigitavel));
  Result := ABoleto.Banco.MontarLinhaDigitavel(ACodigoBarras, ABoleto.ListadeBoletos[AIndice]);
end;

procedure ValidarDadosMinimos(const ADados: TArray<TBoletoImpressaoDados>);
var
  I: Integer;
  TemCodigo: Boolean;
begin
  if Length(ADados) = 0 then
    raise Exception.Create('Nao foi possivel carregar os dados do boleto.');

  if Trim(ADados[0].Cedente) = '' then
    raise Exception.Create('Cedente (empresa) nao informado no cadastro.');
  if Trim(ADados[0].Agencia) = '' then
    raise Exception.Create('Agencia bancaria nao informada na carteira.');
  if Trim(ADados[0].Conta) = '' then
    raise Exception.Create('Conta bancaria nao informada na carteira.');

  for I := 0 to High(ADados) do
  begin
    TemCodigo := (SomenteDigitos(ADados[I].CodigoBarras) <> '') or
      (SomenteDigitos(ADados[I].LinhaDigitavel) <> '');
    if not TemCodigo and (SomenteDigitos(ADados[I].NossoNumero) = '') then
      raise Exception.Create(
        'Boleto sem linha digitavel, codigo de barras ou nosso numero para gerar a impressao.');
  end;
end;

procedure MontarMemTableBanco(const ADados: TBoletoImpressaoDados; ATable: TFDMemTable);
begin
  ATable.Close;
  ATable.FieldDefs.Clear;
  ATable.FieldDefs.Add('Numero', ftString, 20);
  ATable.FieldDefs.Add('Digito', ftString, 1);
  ATable.FieldDefs.Add('Nome', ftString, 100);
  ATable.FieldDefs.Add('DirLogo', ftString, 254);
  ATable.FieldDefs.Add('OrientacoesBanco', ftString, 254);
  ATable.FieldDefs.Add('CIP', ftString, 3);
  ATable.CreateDataSet;
  ATable.Append;
  ATable.FieldByName('Numero').AsString := NumeroBancoExibicao(ADados);
  ATable.FieldByName('Digito').AsString := DigitoBancoExibicao(ADados);
  ATable.FieldByName('Nome').AsString := ADados.BancoNome;
  ATable.FieldByName('DirLogo').AsString := PastaLogosBoleto;
  ATable.FieldByName('OrientacoesBanco').AsString := '';
  ATable.FieldByName('CIP').AsString := '';
  ATable.Post;
end;

procedure MontarMemTableCedente(const ADados: TBoletoImpressaoDados; ATable: TFDMemTable);
var
  Agencia, AgenciaDV, Conta, ContaDV, Documento: string;
begin
  SepararNumeroDigito(ADados.Agencia, Agencia, AgenciaDV);
  SepararNumeroDigito(ADados.Conta, Conta, ContaDV);
  Documento := SomenteDigitos(ADados.CedenteCnpj);

  ATable.Close;
  ATable.FieldDefs.Clear;
  ATable.FieldDefs.Add('Nome', ftString, 100);
  ATable.FieldDefs.Add('CodigoCedente', ftString, 20);
  ATable.FieldDefs.Add('CodigoTransmissao', ftString, 20);
  ATable.FieldDefs.Add('Agencia', ftString, 5);
  ATable.FieldDefs.Add('AgenciaDigito', ftString, 2);
  ATable.FieldDefs.Add('Conta', ftString, 20);
  ATable.FieldDefs.Add('ContaDigito', ftString, 2);
  ATable.FieldDefs.Add('Modalidade', ftString, 20);
  ATable.FieldDefs.Add('Convenio', ftString, 20);
  ATable.FieldDefs.Add('ResponEmissao', ftInteger);
  ATable.FieldDefs.Add('CNPJCPF', ftString, 18);
  ATable.FieldDefs.Add('TipoInscricao', ftInteger);
  ATable.FieldDefs.Add('Logradouro', ftString, 100);
  ATable.FieldDefs.Add('NumeroRes', ftString, 10);
  ATable.FieldDefs.Add('Complemento', ftString, 100);
  ATable.FieldDefs.Add('Bairro', ftString, 100);
  ATable.FieldDefs.Add('Cidade', ftString, 100);
  ATable.FieldDefs.Add('UF', ftString, 2);
  ATable.FieldDefs.Add('CEP', ftString, 9);
  ATable.FieldDefs.Add('Telefone', ftString, 15);
  ATable.CreateDataSet;
  ATable.Append;
  ATable.FieldByName('Nome').AsString := ADados.Cedente;
  ATable.FieldByName('CodigoCedente').AsString := ADados.CodigoCedente;
  ATable.FieldByName('CodigoTransmissao').AsString := '';
  ATable.FieldByName('Agencia').AsString := Agencia;
  ATable.FieldByName('AgenciaDigito').AsString := AgenciaDV;
  ATable.FieldByName('Conta').AsString := Conta;
  ATable.FieldByName('ContaDigito').AsString := ContaDV;
  ATable.FieldByName('Modalidade').AsString := '01';
  ATable.FieldByName('Convenio').AsString := '';
  ATable.FieldByName('ResponEmissao').AsInteger := 0;
  ATable.FieldByName('CNPJCPF').AsString := Documento;
  if Length(Documento) > 11 then
    ATable.FieldByName('TipoInscricao').AsInteger := Integer(pJuridica)
  else
    ATable.FieldByName('TipoInscricao').AsInteger := Integer(pFisica);
  ATable.FieldByName('Logradouro').AsString := ADados.CedenteLogradouro;
  ATable.FieldByName('NumeroRes').AsString := ADados.CedenteNumero;
  ATable.FieldByName('Complemento').AsString := ADados.CedenteComplemento;
  ATable.FieldByName('Bairro').AsString := ADados.CedenteBairro;
  ATable.FieldByName('Cidade').AsString := ADados.CedenteCidade;
  ATable.FieldByName('UF').AsString := ADados.CedenteUF;
  ATable.FieldByName('CEP').AsString := ADados.CedenteCEP;
  ATable.FieldByName('Telefone').AsString := '';
  ATable.Post;
end;

procedure MontarMemTableTitulo(const ADados: TArray<TBoletoImpressaoDados>;
  ABoleto: TACBrBoleto; ATable: TFDMemTable);
var
  I: Integer;
  D: TBoletoImpressaoDados;
  Cod, Linha, DocSacado: string;
  Vencimento, Emissao, Processamento: TDateTime;
begin
  ATable.Close;
  ATable.FieldDefs.Clear;
  ATable.FieldDefs.Add('NossoNum', ftString, 100);
  ATable.FieldDefs.Add('CodCedente', ftString, 100);
  ATable.FieldDefs.Add('CodBarras', ftString, 100);
  ATable.FieldDefs.Add('LinhaDigitavel', ftString, 100);
  ATable.FieldDefs.Add('TipoDoc', ftString, 10);
  ATable.FieldDefs.Add('Vencimento', ftDateTime);
  ATable.FieldDefs.Add('DataDocumento', ftDateTime);
  ATable.FieldDefs.Add('NumeroDocumento', ftString, 20);
  ATable.FieldDefs.Add('TotalParcelas', ftInteger);
  ATable.FieldDefs.Add('Parcela', ftInteger);
  ATable.FieldDefs.Add('EspecieDoc', ftString, 10);
  ATable.FieldDefs.Add('EspecieMod', ftString, 10);
  ATable.FieldDefs.Add('UsoBanco', ftString, 4);
  ATable.FieldDefs.Add('Aceite', ftString, 3);
  ATable.FieldDefs.Add('DataProcessamento', ftDateTime);
  ATable.FieldDefs.Add('NossoNumero', ftString, 20);
  ATable.FieldDefs.Add('Carteira', ftString, 20);
  ATable.FieldDefs.Add('ValorDocumento', ftFloat);
  ATable.FieldDefs.Add('LocalPagamento', ftString, 100);
  ATable.FieldDefs.Add('ValorMoraJuros', ftFloat);
  ATable.FieldDefs.Add('ValorDesconto', ftFloat);
  ATable.FieldDefs.Add('ValorAbatimento', ftFloat);
  ATable.FieldDefs.Add('DataMoraJuros', ftDateTime);
  ATable.FieldDefs.Add('DataDesconto', ftDateTime);
  ATable.FieldDefs.Add('DataABatimento', ftDateTime);
  ATable.FieldDefs.Add('DataProtesto', ftDateTime);
  ATable.FieldDefs.Add('PercentualMulta', ftFloat);
  ATable.FieldDefs.Add('Mensagem', ftMemo);
  ATable.FieldDefs.Add('OcorrenciaOriginal', ftInteger);
  ATable.FieldDefs.Add('Instrucao1', ftString, 100);
  ATable.FieldDefs.Add('Instrucao2', ftString, 100);
  ATable.FieldDefs.Add('Instrucao3', ftString, 100);
  ATable.FieldDefs.Add('TextoLivre', ftString, 100);
  ATable.FieldDefs.Add('Asbace', ftString, 100);
  ATable.FieldDefs.Add('EMV', ftString, 100);
  ATable.FieldDefs.Add('ArquivoLogoEmp', ftString, 100);
  ATable.FieldDefs.Add('Sacado_NomeSacado', ftString, 100);
  ATable.FieldDefs.Add('Sacado_CNPJCPF', ftString, 18);
  ATable.FieldDefs.Add('Sacado_Logradouro', ftString, 100);
  ATable.FieldDefs.Add('Sacado_Complemento', ftString, 100);
  ATable.FieldDefs.Add('Sacado_Numero', ftString, 10);
  ATable.FieldDefs.Add('Sacado_Bairro', ftString, 100);
  ATable.FieldDefs.Add('Sacado_Cidade', ftString, 100);
  ATable.FieldDefs.Add('Sacado_UF', ftString, 2);
  ATable.FieldDefs.Add('Sacado_CEP', ftString, 9);
  ATable.FieldDefs.Add('Sacado_Fone', ftString, 100);
  ATable.FieldDefs.Add('Sacado_Avalista', ftString, 100);
  ATable.FieldDefs.Add('Sacado_Avalista_Nome', ftString, 100);
  ATable.FieldDefs.Add('Sacado_Avalista_CNPJCPF', ftString, 18);
  ATable.FieldDefs.Add('Sacado_Avalista_Logradouro', ftString, 100);
  ATable.FieldDefs.Add('Sacado_Avalista_Numero', ftString, 10);
  ATable.FieldDefs.Add('Sacado_Avalista_Complemento', ftString, 100);
  ATable.FieldDefs.Add('Sacado_Avalista_Bairro', ftString, 100);
  ATable.FieldDefs.Add('Sacado_Avalista_Cidade', ftString, 100);
  ATable.FieldDefs.Add('Sacado_Avalista_UF', ftString, 2);
  ATable.FieldDefs.Add('Sacado_Avalista_CEP', ftString, 9);
  ATable.CreateDataSet;

  for I := 0 to High(ADados) do
  begin
    D := ADados[I];
    Cod := ResolverCodigoBarras(ABoleto, I, D);
    Linha := ResolverLinhaDigitavel(ABoleto, I, D, Cod);

    Vencimento := DataBRParaDate(D.Vencimento);
    Emissao := DataBRParaDate(D.Emissao);
    Processamento := DataBRParaDate(D.DataProcessamento);
    if Vencimento = 0 then
      Vencimento := Date;
    if Emissao = 0 then
      Emissao := Vencimento;
    if Processamento = 0 then
      Processamento := Emissao;

    DocSacado := SomenteDigitos(D.SacadoCpfCnpj);
    ATable.Append;
    ATable.FieldByName('NossoNum').AsString :=
      ABoleto.Banco.MontarCampoNossoNumero(ABoleto.ListadeBoletos[I]);
    ATable.FieldByName('CodCedente').AsString :=
      ABoleto.Banco.MontarCampoCodigoCedente(ABoleto.ListadeBoletos[I]);
    ATable.FieldByName('CodBarras').AsString := Cod;
    ATable.FieldByName('LinhaDigitavel').AsString := Linha;
    if Length(DocSacado) > 11 then
      ATable.FieldByName('TipoDoc').AsString := 'CNPJ: '
    else
      ATable.FieldByName('TipoDoc').AsString := 'CPF: ';
    ATable.FieldByName('Vencimento').AsDateTime := Vencimento;
    ATable.FieldByName('DataDocumento').AsDateTime := Emissao;
    ATable.FieldByName('NumeroDocumento').AsString := D.NumeroDocumento;
    ATable.FieldByName('TotalParcelas').AsInteger := 1;
    ATable.FieldByName('Parcela').AsInteger := 1;
    ATable.FieldByName('EspecieDoc').AsString := D.EspecieDoc;
    if Trim(D.EspecieMoeda) <> '' then
      ATable.FieldByName('EspecieMod').AsString := D.EspecieMoeda
    else
      ATable.FieldByName('EspecieMod').AsString := 'R$';
    ATable.FieldByName('UsoBanco').AsString := '';
    ATable.FieldByName('Aceite').AsString := AceiteExibicao(D);
    ATable.FieldByName('DataProcessamento').AsDateTime := Processamento;
    ATable.FieldByName('NossoNumero').AsString := SomenteDigitos(D.NossoNumero);
    ATable.FieldByName('Carteira').AsString :=
      ABoleto.Banco.MontarCampoCarteira(ABoleto.ListadeBoletos[I]);
    ATable.FieldByName('ValorDocumento').AsFloat := D.ValorNumerico;
    ATable.FieldByName('LocalPagamento').AsString := D.LocalPagamento;
    ATable.FieldByName('ValorMoraJuros').AsFloat := 0;
    ATable.FieldByName('ValorDesconto').AsFloat := 0;
    ATable.FieldByName('ValorAbatimento').AsFloat := 0;
    ATable.FieldByName('PercentualMulta').AsFloat := 0;
    ATable.FieldByName('Mensagem').AsString := D.Observacao;
    ATable.FieldByName('OcorrenciaOriginal').AsInteger := 0;
    ATable.FieldByName('Instrucao1').AsString := D.Instrucao1;
    ATable.FieldByName('Instrucao2').AsString := D.Instrucao2;
    ATable.FieldByName('Instrucao3').AsString := '';
    ATable.FieldByName('TextoLivre').AsString := '';
    ATable.FieldByName('Asbace').AsString := '';
    ATable.FieldByName('EMV').AsString := '';
    ATable.FieldByName('ArquivoLogoEmp').AsString := '';
    ATable.FieldByName('Sacado_NomeSacado').AsString := D.Sacado;
    ATable.FieldByName('Sacado_CNPJCPF').AsString := DocSacado;
    if Trim(D.SacadoLogradouro) <> '' then
    begin
      ATable.FieldByName('Sacado_Logradouro').AsString := D.SacadoLogradouro;
      ATable.FieldByName('Sacado_Complemento').AsString := D.SacadoComplemento;
      ATable.FieldByName('Sacado_Numero').AsString := D.SacadoNumero;
      ATable.FieldByName('Sacado_Bairro').AsString := D.SacadoBairro;
      ATable.FieldByName('Sacado_Cidade').AsString := D.SacadoCidade;
      ATable.FieldByName('Sacado_UF').AsString := D.SacadoUF;
      ATable.FieldByName('Sacado_CEP').AsString := D.SacadoCEP;
    end
    else if Trim(D.SacadoEndereco) <> '' then
    begin
      ATable.FieldByName('Sacado_Logradouro').AsString := D.SacadoEndereco;
      ATable.FieldByName('Sacado_Complemento').AsString := '';
      ATable.FieldByName('Sacado_Numero').AsString := '';
      ATable.FieldByName('Sacado_Bairro').AsString := '';
      ATable.FieldByName('Sacado_Cidade').AsString := '';
      ATable.FieldByName('Sacado_UF').AsString := '';
      ATable.FieldByName('Sacado_CEP').AsString := '';
    end
    else
    begin
      ATable.FieldByName('Sacado_Logradouro').AsString := '';
      ATable.FieldByName('Sacado_Complemento').AsString := '';
      ATable.FieldByName('Sacado_Numero').AsString := '';
      ATable.FieldByName('Sacado_Bairro').AsString := '';
      ATable.FieldByName('Sacado_Cidade').AsString := '';
      ATable.FieldByName('Sacado_UF').AsString := '';
      ATable.FieldByName('Sacado_CEP').AsString := '';
    end;
    ATable.FieldByName('Sacado_Fone').AsString := '';
    ATable.FieldByName('Sacado_Avalista').AsString := '';
    ATable.FieldByName('Sacado_Avalista_Nome').AsString := '';
    ATable.FieldByName('Sacado_Avalista_CNPJCPF').AsString := '';
    ATable.FieldByName('Sacado_Avalista_Logradouro').AsString := '';
    ATable.FieldByName('Sacado_Avalista_Numero').AsString := '';
    ATable.FieldByName('Sacado_Avalista_Complemento').AsString := '';
    ATable.FieldByName('Sacado_Avalista_Bairro').AsString := '';
    ATable.FieldByName('Sacado_Avalista_Cidade').AsString := '';
    ATable.FieldByName('Sacado_Avalista_UF').AsString := '';
    ATable.FieldByName('Sacado_Avalista_CEP').AsString := '';
    ATable.Post;
  end;
end;

procedure ExecutarVisualizacao(const ADados: TArray<TBoletoImpressaoDados>; const ATitulo: string);
var
  Report: TfrxReport;
  DBBanco, DBCedente, DBTitulo: TfrxDBDataset;
  TBBanco, TBCedente, TBTitulo: TFDMemTable;
  BarCodeObject: TfrxBarCodeObject;
  ExportPDF: TfrxPDFExport;
  BoletoAcBr: TACBrBoleto;
  ReportCtx: TBoletoReportContext;
  Caminho, PdfPath, Pasta, NomeRelatorio: string;
begin
  ValidarDadosMinimos(ADados);

  Caminho := CaminhoRelatorioBoleto;
  if not FileExists(Caminho) then
    raise Exception.Create('Relatorio de boleto nao encontrado:' + sLineBreak + Caminho);

  BoletoAcBr := MontarBoletoAcBr(ADados);
  TBBanco := TFDMemTable.Create(nil);
  TBCedente := TFDMemTable.Create(nil);
  TBTitulo := TFDMemTable.Create(nil);
  Report := TfrxReport.Create(nil);
  DBBanco := TfrxDBDataset.Create(nil);
  DBCedente := TfrxDBDataset.Create(nil);
  DBTitulo := TfrxDBDataset.Create(nil);
  ReportCtx := TBoletoReportContext.Create;
  ExportPDF := TfrxPDFExport.Create(nil);
  try
    try
      BoletoAcBr.ChecarDadosObrigatorios;
    except
      on E: Exception do
        raise Exception.Create('Dados bancarios incompletos: ' + E.Message);
    end;

    MontarMemTableBanco(ADados[0], TBBanco);
    MontarMemTableCedente(ADados[0], TBCedente);
    MontarMemTableTitulo(ADados, BoletoAcBr, TBTitulo);

    BarCodeObject := TfrxBarCodeObject.Create(Report);

    DBBanco.DataSet := TBBanco;
    DBBanco.UserName := 'Banco';
    DBBanco.Name := 'frxDBBanco';
    DBBanco.OpenDataSource := False;

    DBCedente.DataSet := TBCedente;
    DBCedente.UserName := 'Cedente';
    DBCedente.Name := 'frxDBCedente';
    DBCedente.OpenDataSource := False;

    DBTitulo.DataSet := TBTitulo;
    DBTitulo.UserName := 'Titulo';
    DBTitulo.Name := 'frxDBTitulo';
    DBTitulo.OpenDataSource := False;

    Report.EngineOptions.UseGlobalDataSetList := False;
    Report.OnProgressStart := ReportCtx.OnProgressStart;
    Report.OnBeforePrint := ReportCtx.OnBeforePrint;
    ReportCtx.Report := Report;
    ReportCtx.Titulo := TBTitulo;
    ReportCtx.NumeroBanco := NumeroBancoExibicao(ADados[0]);

    Report.EnabledDataSets.Clear;
    Report.EnabledDataSets.Add(DBBanco);
    Report.EnabledDataSets.Add(DBCedente);
    Report.EnabledDataSets.Add(DBTitulo);
    Report.LoadFromFile(Caminho);
    if Trim(Report.ScriptText.Text) = '' then
      Report.ScriptText.Text := 'begin' + sLineBreak + 'end.';

    ConfigurarLayoutMeiaFolha(Report);
    AplicarMarcaDaguaVisualizacao(Report);

    ConfigurarComponenteCodigoBarras(Report);

    Report.EngineOptions.SilentMode := True;
    Report.EngineOptions.DestroyForms := False;
    Report.ShowProgress := False;
    Report.PrintOptions.ShowDialog := False;

    if not Report.PrepareReport(True) then
      raise Exception.Create('Falha ao preparar o relatorio do boleto.');

    if ATitulo <> '' then
      NomeRelatorio := ATitulo
    else
      NomeRelatorio := 'Visualizar boleto';

    Pasta := IncludeTrailingPathDelimiter(TPath.GetTempPath) + 'ConsultasBoletoPdf' + PathDelim;
    ForceDirectories(Pasta);
    PdfPath := Pasta + TImpressaoPagina.SanitizarNomeArquivoPdf(NomeRelatorio) + '.pdf';

    ExportPDF.FileName := PdfPath;
    ExportPDF.ShowDialog := False;
    ExportPDF.ShowProgress := False;
    ExportPDF.DefaultPath := Pasta;
    if not Report.Export(ExportPDF) then
      raise Exception.Create('Falha ao exportar o PDF do boleto.');

    if not TFile.Exists(PdfPath) then
      raise Exception.Create('Nao foi possivel gerar o PDF do boleto.');

    TImpressaoPagina.AbrirPdfNoVisualizadorPadrao(PdfPath);
  finally
    if Report <> nil then
    begin
      Report.OnProgressStart := nil;
      Report.OnBeforePrint := nil;
    end;
    ExportPDF.Free;
    Report.Free;
    DBTitulo.Free;
    DBCedente.Free;
    DBBanco.Free;
    TBTitulo.Free;
    TBCedente.Free;
    TBBanco.Free;
    BoletoAcBr.Free;
    ReportCtx.Free;
  end;
end;

class procedure TBoletoRelatorioFr3.VisualizarTitulo(AEmpCodigo, ACrNumero: Integer;
  const ATitulo: string);
var
  Boletos: TArray<TInfoBoletoReceber>;
  Lista: TList<TBoletoImpressaoDados>;
  Arr: TArray<TBoletoImpressaoDados>;
  Dados: TBoletoImpressaoDados;
  I: Integer;
begin
  if not dmConexao.Conectado then
    raise Exception.Create('Banco de dados nao conectado.');

  Lista := TList<TBoletoImpressaoDados>.Create;
  try
    Boletos := TMapaReceber.CarregarBoletos(AEmpCodigo, ACrNumero);
    if Length(Boletos) = 0 then
      raise Exception.Create('Nenhum boleto encontrado para este titulo.');

    for I := 0 to High(Boletos) do
    begin
      Dados := TBoletoImpressao.CarregarDados(AEmpCodigo, Boletos[I].BolContador);
      Lista.Add(Dados);
    end;

    if Lista.Count = 0 then
      raise Exception.Create('Nao foi possivel carregar os dados do boleto.');

    Arr := Lista.ToArray;
    ExecutarVisualizacao(Arr, ATitulo);
  finally
    for I := 0 to Lista.Count - 1 do
      Lista[I].Free;
    Lista.Free;
  end;
end;

end.
