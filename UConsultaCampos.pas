unit UConsultaCampos;

interface

uses
  System.SysUtils, System.Classes, System.Types, Data.DB, Vcl.Graphics, Vcl.Controls, Vcl.StdCtrls,
  Vcl.Forms, Vcl.ExtCtrls, Vcl.Buttons, Vcl.DBGrids;

function TituloAmigavelCampoOrcamento(const ANomeCampo: string): string;
function TituloAmigavelCampoDav(const ANomeCampo: string): string;
function TituloAmigavelCampo(const ANomeCampo: string): string;
procedure AplicarEstiloTituloCampo(ALabel: TLabel);
procedure AplicarFonteSegoeUISemiBold(AFont: TFont; ATamanho: Integer = 0);
procedure AplicarFonteConsultaForm(AForm: TForm);
procedure AjustarLayoutPesquisaConsulta(APanelTopo: TPanel; ALblPesquisa: TLabel;
  AEdtPesquisa: TEdit);
procedure ConfigurarGridConsulta(AGrid: TDBGrid);
procedure AplicarMargemTextoCelulaGrid(var ARect: TRect; AAlinharDireita: Boolean);
procedure DesenharTextoCelulaGrid(ACanvas: TCanvas; var ARect: TRect; const ATexto: string;
  AAlinharDireita: Boolean);
procedure ConfigurarOrdenacaoGrid(AGrid: TDBGrid);
procedure ConfigurarEditMoedaLeitura(AEdit: TEdit);
procedure AjustarLargurasGridDetalhe(AGrid: TDBGrid);
function NomeUsuarioPorCodigo(AEmpCodigo, AUsuCodigo: Integer): string;

implementation

uses
  Winapi.Windows, FireDAC.Stan.Option, FireDAC.Comp.Client, FireDAC.Comp.DataSet, UdmConexao;

type
  TGridOrdenacaoEstado = class(TComponent)
  public
    Campo: string;
    Crescente: Boolean;
    constructor Create(AOwner: TComponent); override;
  end;

  TGridOrdenacaoLink = class(TComponent)
  private
    FGrid: TDBGrid;
  public
    constructor Create(AOwner: TComponent; AGrid: TDBGrid); reintroduce;
    procedure TituloClique(Column: TColumn);
  end;

const
  GRID_ORDENACAO_COMPONENT = 'GridOrdenacaoEstado';

constructor TGridOrdenacaoEstado.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Campo := '';
  Crescente := True;
end;

constructor TGridOrdenacaoLink.Create(AOwner: TComponent; AGrid: TDBGrid);
begin
  inherited Create(AOwner);
  FGrid := AGrid;
end;

function ObterEstadoOrdenacaoGrid(AGrid: TDBGrid): TGridOrdenacaoEstado;
begin
  Result := nil;
  if AGrid = nil then
    Exit;
  Result := TGridOrdenacaoEstado(AGrid.FindComponent(GRID_ORDENACAO_COMPONENT));
  if Result = nil then
  begin
    Result := TGridOrdenacaoEstado.Create(AGrid);
    Result.Name := GRID_ORDENACAO_COMPONENT;
  end;
end;

procedure AplicarOrdenacaoDataSet(ADataSet: TDataSet; const ACampo: string;
  ACrescente: Boolean);
var
  Adapted: TFDAdaptedDataSet;
  Bookmark: TBookmark;
  Idx: string;
begin
  if (ADataSet = nil) or (not ADataSet.Active) or (ACampo = '') then
    Exit;
  if ADataSet.FindField(ACampo) = nil then
    Exit;
  if not (ADataSet is TFDAdaptedDataSet) then
    Exit;

  Adapted := TFDAdaptedDataSet(ADataSet);
  Adapted.FetchOptions.Mode := fmAll;
  if ACrescente then
    Idx := ACampo
  else
    Idx := ACampo + ':D';

  Bookmark := ADataSet.GetBookmark;
  try
    Adapted.IndexFieldNames := Idx;
    if ADataSet.BookmarkValid(Bookmark) then
      ADataSet.GotoBookmark(Bookmark);
  finally
    ADataSet.FreeBookmark(Bookmark);
  end;
end;

procedure OrdenarGridPorColuna(AGrid: TDBGrid; Column: TColumn);
var
  DS: TDataSet;
  Estado: TGridOrdenacaoEstado;
  Campo: string;
begin
  if (AGrid = nil) or (Column = nil) or (Column.Field = nil) then
    Exit;
  if AGrid.DataSource = nil then
    Exit;

  DS := AGrid.DataSource.DataSet;
  if (DS = nil) or (not DS.Active) then
    Exit;

  Campo := Column.Field.FieldName;
  Estado := ObterEstadoOrdenacaoGrid(AGrid);
  if SameText(Estado.Campo, Campo) then
    Estado.Crescente := not Estado.Crescente
  else
  begin
    Estado.Campo := Campo;
    Estado.Crescente := True;
  end;

  AplicarOrdenacaoDataSet(DS, Campo, Estado.Crescente);
