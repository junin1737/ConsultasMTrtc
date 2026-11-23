inherited frmPagar: TfrmPagar
  Caption = 'Contas a Pagar'
  ClientHeight = 630
  ClientWidth = 945
  OnCreate = FormCreate
  TextHeight = 15
  inherited PanelTopo: TPanel
    Width = 945
    inherited edtPesquisa: TEdit
      Left = 120
      Top = 21
    end
  end
  inherited PanelRodape: TPanel
    Top = 573
    Width = 945
  end
  inherited DBGrid1: TConsultaDBGrid
    Width = 945
    Height = 508
  end
end
