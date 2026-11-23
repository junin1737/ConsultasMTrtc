object frmCompraDetalhe: TfrmCompraDetalhe
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsSingle
  Caption = 'Compra - detalhes'
  ClientHeight = 650
  ClientWidth = 740
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
    Width = 740
    Height = 220
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblNumero: TLabel
      Left = 16
      Top = 16
      Width = 45
      Height = 15
      Caption = 'N'#250'mero'
    end
    object edtNumero: TEdit
      Left = 16
      Top = 35
      Width = 100
      Height = 23
      TabOrder = 0
    end
    object lblSerie: TLabel
      Left = 128
      Top = 16
      Width = 28
      Height = 15
      Caption = 'S'#233'rie'
    end
    object edtSerie: TEdit
      Left = 128
      Top = 35
      Width = 80
      Height = 23
      TabOrder = 1
    end
    object lblEmissao: TLabel
      Left = 224
      Top = 16
      Width = 45
      Height = 15
      Caption = 'Emiss'#227'o'
    end
    object edtEmissao: TEdit
      Left = 224
      Top = 35
      Width = 100
      Height = 23
      TabOrder = 2
    end
    object lblEntrada: TLabel
      Left = 336
      Top = 16
      Width = 42
      Height = 15
      Caption = 'Entrada'
    end
    object edtEntrada: TEdit
      Left = 336
      Top = 35
      Width = 100
      Height = 23
      TabOrder = 3
    end
    object lblValorTotal: TLabel
      Left = 456
      Top = 16
      Width = 56
      Height = 15
      Caption = 'Valor total'
    end
    object edtValorTotal: TEdit
      Left = 456
      Top = 35
      Width = 140
      Height = 23
      TabOrder = 4
    end
    object lblFornecedor: TLabel
      Left = 16
      Top = 68
      Width = 60
      Height = 15
      Caption = 'Fornecedor'
    end
    object edtFornecedor: TEdit
      Left = 16
      Top = 87
      Width = 680
      Height = 23
      TabOrder = 5
    end
  end
  object pnlGrids: TPanel
    Left = 0
    Top = 220
    Width = 740
    Height = 373
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object grpProdutos: TGroupBox
      Left = 0
      Top = 0
      Width = 740
      Height = 373
      Align = alClient
      Caption = ' Produtos '
      TabOrder = 0
      object gridProdutos: TDBGrid
        Left = 2
        Top = 17
        Width = 736
        Height = 318
        Align = alClient
        TabOrder = 0
        TitleFont.Charset = DEFAULT_CHARSET
        TitleFont.Color = clWindowText
        TitleFont.Height = -12
        TitleFont.Name = 'Segoe UI'
        TitleFont.Style = []
      end
      object pnlTotalProdutos: TPanel
        Left = 2
        Top = 335
        Width = 736
        Height = 36
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        object lblTotalProdutos: TLabel
          Left = 460
          Top = 10
          Width = 74
          Height = 15
          Anchors = [akTop, akRight]
          Caption = 'Total produtos'
        end
        object edtTotalProdutos: TEdit
          Left = 594
          Top = 7
          Width = 140
          Height = 23
          Anchors = [akTop, akRight]
          TabOrder = 0
        end
      end
    end
  end
  object pnlRodape: TPanel
    Left = 0
    Top = 593
    Width = 740
    Height = 57
    Align = alBottom
    TabOrder = 2
    object btnImprimir: TButton
      Left = 464
      Top = 14
      Width = 120
      Height = 29
      Caption = 'Imprimir'
      TabOrder = 0
      OnClick = btnImprimirClick
    end
    object btnFechar: TButton
      Left = 596
      Top = 14
      Width = 120
      Height = 29
      Caption = 'Fechar'
      TabOrder = 1
      OnClick = btnFecharClick
    end
  end
end
