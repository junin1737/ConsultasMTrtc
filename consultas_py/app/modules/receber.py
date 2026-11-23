"""Modulo Contas a Receber (UfrmReceber.pas / UfrmReceberDetalhe.pas) + boleto PDF."""
from __future__ import annotations

from typing import Any, Dict

from app.docs import boleto_pdf
from app.docs.viewer import open_file, temp_pdf_path
from app.maps import receber as mp
from app.modules.spec import (
    ChoiceFilter, ColumnSpec, Ctx, DetailData, DetailSection, ModuleSpec, PeriodFilter, TextFilter,
)
from app.util import fmt


def _build(conn, f: Dict[str, Any]):
    return mp.sql_lista(f)


def abrir_boleto(ctx: Ctx, alias: str, emp: int, cr: int, documento: str = "") -> str:
    """Gera o PDF dos boletos do titulo e abre no leitor padrao."""
    if not mp.tem_boleto(ctx, alias, emp, cr):
        raise ValueError("Este título não possui boleto.")
    dados = mp.carregar_dados_titulo(ctx, alias, emp, cr)
    path = boleto_pdf.gerar_pdf(dados, temp_pdf_path(f"boleto_{alias}_{documento or cr}"),
                                f"Boleto - {documento}" if documento else "Boleto")
    open_file(path)
    return path


def _acao_boleto(ctx: Ctx, row: Dict[str, Any]) -> None:
    abrir_boleto(ctx, row["Base"], fmt.to_int(row["EMPCODIGO"]), fmt.to_int(row["CRNUMERO"]),
                 fmt.texto(row.get("CRDOCUMENTO")))


def _detail(ctx: Ctx, row: Dict[str, Any]):
    alias, emp, cr = row["Base"], fmt.to_int(row["EMPCODIGO"]), fmt.to_int(row["CRNUMERO"])
    d = mp.carregar_detalhe(ctx, alias, emp, cr)
    if not d:
        return None
    boletos = mp.carregar_boletos(ctx, alias, emp, cr)
    doc = fmt.documento(fmt.texto(d.get("CRDOCUMENTO")))
    data = DetailData(
        title="Detalhes - Contas a Receber",
        fields=[
            ("Documento", doc),
            ("Cliente", fmt.texto(d.get("PESNOME"))),
            ("Emissão", fmt.data(d.get("CRDTEMISSAO"))),
            ("Vencimento", fmt.data(d.get("CRDTVENCTO"))),
            ("Recebimento", fmt.data(d.get("CRDTRECEBIMENTO"))),
            ("Situação", mp.descricao_situacao_receber(d.get("CRSITUACAO"))),
            ("Valor", fmt.moeda(d.get("CRVALOR"))),
            ("Valor recebido", fmt.moeda(d.get("CRVALORRECEBIDO"))),
            ("Valor em aberto", fmt.moeda(d.get("CRVALORABERTO"))),
        ],
        memos=[("Observação", fmt.texto(d.get("CROBSERVACAO")))],
    )
    if boletos:
        data.sections.append(DetailSection(
            "Boletos",
            [
                ColumnSpec("BOLNOSSONUMERO", "Nosso número", "text", 130),
                ColumnSpec("BOLNUMERO", "Número", "text", 90),
                ColumnSpec("BOLVENCIMENTO", "Vencimento", "date", 90),
                ColumnSpec("BOLVALOR", "Valor", "money", 100),
                ColumnSpec("SITUACAO_TXT", "Situação", "text", 90),
                ColumnSpec("BOLDATAPAGAMENTO", "Pagamento", "date", 90),
                ColumnSpec("BOLLINHADIGITAVEL", "Linha digitável", "text", 380),
            ],
            boletos,
        ))
    data.actions.append(("Ver boleto", lambda: abrir_boleto(ctx, alias, emp, cr, doc), bool(boletos)))
    return data


SPEC = ModuleSpec(
    key="receber",
    title="Contas a Receber",
    tile_title="Receber",
    hint="Contas a receber",
    icon="Receber.png",
    search_label="Pesquisar por número, documento ou cliente (Enter pesquisa):",
    columns=[
        ColumnSpec("EMPCODIGO", "Empresa", "int", hidden=True),
        ColumnSpec("CRNUMERO", "Número", "int", hidden=True),
        ColumnSpec("CRDOCUMENTO", "Documento", "doc", 110),
        ColumnSpec("CRDTEMISSAO", "Emissão", "date", 90),
        ColumnSpec("CRDTVENCTO", "Vencimento", "date", 90),
        ColumnSpec("CRDTRECEBIMENTO", "Recebimento", "date", 90),
        ColumnSpec("CODIGO_CLIENTE", "Código", "int", 70),
        ColumnSpec("NOME_PESSOA", "Cliente", "text", 260),
        ColumnSpec("CPF_CNPJ", "CPF/CNPJ", "cpfcnpj", 135),
        ColumnSpec("CRVALOR", "Valor", "money", 110),
        ColumnSpec("CRVALORRECEBIDO", "Valor recebido", "money", 110),
        ColumnSpec("CRVALORABERTO", "Restante", "money", 110),
        ColumnSpec("CRSITUACAO", "Situação", "int", hidden=True),
        ColumnSpec("TEM_BOLETO", "Boleto", "yesno", 60),
    ],
    build=_build,
    detail=_detail,
    filters=[
        ChoiceFilter("situacao", "Situação",
                     [("Todas", ""), ("Recebidas", "recebidas"), ("Em aberto", "aberto"), ("Atrasadas", "atrasadas")], ""),
        ChoiceFilter("boleto", "Boleto", [("Todos", ""), ("Com boleto", "com"), ("Sem boleto", "sem")], ""),
        TextFilter("codigo_cliente", "Código cliente", 90),
        TextFilter("nosso_numero", "Nosso número", 140),
        PeriodFilter("emissao", "Emissão"),
        PeriodFilter("vencimento", "Vencimento"),
        PeriodFilter("recebimento", "Recebimento"),
    ],
    row_color=mp.cor_linha,
    actions=[("Ver boleto", _acao_boleto, lambda r: fmt.to_int(r.get("TEM_BOLETO")) == 1)],
    wide=True,
)
