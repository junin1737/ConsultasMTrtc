program Consultas;



uses

  System.SysUtils,

  Vcl.Forms, Vcl.Dialogs,

  FireDAC.DApt,

  Uprincipal in 'Uprincipal.pas' {frmprincipal},

  UdmConexao in 'UdmConexao.pas' {dmConexao},

  UfrmConfigBanco in 'UfrmConfigBanco.pas' {frmConfigBanco},

  UfrmConsultaBase in 'UfrmConsultaBase.pas' {frmConsultaBase},

  UMapaPessoas in 'UMapaPessoas.pas',
  UMapaOrcamento in 'UMapaOrcamento.pas',
  UCampoObservacao in 'UCampoObservacao.pas',
  UCampoCodigoItem in 'UCampoCodigoItem.pas',
  UOrcamentoImpressao in 'UOrcamentoImpressao.pas',
  UMapaDav in 'UMapaDav.pas',
  UMapaCompra in 'UMapaCompra.pas',
  UMapaNotaFiscal in 'UMapaNotaFiscal.pas',
  UMapaNfce in 'UMapaNfce.pas',
  UMapaReceber in 'UMapaReceber.pas',
  UMapaPagar in 'UMapaPagar.pas',
  UMapaEstoque in 'UMapaEstoque.pas',
  UDavRelatorioImpressao in 'UDavRelatorioImpressao.pas',
  UDavImpressao in 'UDavImpressao.pas',
  UCompraImpressao in 'UCompraImpressao.pas',
  UNotaFiscalImpressao in 'UNotaFiscalImpressao.pas',
  UNFeDanfeVisualizacao in 'UNFeDanfeVisualizacao.pas',
  UNfceXmlResolver in 'UNfceXmlResolver.pas',
  UNfceDanfeVisualizacao in 'UNfceDanfeVisualizacao.pas',
  UNfceRelatorioFr3 in 'UNfceRelatorioFr3.pas',
  UNfceCupomImpressao in 'UNfceCupomImpressao.pas',
  UNfceImpressao in 'UNfceImpressao.pas',
  UConfirmarFechar in 'UConfirmarFechar.pas',
  UConsultaManager in 'UConsultaManager.pas',
  UConsultaDialogs in 'UConsultaDialogs.pas',
  UFormatacaoMoeda in 'UFormatacaoMoeda.pas',
  UImpressaoUtil in 'UImpressaoUtil.pas',
  UConsultaCampos in 'UConsultaCampos.pas',
  UConsultaLayout in 'UConsultaLayout.pas',
  UFiltroPeriodoConsulta in 'UFiltroPeriodoConsulta.pas',
  UFiltroSituacaoNotaFiscal in 'UFiltroSituacaoNotaFiscal.pas',
  USituacaoNotaConsulta in 'USituacaoNotaConsulta.pas',
  UfrmRegistroDetalhe in 'UfrmRegistroDetalhe.pas' {frmRegistroDetalhe},
  UfrmPessoaDetalhe in 'UfrmPessoaDetalhe.pas' {frmPessoaDetalhe},
  UfrmReceberDetalhe in 'UfrmReceberDetalhe.pas' {frmReceberDetalhe},
  UfrmReceberBoletoDetalhe in 'UfrmReceberBoletoDetalhe.pas',
  UfrmVisualizarImpressao in 'UfrmVisualizarImpressao.pas' {frmVisualizarImpressao},
  UBoletoImpressao in 'UBoletoImpressao.pas',
  UBoletoRelatorioFr3 in 'UBoletoRelatorioFr3.pas',
  UfrmPagarDetalhe in 'UfrmPagarDetalhe.pas' {frmPagarDetalhe},
  UfrmProdutoDetalhe in 'UfrmProdutoDetalhe.pas' {frmProdutoDetalhe},

  UfrmClientes in 'UfrmClientes.pas' {frmClientes},

  UfrmEstoque in 'UfrmEstoque.pas' {frmEstoque},

  UfrmOrcamento in 'UfrmOrcamento.pas' {frmOrcamento},
  UfrmOrcamentoDetalhe in 'UfrmOrcamentoDetalhe.pas' {frmOrcamentoDetalhe},

  UfrmReceber in 'UfrmReceber.pas' {frmReceber},

  UfrmPagar in 'UfrmPagar.pas' {frmPagar},

  UfrmDav in 'UfrmDav.pas' {frmDav},
  UfrmDavDetalhe in 'UfrmDavDetalhe.pas' {frmDavDetalhe},

  UfrmCompra in 'UfrmCompra.pas' {frmCompra},
  UfrmCompraDetalhe in 'UfrmCompraDetalhe.pas' {frmCompraDetalhe},
  UfrmNotaFiscal in 'UfrmNotaFiscal.pas' {frmNotaFiscal},
  UfrmNotaFiscalDetalhe in 'UfrmNotaFiscalDetalhe.pas' {frmNotaFiscalDetalhe},

  Vcl.Themes,

  Vcl.Styles;



{$R *.res}



begin

  Application.Initialize;

  Application.MainFormOnTaskbar := True;

  TStyleManager.TrySetStyle('Sky');

  Application.CreateForm(Tfrmprincipal, frmprincipal);

  Application.CreateForm(TdmConexao, dmConexao);

  Application.Run;

end.


