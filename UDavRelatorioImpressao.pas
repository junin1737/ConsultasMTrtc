unit UDavRelatorioImpressao;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Generics.Collections, Data.DB,
  FireDAC.Comp.Client, Vcl.Graphics, UImpressaoUtil, UFormatacaoMoeda, UMapaDav,
  UMapaOrcamento, UMapaCompra, UMapaNotaFiscal, UCampoObservacao, UdmConexao;

type
  TDavLinhaItem = record
    Codigo: string;
    Qtde: Double;
    Unidade: string;
    Descricao: string;
    Tipo: string;
    Unitario: Double;
    Desconto: Double;
    Total: Double;
    BaseICMS: Double;
    ValorICMS: Double;
    BaseST: Double;
    ValorST: Double;
    ValorIPI: Double;
  end;

  TDavRelatorioDados = class
  public
    TituloRelatorio: string;
    EmpresaNome: string;
    EmpresaEndereco: string;
    EmpresaTelefone: string;
    Numero: string;
    Emissao: string;
    Vendedor: string;
    ClienteNome: string;
    ClienteCodigo: string;
    Endereco: string;
    Municipio: string;
    Apelido: string;
    CpfCnpj: string;
    Telefone: string;
    Vencimento: string;
    Pagamento: string;
    Observacao: string;
    Subtotal: Double;
    Desconto: Double;
    Frete: Double;
    Outros: Double;
    Total: Double;
    BaseICMS: Double;
    ValorICMS: Double;
    BaseST: Double;
    ValorST: Double;
    ValorIPI: Double;
    ValorPIS: Double;
    ValorCOFINS: Double;
    Seguro: Double;
    ChaveAcesso: string;
    RotuloParticipante: string;
    Itens: TList<TDavLinhaItem>;
    constructor Create;
    destructor Destroy; override;
  end;

  TDavRelatorioImpressao = class
  public
    class function CarregarDados(AEmpCodigo, ADavContador: Integer): TDavRelatorioDados;
    class function CarregarDadosOrcamento(AEmpCodigo, AOrcContador: Integer): TDavRelatorioDados;
    class function CarregarDadosCompra(AEmpCodigo, AEntcContador: Integer): TDavRelatorioDados;
    class function CarregarDadosNotaFiscal(AEmpCodigo, ANfContador: Integer): TDavRelatorioDados;
    class function BuscarNomeVendedor(AEmpCodigo: Integer; const AVendCodigo,
      AUsuCodigo: string): string;
    class function GerarPaginasPreview(ADados: TDavRelatorioDados): TListaPaginasImpressao;
    class procedure VisualizarPdf(ADados: TDavRelatorioDados; const ANomeArquivo: string);
    class procedure Imprimir(ADados: TDavRelatorioDados; ACanvas: TCanvas; APageWidth,
      APageHeight: Integer);
  end;

implementation

uses
  Winapi.Windows, Vcl.Printers;

const
  COR_ZEBRA = $00F0F0F0;
  COR_COMERCIAL_DESTAQUE = $00A4582C;
  COR_COMERCIAL_GRID = $009C5B35;
  COR_COMERCIAL_ZEBRA = $00F7F9FC;
  COR_COMERCIAL_FUNDO = $00FAFCFE;
  COR_COMERCIAL_TOTAL = $00F0E8DC;

type
  TRenderDav = class
  private
    FCanvas: TCanvas;
    FPageWidth: Integer;
    FPageHeight: Integer;
    FMargemEsq: Integer;
    FMargemDir: Integer;
    FPageBottom: Integer;
    FY: Integer;
    FNumeroPagina: Integer;
    FModoPreview: Boolean;
    FModoFiscal: Boolean;
    FModoComercial: Boolean;
    FPaginas: TListaPaginasImpressao;
    FGridDir: Integer;
    FColCod: Integer;
    FColDesc: Integer;
    FColCodLargura: Integer;
    FColQtdeDir: Integer;
    FColUnitDir: Integer;
    FColTotalDir: Integer;
    FColDescValDir: Integer;
    FColBaseICMSDir: Integer;
    FColICMSDir: Integer;
    FColBaseSTDir: Integer;
    FColSTDir: Integer;
    FColIPIDir: Integer;
    procedure CalcularColunasGrid;
    procedure DefinirFonte(ATamanho: Integer; ANegrito: Boolean);
    function AlturaLinha: Integer;
    procedure Avancar(APixels: Integer);
    procedure NovaPagina;
    procedure Texto(const AX, AY: Integer; const ATexto: string);
    procedure TextoDireita(AXDireita, AY: Integer; const ATexto: string);
    procedure TextoCentro(const ARect: TRect; const ATexto: string);
    procedure LinhaHorizontal;
    procedure DesenharCabecalhoPagina(const ADados: TDavRelatorioDados);
    procedure DesenharCliente(const ADados: TDavRelatorioDados);
    procedure DesenharTituloGrid;
    procedure DesenharLinhaItem(const AItem: TDavLinhaItem; AZebra: Boolean);
    procedure DesenharRodape(const ADados: TDavRelatorioDados);
    procedure DesenharRodapeFiscal(const ADados: TDavRelatorioDados);
    procedure DesenharTituloGridFiscal;
    procedure DesenharLinhaItemFiscal(const AItem: TDavLinhaItem; AZebra: Boolean);
    function EspacoRodape: Integer;
    function TotalPorTipo(const ADados: TDavRelatorioDados; const ATipo: string): Double;
    procedure DesenharContinuacaoGrid;
    function TruncarTextoColuna(const ATexto: string; ALarguraPx: Integer): string;
  public
    constructor Create(ACanvas: TCanvas; APageWidth, APageHeight: Integer;
      AModoPreview: Boolean; APaginas: TListaPaginasImpressao);
    procedure Renderizar(ADados: TDavRelatorioDados);
  end;

function CampoStr(AQuery: TFDQuery; const ANome: string): string;
var
  F: TField;
begin
  Result := '';
  if ANome = '' then
    Exit;
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
  if ANome = '' then
    Exit;
  F := AQuery.FindField(ANome);
  if (F = nil) or F.IsNull then
    Exit;
  Result := F.AsFloat;
end;

function PrimeiroCampoDisponivel(AQuery: TFDQuery;
  const ANomes: array of string): string;
var
  Nome: string;
begin
  Result := '';
  for Nome in ANomes do
    if AQuery.FindField(Nome) <> nil then
      Exit(Nome);
end;

function ValorPorCampos(AQuery: TFDQuery; const ANomes: array of string): string;
var
  Campo: string;
begin
  Campo := PrimeiroCampoDisponivel(AQuery, ANomes);
  if Campo = '' then
    Exit('');
  Result := CampoStr(AQuery, Campo);
end;

function ResolverCodigoItem(AQuery: TFDQuery; const ACampoCod: string): string;
begin
  Result := CampoStr(AQuery, 'CODIGO_ITEM');
  if Result <> '' then
    Exit;

  if ACampoCod <> '' then
    Result := CampoStr(AQuery, ACampoCod);
  if Result <> '' then
    Exit;

  Result := ValorPorCampos(AQuery,
    ['PRODCODIGO', 'PRODCOD', 'PRODREFERENCIA', 'REFERENCIA', 'CODPROD',
     'SERVCODIGO', 'SERVCOD', 'CODIGO']);
end;

function MontarEnderecoPessoa(AQuery: TFDQuery): string;
var
  Rua, Numero, Bairro, Cidade, UF: string;
begin
  Rua := ValorPorCampos(AQuery, ['PESENDERECO', 'ENDERECO', 'LOGRADOURO']);
  Numero := ValorPorCampos(AQuery, ['PESNUMERO', 'NUMERO', 'NUM']);
  Bairro := ValorPorCampos(AQuery, ['PESBAIRRO', 'BAIRRO']);
  Cidade := ValorPorCampos(AQuery, ['PESCIDADE', 'CIDADE', 'MUNICIPIO']);
  UF := ValorPorCampos(AQuery, ['PESUF', 'UF', 'ESTADO']);

  Result := Trim(Rua);
  if Numero <> '' then
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Numero;
  end;
  if Bairro <> '' then
  begin
    if Result <> '' then
      Result := Result + ' - ';
    Result := Result + Bairro;
  end;
  if (Cidade <> '') or (UF <> '') then
  begin
    if Result <> '' then
      Result := Result + ' - ';
    if (Cidade <> '') and (UF <> '') then
      Result := Result + Cidade + '/' + UF
    else
      Result := Result + Cidade + UF;
  end;
end;

procedure ComplementarDadosPessoa(APesCodigo: Integer; var AEndereco, AMunicipio, ATelefone: string);
var
  Q: TFDQuery;
begin
  if (APesCodigo <= 0) or (not dmConexao.Conectado) then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Q.SQL.Text := 'SELECT FIRST 1 * FROM PESSOA WHERE PESCODIGO = :PESCODIGO';
    Q.ParamByName('PESCODIGO').AsInteger := APesCodigo;
    Q.Open;
    if Q.IsEmpty then
      Exit;

    AEndereco := MontarEnderecoPessoa(Q);
    AMunicipio := ValorPorCampos(Q, ['PESCIDADE', 'CIDADE', 'MUNICIPIO']);
    if AMunicipio <> '' then
    begin
      if ValorPorCampos(Q, ['PESUF', 'UF']) <> '' then
        AMunicipio := Trim(AMunicipio + ' - ' + ValorPorCampos(Q, ['PESUF', 'UF']));
    end;
    ATelefone := ValorPorCampos(Q,
      ['PESFONE', 'PESTELEFONE', 'PESTEL', 'PESCELULAR', 'PESFAX', 'FONE', 'TELEFONE']);
  finally
    Q.Free;
  end;
end;

function RelatorioModoFiscal(const ATitulo: string): Boolean;
begin
  Result := SameText(ATitulo, 'NOTA FISCAL') or SameText(ATitulo, 'ENTRADA DE COMPRA');
end;

function RelatorioModoComercial(const ATitulo: string): Boolean;
begin
  Result := SameText(ATitulo, 'DAV') or SameText(ATitulo, 'ORCAMENTO');
end;

function TituloDocumentoComercial(const ADados: TDavRelatorioDados): string;
begin
  if ADados.TituloRelatorio <> '' then
    Result := ADados.TituloRelatorio + ' ' + ADados.Numero
  else
    Result := 'DAV ' + ADados.Numero;
end;

function PrimeiroUltimoNome(const ANome: string): string;
var
  Partes: TStringList;
  I, Primeiro, Ultimo: Integer;
  S: string;
