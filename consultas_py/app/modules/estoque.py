"""Modulo Estoque (UfrmEstoque.pas / UfrmProdutoDetalhe.pas)."""
from __future__ import annotations

from typing import Any, Dict

from app.maps import estoque as mp
from app.modules.spec import ColumnSpec, Ctx, DetailData, ModuleSpec
from app.util import fmt


def _build(conn, f: Dict[str, Any]):
    return mp.sql_lista(conn, f.get("text", ""))


def _detail(ctx: Ctx, row: Dict[str, Any]):
    d = mp.carregar_detalhe(ctx, row["Base"], fmt.to_int(row["EMPCODIGO"]), fmt.to_int(row["PRODCONTADOR"]))
    if not d:
        return None
    return DetailData(
        title="Detalhes - Produto",
        fields=[
            ("Código", fmt.texto(d.get("PRODCONTADOR"))),
            ("Cód. fabricante", fmt.texto(d.get("CODIGO_ITEM"))),
            ("Descrição", fmt.texto(d.get("PRODDESCRICAO"))),
            ("Estoque", fmt.quantidade(d.get("PRODESTOQUE"))),
            ("Estoque de segurança", fmt.quantidade(d.get("PRODESTOQUESEGURANCA"))),
            ("Preço varejo", fmt.moeda(d.get("PRODPRECOVAREJO"))),
            ("Preço atacado", fmt.moeda(d.get("PRODPRECOATACADO"))),
        ],
    )


SPEC = ModuleSpec(
    key="estoque",
    title="Estoque",
    tile_title="Estoque",
    hint="Produtos e saldo em estoque",
    icon="Estoque.png",
    search_label="Pesquisar por código, descrição ou cód. fabricante (Enter pesquisa):",
    columns=[
        ColumnSpec("EMPCODIGO", "Empresa", "int", hidden=True),
        ColumnSpec("PRODCONTADOR", "Código", "int", 80),
        ColumnSpec("CODIGO_ITEM", "Cód. fabricante", "text", 150),
        ColumnSpec("PRODDESCRICAO", "Descrição", "text", 480),
        ColumnSpec("PRODESTOQUE", "Estoque", "qty", 100),
        ColumnSpec("PRODPRECOVAREJO", "Preço varejo", "money", 110),
    ],
    build=_build,
    detail=_detail,
)
