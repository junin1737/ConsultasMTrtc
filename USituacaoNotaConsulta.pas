unit USituacaoNotaConsulta;

interface

uses
  System.Types, Data.DB, Vcl.Graphics, Vcl.Grids, Vcl.DBGrids, UConsultaCampos;

type
  TClasseSituacaoNotaLista = (csnNormal, csnTransmitida, csnCancelada, csnInutilizada);

function MontarSelectSituacaoNotaFiscalLista: string;
function MontarSelectSituacaoNfceLista: string;
function MontarSelectSituacaoCompraLista: string;
function ClassificarSituacaoNotaFiscalLista(ASituacao: Integer;
  const ASituacaoDoc: string): TClasseSituacaoNotaLista;
function ClassificarSituacaoCompraLista(ASituacao: Integer;
  const ASituacaoDoc: string): TClasseSituacaoNotaLista;
function CorFonteSituacaoNotaLista(AClasse: TClasseSituacaoNotaLista): TColor;
function CorFontePorTextoSituacaoNotaLista(const ATexto: string): TColor;
function CorFonteLinhaNotaLista(ADataSet: TDataSet): TColor;
procedure DesenharCelulaGridNotaLista(AGrid: TDBGrid; const Rect: TRect;
  DataCol: Integer; Column: TColumn; State: TGridDrawState);
procedure AplicarLargurasColunasGridNotaVenda(AGrid: TDBGrid);
procedure AplicarLargurasColunasGridCompra(AGrid: TDBGrid);

const
  COR_NOTA_TRANSMITIDA = TColor($00008800);
  COR_NOTA_CANCELADA = clRed;
  COR_NOTA_INUTILIZADA = clGrayText;
  CAMPO_SITUACAO_NOTA_LISTA = 'SITUACAO_NOTA';

implementation

uses
  System.SysUtils;

procedure DefinirLarguraColuna(AGrid: TDBGrid; const ACampo: string; ALargura: Integer);
var
  I: Integer;
begin
  if (AGrid = nil) or (ALargura <= 0) then
    Exit;

  for I := 0 to AGrid.Columns.Count - 1 do
  begin
    if SameText(AGrid.Columns[I].FieldName, ACampo) then
    begin
      AGrid.Columns[I].Width := ALargura;
      Break;
    end;
  end;
end;

function MontarCaseSituacaoNotaLista(const ACampoSituacao, ACampoSituacaoDoc: string): string;
var
  Doc: string;
