unit Uprincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Math, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Buttons,
  Vcl.Menus, Vcl.StdCtrls, System.ImageList, Vcl.ImgList, Vcl.Imaging.pngimage,
  System.IOUtils;

const
  WM_VERIFICAR_CONEXAO = WM_USER + 100;
  WM_EXIBIR_CONSULTA = WM_USER + 101;

type
  TModuloConsulta = (mcClientes, mcEstoque, mcOrcamento, mcReceber, mcPagar, mcDav, mcCompra, mcNotaFiscal);

  Tfrmprincipal = class(TForm)
    pnlCabecalho: TPanel;
    lblTitulo: TLabel;
    lblSubtitulo: TLabel;
    pnlModulos: TPanel;
    pnlTileClientes: TPanel;
    imgModClientes: TImage;
    lblModClientes: TLabel;
    pnlTileEstoque: TPanel;
    imgModEstoque: TImage;
    lblModEstoque: TLabel;
    pnlTileOrcamento: TPanel;
    imgModOrcamento: TImage;
    lblModOrcamento: TLabel;
    pnlTileReceber: TPanel;
    imgModReceber: TImage;
    lblModReceber: TLabel;
    pnlTilePagar: TPanel;
    imgModPagar: TImage;
    lblModPagar: TLabel;
    pnlTileDav: TPanel;
    imgModDav: TImage;
    lblModDav: TLabel;
    pnlTileCompra: TPanel;
    imgModCompra: TImage;
    lblModCompra: TLabel;
    pnlTileNotaFiscal: TPanel;
    imgModNotaFiscal: TImage;
    lblModNotaFiscal: TLabel;
    pnlAreaCentral: TPanel;
    pnlCardInicio: TPanel;
    lblBoasVindas: TLabel;
    pnlRodape: TPanel;
    lblRodape: TLabel;
    MainMenu1: TMainMenu;
    Arquivo1: TMenuItem;
    Cadastros1: TMenuItem;
    Clientes1: TMenuItem;
    Fornecedores1: TMenuItem;
    Produtos1: TMenuItem;
    Relatrios1: TMenuItem;
    sAIR1: TMenuItem;
    ImageList1: TImageList;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnModuloClick(Sender: TObject);
  private
    FConexaoVerificada: Boolean;
    FConsultaPendente: TForm;
    FTileTopNormal: array[TModuloConsulta] of Integer;
    FTileHover: TPanel;
    function PastaRaizExe: string;
    function BuscarArquivoIcone(const AArquivoIcone: string): string;
    function NomeRecursoIcone(const AArquivoIcone: string): string;
    function TileModulo(AModulo: TModuloConsulta): TPanel;
    function ImagemModulo(AModulo: TModuloConsulta): TImage;
    procedure ConfigurarVisual;
    procedure ConfigurarBarraModulos;
    procedure AjustarLayoutPrincipal;
    procedure CarregarIconeImagem(AImagem: TImage; const AArquivoIcone: string);
    procedure LiberarOutrasConsultas(AExceto: TForm);
    procedure FecharConsulta(AForm: TForm);
    procedure ExibirConsulta(AForm: TForm);
    procedure AbrirModulo(AModulo: TModuloConsulta);
    function ObterTileModulo(AControl: TObject): TPanel;
    function CursorDentroTile(ATile: TPanel): Boolean;
    procedure RestaurarTileHover(ATile: TPanel);
    procedure AtivarTileHover(ATile: TPanel);
    procedure ConfigurarHoverTile(ATile: TPanel; AImg: TImage; ALbl: TLabel);
    procedure TileModuloMouseEnter(Sender: TObject);
    procedure TileModuloMouseLeave(Sender: TObject);
    procedure WMVerificarConexao(var Msg: TMessage); message WM_VERIFICAR_CONEXAO;
    procedure WMExibirConsulta(var Msg: TMessage); message WM_EXIBIR_CONSULTA;
  public
  end;

var
  frmprincipal: Tfrmprincipal;

implementation

{$R *.dfm}
{$R ConsultasIcones.res}

uses
  UdmConexao, UConsultaLayout,
  UfrmClientes, UfrmEstoque, UfrmOrcamento, UfrmReceber, UfrmPagar, UfrmDav,
  UfrmCompra, UfrmNotaFiscal,
  UConfirmarFechar, UConsultaManager;