begin
  Result := Trim(ANome);
  if Result = '' then
    Exit;

  Partes := TStringList.Create;
  try
    Partes.StrictDelimiter := True;
    Partes.Delimiter := ' ';
    Partes.DelimitedText := Result;
    I := 0;
    while I < Partes.Count do
    begin
      if Trim(Partes[I]) = '' then
        Partes.Delete(I)
      else
        Inc(I);
    end;

    if Partes.Count = 0 then
      Exit;
    if Partes.Count = 1 then
    begin
      Result := Trim(Partes[0]);
      Exit;
    end;

    Primeiro := 0;
    Ultimo := Partes.Count - 1;
    Result := Trim(Partes[Primeiro]) + ' ' + Trim(Partes[Ultimo]);
  finally
    Partes.Free;
  end;
end;

function NomeVendedorParaExibicao(const ANome: string): string;
begin
  Result := PrimeiroUltimoNome(ANome);
end;

function NomeClienteParaExibicao(const ANome, ACodigo, ACpfCnpj: string): string;
var
  S, Cod: string;
  P: Integer;
begin
  S := Trim(ANome);
  Cod := Trim(ACodigo);

  if (Cod <> '') and (Length(S) >= Length(Cod) + 2) and SameText(Copy(S, 1, Length(Cod)), Cod) then
  begin
    S := Trim(Copy(S, Length(Cod) + 1, MaxInt));
    if (S <> '') and (S[1] in ['-', ':']) then
      S := Trim(Copy(S, 2, MaxInt));
  end;

  if Cod <> '' then
  begin
    P := Pos(' - ' + Cod, S);
    if P > 0 then
      S := Trim(Copy(S, 1, P - 1));
  end;

  Result := S;
  if Trim(ACpfCnpj) <> '' then
  begin
    if Result <> '' then
      Result := Result + ' - ' + Trim(ACpfCnpj)
    else
      Result := Trim(ACpfCnpj);
  end;
end;

function ResolverNomeVendedor(AQuery: TFDQuery; AEmpCodigo: Integer): string;
begin
  Result := ValorPorCampos(AQuery,
    ['VENDNOME', 'NOME_VENDEDOR', 'USUNOME', 'PESNOME_VENDEDOR', 'NOMEVENDEDOR',
     'VENDEDOR', 'DAVVENDEDOR']);
  if Result = '' then
    Result := TDavRelatorioImpressao.BuscarNomeVendedor(AEmpCodigo,
      CampoStr(AQuery, 'VENDCODIGO'), CampoStr(AQuery, 'USUCODIGO'));
  Result := NomeVendedorParaExibicao(Result);
end;

class function TDavRelatorioImpressao.BuscarNomeVendedor(AEmpCodigo: Integer;
  const AVendCodigo, AUsuCodigo: string): string;
var
  Q: TFDQuery;
  Cod: Integer;
begin
  Result := '';
  if not dmConexao.Conectado then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    Cod := StrToIntDef(Trim(AVendCodigo), 0);
    if Cod > 0 then
    begin
      try
        Q.SQL.Text :=
          'SELECT FIRST 1 COALESCE(P.PESNOME, V.VENDNOME) AS PESNOME FROM VENDEDOR V ' +
          'LEFT JOIN PESSOA P ON P.PESCODIGO = V.PESCODIGO ' +
          'WHERE V.EMPCODIGO = :EMPCODIGO AND V.VENDCODIGO = :VENDCODIGO';
        Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
        Q.ParamByName('VENDCODIGO').AsInteger := Cod;
        Q.Open;
        if not Q.IsEmpty then
          Result := Trim(Q.FieldByName('PESNOME').AsString);
      except
      end;
    end;

    if Result <> '' then
      Exit(NomeVendedorParaExibicao(Result));

    Cod := StrToIntDef(Trim(AUsuCodigo), 0);
    if Cod > 0 then
    begin
      try
        Q.Close;
        Q.SQL.Text :=
          'SELECT FIRST 1 P.PESNOME FROM USUARIO U ' +
          'LEFT JOIN PESSOA P ON P.PESCODIGO = U.PESCODIGO ' +
          'WHERE U.EMPCODIGO = :EMPCODIGO AND U.USUCODIGO = :USUCODIGO';
        Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
        Q.ParamByName('USUCODIGO').AsInteger := Cod;
        Q.Open;
        if not Q.IsEmpty then
          Result := Trim(Q.FieldByName('PESNOME').AsString);
      except
      end;
    end;
  finally
    Q.Free;
  end;
end;

constructor TDavRelatorioDados.Create;
begin
  inherited Create;
  Itens := TList<TDavLinhaItem>.Create;
end;

destructor TDavRelatorioDados.Destroy;
begin
  Itens.Free;
  inherited Destroy;
end;

class function TDavRelatorioImpressao.CarregarDados(AEmpCodigo,
  ADavContador: Integer): TDavRelatorioDados;
var
  QDav, QEmp, QProd, QServ: TFDQuery;
  Item: TDavLinhaItem;
  CodCli: string;
  procedure AdicionarItem(const ACodigo, AUnidade, ADescricao, ATipo: string;
    AQtde, AUnitario, ATotal: Double);
  begin
    Item.Codigo := ACodigo;
    Item.Qtde := AQtde;
    Item.Unidade := AUnidade;
    Item.Descricao := ADescricao;
    Item.Tipo := ATipo;
    Item.Unitario := AUnitario;
    Item.Desconto := 0;
    Item.Total := ATotal;
    Item.BaseICMS := 0;
    Item.ValorICMS := 0;
    Item.BaseST := 0;
    Item.ValorST := 0;
    Item.ValorIPI := 0;
    Result.Itens.Add(Item);
    Result.Subtotal := Result.Subtotal + ATotal;
  end;

begin
  Result := TDavRelatorioDados.Create;
  Result.TituloRelatorio := 'DAV';
  if not dmConexao.Conectado then
    Exit;

  QDav := TFDQuery.Create(nil);
  QEmp := TFDQuery.Create(nil);
  QProd := TFDQuery.Create(nil);
  QServ := TFDQuery.Create(nil);
  try
    QDav.Connection := dmConexao.FDConnection1;
    QDav.SQL.Text :=
      'SELECT D.*, P.PESNOME, P.PESCODIGO, P.PESCNPJCPF, ' +
      'P.PESFONE, P.PESENDERECO, P.PESNUMERO, P.PESBAIRRO, P.PESCIDADE, P.PESUF, ' +
      'PV.PESNOME AS VENDNOME, COALESCE(PV.PESNOME, V.VENDNOME) AS NOMEVENDEDOR ' +
      'FROM DAV D ' +
      'LEFT JOIN CLIENTE C ON C.CLICODIGO = D.CLICODIGO AND C.EMPCODIGO = D.EMPCODIGO ' +
      'LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO ' +
      'LEFT JOIN VENDEDOR V ON V.VENDCODIGO = D.VENDCODIGO AND V.EMPCODIGO = D.EMPCODIGO ' +
      'LEFT JOIN PESSOA PV ON PV.PESCODIGO = V.PESCODIGO ' +
      'WHERE D.EMPCODIGO = :EMPCODIGO AND D.DAVCONTADOR = :DAVCONTADOR';
    QDav.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    QDav.ParamByName('DAVCONTADOR').AsInteger := ADavContador;
    try
      QDav.Open;
    except
      QDav.Close;
      QDav.SQL.Text :=
        'SELECT D.*, P.PESNOME, P.PESCODIGO, P.PESCNPJCPF ' +
        'FROM DAV D ' +
        'LEFT JOIN CLIENTE C ON C.CLICODIGO = D.CLICODIGO AND C.EMPCODIGO = D.EMPCODIGO ' +
        'LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO ' +
        'WHERE D.EMPCODIGO = :EMPCODIGO AND D.DAVCONTADOR = :DAVCONTADOR';
      QDav.Open;
    end;

    if QDav.IsEmpty then
      Exit;

    Result.Numero := CampoStr(QDav, 'DAVNUMERO');
    if CampoStr(QDav, 'DAVEMISSAO') <> '' then
    begin
      Result.Emissao := FormatDateTime('dd/mm/yyyy', QDav.FieldByName('DAVEMISSAO').AsDateTime);
      Result.Vencimento := VencimentoTrintaDiasApos(QDav.FieldByName('DAVEMISSAO').AsDateTime);
    end;

    Result.Vendedor := ResolverNomeVendedor(QDav, AEmpCodigo);

    Result.ClienteNome := CampoStr(QDav, 'PESNOME');
    CodCli := CampoStr(QDav, 'CLICODIGO');
    if CodCli = '' then
      CodCli := CampoStr(QDav, 'PESCODIGO');
    Result.ClienteCodigo := CodCli;

    Result.Endereco := MontarEnderecoPessoa(QDav);
    Result.Municipio := ValorPorCampos(QDav, ['PESCIDADE', 'CIDADE', 'MUNICIPIO']);
    Result.Apelido := ValorPorCampos(QDav,
      ['PESAPELIDO', 'PESFANTASIA', 'FANTASIA_APELIDO', 'PESNOMEFANTASIA']);
    Result.CpfCnpj := CampoStr(QDav, 'PESCNPJCPF');
    Result.Telefone := ValorPorCampos(QDav,
      ['PESFONE', 'PESTELEFONE', 'PESTEL', 'PESCELULAR']);

    Result.Pagamento := ValorPorCampos(QDav,
      ['DAVCONDPAGTO', 'DAVPAGAMENTO', 'CONDPAGAMENTO', 'FORMAPAGAMENTO']);
    Result.Observacao := CarregarObservacaoDocumento(QDav,
      ['DAVOBS', 'DAVINFORMACOESADICIONAIS', 'DAVOBSERVACAO', 'OBSERVACAO', 'OBS'],
      'DAV', 'DAVCONTADOR', AEmpCodigo, ADavContador);

    Result.Desconto := CampoFloat(QDav, 'DAVTOTALDESCONTO');
    if Result.Desconto = 0 then
      Result.Desconto := CampoFloat(QDav, 'DAVDESCONTO');
    Result.Frete := CampoFloat(QDav, 'DAVTOTALFRETE');
    if Result.Frete = 0 then
      Result.Frete := CampoFloat(QDav, 'DAVFRETE');
    Result.Outros := CampoFloat(QDav, 'DAVTOTALOUTROS');
    Result.Total := CampoFloat(QDav, 'DAVTOTALLIQUIDO');

    try
      QEmp.Connection := dmConexao.FDConnection1;
      QEmp.SQL.Text := 'SELECT FIRST 1 * FROM EMPRESA WHERE EMPCODIGO = :EMPCODIGO';
      QEmp.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
      QEmp.Open;
      if not QEmp.IsEmpty then
      begin
        Result.EmpresaNome := ValorPorCampos(QEmp,
          ['EMPNOMEFANTASIA', 'EMPRAZAOSOCIAL', 'EMPNOME', 'NOME', 'RAZAOSOCIAL']);
        Result.EmpresaEndereco := ValorPorCampos(QEmp,
          ['EMPENDERECO', 'ENDERECO', 'ENDCOMPLETO']);
        if Result.EmpresaEndereco = '' then
        begin
          Result.EmpresaEndereco := ValorPorCampos(QEmp, ['EMPLOGRADOURO', 'LOGRADOURO']);
          if ValorPorCampos(QEmp, ['EMPNUMERO', 'NUMERO']) <> '' then
            Result.EmpresaEndereco := Trim(Result.EmpresaEndereco + ', ' +
              ValorPorCampos(QEmp, ['EMPNUMERO', 'NUMERO']));
          if ValorPorCampos(QEmp, ['EMPCIDADE', 'CIDADE']) <> '' then
            Result.EmpresaEndereco := Trim(Result.EmpresaEndereco + ' - ' +
              ValorPorCampos(QEmp, ['EMPCIDADE', 'CIDADE']));
        end;
        Result.EmpresaTelefone := ValorPorCampos(QEmp,
          ['EMPTELEFONE', 'TELEFONE', 'FONE', 'EMPTEL']);
      end;
    except
    end;

    QProd.Connection := dmConexao.FDConnection1;
    QProd.SQL.Text := TMapaDav.MontarSQLProdutos;
    QProd.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    QProd.ParamByName('DAVCONTADOR').AsInteger := ADavContador;
    QProd.Open;

    while not QProd.Eof do
    begin
      AdicionarItem(
        ResolverCodigoItem(QProd, ''),
        '',
        CampoStr(QProd, 'PRODDESCRICAO'),
        'P',
        CampoFloat(QProd, 'DAVITEMQTDE'),
        CampoFloat(QProd, 'DAVITEMUNITARIO'),
        CampoFloat(QProd, 'DAVITEMTOTALLIQUIDO'));
      QProd.Next;
    end;

    QServ.Connection := dmConexao.FDConnection1;
    QServ.SQL.Text := TMapaDav.MontarSQLServicos;
    QServ.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    QServ.ParamByName('DAVCONTADOR').AsInteger := ADavContador;
    QServ.Open;

    while not QServ.Eof do
    begin
      AdicionarItem(
        ResolverCodigoItem(QServ, ''),
        '',
        CampoStr(QServ, 'SERVDESCRICAO'),
        'S',
        CampoFloat(QServ, 'DAVITEMSERVQTDE'),
        CampoFloat(QServ, 'DAVITEMSERVUNITARIO'),
        CampoFloat(QServ, 'DAVITEMSERVTOTALLIQUIDO'));
      QServ.Next;
    end;

    if Result.Total = 0 then
      Result.Total := Result.Subtotal - Result.Desconto + Result.Frete + Result.Outros;
  finally
    QServ.Free;
    QProd.Free;
    QEmp.Free;
    QDav.Free;
  end;
