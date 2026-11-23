object frmPagarDetalhe: TfrmPagarDetalhe
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Detalhes - Contas a pagar'
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
    Height = 363
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object lblDocumento: TLabel
      Left = 16
      Top = 16
      Width = 63
      Height = 15
      Caption = 'Documento'
    end
    object edtDocumento: TEdit
      Left = 16
      Top = 35
      Width = 200
      Height = 23
      TabOrder = 0
    end
    object lblPessoa: TLabel
      Left = 232
      Top = 16
      Width = 63
      Height = 15
      Caption = 'Fornecedor'
    end
    object edtPessoa: TEdit
      Left = 232
      Top = 35
      Width = 392
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 1
    end
    object lblEmissao: TLabel
      Left = 16
      Top = 72
      Width = 45
      Height = 15
      Caption = 'Emiss'#227'o'
    end
    object edtEmissao: TEdit
      Left = 16
      Top = 91
      Width = 120
      Height = 23
      TabOrder = 2
    end
    object lblVencimento: TLabel
      Left = 152
      Top = 72
      Width = 63
      Height = 15
      Caption = 'Vencimento'
    end
    object edtVencimento: TEdit
      Left = 152
      Top = 91
      Width = 120
      Height = 23
      TabOrder = 3
    end
    object lblPagamento: TLabel
      Left = 288
      Top = 72
      Width = 58
      Height = 15
      Caption = 'Pagamento'
    end
    object edtPagamento: TEdit
      Left = 288
      Top = 91
      Width = 120
      Height = 23
      TabOrder = 4
    end
    object lblSituacao: TLabel
      Left = 424
      Top = 72
      Width = 49
      Height = 15
      Caption = 'Situa'#231#227'o'
    end
    object edtSituacao: TEdit
      Left = 424
      Top = 91
      Width = 200
      Height = 23
      TabOrder = 5
    end
    object lblValor: TLabel
      Left = 16
      Top = 128
      Width = 30
      Height = 15
      Caption = 'Valor'
    end
    object edtValor: TEdit
      Left = 16
      Top = 147
      Width = 160
      Height = 23
      TabOrder = 6
    end
    object lblValorAberto: TLabel
      Left = 192
      Top = 128
      Width = 72
      Height = 15
      Caption = 'Valor em aberto'
    end
    object edtValorAberto: TEdit
      Left = 192
      Top = 147
      Width = 160
      Height = 23
      TabOrder = 7
    end
    object lblValorPago: TLabel
      Left = 368
      Top = 128
      Width = 58
      Height = 15
      Caption = 'Valor pago'
    end
    object edtValorPago: TEdit
      Left = 368
      Top = 147
      Width = 160
      Height = 23
      TabOrder = 8
    end
    object lblObservacao: TLabel
      Left = 16
      Top = 184
      Width = 65
      Height = 15
      Caption = 'Observa'#231#227'o'
    end
    object memObservacao: TMemo
      Left = 16
      Top = 203
      Width = 608
      Height = 148
      Anchors = [akLeft, akTop, akRight, akBottom]
      ScrollBars = ssVertical
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