const
  PANEL_MODULOS_ALTURA = 148;
  TILE_LARGURA = 132;
  TILE_ALTURA = 116;
  TILE_MARGEM = 24;
  TILE_ESPACO = 9;
  ICON_TAMANHO = 72;
  TILE_HOVER_SOBE = 6;

function Tfrmprincipal.PastaRaizExe: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
end;

function Tfrmprincipal.BuscarArquivoIcone(const AArquivoIcone: string): string;

  function ProcurarNaPasta(const APasta: string): string;
  const
    EXTENSOES: array[0..4] of string = ('.png', '.bmp', '.jpg', '.jpeg', '.ico');
  var
    NomeBase, Caminho, Ext: string;
    Arquivos: TArray<string>;
    I, J: Integer;
  begin
    Result := '';
    if (APasta = '') or (not DirectoryExists(APasta)) then
      Exit;

    Caminho := IncludeTrailingPathDelimiter(APasta) + AArquivoIcone;
    if FileExists(Caminho) then
      Exit(Caminho);

    NomeBase := UpperCase(ChangeFileExt(AArquivoIcone, ''));
    for J := Low(EXTENSOES) to High(EXTENSOES) do
    begin
      Ext := EXTENSOES[J];
      Arquivos := TDirectory.GetFiles(APasta, '*' + Ext);
      for I := 0 to Length(Arquivos) - 1 do
        if SameText(ChangeFileExt(ExtractFileName(Arquivos[I]), ''), NomeBase) then
          Exit(Arquivos[I]);
    end;
  end;

var
  PastaExe, PastaIcones: string;
begin
  PastaExe := PastaRaizExe;
  Result := ProcurarNaPasta(PastaExe);
  if Result <> '' then
    Exit;

  PastaIcones := PastaExe + 'Imagens\';
  Result := ProcurarNaPasta(PastaIcones);
  if Result <> '' then
    Exit;

  PastaIcones := PastaExe + 'icones\';
  Result := ProcurarNaPasta(PastaIcones);
  if Result <> '' then
    Exit;

  PastaIcones := PastaExe + 'icons\';
  Result := ProcurarNaPasta(PastaIcones);
end;

function Tfrmprincipal.NomeRecursoIcone(const AArquivoIcone: string): string;
begin
  Result := UpperCase(ChangeFileExt(ExtractFileName(AArquivoIcone), ''));
end;

function Tfrmprincipal.TileModulo(AModulo: TModuloConsulta): TPanel;
begin
  case AModulo of
    mcClientes: Result := pnlTileClientes;
    mcEstoque: Result := pnlTileEstoque;
    mcOrcamento: Result := pnlTileOrcamento;
    mcReceber: Result := pnlTileReceber;
    mcPagar: Result := pnlTilePagar;
    mcDav: Result := pnlTileDav;
    mcCompra: Result := pnlTileCompra;
    mcNotaFiscal: Result := pnlTileNotaFiscal;
  else
    Result := nil;
  end;
end;

function Tfrmprincipal.ImagemModulo(AModulo: TModuloConsulta): TImage;
begin
  case AModulo of
    mcClientes: Result := imgModClientes;
    mcEstoque: Result := imgModEstoque;
    mcOrcamento: Result := imgModOrcamento;
    mcReceber: Result := imgModReceber;
    mcPagar: Result := imgModPagar;
    mcDav: Result := imgModDav;
    mcCompra: Result := imgModCompra;
    mcNotaFiscal: Result := imgModNotaFiscal;
  else
    Result := nil;
  end;
end;

procedure Tfrmprincipal.CarregarIconeImagem(AImagem: TImage; const AArquivoIcone: string);
var
  Png: TPngImage;
  Stream: TResourceStream;
  Caminho, NomeRes: string;
  Bmp: TBitmap;
  Letra: string;
  Carregou: Boolean;

  procedure AplicarPng(APng: TPngImage);
  begin
    AImagem.Picture.Assign(APng);
    AImagem.Stretch := True;
    AImagem.Proportional := True;
    AImagem.Center := True;
    AImagem.Visible := True;
  end;

