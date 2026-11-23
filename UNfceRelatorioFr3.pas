unit UNfceRelatorioFr3;

interface

uses
  System.SysUtils;

type
  TNfceRelatorioFr3 = class
  public
    class procedure Visualizar(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero: Integer);
    class procedure Imprimir(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero: Integer);
  end;

implementation

uses
  System.IOUtils, Vcl.Forms, Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  frxClass, frxDBSet, frxExportPDF,
  UFormatacaoMoeda, UImpressaoUtil, UNfceCupomImpressao, UMapaNfce;

function CaminhoRelatorioNfceCupom: string;
var
  Base: string;
begin
  Base := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Result := Base + 'Report\NFCeCupom.fr3';
  if FileExists(Result) then
    Exit;
  Result := Base + '..\Report\NFCeCupom.fr3';
  if FileExists(Result) then
    Exit;
  Result := ExtractFilePath(ParamStr(0)) + '..\..\Report\NFCeCupom.fr3';
end;

function FormatarChaveRelatorio(const AChave: string): string;
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

procedure MontarMemTableCabecalho(const ADados: TNfceCupomDados; ATable: TFDMemTable);
begin
  ATable.Close;
  ATable.FieldDefs.Clear;
  ATable.FieldDefs.Add('EMPRESA_NOME', ftString, 120);
  ATable.FieldDefs.Add('EMPRESA_CNPJ', ftString, 20);
  ATable.FieldDefs.Add('EMPRESA_END', ftString, 200);
  ATable.FieldDefs.Add('EMPRESA_FONE', ftString, 30);
  ATable.FieldDefs.Add('NUMERO_NFCE', ftString, 20);
  ATable.FieldDefs.Add('NUMERO_CUPOM', ftString, 20);
  ATable.FieldDefs.Add('EMISSAO', ftString, 20);
  ATable.FieldDefs.Add('TRANSMISSAO', ftString, 20);
  ATable.FieldDefs.Add('SITUACAO', ftString, 20);
  ATable.FieldDefs.Add('CLIENTE', ftString, 120);
  ATable.FieldDefs.Add('CHAVE', ftString, 60);
  ATable.FieldDefs.Add('PROTOCOLO', ftString, 30);
  ATable.FieldDefs.Add('OBSERVACAO', ftMemo);
  ATable.FieldDefs.Add('TOTAL', ftString, 20);
  ATable.CreateDataSet;
  ATable.Append;
  ATable.FieldByName('EMPRESA_NOME').AsString := ADados.EmpresaNome;
  ATable.FieldByName('EMPRESA_CNPJ').AsString := ADados.EmpresaCnpj;
  ATable.FieldByName('EMPRESA_END').AsString := ADados.EmpresaEndereco;
  ATable.FieldByName('EMPRESA_FONE').AsString := ADados.EmpresaTelefone;
  ATable.FieldByName('NUMERO_NFCE').AsString := ADados.NumeroNfce;
  ATable.FieldByName('NUMERO_CUPOM').AsString := ADados.NumeroCupom;
  ATable.FieldByName('EMISSAO').AsString := ADados.Emissao;
  ATable.FieldByName('TRANSMISSAO').AsString := ADados.Transmissao;
  ATable.FieldByName('SITUACAO').AsString := ADados.Situacao;
  ATable.FieldByName('CLIENTE').AsString := ADados.Cliente;
  ATable.FieldByName('CHAVE').AsString := FormatarChaveRelatorio(ADados.Chave);
  ATable.FieldByName('PROTOCOLO').AsString := ADados.Protocolo;
  ATable.FieldByName('OBSERVACAO').AsString := ADados.Observacao;
  ATable.FieldByName('TOTAL').AsString := FormatarMoedaBRL(ADados.Total);
  ATable.Post;
end;

procedure MontarMemTableItens(const ADados: TNfceCupomDados; ATable: TFDMemTable);
var
  I: Integer;
  Item: TNfceCupomItem;