begin
  Doc := 'TRIM(COALESCE(' + ACampoSituacaoDoc + ', ''''))';
  Result :=
    'CAST(CASE ' +
    'WHEN ' + Doc + ' IN (''04'', ''05'') THEN ''Inutilizada'' ' +
    'WHEN ' + Doc + ' = ''02'' THEN ''Cancelada'' ' +
    'ELSE ''Transmitida'' ' +
    'END AS VARCHAR(20) CHARACTER SET WIN1252) AS SITUACAO_NOTA';
end;

function MontarSelectSituacaoNotaFiscalLista: string;
begin
  Result := MontarCaseSituacaoNotaLista('N.NFSITUACAO', 'N.NFSITUACAODOC');
end;

function MontarSelectSituacaoNfceLista: string;
begin
  Result := MontarCaseSituacaoNotaLista('N.VENRNFCESITUACAO', 'N.VENRNFCESITUACAODOC');
end;

function MontarSelectSituacaoCompraLista: string;
begin
  Result := MontarCaseSituacaoNotaLista('E.ENTCSITUACAO', 'E.ENTCSITUACAODOCUMENTO');
end;

function ClassificarPorCampos(ASituacao: Integer; const ASituacaoDoc: string): TClasseSituacaoNotaLista;
var
  Cod: string;
begin
  Cod := Trim(ASituacaoDoc);
  if (Cod = '04') or (Cod = '05') then
    Exit(csnInutilizada);
  if Cod = '02' then
    Exit(csnCancelada);
  Result := csnTransmitida;
end;

function ClassificarSituacaoNotaFiscalLista(ASituacao: Integer;
  const ASituacaoDoc: string): TClasseSituacaoNotaLista;
begin
  Result := ClassificarPorCampos(ASituacao, ASituacaoDoc);
end;

function ClassificarSituacaoCompraLista(ASituacao: Integer;
  const ASituacaoDoc: string): TClasseSituacaoNotaLista;
begin
  Result := ClassificarPorCampos(ASituacao, ASituacaoDoc);
end;

function CorFonteSituacaoNotaLista(AClasse: TClasseSituacaoNotaLista): TColor;
begin
  case AClasse of
    csnTransmitida, csnNormal: Result := COR_NOTA_TRANSMITIDA;
    csnCancelada: Result := COR_NOTA_CANCELADA;
    csnInutilizada: Result := COR_NOTA_INUTILIZADA;
  else
    Result := COR_NOTA_TRANSMITIDA;
  end;
end;

function CorFontePorTextoSituacaoNotaLista(const ATexto: string): TColor;
var
  Sit: string;
begin
  Sit := Trim(ATexto);
  if SameText(Sit, 'Cancelada') then
    Exit(COR_NOTA_CANCELADA);
  if SameText(Sit, 'Inutilizada') then
    Exit(COR_NOTA_INUTILIZADA);
  Result := COR_NOTA_TRANSMITIDA;
end;

function CorFonteLinhaNotaLista(ADataSet: TDataSet): TColor;
var
  CampoDoc, CampoTexto: TField;
  SitDoc: string;
begin
  Result := COR_NOTA_TRANSMITIDA;
  if (ADataSet = nil) or (not ADataSet.Active) then
    Exit;

  CampoDoc := ADataSet.FindField('NFSITUACAODOC');
  if CampoDoc = nil then
    CampoDoc := ADataSet.FindField('VENRNFCESITUACAODOC');
  if CampoDoc = nil then
    CampoDoc := ADataSet.FindField('ENTCSITUACAODOCUMENTO');

  if CampoDoc <> nil then
  begin
    SitDoc := Trim(CampoDoc.AsString);
    if (SitDoc = '04') or (SitDoc = '05') then
      Exit(COR_NOTA_INUTILIZADA);
    if SitDoc = '02' then
      Exit(COR_NOTA_CANCELADA);
  end;

  CampoTexto := ADataSet.FindField(CAMPO_SITUACAO_NOTA_LISTA);
  if CampoTexto <> nil then
    Result := CorFontePorTextoSituacaoNotaLista(CampoTexto.AsString);
end;

procedure DesenharCelulaGridNotaLista(AGrid: TDBGrid; const Rect: TRect;
  DataCol: Integer; Column: TColumn; State: TGridDrawState);
var
  R: TRect;
  Texto: string;
  CorFonte: TColor;
  AlinharDireita: Boolean;
begin
  if AGrid = nil then
    Exit;

  R := Rect;

  if (gdSelected in State) or (gdFocused in State) then
  begin
    AGrid.Canvas.Brush.Color := clHighlight;
    AGrid.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    AGrid.Canvas.Brush.Color := clWindow;
    if AGrid.DataSource <> nil then
      CorFonte := CorFonteLinhaNotaLista(AGrid.DataSource.DataSet)
    else
      CorFonte := clWindowText;
    AGrid.Canvas.Font.Color := CorFonte;
  end;

  AGrid.Canvas.FillRect(R);

  if Column.Field <> nil then
    Texto := Column.Field.DisplayText
  else
    Texto := '';

  AGrid.Canvas.Font := AGrid.Font;
  if not ((gdSelected in State) or (gdFocused in State)) then
  begin
    if AGrid.DataSource <> nil then
      AGrid.Canvas.Font.Color := CorFonteLinhaNotaLista(AGrid.DataSource.DataSet)
    else
      AGrid.Canvas.Font.Color := clWindowText;
  end;

  AlinharDireita := (Column.Field <> nil) and
    (Column.Field.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBcd]);
  DesenharTextoCelulaGrid(AGrid.Canvas, R, Texto, AlinharDireita);
end;

procedure AplicarLargurasColunasGridNotaVenda(AGrid: TDBGrid);
begin
  if (AGrid = nil) or (AGrid.Columns.Count = 0) then
    Exit;

  AGrid.Columns.BeginUpdate;
  try
    DefinirLarguraColuna(AGrid, 'NFNUMEROFISCAL', 78);
    DefinirLarguraColuna(AGrid, 'DOCFNUMERO', 78);
    DefinirLarguraColuna(AGrid, 'NFDTEMISSAO', 88);
    DefinirLarguraColuna(AGrid, 'NFDTSAIDA', 88);
    DefinirLarguraColuna(AGrid, 'NOME_CLIENTE', 248);
    DefinirLarguraColuna(AGrid, 'NFTOTALNOTA', 108);
    DefinirLarguraColuna(AGrid, CAMPO_SITUACAO_NOTA_LISTA, 118);
  finally
    AGrid.Columns.EndUpdate;
  end;
end;

procedure AplicarLargurasColunasGridCompra(AGrid: TDBGrid);
begin
  if (AGrid = nil) or (AGrid.Columns.Count = 0) then
    Exit;

  AGrid.Columns.BeginUpdate;
  try
    DefinirLarguraColuna(AGrid, 'ENTCNUMERO', 78);
    DefinirLarguraColuna(AGrid, 'ENTCSERIE', 62);
    DefinirLarguraColuna(AGrid, 'ENTCDTEMISSAO', 88);
    DefinirLarguraColuna(AGrid, 'ENTCDTENTRADA', 88);
    DefinirLarguraColuna(AGrid, 'NOME_FORNECEDOR', 248);
    DefinirLarguraColuna(AGrid, 'ENTCVRTOTAL', 108);
    DefinirLarguraColuna(AGrid, CAMPO_SITUACAO_NOTA_LISTA, 118);
  finally
    AGrid.Columns.EndUpdate;
  end;
end;

end.
