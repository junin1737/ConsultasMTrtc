object frmProdutoDetalhe: TfrmProdutoDetalhe
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Detalhes - Produto'
  ClientHeight = 280
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object pnlCabecalho: TPanel
    Left = 0
    Top = 0
    Width = 640
    Height = 223
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object lblCodigo: TLabel
      Left = 16
      Top = 16
      Width = 78
      Height = 15
      Caption = 'Cod.Fabricante'
    end
    object edtCodigo: TEdit
      Left = 16
      Top = 35
      Width = 160
      Height = 23
      TabOrder = 0
    end
    object lblDescricao: TLabel
      Left = 192
      Top = 16
      Width = 55
      Height = 15
      Caption = 'Descri'#231#227'o'
    end
    object edtDescricao: TEdit
      Left = 192
      Top = 35
      Width = 432
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 1
    end
    object lblEstoque: TLabel
      Left = 16
      Top = 72
      Width = 42
      Height = 15
      Caption = 'Estoque'
    end
    object edtEstoque: TEdit
      Left = 16
      Top = 91
      Width = 120
      Height = 23
      TabOrder = 2
    end
    object lblEstoqueMinimo: TLabel
      Left = 152
      Top = 72
      Width = 85
      Height = 15
      Caption = 'Estoque m'#237'nimo'
    end
    object edtEstoqueMinimo: TEdit
      Left = 152
      Top = 91
      Width = 120
      Height = 23
      TabOrder = 3
    end
    object lblPrecoVarejo: TLabel
      Left = 16
      Top = 128
      Width = 70
      Height = 15
      Caption = 'Pre'#231'o varejo'
    end
    object edtPrecoVarejo: TEdit
      Left = 16
      Top = 147
      Width = 160
      Height = 23
      TabOrder = 4
    end
    object lblPrecoAtacado: TLabel
      Left = 192
      Top = 128
      Width = 74
      Height = 15
      Caption = 'Pre'#231'o atacado'
    end
    object edtPrecoAtacado: TEdit
      Left = 192
      Top = 147
      Width = 160
      Height = 23
      TabOrder = 5
    end
  end
  object pnlRodape: TPanel
    Left = 0
    Top = 223
    Width = 640
    Height = 57
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnFechar: TButton
      Left = 528
      Top = 14
      Width = 96
      Height = 29
      Caption = 'Fechar'
      TabOrder = 0
      OnClick = btnFecharClick
    end
  end
end
