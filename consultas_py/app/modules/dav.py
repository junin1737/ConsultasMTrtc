"""Modulo DAV (UfrmDav.pas / UfrmDavDetalhe.pas)."""
from __future__ import annotations

from typing import Any, Dict

from app.docs.resumo_pdf import acao_imprimir
from app.maps import dav as mp
from app.modules.helpers import item_columns, itens_section
from app.modules.spec import ColumnSpec, Ctx, DetailData, ModuleSpec, PeriodFilter
from app.util import fmt


def _build(conn, f: Dict[str, Any]):
    return mp.sql_lista(f)


def _detail(ctx: Ctx, row: Dict[str, Any]):
    alias, emp, dav = row["Base"], fmt.to_int(row["EMPCODIGO"]), fmt.to_int(row["DAVCONTADOR"])
    cab = mp.carregar_cabecalho(ctx, alias, emp, dav)
    if not cab:
        return None
    conn = ctx.conn(alias)
    p = {"EMPCODIGO": emp, "DAVCONTADOR": dav}
    sec_srv, tot_srv = itens_section(
        ctx, alias, "Serviços", mp.sql_servicos(conn), p,
        item_columns("DAVITEMSERVORDEM", "SERVDESCRICAO", "DAVITEMSERVQTDE", "DAVITEMSERVUNITARIO",
                     "DAVITEMSERVTOTALLIQUIDO"), "DAVITEMSERVTOTALLIQUIDO")
    sec_prd, tot_prd = itens_section(
        ctx, alias, "Produtos", mp.sql_produtos(conn), p,
        item_columns("DAVITEMORDEM", "PRODDESCRICAO", "DAVITEMQTDE", "DAVITEMUNITARIO",
                     "DAVITEMTOTALLIQUIDO"), "DAVITEMTOTALLIQUIDO")
    data = DetailData(
        title="Detalhes - DAV",
        fields=[
            ("Número DAV", cab["numero"]),
            ("Data emissão", cab["emissao"]),
            ("Cliente", cab["cliente"]),
            ("Vencimento", cab["vencimento"]),
            ("Valor total", cab["valor_total"]),
            ("Usuário", cab["usuario"]),
            ("Total serviços", fmt.moeda(tot_srv)),
            ("Total produtos", fmt.moeda(tot_prd)),
        ],
        memos=[("Observação", cab["observacao"])],
    )
    data.sections = [s for s in (sec_srv, sec_prd) if s]
    data.actions.append(acao_imprimir(data, f"dav_{alias}_{cab['numero']}", f"DAV {cab['numero']}"))
    return data


SPEC = ModuleSpec(
    key="dav",
    title="DAV",
    tile_title="DAV",
    hint="Documentos auxiliares de venda",
    icon="DAV.png",
    search_label="Pesquisar por número ou cliente (Enter pesquisa):",
    columns=[
        ColumnSpec("EMPCODIGO", "Empresa", "int", hidden=True),
        ColumnSpec("DAVCONTADOR", "Contador", "int", hidden=True),
        ColumnSpec("DAVNUMERO", "Número", "int", 90),
        ColumnSpec("DAVEMISSAO", "Emissão", "date", 100),
        ColumnSpec("NOME_CLIENTE", "Cliente", "text", 420),
        ColumnSpec("DAVDATAENTREGA", "Vencimento", "date", 100),
        ColumnSpec("DAVTOTALLIQUIDO", "Valor total", "money", 120),
    ],
    build=_build,
    detail=_detail,
    filters=[PeriodFilter("periodo", "Emissão")],
)
