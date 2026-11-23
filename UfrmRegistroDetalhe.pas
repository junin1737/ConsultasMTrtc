unit UfrmRegistroDetalhe;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Data.DB, UConsultaCampos, UConsultaLayout, UfrmConsultaBase, UConfirmarFechar;

type
  TfrmRegistroDetalhe = class(TForm)
    pnlRodape: TPanel;
    btnFechar: TButton;
    scrollCampos: TScrollBox;
    procedure btnFecharClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FEdits: TArray<TEdit>;
    procedure LimparCampos;
    procedure MontarCampos(ADataset: TDataSet; AOrigem: TfrmConsultaBase);
    function ValorExibicao(AField: TField): string;
  public
    procedure Exibir(ADataset: TDataSet; const ATituloForm: string;
      AOrigem: TfrmConsultaBase = nil);
  end;

implementation

{$R *.dfm}

const
  MARGEM_ESQ = 16;
  LARGURA_LABEL = 200;
  LARGURA_EDIT = 480;
  ALTURA_LINHA = 30;
  TOP_INICIAL = 8;

procedure TfrmRegistroDetalhe.FormCreate(Sender: TObject);
begin
  // AplicarConfirmacaoEsc(Self);
  Caption := 'Detalhes do registro';
  Position := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
end;

procedure TfrmRegistroDetalhe.LimparCampos;
var
  I: Integer;
begin
  for I := 0 to Length(FEdits) - 1 do
    FEdits[I].Free;
  SetLength(FEdits, 0);

  while scrollCampos.ControlCount > 0 do
    scrollCampos.Controls[0].Free;
end;

function TfrmRegistroDetalhe.ValorExibicao(AField: TField): string;
begin
  if AField = nil then
    Exit('');

  if AField.IsNull then
    Exit('');

  Result := AField.DisplayText;
  if Result = '' then
    Result := AField.AsString;
end;

procedure TfrmRegistroDetalhe.MontarCampos(ADataset: TDataSet; AOrigem: TfrmConsultaBase);
var
  I, TopPos, IndiceEdit: Integer;
  Campo: TField;
  Lbl: TLabel;
  Edt: TEdit;
  Titulo: string;
begin
  LimparCampos;

  if (ADataset = nil) or (not ADataset.Active) or ADataset.IsEmpty then
    Exit;

  TopPos := TOP_INICIAL;
  IndiceEdit := 0;
  SetLength(FEdits, ADataset.FieldCount);

  for I := 0 to ADataset.FieldCount - 1 do
  begin
    Campo := ADataset.Fields[I];

    if AOrigem <> nil then
      Titulo := AOrigem.ResolverTituloCampo(Campo.FieldName)
    else
      Titulo := TituloAmigavelCampo(Campo.FieldName);

    Lbl := TLabel.Create(scrollCampos);
    Lbl.Parent := scrollCampos;
    Lbl.Left := MARGEM_ESQ;
    Lbl.Top := TopPos + 4;
    Lbl.Width := LARGURA_LABEL;
    Lbl.Caption := Titulo + ':';
    AplicarEstiloTituloCampo(Lbl);

    Edt := TEdit.Create(scrollCampos);
    Edt.Parent := scrollCampos;
    Edt.Left := MARGEM_ESQ + LARGURA_LABEL + 8;
    Edt.Top := TopPos;
    Edt.Width := LARGURA_EDIT;
    Edt.ReadOnly := True;
    Edt.ParentFont := False;
    Edt.Font.Name := 'Segoe UI';
    Edt.Font.Size := 9;
    Edt.Text := ValorExibicao(Campo);
    Edt.Tag := I;

    FEdits[IndiceEdit] := Edt;
    Inc(IndiceEdit);

    Inc(TopPos, ALTURA_LINHA);
  end;

  ClientHeight := Min(720, 120 + TopPos + pnlRodape.Height);
  AjustarJanelaDetalhe(Self, 760, ClientHeight);
  AjustarBotoesRodapeDireita(pnlRodape, [btnFechar]);
end;

procedure TfrmRegistroDetalhe.Exibir(ADataset: TDataSet; const ATituloForm: string;
  AOrigem: TfrmConsultaBase);
begin
  Caption := ATituloForm;
  MontarCampos(ADataset, AOrigem);
  ShowModal;
end;

procedure TfrmRegistroDetalhe.btnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
