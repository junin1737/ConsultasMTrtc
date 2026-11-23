object frmRegistroDetalhe: TfrmRegistroDetalhe
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Detalhes do registro'
  ClientHeight = 480
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object scrollCampos: TScrollBox
    Left = 0
    Top = 0
    Width = 760
    Height = 423
    Align = alClient
    BorderStyle = bsNone
    TabOrder = 0
  end
  object pnlRodape: TPanel
    Left = 0
    Top = 423
    Width = 760
    Height = 57
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnFechar: TButton
      Left = 648
      Top = 14
      Width = 96
      Height = 29
      Caption = 'Fechar'
      TabOrder = 0
      OnClick = btnFecharClick
    end
  end
end