begin
  if AImagem = nil then
    Exit;

  Carregou := False;
  Png := TPngImage.Create;
  try
    Caminho := BuscarArquivoIcone(AArquivoIcone);
    if Caminho <> '' then
    begin
      try
        Png.LoadFromFile(Caminho);
        AplicarPng(Png);
        Carregou := True;
      except
      end;
    end;

    if not Carregou then
    begin
      NomeRes := NomeRecursoIcone(AArquivoIcone);
      try
        Stream := TResourceStream.Create(HInstance, NomeRes, RT_RCDATA);
        try
          Png.LoadFromStream(Stream);
          AplicarPng(Png);
          Carregou := True;
        finally
          Stream.Free;
        end;
      except
      end;

      if (not Carregou) and SameText(NomeRes, 'NOTAFISCAL') then
      begin
        Caminho := BuscarArquivoIcone('NF-e.png');
        if Caminho <> '' then
        begin
          try
            Png.LoadFromFile(Caminho);
            AplicarPng(Png);
            Carregou := True;
          except
          end;
        end;
      end;
    end;
  finally
    Png.Free;
  end;

  if Carregou then
    Exit;

  Bmp := TBitmap.Create;
  try
    Letra := Copy(ChangeFileExt(ExtractFileName(AArquivoIcone), ''), 1, 1);
    if Letra = '' then
      Letra := '?';
    Bmp.SetSize(ICON_TAMANHO, ICON_TAMANHO);
    Bmp.Canvas.Brush.Color := $00B5752F;
    Bmp.Canvas.FillRect(Rect(0, 0, ICON_TAMANHO, ICON_TAMANHO));
    Bmp.Canvas.Font.Name := 'Segoe UI';
    Bmp.Canvas.Font.Size := 22;
    Bmp.Canvas.Font.Style := [fsBold];
    Bmp.Canvas.Font.Color := clWhite;
    Bmp.Canvas.TextOut(18, 20, Letra);
    AImagem.Picture.Assign(Bmp);
    AImagem.Stretch := True;
    AImagem.Proportional := True;
    AImagem.Center := True;
    AImagem.Visible := True;
  finally
    Bmp.Free;
  end;
end;

procedure Tfrmprincipal.ConfigurarVisual;
begin
  lblTitulo.Caption := 'Consultas';
  lblSubtitulo.Caption :=
    'Acesse os seguintes m'#243'dulos para consultar informa'#231#245'es do sistema antigo';
  lblBoasVindas.Caption := 'Bem vindo ao sistema de consultas...';
  lblRodape.Caption := 'MT Automacoes - Consultas.exe';
end;