end;

class function TDavRelatorioImpressao.CarregarDadosOrcamento(AEmpCodigo,
  AOrcContador: Integer): TDavRelatorioDados;
var
  QOrc, QEmp, QProd, QServ: TFDQuery;
  Item: TDavLinhaItem;
  procedure AdicionarItem(const ACodigo, AUnidade, ADescricao, ATipo: string;
    AQtde, AUnitario, ATotal: Double);
  begin
    Item.Codigo := ACodigo;
    Item.Qtde := AQtde;
    Item.Unidade := AUnidade;
    Item.Descricao := ADescricao;
    Item.Tipo := ATipo;
    Item.Unitario := AUnitario;
    Item.Desconto := 0;
    Item.Total := ATotal;
    Item.BaseICMS := 0;
    Item.ValorICMS := 0;
    Item.BaseST := 0;
    Item.ValorST := 0;
    Item.ValorIPI := 0;
    Result.Itens.Add(Item);
    Result.Subtotal := Result.Subtotal + ATotal;
  end;

begin
  Result := TDavRelatorioDados.Create;
  Result.TituloRelatorio := 'ORCAMENTO';
  if not dmConexao.Conectado then
    Exit;

  QOrc := TFDQuery.Create(nil);
  QEmp := TFDQuery.Create(nil);
  QProd := TFDQuery.Create(nil);
  QServ := TFDQuery.Create(nil);
  try
    QOrc.Connection := dmConexao.FDConnection1;
    QOrc.SQL.Text :=
      'SELECT O.*, P.PESNOME, P.PESCODIGO, P.PESCNPJCPF, ' +
      'P.PESFONE, P.PESENDERECO, P.PESNUMERO, P.PESBAIRRO, P.PESCIDADE, P.PESUF, ' +
      'PV.PESNOME AS VENDNOME, COALESCE(PV.PESNOME, V.VENDNOME) AS NOMEVENDEDOR ' +
      'FROM ORCAMENTO O ' +
      'LEFT JOIN CLIENTE C ON C.CLICODIGO = O.CLICODIGO AND C.EMPCODIGO = O.EMPCODIGO ' +
      'LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO ' +
      'LEFT JOIN VENDEDOR V ON V.VENDCODIGO = O.VENDCODIGO AND V.EMPCODIGO = O.EMPCODIGO ' +
      'LEFT JOIN PESSOA PV ON PV.PESCODIGO = V.PESCODIGO ' +
      'WHERE O.EMPCODIGO = :EMPCODIGO AND O.ORCCONTADOR = :ORCCONTADOR';
    QOrc.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    QOrc.ParamByName('ORCCONTADOR').AsInteger := AOrcContador;
    try
      QOrc.Open;
    except
      QOrc.Close;
      QOrc.SQL.Text :=
        'SELECT O.*, P.PESNOME, P.PESCODIGO, P.PESCNPJCPF ' +
        'FROM ORCAMENTO O ' +
        'LEFT JOIN CLIENTE C ON C.CLICODIGO = O.CLICODIGO AND C.EMPCODIGO = O.EMPCODIGO ' +
        'LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO ' +
        'WHERE O.EMPCODIGO = :EMPCODIGO AND O.ORCCONTADOR = :ORCCONTADOR';
      QOrc.Open;
    end;

    if QOrc.IsEmpty then
      Exit;

    Result.Numero := CampoStr(QOrc, 'ORCNUMERO');
    if CampoStr(QOrc, 'ORCEMISSAO') <> '' then
    begin
      Result.Emissao := FormatDateTime('dd/mm/yyyy', QOrc.FieldByName('ORCEMISSAO').AsDateTime);
      Result.Vencimento := VencimentoTrintaDiasApos(QOrc.FieldByName('ORCEMISSAO').AsDateTime);
    end;

    Result.Vendedor := ResolverNomeVendedor(QOrc, AEmpCodigo);
    Result.ClienteNome := CampoStr(QOrc, 'PESNOME');
    if Result.ClienteNome = '' then
      Result.ClienteNome := ValorPorCampos(QOrc, ['PESNOME_CLIENTE', 'CLIENTE']);
    Result.ClienteCodigo := CampoStr(QOrc, 'CLICODIGO');
    if Result.ClienteCodigo = '' then
      Result.ClienteCodigo := CampoStr(QOrc, 'PESCODIGO');

    Result.Endereco := MontarEnderecoPessoa(QOrc);
    Result.Municipio := ValorPorCampos(QOrc, ['PESCIDADE', 'CIDADE', 'MUNICIPIO']);
    Result.Apelido := ValorPorCampos(QOrc,
      ['PESAPELIDO', 'PESFANTASIA', 'FANTASIA_APELIDO', 'PESNOMEFANTASIA']);
    Result.CpfCnpj := CampoStr(QOrc, 'PESCNPJCPF');
    Result.Telefone := ValorPorCampos(QOrc,
      ['PESFONE', 'PESTELEFONE', 'PESTEL', 'PESCELULAR']);

    Result.Pagamento := ValorPorCampos(QOrc,
      ['ORCCONDPAGTO', 'ORCPAGAMENTO', 'CONDPAGAMENTO', 'FORMAPAGAMENTO']);
    Result.Observacao := CarregarObservacaoDocumento(QOrc,
      ['ORCOBSERVACAO', 'ORCOBS', 'OBSERVACAO', 'OBS'],
      'ORCAMENTO', 'ORCCONTADOR', AEmpCodigo, AOrcContador);

    Result.Desconto := CampoFloat(QOrc, 'ORCTOTALDESCONTO');
    if Result.Desconto = 0 then
      Result.Desconto := CampoFloat(QOrc, 'ORCDESCONTO');
    Result.Frete := CampoFloat(QOrc, 'ORCTOTALFRETE');
    if Result.Frete = 0 then
      Result.Frete := CampoFloat(QOrc, 'ORCFRETE');
    Result.Outros := CampoFloat(QOrc, 'ORCTOTALOUTROS');
    Result.Total := CampoFloat(QOrc, 'ORCTOTALLIQUIDO');

    try
      QEmp.Connection := dmConexao.FDConnection1;
      QEmp.SQL.Text := 'SELECT FIRST 1 * FROM EMPRESA WHERE EMPCODIGO = :EMPCODIGO';
      QEmp.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
      QEmp.Open;
      if not QEmp.IsEmpty then
      begin
        Result.EmpresaNome := ValorPorCampos(QEmp,
          ['EMPNOMEFANTASIA', 'EMPRAZAOSOCIAL', 'EMPNOME', 'NOME', 'RAZAOSOCIAL']);
        Result.EmpresaEndereco := ValorPorCampos(QEmp,
          ['EMPENDERECO', 'ENDERECO', 'ENDCOMPLETO']);
        if Result.EmpresaEndereco = '' then
        begin
          Result.EmpresaEndereco := ValorPorCampos(QEmp, ['EMPLOGRADOURO', 'LOGRADOURO']);
          if ValorPorCampos(QEmp, ['EMPNUMERO', 'NUMERO']) <> '' then
            Result.EmpresaEndereco := Trim(Result.EmpresaEndereco + ', ' +
              ValorPorCampos(QEmp, ['EMPNUMERO', 'NUMERO']));
          if ValorPorCampos(QEmp, ['EMPCIDADE', 'CIDADE']) <> '' then
            Result.EmpresaEndereco := Trim(Result.EmpresaEndereco + ' - ' +
              ValorPorCampos(QEmp, ['EMPCIDADE', 'CIDADE']));
        end;
        Result.EmpresaTelefone := ValorPorCampos(QEmp,
          ['EMPTELEFONE', 'TELEFONE', 'FONE', 'EMPTEL']);
      end;
    except
    end;

    QProd.Connection := dmConexao.FDConnection1;
    QProd.SQL.Text := TMapaOrcamento.MontarSQLProdutos;
    QProd.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    QProd.ParamByName('ORCCONTADOR').AsInteger := AOrcContador;
    QProd.Open;

    while not QProd.Eof do
    begin
      AdicionarItem(
        ResolverCodigoItem(QProd, ''),
        '',
        CampoStr(QProd, 'PRODDESCRICAO'),
        'P',
        CampoFloat(QProd, 'ORCITEMQTDE'),
        CampoFloat(QProd, 'ORCITEMUNITARIO'),
        CampoFloat(QProd, 'ORCITEMTOTALLIQUIDO'));
      QProd.Next;
    end;

    QServ.Connection := dmConexao.FDConnection1;
    QServ.SQL.Text := TMapaOrcamento.MontarSQLServicos;
    QServ.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    QServ.ParamByName('ORCCONTADOR').AsInteger := AOrcContador;
    QServ.Open;

    while not QServ.Eof do
    begin
      AdicionarItem(
        ResolverCodigoItem(QServ, ''),
        '',
        CampoStr(QServ, 'SERVDESCRICAO'),
        'S',
        CampoFloat(QServ, 'ORCITEMSERVQTDE'),
        CampoFloat(QServ, 'ORCITEMSERVUNITARIO'),
        CampoFloat(QServ, 'ORCITEMSERVTOTALLIQUIDO'));
      QServ.Next;
    end;

    if Result.Total = 0 then
      Result.Total := Result.Subtotal - Result.Desconto + Result.Frete + Result.Outros;
  finally
    QServ.Free;
    QProd.Free;
    QEmp.Free;
    QOrc.Free;
  end;
