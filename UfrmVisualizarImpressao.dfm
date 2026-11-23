object frmVisualizarImpressao: TfrmVisualizarImpressao
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMaximize]
  Caption = 'Visualizar impressao'
  ClientHeight = 700
  ClientWidth = 1000
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  WindowState = wsMaximized
  OnCreate = FormCreate
  OnShow = FormShow
  OnDestroy = FormDestroy
  OnResize = FormResize
  TextHeight = 15
  object pnlTopo: TPanel
    Left = 0
    Top = 0
    Width = 1000
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblTitulo: TLabel
      Left = 16
      Top = 10
      Width = 160
      Height = 21
      Caption = 'Visualizar impressao'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object pnlZoom: TPanel
    Left = 0
    Top = 40
    Width = 1000
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object btnZoomMenos: TButton
      Left = 16
      Top = 6
      Width = 36
      Height = 28
      Caption = '-'
      TabOrder = 0
      OnClick = btnZoomMenosClick
    end
    object btnZoomMais: TButton
      Left = 58
      Top = 6
      Width = 36
      Height = 28
      Caption = '+'
      TabOrder = 1
      OnClick = btnZoomMaisClick
    end
    object btnZoomAjustar: TButton
      Left = 104
      Top = 6
      Width = 110
      Height = 28
      Caption = 'Ajustar tela'
      TabOrder = 2
      OnClick = btnZoomAjustarClick
    end
    object btnZoom100: TButton
      Left = 224
      Top = 6
      Width = 90
      Height = 28
      Caption = '100% real'
      TabOrder = 3
      OnClick = btnZoom100Click
    end
    object lblZoom: TLabel
      Left = 328
      Top = 12
      Width = 120
      Height = 15
      Caption = 'Zoom: 100%'
    end
  end
  object scrollVisual: TScrollBox
    Left = 0
    Top = 80
    Width = 1000
    Height = 563
    Align = alClient
    BorderStyle = bsNone
    Color = clBtnFace
    ParentColor = False
    TabOrder = 2
    object paintPagina: TPaintBox
      Left = 0
      Top = 0
      Width = 794
      Height = 1123
      OnPaint = paintPaginaPaint
    end
  end
  object pnlRodape: TPanel
    Left = 0
    Top = 643
    Width = 1000
    Height = 57
    Align = alBottom
    TabOrder = 3
    object btnPrimeira: TButton
      Left = 16
      Top = 14
      Width = 75
      Height = 29
      Caption = '|<'
      TabOrder = 0
      OnClick = btnPrimeiraClick
    end
    object btnAnterior: TButton
      Left = 97
      Top = 14
      Width = 75
      Height = 29
      Caption = '<'
      TabOrder = 1
      OnClick = btnAnteriorClick
    end
    object lblPagina: TLabel
      Left = 184
      Top = 18
      Width = 90
      Height = 15
      Caption = 'Pagina 1 de 1'
    end
    object btnProxima: TButton
      Left = 288
      Top = 14
      Width = 75
      Height = 29
      Caption = '>'
      TabOrder = 2
      OnClick = btnProximaClick
    end
    object btnUltima: TButton
      Left = 369
      Top = 14
      Width = 75
      Height = 29
      Caption = '>|'
      TabOrder = 3
      OnClick = btnUltimaClick
    end
    object btnImprimir: TButton
      Left = 788
      Top = 14
      Width = 90
      Height = 29
      Caption = 'Imprimir'
      TabOrder = 4
      OnClick = btnImprimirClick
    end
    object btnFechar: TButton
      Left = 888
      Top = 14
      Width = 90
      Height = 29
      Caption = 'Fechar'
      TabOrder = 5
      OnClick = btnFecharClick
    end
  end
end
