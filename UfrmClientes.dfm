inherited frmClientes: TfrmClientes
  BorderStyle = bsSizeable
  Caption = 'Clientes'
  ClientHeight = 630
  ClientWidth = 945
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  inherited PanelTopo: TPanel
    Width = 945
    inherited lblPesquisa: TLabel
      Top = 24
    end
    inherited edtPesquisa: TEdit
      Top = 21
      Width = 700
    end
  end
  inherited PanelRodape: TPanel
    Top = 573
    Width = 945
    inherited btnFechar: TButton
      Left = 839
    end
  end
  inherited DBGrid1: TConsultaDBGrid
    Width = 945
    Height = 508
  end
end