end;

procedure TGridOrdenacaoLink.TituloClique(Column: TColumn);
begin
  OrdenarGridPorColuna(FGrid, Column);
end;

function ComecaCom(const ATexto, APrefixo: string): Boolean;
begin
  Result := (Length(ATexto) >= Length(APrefixo)) and
    SameText(Copy(ATexto, 1, Length(APrefixo)), APrefixo);
end;

procedure AplicarFonteSegoeUISemiBold(AFont: TFont; ATamanho: Integer);
begin
  AFont.Name := 'Segoe UI Semibold';
  AFont.Style := [];
  if ATamanho > 0 then
    AFont.Size := ATamanho;
end;

procedure AplicarFonteControle(AControl: TControl);
var
  I: Integer;
  Filho: TControl;
  Win: TWinControl;
begin
  if AControl = nil then
    Exit;

  if AControl is TLabel then
    AplicarFonteSegoeUISemiBold(TLabel(AControl).Font, 9)
  else if AControl is TEdit then
    AplicarFonteSegoeUISemiBold(TEdit(AControl).Font, 9)
  else if AControl is TMemo then
    AplicarFonteSegoeUISemiBold(TMemo(AControl).Font, 9)
  else if AControl is TButton then
    AplicarFonteSegoeUISemiBold(TButton(AControl).Font, 9)
  else if AControl is TSpeedButton then
    AplicarFonteSegoeUISemiBold(TSpeedButton(AControl).Font, 9)
  else if AControl is TDBGrid then
  begin
    AplicarFonteSegoeUISemiBold(TDBGrid(AControl).Font, 9);
    AplicarFonteSegoeUISemiBold(TDBGrid(AControl).TitleFont, 10);
  end;

  if AControl is TWinControl then
  begin
    Win := TWinControl(AControl);
    for I := 0 to Win.ControlCount - 1 do
    begin
      Filho := Win.Controls[I];
      AplicarFonteControle(Filho);
    end;
  end;
end;

procedure AplicarFonteConsultaForm(AForm: TForm);
begin
  if AForm = nil then
    Exit;
  AplicarFonteControle(AForm);
end;

procedure ConfigurarEditMoedaLeitura(AEdit: TEdit);
begin
  if AEdit = nil then
    Exit;
  AEdit.ReadOnly := True;
  AEdit.Color := clWindow;
  AEdit.Alignment := taRightJustify;
  AplicarFonteSegoeUISemiBold(AEdit.Font, 9);
end;

procedure AjustarLayoutPesquisaConsulta(APanelTopo: TPanel; ALblPesquisa: TLabel;
  AEdtPesquisa: TEdit);
const
  MARGEM = 12;
  ESPACO = 10;
begin
  if (APanelTopo = nil) or (ALblPesquisa = nil) or (AEdtPesquisa = nil) then
    Exit;

  ALblPesquisa.AutoSize := True;
  ALblPesquisa.Layout := tlCenter;
  ALblPesquisa.Top := 24;
  ALblPesquisa.Left := MARGEM;

  AEdtPesquisa.Top := 20;
  AEdtPesquisa.Left := ALblPesquisa.Left + ALblPesquisa.Width + ESPACO;
  AEdtPesquisa.Width := APanelTopo.ClientWidth - AEdtPesquisa.Left - MARGEM;
  if AEdtPesquisa.Width < 160 then
    AEdtPesquisa.Width := 160;
end;

procedure ConfigurarOrdenacaoGrid(AGrid: TDBGrid);
var
  Link: TGridOrdenacaoLink;
begin
  if AGrid = nil then
    Exit;
  ObterEstadoOrdenacaoGrid(AGrid);
  AGrid.Options := AGrid.Options + [dgTitles];
  Link := TGridOrdenacaoLink(AGrid.FindComponent('GridOrdenacaoLink'));
  if Link = nil then
  begin
    Link := TGridOrdenacaoLink.Create(AGrid, AGrid);
    Link.Name := 'GridOrdenacaoLink';
  end;
  AGrid.OnTitleClick := Link.TituloClique;
end;

procedure ConfigurarGridConsulta(AGrid: TDBGrid);
begin
  if AGrid = nil then
    Exit;

  AGrid.ReadOnly := True;
  AGrid.Options := AGrid.Options + [dgRowSelect, dgAlwaysShowSelection] - [dgEditing];
  ConfigurarOrdenacaoGrid(AGrid);
end;

