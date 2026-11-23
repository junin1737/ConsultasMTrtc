object frmConsultaBase: TfrmConsultaBase
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  Caption = 'Consulta'
  ClientHeight = 900
  ClientWidth = 1350
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object PanelTopo: TPanel
    Left = 0
    Top = 0
    Width = 1350
    Height = 65
    Align = alTop
    Color = clHighlight
    ParentBackground = False
    TabOrder = 0
    object lblPesquisa: TLabel
      Left = 12
      Top = 24
      Width = 56
      Height = 15
      Caption = 'Pesquisar:'
    end
    object edtPesquisa: TEdit
      Left = 120
      Top = 21
      Width = 700
      Height = 23
      TabOrder = 0
    end
  end
  object PanelRodape: TPanel
    Left = 0
    Top = 843
    Width = 1350
    Height = 57
    Align = alBottom
    TabOrder = 1
    object btnFechar: TButton
      Left = 1242
      Top = 14
      Width = 90
      Height = 29
      Caption = 'Fechar'
      TabOrder = 0
      OnClick = btnFecharClick
    end
  end
  object DBGrid1: TConsultaDBGrid
    Left = 0
    Top = 65
    Width = 1350
    Height = 778
    Align = alClient
    TabOrder = 2
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -12
    TitleFont.Name = 'Segoe UI'
    TitleFont.Style = []
  end
end
