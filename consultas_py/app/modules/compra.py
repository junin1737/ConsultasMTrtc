"""Modulo Compras (UfrmCompra.pas / UfrmCompraDetalhe.pas)."""
from __future__ import annotations

from typing import Any, Dict

from app.docs.danfe import acao_danfe_compra
from app.docs.resumo_pdf import acao_imprimir
from app.maps import compra as mp
from app.maps.common import cor_situacao_nota
from app.modules.helpers import item_columns, itens_section
from app.modules.spec import ColumnSpec, Ctx, DetailData, ModuleSpec, PeriodFilter, SituacaoNotaFilter
from app.util import fmt


def _build(conn, f: Dict[str, Any]):
    return mp.sql_lista(f)


def _detail(ctx: Ctx, row: Dict[str, Any]):
    alias, emp, entc = row["Base"], fmt.to_int(row["EMPCODIGO"]), fmt.to_int(row["ENTCCONTADOR"])
    cab = mp.carregar_cabecalho(ctx, alias, emp, entc)
    if not cab:
        return None
    conn = ctx.conn(alias)
    p = {"EMPCODIGO": emp, "ENTCCONTADOR": entc}
    sec_srv, tot_srv = itens_section(
        ctx, alias, "Serviços", mp.sql_servicos(conn), p,
        item_columns("ENTCISERVITEM", "SERVDESCRICAO", "ENTCISERVQTDE", "ENTCISERVUNITARIO",
                     "ENTCISERVTOTALLIQUIDO"), "ENTCISERVTOTALLIQUIDO")
    sec_prd, tot_prd = itens_section(
        ctx, alias, "Produtos", mp.sql_produtos(conn), p,
        item_columns("ENTCINUMEROITEM", "PRODDESCRICAO", "ENTCIQTDE", "ENTCIVRUNITARIO",
                     "ENTCIVRTOTALLIQUIDO"), "ENTCIVRTOTALLIQUIDO")
    data = DetailData(
        title="Detalhes - Compra",
        fields=[
            ("Número", cab["numero"]),
            ("Série", cab["serie"]),
            ("Emissão", cab["emissao"]),
            ("Entrada", cab["entrada"]),
            ("Fornecedor", cab["fornecedor"]),
            ("Valor total", cab["valor_total"]),
            ("Situação", fmt.texto(row.get("SITUACAO_NOTA"))),
            ("Total produtos", fmt.moeda(tot_prd)),
            ("Total serviços", fmt.moeda(tot_srv)),
            ("Chave NF-e", cab["chave"]),
        ],
        memos=[("Observação", cab["observacao"])],
    )
    data.sections = [s for s in (sec_prd, sec_srv) if s]
    data.actions.append(acao_imprimir(data, f"compra_{alias}_{cab['numero']}", f"Compra {cab['numero']}"))
    data.actions.append(acao_danfe_compra(ctx, row, cab))
    return data


SPEC = ModuleSpec(
    key="compra",
    title="Compras",
    tile_title="Compras",
    hint="Entradas de compra",
    icon="Compras.png",
    search_label="Pesquisar por número ou fornecedor (Enter pesquisa):",
    columns=[
        ColumnSpec("EMPCODIGO", "Empresa", "int", hidden=True),
        ColumnSpec("ENTCCONTADOR", "Contador", "int", hidden=True),
        ColumnSpec("ENTCNUMERO", "Número", "int", 90),
        ColumnSpec("ENTCSERIE", "Série", "text", 60),
        ColumnSpec("ENTCDTEMISSAO", "Emissão", "date", 100),
        ColumnSpec("ENTCDTENTRADA", "Entrada", "date", 100),
        ColumnSpec("NOME_FORNECEDOR", "Fornecedor", "text", 340),
        ColumnSpec("ENTCVRTOTAL", "Valor total", "money", 120),
        ColumnSpec("SITUACAO_NOTA", "Situação", "text", 100),
        ColumnSpec("ENTCCHAVENFE", "Chave NF-e", "text", 340),
        ColumnSpec("ENTCSITUACAO", "Sit.", "int", hidden=True),
        ColumnSpec("ENTCSITUACAODOCUMENTO", "Sit. doc.", "text", hidden=True),
    ],
    build=_build,
    detail=_detail,
    filters=[SituacaoNotaFilter(), PeriodFilter("periodo", "Entrada")],
    row_color=cor_situacao_nota,
    wide=True,
)
