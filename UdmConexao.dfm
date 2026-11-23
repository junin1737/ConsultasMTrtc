object dmConexao: TdmConexao
  OnCreate = DataModuleCreate
  Height = 150
  Width = 215
  PixelsPerInch = 96
  object FDConnection1: TFDConnection
    Connected = False
    LoginPrompt = False
    Left = 40
    Top = 24
  end
  object FDPhysFBDriverLink1: TFDPhysFBDriverLink
    Left = 40
    Top = 80
  end
end