end;

class function TDavRelatorioImpressao.CarregarDadosCompra(AEmpCodigo,
  AEntcContador: Integer): TDavRelatorioDados;
var
  QCom, QEmp, QProd: TFDQuery;
  Item: TDavLinhaItem;
  NumeroDoc: string;
  procedure AdicionarItem(const ACodigo, AUnidade, ADescricao, ATipo: string;
    AQtde, AUnitario, ADesconto, ATotal, ABaseICMS, AValorICMS, ABaseST, AValorST,
    AValorIPI: Double);
  begin
    Item.Codigo := ACodigo;
    Item.Qtde := AQtde;
    Item.Unidade := AUnidade;
    Item.Descricao := ADescricao;
    Item.Tipo := ATipo;
    Item.Unitario := AUnitario;
    Item.Desconto := ADesconto;
    Item.Total := ATotal;
    Item.BaseICMS := ABaseICMS;
    Item.ValorICMS := AValorICMS;
    Item.BaseST := ABaseST;
    Item.ValorST := AValorST;
    Item.ValorIPI := AValorIPI;
    Result.Itens.Add(Item);
    Result.Subtotal := Result.Subtotal + ATotal;
  end;

  procedure CarregarEmpresa;
  begin
    try
      QEmp.Connection := dmConexao.FDConnection1;
      QEmp.SQL.Text := 'SELECT FIRST 1 * FROM EMPRESA WHERE EMPCODIGO = :EMPCODIGO';
      QEmp.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
      QEmp.Open;
      if QEmp.IsEmpty then
        Exit;
      Result.EmpresaNome := ValorPorCampos(QEmp,
        ['EMPNOMEFANTASIA', 'EMPRAZAOSOCIAL', 'EMPNOME', 'NOME', 'RAZAOSOCIAL']);
      Result.EmpresaEndereco := ValorPorCampos(QEmp,
        ['EMPENDERECO', 'ENDERECO', 'ENDCOMPLETO']);
      if Result.EmpresaEndereco = '' then
      begin
        Result.EmpresaEndereco := ValorPorCampos(QEmp, ['EMPLOGRADOURO', 'LOGRADOURO']);
        if ValorPorCampos(QEmp, ['EMPNUMERO', 'NUMERO']) <> '' then
          Result.EmpresaEndereco := Trim(Result.EmpresaEndereco + ', ' +
            ValorPorCampos(QEmp, ['EMPNUMERO', 'NUMERO']));
        if ValorPorCampos(QEmp, ['EMPCIDADE', 'CIDADE']) <> '' then
          Result.EmpresaEndereco := Trim(Result.EmpresaEndereco + ' - ' +
            ValorPorCampos(QEmp, ['EMPCIDADE', 'CIDADE']));
      end;
      Result.EmpresaTelefone := ValorPorCampos(QEmp,
        ['EMPTELEFONE', 'TELEFONE', 'FONE', 'EMPTEL']);
    except
    end;
  end;

begin
  Result := TDavRelatorioDados.Create;
  Result.TituloRelatorio := 'ENTRADA DE COMPRA';
  Result.RotuloParticipante := 'Fornecedor';
  if not dmConexao.Conectado then
    Exit;

  QCom := TFDQuery.Create(nil);
  QEmp := TFDQuery.Create(nil);
  QProd := TFDQuery.Create(nil);
  try
    QCom.Connection := dmConexao.FDConnection1;
    QCom.SQL.Text :=
      'SELECT E.*, P.PESNOME, P.PESCODIGO, P.PESCNPJCPF ' +
      'FROM ENTRADACOMPRA E ' +
      'LEFT JOIN FORNECEDOR F ON F.FORCODIGO = E.FORCODIGO AND F.EMPCODIGO = E.EMPCODIGO ' +
      'LEFT JOIN PESSOA P ON P.PESCODIGO = F.PESCODIGO ' +
      'WHERE E.EMPCODIGO = :EMPCODIGO AND E.ENTCCONTADOR = :ENTCCONTADOR';
    QCom.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    QCom.ParamByName('ENTCCONTADOR').AsInteger := AEntcContador;
    QCom.Open;
    if QCom.IsEmpty then
      Exit;

    NumeroDoc := CampoStr(QCom, 'ENTCNUMERO');
    if CampoStr(QCom, 'ENTCSERIE') <> '' then
      NumeroDoc := Trim(NumeroDoc + ' / ' + CampoStr(QCom, 'ENTCSERIE'));
    Result.Numero := NumeroDoc;

    if CampoStr(QCom, 'ENTCDTEMISSAO') <> '' then
      Result.Emissao := FormatDateTime('dd/mm/yyyy', QCom.FieldByName('ENTCDTEMISSAO').AsDateTime);
    if CampoStr(QCom, 'ENTCDTENTRADA') <> '' then
      Result.Vencimento := FormatDateTime('dd/mm/yyyy', QCom.FieldByName('ENTCDTENTRADA').AsDateTime);

    Result.ClienteNome := CampoStr(QCom, 'PESNOME');
    Result.CpfCnpj := CampoStr(QCom, 'PESCNPJCPF');
    ComplementarDadosPessoa(QCom.FieldByName('PESCODIGO').AsInteger,
      Result.Endereco, Result.Municipio, Result.Telefone);
    Result.Observacao := CampoStr(QCom, 'ENTCOBSDOCUMENTO');
    Result.ChaveAcesso := CampoStr(QCom, 'ENTCCHAVENFE');
    Result.Desconto := CampoFloat(QCom, 'ENTCVRDESCONTO');
    Result.Frete := CampoFloat(QCom, 'ENTCVRFRETE');
    Result.Outros := CampoFloat(QCom, 'ENTCVROUTROSCUSTOS');
    if Result.Outros = 0 then
      Result.Outros := CampoFloat(QCom, 'ENTCVRDESPESAS');
    Result.Seguro := CampoFloat(QCom, 'ENTCVRSEGURO');
    Result.BaseICMS := CampoFloat(QCom, 'ENTCVRBASECALCULO');
    Result.ValorICMS := CampoFloat(QCom, 'ENTCVRICMS');
    Result.BaseST := CampoFloat(QCom, 'ENTCVRBASECALCULOST');
    Result.ValorST := CampoFloat(QCom, 'ENTCVRICMSST');
    Result.ValorIPI := CampoFloat(QCom, 'ENTCVRIPI');
    Result.ValorPIS := CampoFloat(QCom, 'ENTCVRPIS');
    Result.ValorCOFINS := CampoFloat(QCom, 'ENTCVRCOFINS');
    Result.Total := CampoFloat(QCom, 'ENTCVRTOTAL');

    CarregarEmpresa;

    QProd.Connection := dmConexao.FDConnection1;
    QProd.SQL.Text := TMapaCompra.MontarSQLProdutosImpressao;
    QProd.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    QProd.ParamByName('ENTCCONTADOR').AsInteger := AEntcContador;
    QProd.Open;
    while not QProd.Eof do
    begin
      AdicionarItem(
        ResolverCodigoItem(QProd, ''),
        '',
        CampoStr(QProd, 'PRODDESCRICAO'),
        'P',
        CampoFloat(QProd, 'ENTCIQTDE'),
        CampoFloat(QProd, 'ENTCIVRUNITARIO'),
        CampoFloat(QProd, 'ENTCIVRDESCONTO'),
        CampoFloat(QProd, 'ENTCIVRTOTALLIQUIDO'),
        CampoFloat(QProd, 'ENTCIVRBASECALCULO'),
        CampoFloat(QProd, 'ENTCIVRICMS'),
        CampoFloat(QProd, 'ENTCIVRBASECALCULOST'),
        CampoFloat(QProd, 'ENTCIVRICMSST'),
        CampoFloat(QProd, 'ENTCIIPI'));
      QProd.Next;
    end;

    if Result.Total = 0 then
      Result.Total := Result.Subtotal - Result.Desconto + Result.Frete + Result.Outros;
  finally
    QProd.Free;
    QEmp.Free;
    QCom.Free;
  end;
end;

class function TDavRelatorioImpressao.CarregarDadosNotaFiscal(AEmpCodigo,
  ANfContador: Integer): TDavRelatorioDados;
