inherited frmReceber: TfrmReceber
  Caption = 'Contas a Receber'
  ClientHeight = 630
  ClientWidth = 945
  OnCreate = FormCreate
  TextHeight = 15
  inherited PanelTopo: TPanel
    Width = 945
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
