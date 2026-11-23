unit UBoletoImpressao;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Generics.Collections,
  Vcl.Graphics, UImpressaoUtil, UMapaReceber;

type
  TBoletoImpressaoDados = class
  public
    Documento: string;
    Sacado: string;
    SacadoCpfCnpj: string;
    SacadoLogradouro: string;
    SacadoNumero: string;
    SacadoComplemento: string;
    SacadoBairro: string;
    SacadoCidade: string;
    SacadoUF: string;
    SacadoCEP: string;
    SacadoEndereco: string;
    Cedente: string;
    CedenteCnpj: string;
    CedenteLogradouro: string;
    CedenteNumero: string;
    CedenteComplemento: string;
    CedenteBairro: string;
    CedenteCidade: string;
    CedenteUF: string;
    CedenteCEP: string;
    CedenteEndereco: string;
    BancoCodigo: string;
    BancoCodigoExibicao: string;
    BancoNome: string;
    Agencia: string;
    Conta: string;
    AgenciaCodigoBeneficiario: string;
    Carteira: string;
    CodigoCedente: string;
    NossoNumero: string;
    NumeroDocumento: string;
    NumeroBoleto: string;
    Emissao: string;
    Vencimento: string;
    DataProcessamento: string;
    Valor: string;
    ValorNumerico: Double;
    LocalPagamento: string;
    Instrucao1: string;
    Instrucao2: string;
    LinhaDigitavel: string;
    CodigoBarras: string;
    Observacao: string;
    Situacao: string;
    EspecieMoeda: string;
    EspecieDoc: string;
    Aceite: string;
  end;

  TBoletoImpressao = class
  public
    class function CarregarDados(AEmpCodigo, ABolContador: Integer): TBoletoImpressaoDados;
    class function GerarPaginasTitulo(AEmpCodigo, ACrNumero: Integer): TListaPaginasImpressao;
    class function GerarPaginasBoletos(const ADados: TArray<TBoletoImpressaoDados>): TListaPaginasImpressao;
    class procedure VisualizarTitulo(AEmpCodigo, ACrNumero: Integer; const ATitulo: string = '');
  end;

implementation

uses
  Winapi.Windows, System.Math, Data.DB, FireDAC.Comp.Client, UdmConexao,
  UFormatacaoMoeda, UMapaPessoas, Vcl.Forms, Vcl.Printers, Vcl.Dialogs, UfrmVisualizarImpressao,
  UBoletoRelatorioFr3;

const
  BOLETO_PAGE_LARGURA = IMPRESSAO_PREVIEW_LARGURA;
  BOLETO_PAGE_ALTURA = 780;
  BOLETO_PREVIEW_ESCALA = 2;
  BOLETO_MARGEM = 24;
  BOLETO_COL_VALOR = 178;
  BOLETO_ALT_HEADER = 32;
  BOLETO_ALT_LINHA = 24;
  BOLETO_ALT_LINHA_ALTA = 72;
  BOLETO_ALT_BARCODE = 58;
  COR_SICOOB_VERDE = TColor($0000A060);
  COR_SICOOB_AZUL = TColor($00804000);

type
  TRenderBoleto = class
  private
    FCanvas: TCanvas;
    FPageWidth: Integer;
    FPageHeight: Integer;
    FMargem: Integer;
    FModoPreview: Boolean;
    FPaginas: TListaPaginasImpressao;
    FEscalaPreview: Integer;
    procedure AplicarEscalaPreview;
    function LarguraUtil: Integer;
    function ColValor: Integer;
    function Direita: Integer;
    procedure NovaPagina;
    procedure DefinirFonte(ATamanho: Integer; ANegrito: Boolean; const ANomeFonte: string = 'Arial');
    procedure Texto(const AX, AY: Integer; const ATexto: string);
    procedure TextoDireita(AXDireita, AY: Integer; const ATexto: string);
    procedure TextoCentro(const ARect: TRect; AY: Integer; const ATexto: string);
    procedure LinhaHorizontal(const ALeft, ARight, AY: Integer; ADashed: Boolean = False);
    procedure Caixa(const ARect: TRect);
    procedure Celula(const ARect: TRect; const ARotulo, AValor: string;
      AValorNegrito: Boolean = True; AValorDireita: Boolean = False; AAltValor: Integer = 11);
    procedure CelulaInstrucoes(const ARect: TRect; const ARotulo: string; const ATextos: TArray<string>);
    procedure DesenharLogoBanco(const ARect: TRect; ADados: TBoletoImpressaoDados);
    function DesenharCabecalhoFebraban(const ATop: Integer; ADados: TBoletoImpressaoDados): Integer;
    function DesenharReciboPagador(const ATop: Integer; ADados: TBoletoImpressaoDados): Integer;
    function DesenharLinhaCorte(const ATop: Integer): Integer;
    function DesenharFichaCompensacao(const ATop: Integer; ADados: TBoletoImpressaoDados): Integer;
    procedure DesenharCodigoBarrasITF(const ACodigo: string; const ARect: TRect);
  public
    constructor Create(ACanvas: TCanvas; APageWidth, APageHeight: Integer;
      AModoPreview: Boolean; APaginas: TListaPaginasImpressao);
    procedure Renderizar(ADados: TBoletoImpressaoDados);
    class function GerarPaginas(const ADados: TArray<TBoletoImpressaoDados>): TListaPaginasImpressao;
  end;

  TBoletoPreviewContext = class
  public
    Paginas: TListaPaginasImpressao;
    procedure Imprimir(Sender: TObject);
  end;