procedure Tfrmprincipal.ConfigurarBarraModulos;
const
  MODULOS: array[TModuloConsulta] of record
    Caption: string;
    Hint: string;
    Icone: string;
  end = (
    (Caption: 'Clientes'; Hint: 'Consulta de clientes'; Icone: 'Clientes.png'),
    (Caption: 'Estoque'; Hint: 'Consulta de estoque'; Icone: 'Estoque.png'),
    (Caption: 'Or'#231'amento'; Hint: 'Consulta de or'#231'amentos'; Icone: 'Orcamento.png'),
    (Caption: 'Receber'; Hint: 'Contas a receber'; Icone: 'Receber.png'),
    (Caption: 'Pagar'; Hint: 'Contas a pagar'; Icone: 'Pagar.png'),
    (Caption: 'DAV'; Hint: 'Documento auxiliar de venda'; Icone: 'Dav.png'),
    (Caption: 'Compras'; Hint: 'Entrada de compras / NF-e de entrada'; Icone: 'Compras.png'),
    (Caption: 'NFe Venda'; Hint: 'Notas fiscais de venda'; Icone: 'NotaFiscal.png')
  );
var
  Modulo: TModuloConsulta;
  Tile: TPanel;
  Img: TImage;
  Lbl: TLabel;
  Indice, LeftPos: Integer;
  TileLargura, TileAltura, TileEspaco, TileMargem, IconTam: Integer;
  Escala: Double;
  ReqWidth, QtdeModulos: Integer;
begin
  Indice := 0;
  FTileHover := nil;
  Screen.Cursor := crDefault;

  QtdeModulos := Ord(High(TModuloConsulta)) - Ord(Low(TModuloConsulta)) + 1;
  ReqWidth := (TILE_MARGEM * 2) + (QtdeModulos * TILE_LARGURA) +
    ((QtdeModulos - 1) * TILE_ESPACO);
  Escala := CalcularEscalaHorizontal(ReqWidth, 8);
  TileMargem := Max(8, Round(TILE_MARGEM * Escala));
  TileLargura := Max(88, Round(TILE_LARGURA * Escala));
  TileAltura := Max(92, Round(TILE_ALTURA * Escala));
  TileEspaco := Max(4, Round(TILE_ESPACO * Escala));
  IconTam := Max(48, Round(ICON_TAMANHO * Escala));
  LeftPos := TileMargem;

  for Modulo := Low(TModuloConsulta) to High(TModuloConsulta) do
  begin
    Tile := TileModulo(Modulo);
    Img := ImagemModulo(Modulo);
    if (Tile = nil) or (Img = nil) then
      Continue;

    Lbl := nil;
    for Indice := 0 to Tile.ControlCount - 1 do
      if Tile.Controls[Indice] is TLabel then
      begin
        Lbl := TLabel(Tile.Controls[Indice]);
        Break;
      end;

    Tile.Left := LeftPos;
    Tile.Top := TileMargem;
    Tile.Width := TileLargura;
    Tile.Height := TileAltura;
    Tile.BevelOuter := bvNone;
    Tile.BevelInner := bvNone;
    Tile.Tag := Ord(Modulo);
    FTileTopNormal[Modulo] := TileMargem;
    Tile.Hint := MODULOS[Modulo].Hint;
    Tile.ShowHint := True;

    Img.Left := (Tile.Width - IconTam) div 2;
    Img.Top := 10;
    Img.Width := IconTam;
    Img.Height := IconTam;
    Img.Tag := Ord(Modulo);
    Img.Hint := Tile.Hint;
    Img.ShowHint := True;
    Img.StyleElements := [seFont, seBorder];

    if Lbl <> nil then
    begin
      Lbl.Caption := MODULOS[Modulo].Caption;
      Lbl.Tag := Ord(Modulo);
      Lbl.Hint := Tile.Hint;
      Lbl.ShowHint := True;
    end;

    CarregarIconeImagem(Img, MODULOS[Modulo].Icone);
    ConfigurarHoverTile(Tile, Img, Lbl);

    LeftPos := LeftPos + TileLargura + TileEspaco;
  end;

  pnlModulos.Height := (TileMargem * 2) + TileAltura;
end;

procedure Tfrmprincipal.AjustarLayoutPrincipal;
var
  Area: TRect;
  AlturaMin: Integer;
begin
  Area := ObterAreaTrabalhoTela;
  AlturaMin := pnlCabecalho.Height + pnlModulos.Height + pnlRodape.Height + 120;

  if ClientWidth > Area.Width - 16 then
    ClientWidth := Area.Width - 16;
  if ClientHeight > Area.Height - 16 then
    ClientHeight := Area.Height - 16;
  if ClientHeight < AlturaMin then
    ClientHeight := Min(AlturaMin, Area.Height - 16);

  Constraints.MaxWidth := Area.Width;
  Constraints.MaxHeight := Area.Height;
  Position := poScreenCenter;
end;

procedure Tfrmprincipal.ConfigurarHoverTile(ATile: TPanel; AImg: TImage; ALbl: TLabel);
begin
  if ATile = nil then
    Exit;

  ATile.OnMouseEnter := TileModuloMouseEnter;
  ATile.OnMouseLeave := TileModuloMouseLeave;

  if AImg <> nil then
  begin
    AImg.OnMouseEnter := TileModuloMouseEnter;
    AImg.OnMouseLeave := TileModuloMouseLeave;
  end;

  if ALbl <> nil then
  begin
    ALbl.OnMouseEnter := TileModuloMouseEnter;
    ALbl.OnMouseLeave := TileModuloMouseLeave;
  end;
end;

function Tfrmprincipal.ObterTileModulo(AControl: TObject): TPanel;
var
  Ctrl: TControl;
begin
  Result := nil;
  if not (AControl is TControl) then
    Exit;

  Ctrl := TControl(AControl);
  if (Ctrl is TPanel) and (Ctrl.Parent = pnlModulos) then
    Exit(TPanel(Ctrl));

  if (Ctrl.Parent <> nil) and (Ctrl.Parent is TPanel) and
    (TPanel(Ctrl.Parent).Parent = pnlModulos) then
    Exit(TPanel(Ctrl.Parent));
end;

function Tfrmprincipal.CursorDentroTile(ATile: TPanel): Boolean;
var
  P: TPoint;
begin
  Result := False;
  if (ATile = nil) or (not ATile.HandleAllocated) then
    Exit;

  P := ATile.ScreenToClient(Mouse.CursorPos);
  Result := PtInRect(Rect(0, 0, ATile.Width, ATile.Height), P);
end;

procedure Tfrmprincipal.RestaurarTileHover(ATile: TPanel);
var
  Modulo: TModuloConsulta;
begin
  if ATile = nil then
    Exit;

  Modulo := TModuloConsulta(ATile.Tag);
  ATile.Top := FTileTopNormal[Modulo];

  if FTileHover = ATile then
  begin
    FTileHover := nil;
    Screen.Cursor := crDefault;
  end;
end;

procedure Tfrmprincipal.AtivarTileHover(ATile: TPanel);
var
  Modulo: TModuloConsulta;
begin
  if (ATile = nil) or (FTileHover = ATile) then
    Exit;

  if Assigned(FTileHover) then
    RestaurarTileHover(FTileHover);

  FTileHover := ATile;
  Modulo := TModuloConsulta(ATile.Tag);
  ATile.Top := FTileTopNormal[Modulo] - TILE_HOVER_SOBE;
  ATile.BringToFront;
  Screen.Cursor := crHandPoint;
end;

procedure Tfrmprincipal.TileModuloMouseEnter(Sender: TObject);
var
  Tile: TPanel;
begin
  Tile := ObterTileModulo(Sender);
  AtivarTileHover(Tile);
end;

procedure Tfrmprincipal.TileModuloMouseLeave(Sender: TObject);
var
  Tile: TPanel;
begin
  Tile := ObterTileModulo(Sender);
  if Tile = nil then
    Exit;

  if CursorDentroTile(Tile) then
    Exit;

  RestaurarTileHover(Tile);
end;

procedure Tfrmprincipal.FecharConsulta(AForm: TForm);
begin
  if not Assigned(AForm) then
    Exit;

  if AForm = frmClientes then
    FreeAndNil(frmClientes)
  else if AForm = frmEstoque then
    FreeAndNil(frmEstoque)
  else if AForm = frmOrcamento then
    FreeAndNil(frmOrcamento)
  else if AForm = frmReceber then
    FreeAndNil(frmReceber)
  else if AForm = frmPagar then
    FreeAndNil(frmPagar)
  else if AForm = frmDav then
    FreeAndNil(frmDav)
  else if AForm = frmCompra then
    FreeAndNil(frmCompra)
  else if AForm = frmNotaFiscal then
    FreeAndNil(frmNotaFiscal)
  else
    AForm.Free;
end;

procedure Tfrmprincipal.LiberarOutrasConsultas(AExceto: TForm);
begin
  if Assigned(frmClientes) and (frmClientes <> AExceto) then
  begin
    if frmClientes.Visible then
      frmClientes.Hide;
    FreeAndNil(frmClientes);
  end;
  if Assigned(frmEstoque) and (frmEstoque <> AExceto) then
  begin
    if frmEstoque.Visible then
      frmEstoque.Hide;
    FreeAndNil(frmEstoque);
  end;
  if Assigned(frmOrcamento) and (frmOrcamento <> AExceto) then
  begin
    if frmOrcamento.Visible then
      frmOrcamento.Hide;
    FreeAndNil(frmOrcamento);
  end;
  if Assigned(frmReceber) and (frmReceber <> AExceto) then
  begin
    if frmReceber.Visible then
      frmReceber.Hide;
    FreeAndNil(frmReceber);
  end;
  if Assigned(frmPagar) and (frmPagar <> AExceto) then
  begin
    if frmPagar.Visible then
      frmPagar.Hide;
    FreeAndNil(frmPagar);
  end;
  if Assigned(frmDav) and (frmDav <> AExceto) then
  begin
    if frmDav.Visible then
      frmDav.Hide;
    FreeAndNil(frmDav);
  end;
  if Assigned(frmCompra) and (frmCompra <> AExceto) then
  begin
    if frmCompra.Visible then
      frmCompra.Hide;
    FreeAndNil(frmCompra);
  end;
  if Assigned(frmNotaFiscal) and (frmNotaFiscal <> AExceto) then
  begin
    if frmNotaFiscal.Visible then
      frmNotaFiscal.Hide;
    FreeAndNil(frmNotaFiscal);
  end;
end;

procedure Tfrmprincipal.ExibirConsulta(AForm: TForm);
begin
  if not Assigned(AForm) then
    Exit;

  LiberarOutrasConsultas(AForm);
  FConsultaPendente := AForm;
  PostMessage(Handle, WM_EXIBIR_CONSULTA, 0, 0);
end;

procedure Tfrmprincipal.WMExibirConsulta(var Msg: TMessage);
var
  Form: TForm;
begin
  Form := FConsultaPendente;
  FConsultaPendente := nil;
  if not Assigned(Form) then
    Exit;

  Form.Show;
  Form.BringToFront;
  if Form.HandleAllocated then
    SetForegroundWindow(Form.Handle);
end;

procedure Tfrmprincipal.AbrirModulo(AModulo: TModuloConsulta);
begin
  case AModulo of
    mcClientes:
      begin
        if not Assigned(frmClientes) then
          Application.CreateForm(TfrmClientes, frmClientes);
        ExibirConsulta(frmClientes);
        frmClientes.CarregarDados;
      end;
    mcEstoque:
      begin
        if not Assigned(frmEstoque) then
          Application.CreateForm(TfrmEstoque, frmEstoque);
        ExibirConsulta(frmEstoque);
        frmEstoque.CarregarDados;
      end;
    mcOrcamento:
      begin
        if not Assigned(frmOrcamento) then
          Application.CreateForm(TfrmOrcamento, frmOrcamento);
        ExibirConsulta(frmOrcamento);
        frmOrcamento.CarregarDados;
      end;
    mcReceber:
      begin
        if not Assigned(frmReceber) then
          Application.CreateForm(TfrmReceber, frmReceber);
        ExibirConsulta(frmReceber);
        frmReceber.CarregarDados;
      end;
    mcPagar:
      begin
        if not Assigned(frmPagar) then
          Application.CreateForm(TfrmPagar, frmPagar);
        ExibirConsulta(frmPagar);
        frmPagar.CarregarDados;
      end;
    mcDav:
      begin
        if not Assigned(frmDav) then
          Application.CreateForm(TfrmDav, frmDav);
        ExibirConsulta(frmDav);
        frmDav.CarregarDados;
      end;
    mcCompra:
      begin
        if not Assigned(frmCompra) then
          Application.CreateForm(TfrmCompra, frmCompra);
        ExibirConsulta(frmCompra);
        frmCompra.CarregarDados;
      end;
    mcNotaFiscal:
      begin
        if not Assigned(frmNotaFiscal) then
          Application.CreateForm(TfrmNotaFiscal, frmNotaFiscal);
        ExibirConsulta(frmNotaFiscal);
        frmNotaFiscal.CarregarDados;
      end;
  end;
end;

procedure Tfrmprincipal.btnModuloClick(Sender: TObject);
var
  TagModulo: Integer;
begin
  if Sender is TPanel then
    TagModulo := TPanel(Sender).Tag
  else if Sender is TImage then
    TagModulo := TImage(Sender).Tag
  else if Sender is TLabel then
    TagModulo := TLabel(Sender).Tag
  else
    Exit;

  AbrirModulo(TModuloConsulta(TagModulo));
end;

procedure Tfrmprincipal.FormCreate(Sender: TObject);
begin
  FConexaoVerificada := False;
  AplicarConfirmacaoEsc(Self, MSG_SAIR_SISTEMA);
  RegistrarFecharConsulta(FecharConsulta);
  ConfigurarVisual;
  ConfigurarBarraModulos;
  AjustarLayoutPrincipal;
end;

procedure Tfrmprincipal.FormShow(Sender: TObject);
begin
  if FConexaoVerificada then
    Exit;
  PostMessage(Handle, WM_VERIFICAR_CONEXAO, 0, 0);
end;

procedure Tfrmprincipal.WMVerificarConexao(var Msg: TMessage);
begin
  if FConexaoVerificada then
    Exit;
  FConexaoVerificada := True;

  if not dmConexao.Conectar then
    Close;
end;

end.
