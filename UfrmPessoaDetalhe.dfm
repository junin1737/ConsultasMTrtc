object frmPessoaDetalhe: TfrmPessoaDetalhe
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Detalhes do cliente'
  ClientHeight = 420
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
    Height = 88
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblCodigo: TLabel
      Left = 16
      Top = 16
      Width = 42
      Height = 15
      Caption = 'C'#243'digo'
    end
    object edtCodigo: TEdit
      Left = 16
      Top = 35
      Width = 100
      Height = 23
      TabOrder = 0
    end
    object lblNome: TLabel
      Left = 128
      Top = 16
      Width = 34
      Height = 15
      Caption = 'Nome'
    end
    object edtNome: TEdit
      Left = 128
      Top = 35
      Width = 496
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 1
    end
  end
  object pnlDados: TPanel
    Left = 0
    Top = 88
    Width = 640
    Height = 275
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lblCpfCnpj: TLabel
      Left = 16
      Top = 16
      Width = 58
      Height = 15
      Caption = 'CPF/CNPJ'
    end
    object edtCpfCnpj: TEdit
      Left = 16
      Top = 35
      Width = 220
      Height = 23
      TabOrder = 0
    end
    object lblIE: TLabel
      Left = 256
      Top = 16
      Width = 95
      Height = 15
      Caption = 'Inscri'#231#227'o estadual'
    end
    object edtIE: TEdit
      Left = 256
      Top = 35
      Width = 368
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 1
    end
    object lblEndereco: TLabel
      Left = 16
      Top = 72
      Width = 52
      Height = 15
      Caption = 'Endere'#231'o'
    end
    object edtEndereco: TEdit
      Left = 16
      Top = 91
      Width = 480
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 2
    end
    object lblNumero: TLabel
      Left = 512
      Top = 72
      Width = 44
      Height = 15
      Caption = 'N'#250'mero'
    end
    object edtNumero: TEdit
      Left = 512
      Top = 91
      Width = 112
      Height = 23
      Anchors = [akTop, akRight]
      TabOrder = 3
    end
    object lblBairro: TLabel
      Left = 16
      Top = 128
      Width = 35
      Height = 15
      Caption = 'Bairro'
    end
    object edtBairro: TEdit
      Left = 16
      Top = 147
      Width = 220
      Height = 23
      TabOrder = 4
    end
    object lblCidade: TLabel
      Left = 256
      Top = 128
      Width = 40
      Height = 15
      Caption = 'Cidade'
    end
    object edtCidade: TEdit
      Left = 256
      Top = 147
      Width = 280
      Height = 23
      TabOrder = 5
    end
    object lblUf: TLabel
      Left = 552
      Top = 128
      Width = 14
      Height = 15
      Caption = 'UF'
    end
    object edtUf: TEdit
      Left = 552
      Top = 147
      Width = 72
      Height = 23
      Anchors = [akTop, akRight]
      TabOrder = 6
    end
    object lblCep: TLabel
      Left = 16
      Top = 184
      Width = 22
      Height = 15
      Caption = 'CEP'
    end
    object edtCep: TEdit
      Left = 16
      Top = 203
      Width = 120
      Height = 23
      TabOrder = 7
    end
    object lblTelefone: TLabel
      Left = 160
      Top = 184
      Width = 46
      Height = 15
      Caption = 'Telefone'
    end
    object edtTelefone: TEdit
      Left = 160
      Top = 203
      Width = 200
      Height = 23
      TabOrder = 8
    end
    object lblCelular: TLabel
      Left = 384
      Top = 184
      Width = 40
      Height = 15
      Caption = 'Celular'
    end
    object edtCelular: TEdit
      Left = 384
      Top = 203
      Width = 240
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 9
    end
  end
  object pnlRodape: TPanel
    Left = 0
    Top = 363
    Width = 640
    Height = 57
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
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