function SomenteDigitos(const ATexto: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(ATexto) do
    if CharInSet(ATexto[I], ['0'..'9']) then
      Result := Result + ATexto[I];
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

function ValorCampo(AQuery: TFDQuery; const ANome: string): string;
begin
  if (AQuery.FindField(ANome) = nil) or AQuery.FieldByName(ANome).IsNull then
    Exit('');
  Result := Trim(AQuery.FieldByName(ANome).AsString);
end;

function ValorData(AQuery: TFDQuery; const ANome: string): string;
begin
  if (AQuery.FindField(ANome) = nil) or AQuery.FieldByName(ANome).IsNull then
    Exit('');
  Result := FormatDateTime('dd/mm/yyyy', AQuery.FieldByName(ANome).AsDateTime);
end;

function MontarEndereco(const ALogradouro, ANumero, ABairro, ACidade, AUF, ACEP: string): string;
var
  Partes: TArray<string>;
  I: Integer;
begin
  SetLength(Partes, 0);
  if Trim(ALogradouro) <> '' then
  begin
    if Trim(ANumero) <> '' then
      Partes := Partes + [Trim(ALogradouro) + ', ' + Trim(ANumero)]
    else
      Partes := Partes + [Trim(ALogradouro)];
  end;
  if Trim(ABairro) <> '' then
    Partes := Partes + [Trim(ABairro)];
  if Trim(ACidade) <> '' then
  begin
    if Trim(AUF) <> '' then
      Partes := Partes + [Trim(ACidade) + '/' + Trim(AUF)]
    else
      Partes := Partes + [Trim(ACidade)];
  end;
  if Trim(ACEP) <> '' then
    Partes := Partes + ['CEP: ' + FormatarCep(ACEP)];
  Result := '';
  for I := 0 to High(Partes) do
  begin
    if Result <> '' then
      Result := Result + ' - ';
    Result := Result + Partes[I];
  end;
end;

procedure AplicarEnderecoSacado(const AEndereco: TEnderecoPessoa; ADados: TBoletoImpressaoDados);
begin
  ADados.SacadoLogradouro := AEndereco.Logradouro;
  ADados.SacadoNumero := AEndereco.Numero;
  ADados.SacadoComplemento := AEndereco.Complemento;
  ADados.SacadoBairro := AEndereco.Bairro;
  ADados.SacadoCidade := AEndereco.Cidade;
  ADados.SacadoUF := AEndereco.Uf;
  ADados.SacadoCEP := AEndereco.Cep;
  ADados.SacadoEndereco := MontarEndereco(AEndereco.Logradouro, AEndereco.Numero,
    AEndereco.Bairro, AEndereco.Cidade, AEndereco.Uf, AEndereco.Cep);
end;

procedure AplicarEnderecoCedente(const AEndereco: TEnderecoPessoa; ADados: TBoletoImpressaoDados);
begin
  ADados.CedenteLogradouro := AEndereco.Logradouro;
  ADados.CedenteNumero := AEndereco.Numero;
  ADados.CedenteComplemento := AEndereco.Complemento;
  ADados.CedenteBairro := AEndereco.Bairro;
  ADados.CedenteCidade := AEndereco.Cidade;
  ADados.CedenteUF := AEndereco.Uf;
  ADados.CedenteCEP := AEndereco.Cep;
  ADados.CedenteEndereco := MontarEndereco(AEndereco.Logradouro, AEndereco.Numero,
    AEndereco.Bairro, AEndereco.Cidade, AEndereco.Uf, AEndereco.Cep);
end;

function CodigoBancoExibicao(const ACodigoBanco, ALinhaDigitavel: string): string;
var
  D, Cod: string;
begin
  D := SomenteDigitos(ALinhaDigitavel);
  if Length(D) >= 4 then
    Exit(Copy(D, 1, 3) + '-' + Copy(D, 4, 1));
  Cod := SomenteDigitos(ACodigoBanco);
  if Length(Cod) >= 3 then
    Exit(Copy(Cod, 1, 3) + '-0');
  if Cod <> '' then
    Exit(Cod + '-0');
  Result := '';
end;

function FormatarAgenciaCodigoBeneficiario(const AAgencia, AConta, ACodigoCedente: string): string;
begin
  Result := Trim(AAgencia);
  if ACodigoCedente <> '' then
  begin
    if Result <> '' then
      Result := Result + ' / ' + ACodigoCedente
    else
      Result := ACodigoCedente;
  end
  else if AConta <> '' then
  begin
    if Result <> '' then
      Result := Result + ' / ' + AConta
    else
      Result := AConta;
  end;
end;

type
  TMapaCamposPessoaBoleto = class
  private
    class var FCampos: TStringList;
    class var FCarregado: Boolean;
    class procedure GarantirCarregado;
    class function TemCampo(const ANome: string): Boolean;
    class function PrimeiroCampo(const ANomes: array of string): string;
    class function ExprCampo(const AAlias: string; const ANomes: array of string;
      const AAliasSql: string): string;
  public
    class function MontarSelectEndereco(const AAlias, APref: string): string;
  end;

class procedure TMapaCamposPessoaBoleto.GarantirCarregado;
var
  Q: TFDQuery;
begin
  if FCarregado then
    Exit;
  if not dmConexao.Conectado then
    Exit;
  FCampos := TStringList.Create;
  FCampos.CaseSensitive := False;
  FCampos.Sorted := True;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT TRIM(R.RDB$FIELD_NAME) AS CAMPO ' +
      'FROM RDB$RELATION_FIELDS R ' +
      'WHERE R.RDB$RELATION_NAME = ''PESSOA''';
    Q.Open;
    while not Q.Eof do
    begin
      FCampos.Add(Trim(Q.FieldByName('CAMPO').AsString));
      Q.Next;
    end;
    FCarregado := True;
  finally
    Q.Free;
  end;
end;

class function TMapaCamposPessoaBoleto.TemCampo(const ANome: string): Boolean;
begin
  GarantirCarregado;
  Result := FCampos.IndexOf(ANome) >= 0;
end;

class function TMapaCamposPessoaBoleto.PrimeiroCampo(const ANomes: array of string): string;
var
  I: Integer;
begin
  GarantirCarregado;
  for I := Low(ANomes) to High(ANomes) do
    if TemCampo(ANomes[I]) then
      Exit(ANomes[I]);
  Result := '';
end;

class function TMapaCamposPessoaBoleto.ExprCampo(const AAlias: string;
  const ANomes: array of string; const AAliasSql: string): string;
var
  Campo: string;
begin
  Campo := PrimeiroCampo(ANomes);
  if Campo <> '' then
    Result := Format('%s.%s AS %s', [AAlias, Campo, AAliasSql])
  else
    Result := Format('CAST(NULL AS VARCHAR(120) CHARACTER SET WIN1252) AS %s', [AAliasSql]);
end;

class function TMapaCamposPessoaBoleto.MontarSelectEndereco(const AAlias,
  APref: string): string;
begin
  Result :=
    ExprCampo(AAlias, ['PESENDERECO', 'PESLOGRADOURO', 'ENDERECO', 'LOGRADOURO', 'RUA'],
      APref + '_LOG') + ', ' +
    ExprCampo(AAlias, ['PESNUMERO', 'NUMERO', 'NUM'], APref + '_NUM') + ', ' +
    ExprCampo(AAlias, ['PESBAIRRO', 'BAIRRO'], APref + '_BAIRRO') + ', ' +
    ExprCampo(AAlias, ['PESCIDADE', 'CIDADE', 'MUNICIPIO'], APref + '_CIDADE') + ', ' +
    ExprCampo(AAlias, ['PESUF', 'UF', 'ESTADO'], APref + '_UF') + ', ' +
    ExprCampo(AAlias, ['PESCEP', 'CEP'], APref + '_CEP');
end;

class function TBoletoImpressao.CarregarDados(AEmpCodigo, ABolContador: Integer): TBoletoImpressaoDados;
var
  Q: TFDQuery;
  EndSacado, EndCedente: TEnderecoPessoa;
  PesSacado, PesCedente: Integer;
begin
  Result := TBoletoImpressaoDados.Create;
  Result.EspecieMoeda := 'R$';
  Result.EspecieDoc := 'DM';
  Result.Aceite := 'N';

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text :=
      'SELECT FIRST 1 ' +
      'CR.CRDOCUMENTO, CR.PCCODIGO, B.BOLCONTADOR, B.BOLNOSSONUMERO, B.BOLNUMERO, B.BOLVENCIMENTO, B.BOLVALOR, B.BOLDATA, ' +
      'B.BOLLINHADIGITAVEL, B.BOLCODBARRAS, B.BOLNUMERODOCUMENTO, B.BOLSITUACAO, B.BOLOBSERVACAO, ' +
      'CART.CARTLOCALPAGAMENTO, CART.CARTINSTRUCAO1, CART.CARTINSTRUCAO2, CART.CARTCODIGOCEDENTE, CART.CARTNUMERO, ' +
      'CBAN.CBAGENCIA, CBAN.CBCONTA, BN.BANCOCODIGO, BN.BANCODESCRICAO, ' +
      'SAC.PCDESCRICAO AS SACADO, ' +
      TMapaCamposPessoaBoleto.ExprCampo('SAC_P', ['PESCNPJCPF', 'CNPJ_CPF', 'CPF_CNPJ'], 'SACADO_CPF') + ', ' +
      'COALESCE(SAC_P.PESCODIGO, C.PESCODIGO) AS SACADO_PESCODIGO, ' +
      'CED.PESNOME AS CEDENTE, ' +
      TMapaCamposPessoaBoleto.ExprCampo('CED', ['PESCNPJCPF', 'CNPJ_CPF', 'CPF_CNPJ'], 'CEDENTE_CNPJ') + ', ' +
      'CED.PESCODIGO AS CEDENTE_PESCODIGO ' +
      'FROM BOLETO B ' +
      'JOIN CRBOLETO CB ON CB.EMPCODIGO = B.EMPCODIGO AND CB.BOLCONTADOR = B.BOLCONTADOR ' +
      'JOIN CONTASRECEBER CR ON CR.EMPCODIGO = CB.EMPCODIGO AND CR.CRNUMERO = CB.CRNUMERO ' +
      'JOIN CARTEIRA CART ON CART.EMPCODIGO = CB.EMPCODIGO AND CART.CONTCCODIGO = CB.CONTCCODIGO ' +
      'AND CART.CARTCODIGO = CB.CARTCODIGO ' +
      'LEFT JOIN CONTABANCARIA CBAN ON CBAN.EMPCODIGO = CB.EMPCODIGO AND CBAN.CONTCCODIGO = CB.CONTCCODIGO ' +
      'LEFT JOIN BANCO BN ON BN.BANCOCODIGO = CBAN.BANCOCODIGO ' +
      'LEFT JOIN PLANOCONTAS SAC ON SAC.EMPCODIGO = CR.EMPCODIGO AND SAC.PCCODIGO = CR.PCCODIGO ' +
      'LEFT JOIN PESSOA SAC_P ON SAC_P.PESCODIGO = CR.PCCODIGO ' +
      'LEFT JOIN CLIENTE C ON C.EMPCODIGO = CR.EMPCODIGO AND C.CLICODIGO = CR.PCCODIGO ' +
      'LEFT JOIN EMPRESAPESSOA EP ON EP.EMPCODIGO = CR.EMPCODIGO ' +
      'LEFT JOIN PESSOA CED ON CED.PESCODIGO = EP.PESCODIGO ' +
      'WHERE B.EMPCODIGO = :EMPCODIGO AND B.BOLCONTADOR = :BOLCONTADOR';
    Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    Q.ParamByName('BOLCONTADOR').AsInteger := ABolContador;
    Q.Open;
    if Q.IsEmpty then
      Exit;

    Result.Documento := FormatarDocumentoConsulta(ValorCampo(Q, 'CRDOCUMENTO'));
    Result.Sacado := ValorCampo(Q, 'SACADO');
    Result.SacadoCpfCnpj := FormatarCpfCnpj(ValorCampo(Q, 'SACADO_CPF'));

    PesSacado := StrToIntDef(ValorCampo(Q, 'SACADO_PESCODIGO'), 0);
    EndSacado := TMapaPessoas.CarregarEndereco(AEmpCodigo, PesSacado);
    AplicarEnderecoSacado(EndSacado, Result);

    Result.Cedente := ValorCampo(Q, 'CEDENTE');
    Result.CedenteCnpj := FormatarCpfCnpj(ValorCampo(Q, 'CEDENTE_CNPJ'));

    PesCedente := StrToIntDef(ValorCampo(Q, 'CEDENTE_PESCODIGO'), 0);
    EndCedente := TMapaPessoas.CarregarEndereco(AEmpCodigo, PesCedente);
    AplicarEnderecoCedente(EndCedente, Result);

    Result.BancoCodigo := ValorCampo(Q, 'BANCOCODIGO');
    Result.BancoNome := ValorCampo(Q, 'BANCODESCRICAO');
    Result.Agencia := ValorCampo(Q, 'CBAGENCIA');
    Result.Conta := ValorCampo(Q, 'CBCONTA');
    Result.Carteira := ValorCampo(Q, 'CARTNUMERO');
    Result.CodigoCedente := ValorCampo(Q, 'CARTCODIGOCEDENTE');
    Result.AgenciaCodigoBeneficiario := FormatarAgenciaCodigoBeneficiario(
      Result.Agencia, Result.Conta, Result.CodigoCedente);
    Result.NossoNumero := ValorCampo(Q, 'BOLNOSSONUMERO');
    Result.NumeroDocumento := ValorCampo(Q, 'BOLNUMERODOCUMENTO');
    if Result.NumeroDocumento = '' then
      Result.NumeroDocumento := Result.Documento;
    Result.NumeroBoleto := ValorCampo(Q, 'BOLNUMERO');
    Result.Emissao := ValorData(Q, 'BOLDATA');
    Result.Vencimento := ValorData(Q, 'BOLVENCIMENTO');
    Result.DataProcessamento := Result.Emissao;
    Result.ValorNumerico := Q.FieldByName('BOLVALOR').AsFloat;
    Result.Valor := FormatarMoedaBRL(Result.ValorNumerico);
    Result.LocalPagamento := ValorCampo(Q, 'CARTLOCALPAGAMENTO');
    if Result.LocalPagamento = '' then
      Result.LocalPagamento := 'Pag'#225'vel em qualquer ag'#234'ncia banc'#225'ria at'#233' o vencimento';
    Result.Instrucao1 := ValorCampo(Q, 'CARTINSTRUCAO1');
    Result.Instrucao2 := ValorCampo(Q, 'CARTINSTRUCAO2');
    Result.LinhaDigitavel := ValorCampo(Q, 'BOLLINHADIGITAVEL');
    Result.CodigoBarras := ValorCampo(Q, 'BOLCODBARRAS');
    if Result.CodigoBarras = '' then
      Result.CodigoBarras := LinhaDigitavelParaCodigoBarras(Result.LinhaDigitavel);
    Result.Observacao := ValorCampo(Q, 'BOLOBSERVACAO');
    Result.Situacao := TMapaReceber.DescricaoSituacaoBoleto(Q.FieldByName('BOLSITUACAO').AsInteger);
    Result.BancoCodigoExibicao := CodigoBancoExibicao(Result.BancoCodigo, Result.LinhaDigitavel);
  finally
    Q.Free;
  end;
end;

class function TBoletoImpressao.GerarPaginasBoletos(
  const ADados: TArray<TBoletoImpressaoDados>): TListaPaginasImpressao;
begin
  Result := TRenderBoleto.GerarPaginas(ADados);
end;

class function TBoletoImpressao.GerarPaginasTitulo(AEmpCodigo, ACrNumero: Integer): TListaPaginasImpressao;
var
  Boletos: TArray<TInfoBoletoReceber>;
  Lista: TList<TBoletoImpressaoDados>;
  I: Integer;
  Arr: TArray<TBoletoImpressaoDados>;
begin
  Lista := TList<TBoletoImpressaoDados>.Create;
  try
    Boletos := TMapaReceber.CarregarBoletos(AEmpCodigo, ACrNumero);
    if Length(Boletos) = 0 then
      raise Exception.Create('Nenhum boleto encontrado para este titulo.');

    for I := 0 to High(Boletos) do
      Lista.Add(CarregarDados(AEmpCodigo, Boletos[I].BolContador));

    if Lista.Count = 0 then
      raise Exception.Create('Nao foi possivel carregar os dados do boleto.');

    Arr := Lista.ToArray;
    Result := GerarPaginasBoletos(Arr);
    for I := 0 to Lista.Count - 1 do
      Lista[I].Free;
  finally
    Lista.Free;
  end;
end;

procedure TBoletoPreviewContext.Imprimir(Sender: TObject);
begin
  TImpressaoPagina.ImprimirPaginasPreview(Paginas);
end;

class procedure TBoletoImpressao.VisualizarTitulo(AEmpCodigo, ACrNumero: Integer;
  const ATitulo: string);
begin
  TBoletoRelatorioFr3.VisualizarTitulo(AEmpCodigo, ACrNumero, ATitulo);
end;

constructor TRenderBoleto.Create(ACanvas: TCanvas; APageWidth, APageHeight: Integer;
  AModoPreview: Boolean; APaginas: TListaPaginasImpressao);
begin
  inherited Create;
  FCanvas := ACanvas;
  FPageWidth := APageWidth;
  FPageHeight := APageHeight;
  FMargem := BOLETO_MARGEM;
  FModoPreview := AModoPreview;
  FPaginas := APaginas;
  FEscalaPreview := BOLETO_PREVIEW_ESCALA;
end;

procedure TRenderBoleto.AplicarEscalaPreview;
begin
  if FEscalaPreview <= 1 then
    Exit;
  SetMapMode(FCanvas.Handle, MM_ANISOTROPIC);
  SetWindowExtEx(FCanvas.Handle, FPageWidth, FPageHeight, nil);
  SetViewportExtEx(FCanvas.Handle, FPageWidth * FEscalaPreview, FPageHeight * FEscalaPreview, nil);
end;

function TRenderBoleto.LarguraUtil: Integer;
begin
  Result := FPageWidth - (FMargem * 2);
end;

function TRenderBoleto.ColValor: Integer;
begin
  Result := FMargem + LarguraUtil - BOLETO_COL_VALOR;
end;

function TRenderBoleto.Direita: Integer;
begin
  Result := FPageWidth - FMargem;
end;

procedure TRenderBoleto.NovaPagina;
var
  Bmp: Vcl.Graphics.TBitmap;
begin
  if not FModoPreview then
    Exit;

  Bmp := Vcl.Graphics.TBitmap.Create;
  TImpressaoPagina.PrepararBitmapPagina(Bmp,
    FPageWidth * FEscalaPreview, FPageHeight * FEscalaPreview);
  FPaginas.Add(Bmp);
  FCanvas := Bmp.Canvas;
  AplicarEscalaPreview;
end;

procedure TRenderBoleto.DefinirFonte(ATamanho: Integer; ANegrito: Boolean; const ANomeFonte: string);
begin
  if ANegrito then
    FCanvas.Font.Style := [fsBold]
  else
    FCanvas.Font.Style := [];
  FCanvas.Font.Name := ANomeFonte;
  FCanvas.Font.Size := ATamanho;
  FCanvas.Font.Color := clBlack;
  FCanvas.Font.Quality := fqClearTypeNatural;
end;

procedure TRenderBoleto.Texto(const AX, AY: Integer; const ATexto: string);
begin
  FCanvas.TextOut(AX, AY, ATexto);
end;

procedure TRenderBoleto.TextoDireita(AXDireita, AY: Integer; const ATexto: string);
begin
  Texto(AXDireita - FCanvas.TextWidth(ATexto), AY, ATexto);
end;

procedure TRenderBoleto.TextoCentro(const ARect: TRect; AY: Integer; const ATexto: string);
begin
  Texto(ARect.Left + ((ARect.Right - ARect.Left) - FCanvas.TextWidth(ATexto)) div 2, AY, ATexto);
end;

procedure TRenderBoleto.LinhaHorizontal(const ALeft, ARight, AY: Integer; ADashed: Boolean);
begin
  FCanvas.Pen.Color := clBlack;
  FCanvas.Pen.Width := 1;
  if ADashed then
    FCanvas.Pen.Style := psDash
  else
    FCanvas.Pen.Style := psSolid;
  FCanvas.MoveTo(ALeft, AY);
  FCanvas.LineTo(ARight, AY);
  FCanvas.Pen.Style := psSolid;
end;

procedure TRenderBoleto.Caixa(const ARect: TRect);
begin
  FCanvas.Pen.Color := clBlack;
  FCanvas.Pen.Width := 1;
  FCanvas.Brush.Style := bsClear;
  FCanvas.Rectangle(ARect);
end;

procedure TRenderBoleto.Celula(const ARect: TRect; const ARotulo, AValor: string;
  AValorNegrito, AValorDireita: Boolean; AAltValor: Integer);
var
  R: TRect;
begin
  Caixa(ARect);
  R := ARect;
  InflateRect(R, -3, -2);
  DefinirFonte(6, False);
  Texto(R.Left, R.Top, ARotulo);
  if AValorNegrito then
    DefinirFonte(8, True)
  else
    DefinirFonte(8, False);
  if AValorDireita then
    TextoDireita(R.Right, R.Top + AAltValor, AValor)
  else
    Texto(R.Left, R.Top + AAltValor, Copy(AValor, 1, 120));
end;

procedure TRenderBoleto.CelulaInstrucoes(const ARect: TRect; const ARotulo: string;
  const ATextos: TArray<string>);
var
  R: TRect;
  I, Y: Integer;
  Linha: string;
begin
  Caixa(ARect);
  R := ARect;
  InflateRect(R, -3, -2);
  DefinirFonte(6, False);
  Texto(R.Left, R.Top, ARotulo);
  Y := R.Top + 10;
  DefinirFonte(7, False);
  for I := 0 to High(ATextos) do
  begin
    Linha := Trim(ATextos[I]);
    if Linha = '' then
      Continue;
    Texto(R.Left, Y, Copy(Linha, 1, 95));
    Inc(Y, 11);
    if Y > R.Bottom - 10 then
      Break;
  end;
end;

procedure TRenderBoleto.DesenharLogoBanco(const ARect: TRect; ADados: TBoletoImpressaoDados);
var
  Pts: array[0..2] of TPoint;
  CX, CY, Tamanho: Integer;
  NomeBanco: string;
begin
  Caixa(ARect);
  if SomenteDigitos(ADados.BancoCodigo) = '756' then
  begin
    CX := ARect.Left + 28;
    CY := ARect.Top + (ARect.Bottom - ARect.Top) div 2;
    Tamanho := 10;
    FCanvas.Brush.Color := COR_SICOOB_VERDE;
    FCanvas.Pen.Color := COR_SICOOB_VERDE;

    Pts[0] := Point(CX, CY - Tamanho);
    Pts[1] := Point(CX - Tamanho, CY + Tamanho div 2);
    Pts[2] := Point(CX + Tamanho, CY + Tamanho div 2);
    FCanvas.Polygon(Pts);

    Pts[0] := Point(CX - 14, CY - Tamanho + 4);
    Pts[1] := Point(CX - 14 - Tamanho, CY + Tamanho div 2 + 4);
    Pts[2] := Point(CX - 14 + Tamanho, CY + Tamanho div 2 + 4);
    FCanvas.Polygon(Pts);

    Pts[0] := Point(CX + 14, CY - Tamanho + 4);
    Pts[1] := Point(CX + 14 - Tamanho, CY + Tamanho div 2 + 4);
    Pts[2] := Point(CX + 14 + Tamanho, CY + Tamanho div 2 + 4);
    FCanvas.Polygon(Pts);

    DefinirFonte(11, True);
    FCanvas.Font.Color := COR_SICOOB_AZUL;
    Texto(ARect.Left + 52, ARect.Top + 8, 'SICOOB');
    FCanvas.Font.Color := clBlack;
  end
  else
  begin
    NomeBanco := ADados.BancoNome;
    if NomeBanco = '' then
      NomeBanco := 'Banco';
    DefinirFonte(10, True);
    Texto(ARect.Left + 8, ARect.Top + 9, Copy(NomeBanco, 1, 22));
  end;
end;

function TRenderBoleto.DesenharCabecalhoFebraban(const ATop: Integer;
  ADados: TBoletoImpressaoDados): Integer;
var
  RLogo, RCodigo, RLinha: TRect;
  LinhaExibicao: string;
begin
  RLogo := Rect(FMargem, ATop, FMargem + 168, ATop + BOLETO_ALT_HEADER);
  RCodigo := Rect(RLogo.Right, ATop, RLogo.Right + 58, ATop + BOLETO_ALT_HEADER);
  RLinha := Rect(RCodigo.Right, ATop, Direita, ATop + BOLETO_ALT_HEADER);

  DesenharLogoBanco(RLogo, ADados);
  Caixa(RCodigo);
  DefinirFonte(14, True);
  TextoCentro(RCodigo, ATop + 8, ADados.BancoCodigoExibicao);

  Caixa(RLinha);
  LinhaExibicao := FormatarLinhaDigitavelExibicao(ADados.LinhaDigitavel);
  DefinirFonte(11, True);
  TextoCentro(RLinha, ATop + 9, LinhaExibicao);

  Result := ATop + BOLETO_ALT_HEADER;
end;

function TRenderBoleto.DesenharReciboPagador(const ATop: Integer;
  ADados: TBoletoImpressaoDados): Integer;
var
  Y, X, W, C1, C2, C3, C4: Integer;
  R: TRect;
  PagadorTexto: string;
begin
  Y := DesenharCabecalhoFebraban(ATop, ADados);
  W := LarguraUtil;
  X := FMargem;

  C1 := X + Round(W * 0.12);
  C2 := X + Round(W * 0.30);
  C3 := X + Round(W * 0.58);
  C4 := X + Round(W * 0.78);

  R := Rect(X, Y, C1, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Vencimento', ADados.Vencimento);
  R := Rect(C1, Y, C2, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Ag'#234'ncia/C'#243'digo Benefici'#225'rio', ADados.AgenciaCodigoBeneficiario);
  R := Rect(C2, Y, C3, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Benefici'#225'rio', ADados.Cedente);
  R := Rect(C3, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, 'CNPJ/CPF do Benefici'#225'rio', ADados.CedenteCnpj);
  Inc(Y, BOLETO_ALT_LINHA);

  R := Rect(X, Y, C4, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Endere'#231'o do Benefici'#225'rio', ADados.CedenteEndereco);
  R := Rect(C4, Y, C4 + Round(W * 0.08), Y + BOLETO_ALT_LINHA);
  Celula(R, 'Esp'#233'cie', ADados.EspecieMoeda);
  R := Rect(C4 + Round(W * 0.08), Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Quantidade', '');
  Inc(Y, BOLETO_ALT_LINHA);

  C1 := X + Round(W * 0.16);
  C2 := X + Round(W * 0.32);
  C3 := X + Round(W * 0.48);
  C4 := X + Round(W * 0.64);
  R := Rect(X, Y, C1, Y + BOLETO_ALT_LINHA);
  Celula(R, '(=) Valor do Documento', ADados.Valor, True, True);
  R := Rect(C1, Y, C2, Y + BOLETO_ALT_LINHA);
  Celula(R, '(-) Desconto/Abatimento', '', True, True);
  R := Rect(C2, Y, C3, Y + BOLETO_ALT_LINHA);
  Celula(R, '(+) Juros/Multa', '', True, True);
  R := Rect(C3, Y, C4, Y + BOLETO_ALT_LINHA);
  Celula(R, '(=) Valor Cobrado', ADados.Valor, True, True);
  R := Rect(C4, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Nosso N'#250'mero', ADados.NossoNumero);
  Inc(Y, BOLETO_ALT_LINHA);

  C2 := X + Round(W * 0.22);
  R := Rect(X, Y, C2, Y + BOLETO_ALT_LINHA);
  Celula(R, 'N'#186' do Documento', ADados.NumeroDocumento);
  PagadorTexto := ADados.Sacado;
  if ADados.SacadoCpfCnpj <> '' then
    PagadorTexto := PagadorTexto + '  CPF/CNPJ: ' + ADados.SacadoCpfCnpj;
  R := Rect(C2, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Pagador', PagadorTexto);
  Inc(Y, BOLETO_ALT_LINHA);

  DefinirFonte(6, False);
  TextoDireita(Direita, Y + 4, 'Autentica'#231#227'o Mec'#226'nica - Recibo do Pagador');
  Result := Y + 16;
end;

function TRenderBoleto.DesenharLinhaCorte(const ATop: Integer): Integer;
begin
  LinhaHorizontal(FMargem, Direita, ATop + 6, True);
  DefinirFonte(6, False);
  Texto(FMargem, ATop + 10, 'Corte na linha pontilhada');
  Result := ATop + 24;
end;

function TRenderBoleto.DesenharFichaCompensacao(const ATop: Integer;
  ADados: TBoletoImpressaoDados): Integer;
var
  Y, X, W, CV, C1, C2, C3, C4, C5: Integer;
  R: TRect;
  Instrucoes: TArray<string>;
  PagadorTexto: string;
  I, Qtd: Integer;
  Linha: string;
begin
  Y := DesenharCabecalhoFebraban(ATop, ADados);
  X := FMargem;
  W := LarguraUtil;
  CV := ColValor;

  R := Rect(X, Y, CV - 1, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Local do Pagamento', ADados.LocalPagamento);
  R := Rect(CV, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Vencimento', ADados.Vencimento, True, True);
  Inc(Y, BOLETO_ALT_LINHA);

  R := Rect(X, Y, CV - 1, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Benefici'#225'rio', ADados.Cedente + '  ' + ADados.CedenteCnpj);
  R := Rect(CV, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Ag'#234'ncia/C'#243'digo Benefici'#225'rio', ADados.AgenciaCodigoBeneficiario, True, True);
  Inc(Y, BOLETO_ALT_LINHA);

  R := Rect(X, Y, CV - 1, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Endere'#231'o do Benefici'#225'rio', ADados.CedenteEndereco);
  R := Rect(CV, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Nosso N'#250'mero', ADados.NossoNumero, True, True);
  Inc(Y, BOLETO_ALT_LINHA);

  C1 := X + Round((CV - X) * 0.18);
  C2 := X + Round((CV - X) * 0.38);
  C3 := X + Round((CV - X) * 0.54);
  C4 := X + Round((CV - X) * 0.68);
  C5 := X + Round((CV - X) * 0.84);
  R := Rect(X, Y, C1, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Data do Documento', ADados.Emissao);
  R := Rect(C1, Y, C2, Y + BOLETO_ALT_LINHA);
  Celula(R, 'N'#186' do Documento', ADados.NumeroDocumento);
  R := Rect(C2, Y, C3, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Esp'#233'cie Doc.', ADados.EspecieDoc);
  R := Rect(C3, Y, C4, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Aceite', ADados.Aceite);
  R := Rect(C4, Y, CV - 1, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Data do Processamento', ADados.DataProcessamento);
  R := Rect(CV, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, '(=) Valor do Documento', ADados.Valor, True, True);
  Inc(Y, BOLETO_ALT_LINHA);

  C1 := X + Round((CV - X) * 0.16);
  C2 := X + Round((CV - X) * 0.32);
  C3 := X + Round((CV - X) * 0.48);
  C4 := X + Round((CV - X) * 0.64);
  R := Rect(X, Y, C1, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Uso do Banco', '');
  R := Rect(C1, Y, C2, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Carteira', ADados.Carteira);
  R := Rect(C2, Y, C3, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Esp'#233'cie', ADados.EspecieMoeda);
  R := Rect(C3, Y, C4, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Quantidade', '');
  R := Rect(C4, Y, CV - 1, Y + BOLETO_ALT_LINHA);
  Celula(R, 'Valor', '');
  R := Rect(CV, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, '(-) Desconto/Abatimento', '', True, True);
  Inc(Y, BOLETO_ALT_LINHA);

  Qtd := 0;
  SetLength(Instrucoes, 0);
  if ADados.Instrucao1 <> '' then
  begin
    SetLength(Instrucoes, Qtd + 1);
    Instrucoes[Qtd] := ADados.Instrucao1;
    Inc(Qtd);
  end;
  if ADados.Instrucao2 <> '' then
  begin
    SetLength(Instrucoes, Qtd + 1);
    Instrucoes[Qtd] := ADados.Instrucao2;
    Inc(Qtd);
  end;
  if ADados.Observacao <> '' then
  begin
    Linha := ADados.Observacao;
    while Linha <> '' do
    begin
      I := Pos('|', Linha);
      if I > 0 then
      begin
        SetLength(Instrucoes, Qtd + 1);
        Instrucoes[Qtd] := Trim(Copy(Linha, 1, I - 1));
        Inc(Qtd);
        Delete(Linha, 1, I);
      end
      else
      begin
        SetLength(Instrucoes, Qtd + 1);
        Instrucoes[Qtd] := Trim(Linha);
        Inc(Qtd);
        Linha := '';
      end;
    end;
  end;

  R := Rect(X, Y, CV - 1, Y + BOLETO_ALT_LINHA_ALTA);
  CelulaInstrucoes(R, 'Instru'#231#245'es (Texto de Responsabilidade do Benefici'#225'rio)', Instrucoes);

  R := Rect(CV, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, '(-) Outras Dedu'#231#245'es', '', True, True);
  Inc(Y, BOLETO_ALT_LINHA);
  R := Rect(CV, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, '(+) Juros/Multa', '', True, True);
  Inc(Y, BOLETO_ALT_LINHA);
  R := Rect(CV, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, '(+) Outros Acr'#233'scimos', '', True, True);
  Inc(Y, BOLETO_ALT_LINHA);
  R := Rect(CV, Y, Direita, Y + BOLETO_ALT_LINHA);
  Celula(R, '(=) Valor Cobrado', ADados.Valor, True, True);
  Y := Y - (BOLETO_ALT_LINHA * 3);
  Inc(Y, BOLETO_ALT_LINHA_ALTA);

  PagadorTexto := ADados.Sacado;
  if ADados.SacadoCpfCnpj <> '' then
    PagadorTexto := PagadorTexto + '  CPF/CNPJ: ' + ADados.SacadoCpfCnpj;
  if ADados.SacadoEndereco <> '' then
    PagadorTexto := PagadorTexto + '  ' + ADados.SacadoEndereco;
  R := Rect(X, Y, Direita, Y + 34);
  Celula(R, 'Pagador', PagadorTexto, False, False, 10);

  Inc(Y, 34);
  R := Rect(X, Y, CV - 1, Y + 22);
  Celula(R, 'Sacador/Avalista', '', False, False, 10);
  R := Rect(CV, Y, Direita, Y + 22);
  Celula(R, 'C'#243'digo de baixa', '', False, False, 10);
  Inc(Y, 22);

  DefinirFonte(6, False);
  TextoDireita(Direita, Y + 2, 'Autentica'#231#227'o Mec'#226'nica - Ficha de Compensa'#231#227'o');
  Inc(Y, 14);

  R := Rect(X, Y, Direita, Y + BOLETO_ALT_BARCODE);
  Caixa(R);
  DesenharCodigoBarrasITF(ADados.CodigoBarras, R);
  Result := Y + BOLETO_ALT_BARCODE;
end;

function ITFPattern(ADigito: Char): string;
begin
  case ADigito of
    '0': Result := 'nnwwn';
    '1': Result := 'wnnnw';
    '2': Result := 'nwnnw';
    '3': Result := 'wwnnn';
    '4': Result := 'nnwnw';
    '5': Result := 'wnwnn';
    '6': Result := 'nwwnn';
    '7': Result := 'nnnww';
    '8': Result := 'wnnwn';
    '9': Result := 'nwnwn';
  else
    Result := 'nnnnn';
  end;
end;

procedure TRenderBoleto.DesenharCodigoBarrasITF(const ACodigo: string; const ARect: TRect);
const
  MODULO_ESTREITO = 2;
  MODULO_LARGO = 5;
var
  Codigo: string;
  I, X, YTop, YBottom, J: Integer;
  C1, C2: Char;
  P1, P2: string;
  Modulo: Integer;

  procedure AvancarModulo(ADesenharBarra, AWide: Boolean);
  begin
    Modulo := MODULO_ESTREITO;
    if AWide then
      Modulo := MODULO_LARGO;
    if ADesenharBarra then
    begin
      FCanvas.Brush.Color := clBlack;
      FCanvas.FillRect(Rect(X, YTop, X + Modulo, YBottom));
    end;
    Inc(X, Modulo);
  end;

begin
  Codigo := SomenteDigitos(ACodigo);
  if (Length(Codigo) mod 2) <> 0 then
    Codigo := '0' + Codigo;
  if Codigo = '' then
    Exit;

  YTop := ARect.Top + 6;
  YBottom := ARect.Bottom - 6;
  X := ARect.Left + 10;
  FCanvas.Brush.Color := clWhite;
  FCanvas.FillRect(ARect);

  AvancarModulo(True, False);
  AvancarModulo(False, False);
  AvancarModulo(True, False);
  AvancarModulo(False, False);

  for I := 1 to Length(Codigo) div 2 do
  begin
    C1 := Codigo[(I - 1) * 2 + 1];
    C2 := Codigo[(I - 1) * 2 + 2];
    P1 := ITFPattern(C1);
    P2 := ITFPattern(C2);
    for J := 1 to 5 do
    begin
      AvancarModulo(True, P1[J] = 'w');
      AvancarModulo(False, P2[J] = 'w');
    end;
  end;

  AvancarModulo(True, True);
  AvancarModulo(False, False);
  AvancarModulo(True, False);
end;

procedure TRenderBoleto.Renderizar(ADados: TBoletoImpressaoDados);
var
  Y: Integer;
begin
  NovaPagina;
  Y := FMargem;
  Y := DesenharReciboPagador(Y, ADados);
  Y := DesenharLinhaCorte(Y);
  DesenharFichaCompensacao(Y, ADados);
end;

class function TRenderBoleto.GerarPaginas(
  const ADados: TArray<TBoletoImpressaoDados>): TListaPaginasImpressao;
var
  Render: TRenderBoleto;
  I: Integer;
begin
  Result := TListaPaginasImpressao.Create;
  Render := TRenderBoleto.Create(nil, BOLETO_PAGE_LARGURA, BOLETO_PAGE_ALTURA, True, Result);
  try
    for I := 0 to High(ADados) do
      Render.Renderizar(ADados[I]);
  finally
    Render.Free;
  end;

  for I := 0 to Result.Count - 1 do
    TImpressaoPagina.FinalizarPaginaBitmap(Result.Pagina(I));
end;

end.