procedure AplicarMargemTextoCelulaGrid(var ARect: TRect; AAlinharDireita: Boolean);
const
  MARGEM_ESQ = 8;
  MARGEM_DIR = 8;
begin
  if AAlinharDireita then
  begin
    Dec(ARect.Right, MARGEM_DIR);
    Inc(ARect.Left, 2);
  end
  else
  begin
    Inc(ARect.Left, MARGEM_ESQ);
    Dec(ARect.Right, 4);
  end;
end;

procedure DesenharTextoCelulaGrid(ACanvas: TCanvas; var ARect: TRect; const ATexto: string;
  AAlinharDireita: Boolean);
var
  Flags: Cardinal;
begin
  AplicarMargemTextoCelulaGrid(ARect, AAlinharDireita);
  if AAlinharDireita then
    Flags := DT_RIGHT or DT_VCENTER or DT_SINGLELINE
  else
    Flags := DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS;
  DrawText(ACanvas.Handle, PChar(ATexto), Length(ATexto), ARect, Flags);
end;

procedure AplicarEstiloTituloCampo(ALabel: TLabel);
begin
  ALabel.ParentFont := False;
  AplicarFonteSegoeUISemiBold(ALabel.Font, 10);
end;

function TituloAmigavelCampoOrcamento(const ANomeCampo: string): string;
var
  Nome: string;
