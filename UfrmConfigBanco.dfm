object frmConfigBanco: TfrmConfigBanco
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Configura'#231#227'o do banco Firebird'
  ClientHeight = 249
  ClientWidth = 520
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblDatabase: TLabel
    Left = 16
    Top = 16
    Width = 69
    Height = 15
    Caption = 'Arquivo .fdb:'
  end
  object lblServer: TLabel
    Left = 16
    Top = 72
    Width = 89
    Height = 15
    Caption = 'Servidor Firebird:'
  end
  object lblPorta: TLabel
    Left = 368
    Top = 72
    Width = 31
    Height = 15
    Caption = 'Porta:'
  end
  object lblUsuario: TLabel
    Left = 16
    Top = 120
    Width = 43
    Height = 15
    Caption = 'Usu'#225'rio:'
  end
  object lblSenha: TLabel
    Left = 264
    Top = 120
    Width = 35
    Height = 15
    Caption = 'Senha:'
  end
  object edtDatabase: TEdit
    Left = 16
    Top = 37
    Width = 417
    Height = 23
    TabOrder = 0
  end
  object btnProcurar: TButton
    Left = 439
    Top = 36
    Width = 65
    Height = 25
    Caption = 'Procurar...'
    TabOrder = 1
    OnClick = btnProcurarClick
  end
  object edtServer: TEdit
    Left = 16
    Top = 93
    Width = 337
    Height = 23
    TabOrder = 2
  end
  object edtPorta: TEdit
    Left = 368
    Top = 93
    Width = 136
    Height = 23
    TabOrder = 3
  end
  object edtUsuario: TEdit
    Left = 16
    Top = 141
    Width = 225
    Height = 23
    TabOrder = 4
  end
  object edtSenha: TEdit
    Left = 264
    Top = 141
    Width = 240
    Height = 23
    PasswordChar = '*'
    TabOrder = 5
  end
  object lblDeteccao: TLabel
    Left = 16
    Top = 170
    Width = 488
    Height = 15
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGray
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = [fsItalic]
    ParentFont = False
  end
  object PanelBotoes: TPanel
    Left = 0
    Top = 192
    Width = 520
    Height = 57
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 6
    object btnOk: TButton
      Left = 328
      Top = 14
      Width = 85
      Height = 29
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOkClick
    end
    object btnCancelar: TButton
      Left = 419
      Top = 14
      Width = 85
      Height = 29
      Cancel = True
      Caption = 'Cancelar'
      ModalResult = 2
      TabOrder = 1
    end
  end
  object OpenDialog1: TOpenDialog
    Left = 240
    Top = 192
  end
end