var
  QNf, QEmp, QProd: TFDQuery;
  Item: TDavLinhaItem;
  procedure AdicionarItem(const ACodigo, AUnidade, ADescricao, ATipo: string;
    AQtde, AUnitario, ADesconto, ATotal, ABaseICMS, AValorICMS, ABaseST, AValorST,
    AValorIPI: Double);
  begin
    Item.Codigo := ACodigo;
    Item.Qtde := AQtde;
    Item.Unidade := AUnidade;
    Item.Descricao := ADescricao;
    Item.Tipo := ATipo;
    Item.Unitario := AUnitario;
    Item.Desconto := ADesconto;
    Item.Total := ATotal;
    Item.BaseICMS := ABaseICMS;
    Item.ValorICMS := AValorICMS;
    Item.BaseST := ABaseST;
    Item.ValorST := AValorST;
    Item.ValorIPI := AValorIPI;
    Result.Itens.Add(Item);
    Result.Subtotal := Result.Subtotal + ATotal;
  end;

  procedure CarregarEmpresa;
  begin
    try
      QEmp.Connection := dmConexao.FDConnection1;
      QEmp.SQL.Text := 'SELECT FIRST 1 * FROM EMPRESA WHERE EMPCODIGO = :EMPCODIGO';
      QEmp.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
      QEmp.Open;
      if QEmp.IsEmpty then
        Exit;
      Result.EmpresaNome := ValorPorCampos(QEmp,
        ['EMPNOMEFANTASIA', 'EMPRAZAOSOCIAL', 'EMPNOME', 'NOME', 'RAZAOSOCIAL']);
      Result.EmpresaEndereco := ValorPorCampos(QEmp,
        ['EMPENDERECO', 'ENDERECO', 'ENDCOMPLETO']);
      if Result.EmpresaEndereco = '' then
      begin
        Result.EmpresaEndereco := ValorPorCampos(QEmp, ['EMPLOGRADOURO', 'LOGRADOURO']);
        if ValorPorCampos(QEmp, ['EMPNUMERO', 'NUMERO']) <> '' then
          Result.EmpresaEndereco := Trim(Result.EmpresaEndereco + ', ' +
            ValorPorCampos(QEmp, ['EMPNUMERO', 'NUMERO']));
        if ValorPorCampos(QEmp, ['EMPCIDADE', 'CIDADE']) <> '' then
          Result.EmpresaEndereco := Trim(Result.EmpresaEndereco + ' - ' +
            ValorPorCampos(QEmp, ['EMPCIDADE', 'CIDADE']));
      end;
      Result.EmpresaTelefone := ValorPorCampos(QEmp,
        ['EMPTELEFONE', 'TELEFONE', 'FONE', 'EMPTEL']);
    except
    end;
  end;

begin
  Result := TDavRelatorioDados.Create;
  Result.TituloRelatorio := 'NOTA FISCAL';
  Result.RotuloParticipante := 'Destinatario';
  if not dmConexao.Conectado then
    Exit;

  QNf := TFDQuery.Create(nil);
  QEmp := TFDQuery.Create(nil);
  QProd := TFDQuery.Create(nil);
  try
    QNf.Connection := dmConexao.FDConnection1;
    QNf.SQL.Text :=
      'SELECT N.*, P.PESNOME, P.PESCODIGO, P.PESCNPJCPF, NFEN.NFNFECHAVE ' +
      'FROM NOTAFISCAL N ' +
      'LEFT JOIN PESSOA P ON P.PESCODIGO = N.PESCODIGO ' +
      'LEFT JOIN NOTAFISCALNFE NFEN ON NFEN.EMPCODIGO = N.EMPCODIGO AND NFEN.NFCONTADOR = N.NFCONTADOR ' +
      'WHERE N.EMPCODIGO = :EMPCODIGO AND N.NFCONTADOR = :NFCONTADOR';
    QNf.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    QNf.ParamByName('NFCONTADOR').AsInteger := ANfContador;
    QNf.Open;
    if QNf.IsEmpty then
      Exit;

    Result.Numero := CampoStr(QNf, 'NFNUMEROFISCAL');
    if Result.Numero = '' then
      Result.Numero := CampoStr(QNf, 'DOCFNUMERO');

    if CampoStr(QNf, 'NFDTEMISSAO') <> '' then
      Result.Emissao := FormatDateTime('dd/mm/yyyy', QNf.FieldByName('NFDTEMISSAO').AsDateTime);
    if CampoStr(QNf, 'NFDTSAIDA') <> '' then
      Result.Vencimento := FormatDateTime('dd/mm/yyyy', QNf.FieldByName('NFDTSAIDA').AsDateTime);

    Result.ClienteNome := CampoStr(QNf, 'PESNOME');
    Result.CpfCnpj := CampoStr(QNf, 'PESCNPJCPF');
    ComplementarDadosPessoa(QNf.FieldByName('PESCODIGO').AsInteger,
      Result.Endereco, Result.Municipio, Result.Telefone);
    Result.Observacao := CampoStr(QNf, 'NFADCIONAIS');
    Result.ChaveAcesso := CampoStr(QNf, 'NFNFECHAVE');
    Result.Desconto := CampoFloat(QNf, 'NFDESCONTO');
    Result.Frete := CampoFloat(QNf, 'NFFRETE');
    Result.Outros := CampoFloat(QNf, 'NFOUTRADESPESA');
    Result.Seguro := CampoFloat(QNf, 'NFSEGURO');
    Result.BaseICMS := CampoFloat(QNf, 'NFBASEICMS');
    Result.ValorICMS := CampoFloat(QNf, 'NFVALORICMS');
    Result.BaseST := CampoFloat(QNf, 'NFBASEICMSSUB');
    Result.ValorST := CampoFloat(QNf, 'NFVALORICMSSUB');
    Result.ValorIPI := CampoFloat(QNf, 'NFIPI');
    Result.ValorPIS := CampoFloat(QNf, 'NFTOTALPIS');
    Result.ValorCOFINS := CampoFloat(QNf, 'NFTOTALCOFINS');
    Result.Total := CampoFloat(QNf, 'NFTOTALNOTA');

    CarregarEmpresa;

    QProd.Connection := dmConexao.FDConnection1;
    QProd.SQL.Text := TMapaNotaFiscal.MontarSQLProdutosImpressao;
    QProd.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
    QProd.ParamByName('NFCONTADOR').AsInteger := ANfContador;
    QProd.Open;
    while not QProd.Eof do
    begin
      AdicionarItem(
        ResolverCodigoItem(QProd, ''),
        '',
        CampoStr(QProd, 'PRODDESCRICAO'),
        'P',
        CampoFloat(QProd, 'NFITEMQTDE'),
        CampoFloat(QProd, 'NFITEMUNITARIO'),
        CampoFloat(QProd, 'NFITEMDESCONTO'),
        CampoFloat(QProd, 'NFITEMTOTALLIQUIDO'),
        CampoFloat(QProd, 'NFITEMBASEICMS'),
        CampoFloat(QProd, 'NFITEMVALORICMS'),
        CampoFloat(QProd, 'NFITEMBASEICMSST'),
        CampoFloat(QProd, 'NFITEMVALORICMSST'),
        CampoFloat(QProd, 'NFITEMIPI'));
      QProd.Next;
    end;

    if Result.Total = 0 then
      Result.Total := Result.Subtotal - Result.Desconto + Result.Frete + Result.Outros;
  finally
    QProd.Free;
    QEmp.Free;
    QNf.Free;
  end;
end;

constructor TRenderDav.Create(ACanvas: TCanvas; APageWidth, APageHeight: Integer;
  AModoPreview: Boolean; APaginas: TListaPaginasImpressao);
var
  Bmp: Vcl.Graphics.TBitmap;
begin
  FCanvas := ACanvas;
  FPageWidth := APageWidth;
  FPageHeight := APageHeight;
  FModoPreview := AModoPreview;
  FModoFiscal := False;
  FModoComercial := False;
  FPaginas := APaginas;
  FMargemEsq := 36;
  FMargemDir := FPageWidth - 36;
  FPageBottom := FPageHeight - 70;
  FY := 28;
  if FPageHeight <= IMPRESSAO_MEIA_A4_ALTURA + 40 then
  begin
    FMargemEsq := 20;
    FMargemDir := FPageWidth - 20;
    FPageBottom := FPageHeight - 28;
    FY := 10;
  end;
  FNumeroPagina := 1;
  CalcularColunasGrid;
  SetBkMode(FCanvas.Handle, TRANSPARENT);

  if FModoPreview and (FPaginas <> nil) and (FPaginas.Count = 0) then
  begin
    Bmp := Vcl.Graphics.TBitmap.Create;
    try
      TImpressaoPagina.PrepararBitmapPagina(Bmp, FPageWidth, FPageHeight);
      FPaginas.Add(Bmp);
      FCanvas := Bmp.Canvas;
    except
      Bmp.Free;
      raise;
    end;
  end;
end;

procedure TRenderDav.CalcularColunasGrid;
var
  LarguraUtil: Integer;
begin
  LarguraUtil := FMargemDir - FMargemEsq;
  FGridDir := FMargemDir;
  if FModoFiscal then
  begin
    FColCodLargura := 22;
    FColTotalDir := FMargemDir - 4;
    FColIPIDir := FColTotalDir - 44;
    FColSTDir := FColIPIDir - 38;
    FColBaseSTDir := FColSTDir - 44;
    FColICMSDir := FColBaseSTDir - 38;
    FColBaseICMSDir := FColICMSDir - 44;
    FColDescValDir := FColBaseICMSDir - 38;
    FColUnitDir := FColDescValDir - 44;
    FColQtdeDir := FColUnitDir - 34;
    FColCod := FMargemEsq + 2;
    FColDesc := FMargemEsq + 26;
  end
  else if FModoComercial and (FPageHeight <= IMPRESSAO_MEIA_A4_ALTURA + 40) then
  begin
    FColCod := FMargemEsq + 4;
    FColCodLargura := 132;
    FColDesc := FColCod + FColCodLargura + 14;
    FColQtdeDir := FMargemEsq + 498;
    FColUnitDir := FMargemEsq + 668;
    FColTotalDir := FMargemDir - 4;
  end
  else
  begin
    FColCod := FMargemEsq + 6;
    FColCodLargura := 104;
    FColDesc := FColCod + FColCodLargura + 12;
    FColQtdeDir := FMargemEsq + Round(LarguraUtil * 0.54);
    FColUnitDir := FMargemEsq + Round(LarguraUtil * 0.72);
    FColTotalDir := FMargemDir - 8;
  end;
end;

function TRenderDav.TruncarTextoColuna(const ATexto: string; ALarguraPx: Integer): string;
var
  S: string;
  I: Integer;
begin
  S := Trim(ATexto);
  if (S = '') or (ALarguraPx <= 0) then
    Exit(S);

  Result := S;
  if FCanvas.TextWidth(S) <= ALarguraPx then
    Exit;

  for I := Length(S) downto 1 do
  begin
    Result := Copy(S, 1, I) + '...';
    if FCanvas.TextWidth(Result) <= ALarguraPx then
      Exit;
  end;

  Result := Copy(S, 1, 1) + '...';
end;

