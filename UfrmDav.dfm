inherited frmDav: TfrmDav
  BorderStyle = bsSizeable
  Caption = 'DAV'
  ClientHeight = 630
  ClientWidth = 945
  Position = poScreenCenter
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
