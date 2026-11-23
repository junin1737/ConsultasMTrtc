"""Helpers comuns aos modulos de documentos (orcamento/DAV/compra/notas)."""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from app.maps.common import soma
from app.modules.spec import ColumnSpec, Ctx, DetailSection


def item_columns(ordem: str, desc: str, qtde: str, unit: str, total: str,
                 titulo_codigo: str = "Código") -> List[ColumnSpec]:
    return [
        ColumnSpec(ordem, "Item", "int", 50),
        ColumnSpec("CODIGO_ITEM", titulo_codigo, "text", 140),
        ColumnSpec(desc, "Descrição", "text", 380),
        ColumnSpec(qtde, "Qtde", "qty", 80),
        ColumnSpec(unit, "Vl. unitário", "money", 100),
        ColumnSpec(total, "Total", "money", 110),
    ]


def itens_section(ctx: Ctx, alias: str, titulo: str, sql: str, params: Dict[str, Any],
                  cols: List[ColumnSpec], total_key: str):
    """Retorna (DetailSection | None, total)."""
    try:
        rows = ctx.query(alias, sql, params).dicts()
    except Exception:  # noqa: BLE001  (tabela de servicos pode nao existir em bases antigas)
        rows = []
    if not rows:
        return None, 0.0
    return DetailSection(titulo, cols, rows), soma(rows, total_key)