procedure TRenderDav.DefinirFonte(ATamanho: Integer; ANegrito: Boolean);
begin
  SetBkMode(FCanvas.Handle, TRANSPARENT);
  FCanvas.Font.Name := 'Arial';
  FCanvas.Font.Charset := DEFAULT_CHARSET;
  FCanvas.Font.Quality := fqNonAntialiased;
  FCanvas.Font.Size := ATamanho;
  FCanvas.Font.Color := clBlack;
  if ANegrito then
    FCanvas.Font.Style := [fsBold]
  else
    FCanvas.Font.Style := [];
end;

function TRenderDav.AlturaLinha: Integer;
begin
  Result := FCanvas.TextHeight('Ag') + 6;
end;

procedure TRenderDav.Avancar(APixels: Integer);
begin
  Inc(FY, APixels);
end;

procedure TRenderDav.NovaPagina;
var
  Bmp: Vcl.Graphics.TBitmap;
begin
  Inc(FNumeroPagina);
  if FModoPreview then
  begin
    Bmp := Vcl.Graphics.TBitmap.Create;
    TImpressaoPagina.PrepararBitmapPagina(Bmp, FPageWidth, FPageHeight);
    FPaginas.Add(Bmp);
    FCanvas := Bmp.Canvas;
    if FPageHeight <= IMPRESSAO_MEIA_A4_ALTURA + 40 then
      FY := 10
    else
      FY := 28;
    Exit;
  end;
  Printer.NewPage;
  FY := 28;
end;

procedure TRenderDav.Texto(const AX, AY: Integer; const ATexto: string);
begin
  if ATexto <> '' then
    FCanvas.TextOut(AX, AY, ATexto);
end;

procedure TRenderDav.TextoDireita(AXDireita, AY: Integer; const ATexto: string);
begin
  if ATexto <> '' then
    FCanvas.TextOut(AXDireita - FCanvas.TextWidth(ATexto), AY, ATexto);
end;

procedure TRenderDav.TextoCentro(const ARect: TRect; const ATexto: string);
var
  X, Y: Integer;
begin
  if ATexto = '' then
    Exit;
  X := ARect.Left + ((ARect.Right - ARect.Left) - FCanvas.TextWidth(ATexto)) div 2;
  Y := ARect.Top + ((ARect.Bottom - ARect.Top) - FCanvas.TextHeight(ATexto)) div 2;
  Texto(X, Y, ATexto);
end;

procedure TRenderDav.LinhaHorizontal;
begin
  FCanvas.Pen.Color := clBlack;
  FCanvas.MoveTo(FMargemEsq, FY);
  FCanvas.LineTo(FMargemDir, FY);
  Avancar(8);
end;

function TRenderDav.EspacoRodape: Integer;
begin
  if FModoFiscal then
    Result := 320
  else if FModoComercial and (FPageHeight <= IMPRESSAO_MEIA_A4_ALTURA + 40) then
    Result := 150
  else if FModoComercial then
    Result := 170
  else
    Result := 200;
end;

function TRenderDav.TotalPorTipo(const ADados: TDavRelatorioDados;
  const ATipo: string): Double;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ADados.Itens.Count - 1 do
    if SameText(ADados.Itens[I].Tipo, ATipo) then
      Result := Result + ADados.Itens[I].Total;
end;

procedure TRenderDav.DesenharContinuacaoGrid;
begin
  if FModoFiscal then
    DesenharTituloGridFiscal
  else
    DesenharTituloGrid;
end;

procedure TRenderDav.DesenharCabecalhoPagina(const ADados: TDavRelatorioDados);
var
  R, Badge: TRect;
  TituloDav: string;
  YIni, YTopo: Integer;
begin
  YIni := FY;
  if FModoComercial then
  begin
    if FPageHeight <= IMPRESSAO_MEIA_A4_ALTURA + 40 then
    begin
      FCanvas.Brush.Style := bsSolid;
      FCanvas.Brush.Color := COR_COMERCIAL_DESTAQUE;
      FCanvas.FillRect(Rect(FMargemEsq, FY, FMargemDir, FY + 3));
      Inc(FY, 8);

      YTopo := FY;
      DefinirFonte(8, False);
      Texto(FMargemEsq, YTopo, 'Emissao: ' + ADados.Emissao);
      if ADados.Vencimento <> '' then
        TextoDireita(FMargemDir, YTopo, 'Venc.: ' + ADados.Vencimento);

      TituloDav := TituloDocumentoComercial(ADados);
      DefinirFonte(14, True);
      FCanvas.Font.Color := COR_COMERCIAL_DESTAQUE;
      TextoCentro(Rect(FMargemEsq, YTopo - 2, FMargemDir, YTopo + AlturaLinha + 8), TituloDav);
      FCanvas.Font.Color := clBlack;

      FY := YTopo + AlturaLinha + 6;
      LinhaHorizontal;
      Exit;
    end;

    FCanvas.Brush.Color := COR_COMERCIAL_DESTAQUE;
    FCanvas.FillRect(Rect(FMargemEsq, FY, FMargemDir, FY + 4));
    Inc(FY, 10);

    FCanvas.Brush.Color := COR_COMERCIAL_FUNDO;
    FCanvas.FillRect(Rect(FMargemEsq, FY, FMargemDir, FY + 96));
    FCanvas.Pen.Color := COR_COMERCIAL_GRID;
    FCanvas.Rectangle(FMargemEsq, FY, FMargemDir, FY + 96);

    DefinirFonte(13, True);
    R := Rect(FMargemEsq + 14, FY + 10, FMargemDir - 170, FY + 34);
    TextoCentro(R, ADados.EmpresaNome);
    DefinirFonte(9, False);
    R.Top := R.Top + 22;
    R.Bottom := R.Bottom + 16;
    TextoCentro(R, ADados.EmpresaEndereco);
    R.Top := R.Top + 14;
    R.Bottom := R.Bottom + 14;
    if ADados.EmpresaTelefone <> '' then
      TextoCentro(R, 'Tel.: ' + ADados.EmpresaTelefone);

    if ADados.TituloRelatorio <> '' then
      TituloDav := ADados.TituloRelatorio
    else
      TituloDav := 'DAV';
    Badge := Rect(FMargemDir - 150, FY + 12, FMargemDir - 14, FY + 52);
    FCanvas.Brush.Color := COR_COMERCIAL_DESTAQUE;
    FCanvas.FillRect(Badge);
    DefinirFonte(16, True);
    FCanvas.Font.Color := clWhite;
    TextoCentro(Badge, TituloDav);
    FCanvas.Font.Color := clBlack;

    DefinirFonte(9, False);
    TextoDireita(FMargemDir - 14, FY + 60, 'Numero: ' + ADados.Numero);
    TextoDireita(FMargemDir - 14, FY + 74, 'Emissao: ' + ADados.Emissao);
    if ADados.Vendedor <> '' then
      TextoDireita(FMargemDir - 14, FY + 88, 'Vendedor: ' + ADados.Vendedor);

    FY := YIni + 106;
    LinhaHorizontal;
    Exit;
  end;

  DefinirFonte(11, True);
  R := Rect(FMargemEsq, FY, FMargemDir - 120, FY + 52);
  TextoCentro(R, ADados.EmpresaNome);
  DefinirFonte(9, False);
  R.Top := R.Top + 18;
  TextoCentro(R, ADados.EmpresaEndereco);
  R.Top := R.Top + 14;
  if ADados.EmpresaTelefone <> '' then
    TextoCentro(R, 'Tel.: ' + ADados.EmpresaTelefone);

  DefinirFonte(22, True);
  if RelatorioModoFiscal(ADados.TituloRelatorio) then
    TituloDav := 'DANFE'
  else if ADados.TituloRelatorio <> '' then
    TituloDav := ADados.TituloRelatorio
  else
    TituloDav := 'DAV';
  TextoDireita(FMargemDir, FY, TituloDav);

  DefinirFonte(9, False);
  TextoDireita(FMargemDir, FY + 30, 'Numero: ' + ADados.Numero);
  TextoDireita(FMargemDir, FY + 44, 'Emissao: ' + ADados.Emissao);
  if ADados.Vendedor <> '' then
    TextoDireita(FMargemDir, FY + 58, 'Vendedor: ' + ADados.Vendedor);
  if ADados.Vencimento <> '' then
  begin
    if SameText(ADados.TituloRelatorio, 'ENTRADA DE COMPRA') then
      TextoDireita(FMargemDir, FY + 72, 'Entrada: ' + ADados.Vencimento)
    else if SameText(ADados.TituloRelatorio, 'NOTA FISCAL') then
      TextoDireita(FMargemDir, FY + 72, 'Saida: ' + ADados.Vencimento)
    else
      TextoDireita(FMargemDir, FY + 72, 'Vencimento: ' + ADados.Vencimento);
  end;

  FY := FY + 88;
  LinhaHorizontal;
end;

procedure TRenderDav.DesenharCliente(const ADados: TDavRelatorioDados);
var
  Rotulo: string;
  YIni, YFim: Integer;
begin
  YIni := FY;
  if FModoComercial then
  begin
    if FPageHeight <= IMPRESSAO_MEIA_A4_ALTURA + 40 then
    begin
      DefinirFonte(8, True);
      Texto(FMargemEsq, FY, 'CLIENTE');
      Avancar(AlturaLinha);
      DefinirFonte(8, False);
      Rotulo := NomeClienteParaExibicao(ADados.ClienteNome, ADados.ClienteCodigo,
        ADados.CpfCnpj);
      Texto(FMargemEsq, FY, Rotulo);
      Avancar(AlturaLinha + 2);
      DefinirFonte(8, True);
      Texto(FMargemEsq, FY, 'Vendedor');
      Avancar(AlturaLinha);
      DefinirFonte(8, False);
      if ADados.Vendedor <> '' then
        Texto(FMargemEsq, FY, ADados.Vendedor);
      Avancar(AlturaLinha + 4);
      LinhaHorizontal;
      Exit;
    end;

    DefinirFonte(8, True);
    Texto(FMargemEsq, FY, 'DADOS DO CLIENTE');
    Avancar(AlturaLinha + 2);
    YIni := FY;
  end;

  DefinirFonte(9, False);
  Rotulo := ADados.RotuloParticipante;
  if Rotulo = '' then
    Rotulo := 'Cliente';
  Texto(FMargemEsq, FY, Rotulo + ': ' + ADados.ClienteNome);
  Avancar(AlturaLinha);
  if ADados.Endereco <> '' then
  begin
    Texto(FMargemEsq, FY, 'Endereco: ' + ADados.Endereco);
    Avancar(AlturaLinha);
  end;
  if ADados.Municipio <> '' then
  begin
    Texto(FMargemEsq, FY, 'Municipio: ' + ADados.Municipio);
    Avancar(AlturaLinha);
  end;
  if ADados.Apelido <> '' then
  begin
    Texto(FMargemEsq, FY, 'Apelido: ' + ADados.Apelido);
    Avancar(AlturaLinha);
  end;
  if ADados.CpfCnpj <> '' then
  begin
    Texto(FMargemEsq, FY, 'CPF/CNPJ: ' + ADados.CpfCnpj);
    Avancar(AlturaLinha);
  end;
  if ADados.Telefone <> '' then
  begin
    Texto(FMargemEsq, FY, 'Tel.: ' + ADados.Telefone);
    Avancar(AlturaLinha);
  end;
  if ADados.ChaveAcesso <> '' then
  begin
    Texto(FMargemEsq, FY, 'Chave de acesso: ' + ADados.ChaveAcesso);
    Avancar(AlturaLinha);
  end;

  if FModoComercial then
  begin
    YFim := FY + 4;
    FCanvas.Brush.Style := bsClear;
    FCanvas.Pen.Color := COR_COMERCIAL_GRID;
    FCanvas.Rectangle(FMargemEsq, YIni - 4, FMargemDir, YFim);
    FCanvas.Brush.Style := bsSolid;
    Inc(FY, 6);
  end;

  LinhaHorizontal;