begin
  Nome := UpperCase(ANomeCampo);

  if SameText(Nome, 'ORCCODIGO') then
    Exit('C'#243'digo');
  if SameText(Nome, 'ORCNUMERO') or (ComecaCom(Nome, 'ORC') and (Pos('NUMERO', Nome) > 0)) then
    Exit('N'#250'mero');
  if SameText(Nome, 'ORCDATA') or SameText(Nome, 'DATA') or SameText(Nome, 'DTORCAMENTO') then
    Exit('Data');
  if SameText(Nome, 'ORCPESCODIGO') or SameText(Nome, 'PESCODIGO') then
    Exit('C'#243'digo cliente');
  if Pos('NOME', Nome) > 0 then
    Exit('Nome');
  if Pos('CLIENTE', Nome) > 0 then
    Exit('Cliente');
  if Pos('VENDEDOR', Nome) > 0 then
    Exit('Vendedor');
  if Pos('VALOR', Nome) > 0 then
    Exit('Valor');
  if Pos('TOTAL', Nome) > 0 then
    Exit('Total');
  if Pos('SITUACAO', Nome) > 0 then
    Exit('Situa'#231#227'o');
  if Pos('STATUS', Nome) > 0 then
    Exit('Status');
  if Pos('OBS', Nome) > 0 then
    Exit('Observa'#231#245'es');
  if Pos('EMPCODIGO', Nome) > 0 then
    Exit('Empresa');
  if Pos('DESCONTO', Nome) > 0 then
    Exit('Desconto');
  if Pos('VALIDADE', Nome) > 0 then
    Exit('Validade');
  if Pos('ENTREGA', Nome) > 0 then
    Exit('Entrega');
  if Pos('PAGAMENTO', Nome) > 0 then
    Exit('Pagamento');
  if Pos('ATIVO', Nome) > 0 then
    Exit('Ativo');

  if ComecaCom(Nome, 'ORC') and (Length(Nome) > 3) then
    Exit(Copy(ANomeCampo, 4, MaxInt));

  Result := ANomeCampo;
end;

function TituloAmigavelCampoDav(const ANomeCampo: string): string;
var
  Nome: string;
begin
  Nome := UpperCase(ANomeCampo);

  if SameText(Nome, 'DAVCODIGO') then
    Exit('C'#243'digo');
  if SameText(Nome, 'DAVNUMERO') or (ComecaCom(Nome, 'DAV') and (Pos('NUMERO', Nome) > 0)) then
    Exit('N'#250'mero');
  if SameText(Nome, 'DAVDATA') or SameText(Nome, 'DATA') then
    Exit('Data');
  if SameText(Nome, 'DAVPESCODIGO') or SameText(Nome, 'PESCODIGO') then
    Exit('C'#243'digo cliente');
  if Pos('ORCCODIGO', Nome) > 0 then
    Exit('Or'#231'amento');
  if Pos('NOME', Nome) > 0 then
    Exit('Nome');
  if Pos('CLIENTE', Nome) > 0 then
    Exit('Cliente');
  if Pos('VENDEDOR', Nome) > 0 then
    Exit('Vendedor');
  if Pos('VALOR', Nome) > 0 then
    Exit('Valor');
  if Pos('TOTAL', Nome) > 0 then
    Exit('Total');
  if Pos('SITUACAO', Nome) > 0 then
    Exit('Situa'#231#227'o');
  if Pos('STATUS', Nome) > 0 then
    Exit('Status');
  if Pos('OBS', Nome) > 0 then
    Exit('Observa'#231#245'es');
  if Pos('EMPCODIGO', Nome) > 0 then
    Exit('Empresa');
  if Pos('DESCONTO', Nome) > 0 then
    Exit('Desconto');
  if Pos('PAGAMENTO', Nome) > 0 then
    Exit('Pagamento');
  if Pos('ATIVO', Nome) > 0 then
    Exit('Ativo');

  if ComecaCom(Nome, 'DAV') and (Length(Nome) > 3) then
    Exit(Copy(ANomeCampo, 4, MaxInt));

  Result := ANomeCampo;
end;

function TituloAmigavelCampo(const ANomeCampo: string): string;
var
  Nome: string;
begin
  Nome := UpperCase(ANomeCampo);

  if ComecaCom(Nome, 'DAV') then
    Exit(TituloAmigavelCampoDav(ANomeCampo));

  if ComecaCom(Nome, 'ORC') then
    Exit(TituloAmigavelCampoOrcamento(ANomeCampo));

  if SameText(Nome, 'PESCODIGO') then
    Exit('C'#243'digo');
  if SameText(Nome, 'PESNOME') then
    Exit('Nome');
  if SameText(Nome, 'PESTIPOPESSOA') then
    Exit('Tipo pessoa');
  if SameText(Nome, 'PESCNPJCPF') then
    Exit('CPF/CNPJ');
  if SameText(Nome, 'PESTIPOIE') then
    Exit('Tipo IE');
  if SameText(Nome, 'PESIE') then
    Exit('Inscri'#231#227'o estadual');
  if SameText(Nome, 'PESATIVO') then
    Exit('Ativo');

  Result := ANomeCampo;
end;

procedure AjustarLargurasGridDetalhe(AGrid: TDBGrid);
var
  I, LarguraUsada, LarguraDesc, IdxDesc: Integer;
  Col: TColumn;
  Nome: string;
begin
  if (AGrid = nil) or (AGrid.Columns.Count = 0) then
    Exit;

  IdxDesc := -1;
  LarguraUsada := GetSystemMetrics(SM_CXVSCROLL) + 6;

  for I := 0 to AGrid.Columns.Count - 1 do
  begin
    Col := AGrid.Columns[I];
    Nome := UpperCase(Col.FieldName);

    if SameText(Nome, 'CODIGO_ITEM') then
      Col.Width := 150
    else if SameText(Nome, 'ENTCINUMEROITEM') or SameText(Nome, 'NFITEMCONTADOR')
      or SameText(Nome, 'ENTCISERVITEM') or SameText(Nome, 'NFITEMSERVCONTADOR')
      or (Pos('ORDEM', Nome) > 0) then
      Col.Width := 48
    else if Pos('DESCRICAO', Nome) > 0 then
    begin
      IdxDesc := I;
      Continue;
    end
    else if Pos('QTDE', Nome) > 0 then
      Col.Width := 68
    else if Pos('UNITARIO', Nome) > 0 then
      Col.Width := 88
    else if Pos('TOTALLIQUIDO', Nome) > 0 then
      Col.Width := 92
    else
      Col.Width := 72;

    Inc(LarguraUsada, Col.Width);
  end;

  if IdxDesc >= 0 then
  begin
    LarguraDesc := AGrid.ClientWidth - LarguraUsada;
    if LarguraDesc < 160 then
      LarguraDesc := 160;
    AGrid.Columns[IdxDesc].Width := LarguraDesc;
  end;
end;

function NomeUsuarioPorCodigo(AEmpCodigo, AUsuCodigo: Integer): string;
var
  Q: TFDQuery;
begin
  Result := '';
  if (AEmpCodigo <= 0) or (AUsuCodigo <= 0) then
    Exit;
  if not dmConexao.Conectado then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := dmConexao.FDConnection1;
    try
      Q.SQL.Text :=
        'SELECT FIRST 1 COALESCE(P.PESNOME, U.USUNOME, U.USULOGIN) AS NOME ' +
        'FROM USUARIO U ' +
        'LEFT JOIN PESSOA P ON P.PESCODIGO = U.PESCODIGO ' +
        'WHERE U.EMPCODIGO = :EMPCODIGO AND U.USUCODIGO = :USUCODIGO';
      Q.ParamByName('EMPCODIGO').AsInteger := AEmpCodigo;
      Q.ParamByName('USUCODIGO').AsInteger := AUsuCodigo;
      Q.Open;
      if not Q.IsEmpty then
        Result := Trim(Q.FieldByName('NOME').AsString);
    except
    end;
  finally
    Q.Free;
  end;
end;

end.
