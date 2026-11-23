object frmDavDetalhe: TfrmDavDetalhe

  Left = 0

  Top = 0

  BorderIcons = [biSystemMenu]

  BorderStyle = bsSingle

  Caption = 'DAV - detalhes'

  ClientHeight = 620

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

    Width = 980

    Height = 190

    Align = alTop

    BevelOuter = bvNone

    TabOrder = 0

    object lblNumero: TLabel

      Left = 16

      Top = 16

      Width = 68

      Height = 15

      Caption = 'N'#250'mero DAV'

    end

    object edtNumero: TEdit

      Left = 16

      Top = 35

      Width = 120

      Height = 23

      TabOrder = 0

    end

    object lblEmissao: TLabel

      Left = 152

      Top = 16

      Width = 72

      Height = 15

      Caption = 'Data emiss'#227'o'

    end

    object edtEmissao: TEdit

      Left = 152

      Top = 35

      Width = 120

      Height = 23

      TabOrder = 1

    end

    object lblVencimento: TLabel

      Left = 288

      Top = 16

      Width = 62

      Height = 15

      Caption = 'Vencimento'

    end

    object edtVencimento: TEdit

      Left = 288

      Top = 35

      Width = 120

      Height = 23

      TabOrder = 2

    end

    object lblValorTotal: TLabel

      Left = 424

      Top = 16

      Width = 56

      Height = 15

      Caption = 'Valor total'

    end

    object edtValorTotal: TEdit

      Left = 424

      Top = 35

      Width = 140

      Height = 23

      TabOrder = 3

    end

    object lblCliente: TLabel

      Left = 16

      Top = 68

      Width = 37

      Height = 15

      Caption = 'Cliente'

    end

    object edtCliente: TEdit

      Left = 16

      Top = 87

      Width = 680

      Height = 23

      TabOrder = 4

    end

  end

  object pnlGrids: TPanel
    Left = 0
    Top = 190
    Width = 980
    Height = 373
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object grpServicos: TGroupBox
      Left = 0
      Top = 0
      Width = 980
      Height = 218
      Align = alTop
      Caption = ' Servi'#231'os '
      TabOrder = 0
      object gridServicos: TDBGrid
        Left = 2
        Top = 17
        Width = 976
        Height = 163
        Align = alClient
        TabOrder = 0
        TitleFont.Charset = DEFAULT_CHARSET
        TitleFont.Color = clWindowText
        TitleFont.Height = -12
        TitleFont.Name = 'Segoe UI'
        TitleFont.Style = []
      end
      object pnlTotalServicos: TPanel
        Left = 2
        Top = 180
        Width = 976
        Height = 36
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        object lblTotalServicos: TLabel
          Left = 700
          Top = 10
          Width = 72
          Height = 15
          Anchors = [akTop, akRight]
          Caption = 'Total servi'#231'os'
        end
        object edtTotalServicos: TEdit
          Left = 834
          Top = 7
          Width = 140
          Height = 23
          Anchors = [akTop, akRight]
          TabOrder = 0
        end
      end
    end
    object grpProdutos: TGroupBox
      Left = 0
      Top = 218
      Width = 980
      Height = 155
      Align = alClient
      Caption = ' Produtos '
      TabOrder = 1
      object gridProdutos: TDBGrid
        Left = 2
        Top = 17
        Width = 976
        Height = 100
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
        Top = 117
        Width = 976
        Height = 36
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 1
        object lblTotalProdutos: TLabel
          Left = 700
          Top = 10
          Width = 74
          Height = 15
          Anchors = [akTop, akRight]
          Caption = 'Total produtos'
        end
        object edtTotalProdutos: TEdit
          Left = 834
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

    Top = 563

    Width = 980

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