end;

procedure TRenderDav.DesenharTituloGrid;
begin
  DefinirFonte(8, True);
  if FModoComercial then
  begin
    FCanvas.Brush.Color := COR_COMERCIAL_GRID;
    FCanvas.FillRect(Rect(FMargemEsq, FY, FMargemDir, FY + AlturaLinha + 2));
    FCanvas.Font.Color := clWhite;
  end
  else
  begin
    FCanvas.Brush.Color := $00D8D8D8;
    FCanvas.FillRect(Rect(FMargemEsq, FY, FMargemDir, FY + AlturaLinha));
  end;
  Texto(FColCod, FY + 2, 'Cod.Fabrican');
  Texto(FColDesc, FY + 2, 'Produto/Servico');
  TextoDireita(FColQtdeDir, FY + 2, 'Qtd.');
  TextoDireita(FColUnitDir, FY + 2, 'Vlr Unit.');
  TextoDireita(FColTotalDir, FY + 2, 'Vlr Total');
  FCanvas.Font.Color := clBlack;
  Avancar(AlturaLinha + 2);
end;

procedure TRenderDav.DesenharLinhaItem(const AItem: TDavLinhaItem; AZebra: Boolean);
var
  H, MaxChars, LarguraDesc: Integer;
  Codigo, Desc: string;
begin
  H := AlturaLinha;
  if FY + H + EspacoRodape > FPageBottom then
  begin
    NovaPagina;
    DesenharContinuacaoGrid;
  end;

  if AZebra then
  begin
    if FModoComercial then
      FCanvas.Brush.Color := COR_COMERCIAL_ZEBRA
    else
      FCanvas.Brush.Color := COR_ZEBRA;
  end
  else
    FCanvas.Brush.Color := clWhite;
  FCanvas.FillRect(Rect(FMargemEsq, FY, FMargemDir, FY + H));

  DefinirFonte(8, False);
  Codigo := TruncarTextoColuna(AItem.Codigo, FColCodLargura);
  Texto(FColCod, FY + 2, Codigo);
  Desc := AItem.Descricao;
  LarguraDesc := FColQtdeDir - FColDesc - 16;
  if LarguraDesc < 80 then
    LarguraDesc := 80;
  Desc := TruncarTextoColuna(Desc, LarguraDesc);
  Texto(FColDesc, FY + 2, Desc);
  TextoDireita(FColQtdeDir, FY + 2, FormatarQuantidade(AItem.Qtde));
  TextoDireita(FColUnitDir, FY + 2, FormatarMoedaBRL(AItem.Unitario));
  TextoDireita(FColTotalDir, FY + 2, FormatarMoedaBRL(AItem.Total));
  Avancar(H);
end;

procedure TRenderDav.DesenharTituloGridFiscal;
begin
  DefinirFonte(7, True);
  FCanvas.Brush.Color := $00D8D8D8;
  FCanvas.FillRect(Rect(FMargemEsq, FY, FMargemDir, FY + AlturaLinha));
  Texto(FColCod, FY + 2, 'Item');
  Texto(FColDesc, FY + 2, 'Descricao');
  TextoDireita(FColQtdeDir, FY + 2, 'Qtd');
  TextoDireita(FColUnitDir, FY + 2, 'V.Unit');
  TextoDireita(FColDescValDir, FY + 2, 'Desc.');
  TextoDireita(FColBaseICMSDir, FY + 2, 'BC ICMS');
  TextoDireita(FColICMSDir, FY + 2, 'ICMS');
  TextoDireita(FColBaseSTDir, FY + 2, 'BC ST');
  TextoDireita(FColSTDir, FY + 2, 'ST');
  TextoDireita(FColIPIDir, FY + 2, 'IPI');
  TextoDireita(FColTotalDir, FY + 2, 'Total');
  Avancar(AlturaLinha + 2);
end;

procedure TRenderDav.DesenharLinhaItemFiscal(const AItem: TDavLinhaItem; AZebra: Boolean);
var
  H, MaxChars: Integer;
  Desc: string;
begin
  H := AlturaLinha;
  if FY + H + EspacoRodape > FPageBottom then
  begin
    NovaPagina;
    DesenharContinuacaoGrid;
  end;

  if AZebra then
    FCanvas.Brush.Color := COR_ZEBRA
  else
    FCanvas.Brush.Color := clWhite;
  FCanvas.FillRect(Rect(FMargemEsq, FY, FMargemDir, FY + H));

  DefinirFonte(7, False);
  Texto(FColCod, FY + 2, AItem.Codigo);
  Desc := AItem.Descricao;
  MaxChars := (FColQtdeDir - FColDesc - 12) div 6;
  if MaxChars < 12 then
    MaxChars := 12;
  if Length(Desc) > MaxChars then
    Desc := Copy(Desc, 1, MaxChars) + '...';
  Texto(FColDesc, FY + 2, Desc);
  TextoDireita(FColQtdeDir, FY + 2, FormatarQuantidade(AItem.Qtde));
  TextoDireita(FColUnitDir, FY + 2, FormatarMoedaBRL(AItem.Unitario));
  TextoDireita(FColDescValDir, FY + 2, FormatarMoedaBRL(AItem.Desconto));
  TextoDireita(FColBaseICMSDir, FY + 2, FormatarMoedaBRL(AItem.BaseICMS));
  TextoDireita(FColICMSDir, FY + 2, FormatarMoedaBRL(AItem.ValorICMS));
  TextoDireita(FColBaseSTDir, FY + 2, FormatarMoedaBRL(AItem.BaseST));
  TextoDireita(FColSTDir, FY + 2, FormatarMoedaBRL(AItem.ValorST));
  TextoDireita(FColIPIDir, FY + 2, FormatarMoedaBRL(AItem.ValorIPI));
  TextoDireita(FColTotalDir, FY + 2, FormatarMoedaBRL(AItem.Total));
  Avancar(H);
end;

procedure TRenderDav.DesenharRodapeFiscal(const ADados: TDavRelatorioDados);
var
  BOX_LEFT, BOX_RIGHT, YBox, YLinha, YFimEsquerda, I, AlturaBox, MaxChars: Integer;
  Linhas: array[0..6] of string;
  Valores: array[0..6] of string;
  Impostos: array[0..6] of string;
  ValImp: array[0..6] of string;
  Obs: string;
begin
  if FY + EspacoRodape > FPageBottom then
    NovaPagina;

  BOX_RIGHT := FMargemDir;
  BOX_LEFT := BOX_RIGHT - 250;
  YBox := FY;
  AlturaBox := (AlturaLinha * 7) + 14;

  Linhas[0] := 'Subtotal';
  Valores[0] := FormatarMoedaBRL(ADados.Subtotal);
  Linhas[1] := 'Desconto';
  Valores[1] := FormatarMoedaBRL(ADados.Desconto);
  Linhas[2] := 'Frete';
  Valores[2] := FormatarMoedaBRL(ADados.Frete);
  Linhas[3] := 'Seguro';
  Valores[3] := FormatarMoedaBRL(ADados.Seguro);
  Linhas[4] := 'Outras despesas';
  Valores[4] := FormatarMoedaBRL(ADados.Outros);
  Linhas[5] := 'IPI';
  Valores[5] := FormatarMoedaBRL(ADados.ValorIPI);
  Linhas[6] := 'Valor total da nota';
  Valores[6] := FormatarMoedaBRL(ADados.Total);

  Impostos[0] := 'Base calc. ICMS';
  ValImp[0] := FormatarMoedaBRL(ADados.BaseICMS);
  Impostos[1] := 'Valor ICMS';
  ValImp[1] := FormatarMoedaBRL(ADados.ValorICMS);
  Impostos[2] := 'Base calc. ICMS ST';
  ValImp[2] := FormatarMoedaBRL(ADados.BaseST);
  Impostos[3] := 'Valor ICMS ST';
  ValImp[3] := FormatarMoedaBRL(ADados.ValorST);
  Impostos[4] := 'Valor IPI';
  ValImp[4] := FormatarMoedaBRL(ADados.ValorIPI);
  Impostos[5] := 'Valor PIS';
  ValImp[5] := FormatarMoedaBRL(ADados.ValorPIS);
  Impostos[6] := 'Valor COFINS';
  ValImp[6] := FormatarMoedaBRL(ADados.ValorCOFINS);

  FCanvas.Brush.Color := clWhite;
  FCanvas.FillRect(Rect(BOX_LEFT, YBox, BOX_RIGHT, YBox + AlturaBox));
  FCanvas.Pen.Color := clBlack;
  FCanvas.Rectangle(BOX_LEFT, YBox, BOX_RIGHT, YBox + AlturaBox);

  for I := 0 to 6 do
  begin
    YLinha := YBox + 6 + (I * AlturaLinha);
    if I = 6 then
      DefinirFonte(8, True)
    else
      DefinirFonte(8, False);
    Texto(BOX_LEFT + 8, YLinha, Linhas[I]);
    TextoDireita(BOX_RIGHT - 8, YLinha, Valores[I]);
  end;

  DefinirFonte(8, False);
  YLinha := YBox;
  YFimEsquerda := YBox;
  for I := 0 to 6 do
  begin
    Texto(FMargemEsq, YLinha, Impostos[I] + ': ' + ValImp[I]);
    Inc(YLinha, AlturaLinha);
    YFimEsquerda := YLinha;
  end;

  if ADados.Observacao <> '' then
  begin
    Obs := 'Dados adicionais: ' + ADados.Observacao;
    MaxChars := (BOX_LEFT - FMargemEsq - 16) div 7;
    if MaxChars < 24 then
      MaxChars := 24;
    if Length(Obs) > MaxChars then
      Obs := Copy(Obs, 1, MaxChars) + '...';
    Texto(FMargemEsq, YLinha, Obs);
    Inc(YLinha, AlturaLinha);
    YFimEsquerda := YLinha;
  end;

  FY := YBox + AlturaBox;
  if YFimEsquerda > FY then
    FY := YFimEsquerda;
  Inc(FY, 16);
  DefinirFonte(8, False);
  TextoDireita(FMargemDir, FPageHeight - 40, IntToStr(FNumeroPagina));