begin
  ATable.Close;
  ATable.FieldDefs.Clear;
  ATable.FieldDefs.Add('ITEM_SEQ', ftString, 5);
  ATable.FieldDefs.Add('DESCRICAO', ftString, 120);
  ATable.FieldDefs.Add('LINHA_VALOR', ftString, 40);
  ATable.CreateDataSet;

  for I := 0 to ADados.Itens.Count - 1 do
  begin
    Item := ADados.Itens[I];
    ATable.Append;
    ATable.FieldByName('ITEM_SEQ').AsString := IntToStr(I + 1);
    ATable.FieldByName('DESCRICAO').AsString := Item.Descricao;
    ATable.FieldByName('LINHA_VALOR').AsString :=
      Format('%s x %s = %s',
        [FormatarQuantidade(Item.Qtde), FormatarMoedaBRL(Item.Unitario),
         FormatarMoedaBRL(Item.Total)]);
    ATable.Post;
  end;
end;

procedure ExecutarRelatorio(const ADados: TNfceCupomDados; AImprimir: Boolean);
var
  Report: TfrxReport;
  DBCab, DBItens: TfrxDBDataset;
  TBCab, TBItens: TFDMemTable;
  ExportPDF: TfrxPDFExport;
  Caminho, PdfPath, Pasta: string;
begin
  Caminho := CaminhoRelatorioNfceCupom;
  if not FileExists(Caminho) then
    raise Exception.Create('Relatorio NFC-e nao encontrado:' + sLineBreak + Caminho);

  TBCab := TFDMemTable.Create(nil);
  TBItens := TFDMemTable.Create(nil);
  Report := TfrxReport.Create(nil);
  DBCab := TfrxDBDataset.Create(nil);
  DBItens := TfrxDBDataset.Create(nil);
  ExportPDF := TfrxPDFExport.Create(nil);
  try
    MontarMemTableCabecalho(ADados, TBCab);
    MontarMemTableItens(ADados, TBItens);

    DBCab.Name := 'frxDBCabecalho';
    DBCab.UserName := 'Cabecalho';
    DBCab.DataSet := TBCab;

    DBItens.Name := 'frxDBItens';
    DBItens.UserName := 'Itens';
    DBItens.DataSet := TBItens;

    Report.DataSets.Add(DBCab);
    Report.DataSets.Add(DBItens);
    Report.LoadFromFile(Caminho);
    if Trim(Report.ScriptText.Text) = '' then
      Report.ScriptText.Text := 'begin' + sLineBreak + 'end.';

    Report.PrepareReport(True);

    if AImprimir then
    begin
      Report.Print;
      Exit;
    end;

    Pasta := IncludeTrailingPathDelimiter(TPath.GetTempPath) + 'ConsultasNfcePdf' + PathDelim;
    ForceDirectories(Pasta);
    PdfPath := Pasta + TImpressaoPagina.SanitizarNomeArquivoPdf('NFC-e ' + ADados.NumeroNfce) + '.pdf';
    ExportPDF.FileName := PdfPath;
    ExportPDF.ShowDialog := False;
    ExportPDF.ShowProgress := False;
    ExportPDF.DefaultPath := Pasta;
    Report.Export(ExportPDF);
    if (PdfPath = '') or (not TFile.Exists(PdfPath)) then
      raise Exception.Create('Nao foi possivel gerar o PDF da NFC-e.');
    TImpressaoPagina.AbrirPdfNoVisualizadorPadrao(PdfPath);
  finally
    ExportPDF.Free;
    Report.Free;
    DBItens.Free;
    DBCab.Free;
    TBItens.Free;
    TBCab.Free;
  end;
end;

class procedure TNfceRelatorioFr3.Visualizar(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer);
var
  Dados: TNfceCupomDados;
begin
  Dados := TNfceCupomImpressao.CarregarDados(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  try
    if Dados.NumeroNfce = '' then
      raise Exception.Create('NFC-e nao encontrada para impressao.');
    ExecutarRelatorio(Dados, False);
  finally
    Dados.Free;
  end;
end;

class procedure TNfceRelatorioFr3.Imprimir(AEmpCodigo, AVenNumero, ATerNumero,
  ANfceNumero: Integer);
var
  Dados: TNfceCupomDados;
begin
  Dados := TNfceCupomImpressao.CarregarDados(AEmpCodigo, AVenNumero, ATerNumero, ANfceNumero);
  try
    if Dados.NumeroNfce = '' then
      raise Exception.Create('NFC-e nao encontrada para impressao.');
    ExecutarRelatorio(Dados, True);
  finally
    Dados.Free;
  end;
end;

end.
