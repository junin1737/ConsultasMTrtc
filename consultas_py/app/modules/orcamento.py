"""Modulo Orcamento (UfrmOrcamento.pas / UfrmOrcamentoDetalhe.pas)."""
from __future__ import annotations

from typing import Any, Dict

from app.maps import orcamento as mp
from app.modules.helpers import item_columns, itens_section
from app.modules.spec import ColumnSpec, Ctx, DetailData, ModuleSpec, PeriodFilter
from app.docs.resumo_pdf import acao_imprimir
from app.util import fmt


def _build(conn, f: Dict[str, Any]):
    return mp.sql_lista(f)


def _detail(ctx: Ctx, row: Dict[str, Any]):
    alias, emp, orc = row["Base"], fmt.to_int(row["EMPCODIGO"]), fmt.to_int(row["ORCCONTADOR"])
    cab = mp.carregar_cabecalho(ctx, alias, emp, orc)
    if not cab:
        return None
    conn = ctx.conn(alias)
    p = {"EMPCODIGO": emp, "ORCCONTADOR": orc}
    sec_srv, tot_srv = itens_section(
        ctx, alias, "Serviços", mp.sql_servicos(conn), p,
        item_columns("ORCITEMSERVORDEM", "SERVDESCRICAO", "ORCITEMSERVQTDE", "ORCITEMSERVUNITARIO",
                     "ORCITEMSERVTOTALLIQUIDO"), "ORCITEMSERVTOTALLIQUIDO")
    sec_prd, tot_prd = itens_section(
        ctx, alias, "Produtos", mp.sql_produtos(conn), p,
        item_columns("ORCITEMORDEM", "PRODDESCRICAO", "ORCITEMQTDE", "ORCITEMUNITARIO",
                     "ORCITEMTOTALLIQUIDO"), "ORCITEMTOTALLIQUIDO")
    data = DetailData(
        title="Detalhes - Orçamento",
        fields=[
            ("Número orçamento", cab["numero"]),
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
    data.actions.append(acao_imprimir(data, f"orcamento_{alias}_{cab['numero']}", f"Orçamento {cab['numero']}"))
    return data


SPEC = ModuleSpec(
    key="orcamento",
    title="Orçamentos",
    tile_title="Orçamento",
    hint="Orçamentos",
    icon="Orcamento.png",
    search_label="Pesquisar por número ou cliente (Enter pesquisa):",
    columns=[
        ColumnSpec("EMPCODIGO", "Empresa", "int", hidden=True),
        ColumnSpec("ORCCONTADOR", "Contador", "int", hidden=True),
        ColumnSpec("ORCNUMERO", "Número", "int", 90),
        ColumnSpec("ORCEMISSAO", "Emissão", "date", 100),
        ColumnSpec("PESNOME", "Cliente", "text", 420),
        ColumnSpec("DATA_VENCIMENTO", "Vencimento", "date", 100),
        ColumnSpec("ORCTOTALLIQUIDO", "Valor total", "money", 120),
    ],
    build=_build,
    detail=_detail,
    filters=[PeriodFilter("periodo", "Emissão", active_by_default=True)],
)