end;

procedure TRenderDav.DesenharRodape(const ADados: TDavRelatorioDados);
var
  BOX_LEFT, BOX_RIGHT, YBox, YLinha, YFimEsquerda, I, AlturaBox, MaxChars, QtdLinhas: Integer;
  Linhas: array[0..6] of string;
  Valores: array[0..6] of string;
  Obs, Pagto: string;
  TotalPecas, TotalServicos: Double;
  MeiaA4Comercial: Boolean;
begin
  MeiaA4Comercial := FModoComercial and (FPageHeight <= IMPRESSAO_MEIA_A4_ALTURA + 40);

  if FY + EspacoRodape > FPageBottom then
    NovaPagina;

  BOX_RIGHT := FMargemDir;
  BOX_LEFT := BOX_RIGHT - 250;
  if MeiaA4Comercial then
    BOX_LEFT := BOX_RIGHT - 210;

  if FModoComercial then
  begin
    TotalPecas := TotalPorTipo(ADados, 'P');
    TotalServicos := TotalPorTipo(ADados, 'S');
    QtdLinhas := 5;
    Linhas[0] := 'Total pecas';
    Valores[0] := FormatarMoedaBRL(TotalPecas);
    Linhas[1] := 'Total servicos';
    Valores[1] := FormatarMoedaBRL(TotalServicos);
    Linhas[2] := 'Desconto';
    Valores[2] := FormatarMoedaBRL(ADados.Desconto);
    Linhas[3] := 'Frete';
    Valores[3] := FormatarMoedaBRL(ADados.Frete);
    if (ADados.Outros <> 0) or (not FModoComercial) then
    begin
      Linhas[4] := 'Outros';
      Valores[4] := FormatarMoedaBRL(ADados.Outros);
      Linhas[5] := 'Total';
      Valores[5] := FormatarMoedaBRL(ADados.Total);
      QtdLinhas := 6;
    end
    else
    begin
      Linhas[4] := 'Total';
      Valores[4] := FormatarMoedaBRL(ADados.Total);
      QtdLinhas := 5;
    end;
  end
  else
  begin
    QtdLinhas := 5;
    Linhas[0] := 'Subtotal';
    Valores[0] := FormatarMoedaBRL(ADados.Subtotal);
    Linhas[1] := 'Desconto';
    Valores[1] := FormatarMoedaBRL(ADados.Desconto);
    Linhas[2] := 'Frete';
    Valores[2] := FormatarMoedaBRL(ADados.Frete);
    Linhas[3] := 'Outros';
    Valores[3] := FormatarMoedaBRL(ADados.Outros);
    Linhas[4] := 'Total';
    Valores[4] := FormatarMoedaBRL(ADados.Total);
  end;

  AlturaBox := (AlturaLinha * QtdLinhas) + 10;

  if MeiaA4Comercial then
    YBox := FPageBottom - AlturaBox - 22
  else
    YBox := FY;

  FCanvas.Brush.Style := bsSolid;
  FCanvas.Brush.Color := clWhite;
  FCanvas.FillRect(Rect(BOX_LEFT, YBox, BOX_RIGHT, YBox + AlturaBox));
  FCanvas.Pen.Color := clBlack;
  FCanvas.Rectangle(BOX_LEFT, YBox, BOX_RIGHT, YBox + AlturaBox);

  for I := 0 to QtdLinhas - 1 do
  begin
    YLinha := YBox + 4 + (I * AlturaLinha);
    if I = QtdLinhas - 1 then
    begin
      DefinirFonte(10, True);
      if FModoComercial then
        FCanvas.Brush.Color := COR_COMERCIAL_TOTAL
      else
        FCanvas.Brush.Color := clWhite;
      FCanvas.Brush.Style := bsSolid;
      FCanvas.FillRect(Rect(BOX_LEFT + 1, YLinha - 2, BOX_RIGHT - 1, YLinha + AlturaLinha));
    end
    else
      DefinirFonte(8, False);
    Texto(BOX_LEFT + 8, YLinha, Linhas[I]);
    TextoDireita(BOX_RIGHT - 8, YLinha, Valores[I]);
  end;

  DefinirFonte(8, False);
  if MeiaA4Comercial then
    YLinha := FY
  else
    YLinha := YBox;
  YFimEsquerda := YLinha;

  if (not MeiaA4Comercial) and (ADados.Vencimento <> '') then
  begin
    Texto(FMargemEsq, YLinha, 'Dt. Venc.: ' + ADados.Vencimento);
    Inc(YLinha, AlturaLinha);
    YFimEsquerda := YLinha;
  end;

  if ADados.Pagamento <> '' then
  begin
    Pagto := 'Pagamento: ' + ADados.Pagamento;
    MaxChars := (BOX_LEFT - FMargemEsq - 20) div 7;
    if MaxChars < 20 then
      MaxChars := 20;
    if Length(Pagto) > MaxChars then
      Pagto := Copy(Pagto, 1, MaxChars) + '...';
    Texto(FMargemEsq, YLinha, Pagto);
    Inc(YLinha, AlturaLinha);
    YFimEsquerda := YLinha;
  end;

  if ADados.Observacao <> '' then
  begin
    Obs := 'Observacao: ' + ADados.Observacao;
    MaxChars := (BOX_LEFT - FMargemEsq - 20) div 7;
    if MaxChars < 20 then
      MaxChars := 20;
    if Length(Obs) > MaxChars then
      Obs := Copy(Obs, 1, MaxChars) + '...';
    if MeiaA4Comercial and (YLinha + AlturaLinha > YBox - 2) then
      YLinha := YBox - AlturaLinha - 2;
    Texto(FMargemEsq, YLinha, Obs);
    Inc(YLinha, AlturaLinha);
    YFimEsquerda := YLinha;
  end;

  if MeiaA4Comercial then
    FY := FPageBottom - 18
  else
  begin
    FY := YBox + AlturaBox;
    if YFimEsquerda > FY then
      FY := YFimEsquerda;
    if FPageHeight > IMPRESSAO_MEIA_A4_ALTURA + 40 then
    begin
      Inc(FY, 24);
      FCanvas.Pen.Color := clBlack;
      FCanvas.MoveTo(220, FY);
      FCanvas.LineTo(520, FY);
      DefinirFonte(8, False);
      TextoCentro(Rect(220, FY + 6, 520, FY + 24), ADados.ClienteNome);
    end
    else
      Inc(FY, 8);
  end;

  DefinirFonte(7, False);
  TextoDireita(FMargemDir, FPageHeight - 18, IntToStr(FNumeroPagina));
end;

procedure TRenderDav.Renderizar(ADados: TDavRelatorioDados);
var
  I: Integer;
  Zebra: Boolean;
begin
  FModoFiscal := RelatorioModoFiscal(ADados.TituloRelatorio);
  FModoComercial := RelatorioModoComercial(ADados.TituloRelatorio);
  CalcularColunasGrid;
  DesenharCabecalhoPagina(ADados);
  DesenharCliente(ADados);
  if FModoFiscal then
    DesenharTituloGridFiscal
  else
    DesenharTituloGrid;
  Zebra := False;
  for I := 0 to ADados.Itens.Count - 1 do
  begin
    if FModoFiscal then
      DesenharLinhaItemFiscal(ADados.Itens[I], Zebra)
    else
      DesenharLinhaItem(ADados.Itens[I], Zebra);
    Zebra := not Zebra;
  end;
  if FModoFiscal then
    DesenharRodapeFiscal(ADados)
  else
    DesenharRodape(ADados);
end;

class function TDavRelatorioImpressao.GerarPaginasPreview(
  ADados: TDavRelatorioDados): TListaPaginasImpressao;
var
  Render: TRenderDav;
  Bmp: Vcl.Graphics.TBitmap;
  Largura, Altura, I: Integer;
begin
  Result := TListaPaginasImpressao.Create;
  Bmp := Vcl.Graphics.TBitmap.Create;
  try
    Largura := IMPRESSAO_PREVIEW_LARGURA;
    if RelatorioModoComercial(ADados.TituloRelatorio) then
      Altura := IMPRESSAO_MEIA_A4_ALTURA
    else
      Altura := IMPRESSAO_PREVIEW_ALTURA;

    TImpressaoPagina.PrepararBitmapPagina(Bmp, Largura, Altura);
    Result.Add(Bmp);
    Render := TRenderDav.Create(Bmp.Canvas, Largura, Altura, True, Result);
    try
      Render.Renderizar(ADados);
    finally
      Render.Free;
    end;

    for I := 0 to Result.Count - 1 do
      TImpressaoPagina.FinalizarPaginaBitmap(Result.Pagina(I));
  except
    Result.Free;
    raise;
  end;
end;

class procedure TDavRelatorioImpressao.VisualizarPdf(ADados: TDavRelatorioDados;
  const ANomeArquivo: string);
var
  Paginas: TListaPaginasImpressao;
begin
  Paginas := GerarPaginasPreview(ADados);
  try
    if Paginas.Count = 0 then
      raise Exception.Create('Nao foi possivel gerar o documento para impressao.');
    TImpressaoPagina.GerarPdfEAbrir(Paginas, ANomeArquivo);
  finally
    Paginas.Free;
  end;
end;

class procedure TDavRelatorioImpressao.Imprimir(ADados: TDavRelatorioDados;
  ACanvas: TCanvas; APageWidth, APageHeight: Integer);
var
  Paginas: TListaPaginasImpressao;
begin
  Paginas := GerarPaginasPreview(ADados);
  try
    if Paginas.Count = 0 then
      raise Exception.Create('Nao foi possivel gerar as paginas para impressao.');
    TImpressaoPagina.ImprimirPaginasPreview(Paginas);
  finally
    Paginas.Free;
  end;
end;

end.
