object frmVisualizarDanfe: TfrmVisualizarDanfe

  Left = 0

  Top = 0

  BorderIcons = [biSystemMenu, biMaximize]

  Caption = 'DANFE'

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

      Width = 48

      Height = 21

      Caption = 'DANFE'

      Font.Charset = DEFAULT_CHARSET

      Font.Color = clWindowText

      Font.Height = -16

      Font.Name = 'Segoe UI'

      Font.Style = [fsBold]

      ParentFont = False

    end

  end

  object webPdf: TWebBrowser

    Left = 0

    Top = 40

    Width = 1000

    Height = 603

    Align = alClient

    TabOrder = 1

    Silent = True

    SelectedEngine = EdgeIfAvailable

    ControlData = {

      4C000000FA3F0000813400000000000000000000000000000000000000000000

      000000004C000000000000000000000001000000E0D057007335CF11AE690800

      2B2E12620A000000000000004C0000000114020000000000C000000000000046

      8000000000000000000000000000000000000000000000000000000000000000

      00000000000000000100000000000000000000000000000000000000}

  end

  object pnlRodape: TPanel

    Left = 0

    Top = 643

    Width = 1000

    Height = 57

    Align = alBottom

    TabOrder = 2

    object btnSalvarPdf: TButton

      Left = 688

      Top = 14

      Width = 90

      Height = 29

      Caption = 'Salvar PDF'

      TabOrder = 0

      OnClick = btnSalvarPdfClick

    end

    object btnImprimir: TButton

      Left = 788

      Top = 14

      Width = 90

      Height = 29

      Caption = 'Imprimir'

      TabOrder = 1

      OnClick = btnImprimirClick

    end

    object btnFechar: TButton

      Left = 888

      Top = 14

      Width = 90

      Height = 29

      Caption = 'Fechar'

      TabOrder = 2

      OnClick = btnFecharClick

    end

  end

  object dlgSalvarPdf: TSaveDialog

    DefaultExt = 'pdf'

    Filter = 'Arquivo PDF (*.pdf)|*.pdf|Todos os arquivos (*.*)|*.*'

    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]

    Left = 560

    Top = 320

  end

end

