"""Estoque (port de UMapaEstoque.pas)."""
from __future__ import annotations

from typing import Any, Dict, Optional, Tuple

from app.maps.common import select_codigo_produto
from app.util import fmt


def sql_lista(conn, filtro: str) -> Tuple[str, Dict[str, Any]]:
    filtro = (filtro or "").strip()
    campo_codigo = select_codigo_produto(conn) or "P.PRODCODFABRICANTE AS CODIGO_ITEM, "
    sql = ("SELECT FIRST 2000 P.EMPCODIGO, P.PRODCONTADOR, " + campo_codigo +
           "P.PRODDESCRICAO, P.PRODESTOQUE, P.PRODPRECOVAREJO FROM PRODUTO P ")
    params: Dict[str, Any] = {}
    if filtro:
        if fmt.so_digitos(filtro):
            sql += "WHERE P.PRODCONTADOR = :DOCNUMERO "
            params["DOCNUMERO"] = int(filtro)
        else:
            sql += ("WHERE (P.PRODDESCRICAO CONTAINING :FILTRO_TEXTO "
                    "OR P.PRODCODFABRICANTE CONTAINING :FILTRO_TEXTO) ")
            params["FILTRO_TEXTO"] = filtro
    return sql + "ORDER BY P.PRODDESCRICAO", params


def carregar_detalhe(ctx, alias: str, emp: int, prod: int) -> Optional[Dict[str, Any]]:
    campo_codigo = select_codigo_produto(ctx.conn(alias)) or "P.PRODCODFABRICANTE AS CODIGO_ITEM, "
    return ctx.query(
        alias,
        "SELECT FIRST 1 P.EMPCODIGO, P.PRODCONTADOR, " + campo_codigo +
        "P.PRODDESCRICAO, P.PRODESTOQUE, P.PRODPRECOVAREJO, P.PRODPRECOATACADO, P.PRODESTOQUESEGURANCA "
        "FROM PRODUTO P WHERE P.EMPCODIGO = :EMPCODIGO AND P.PRODCONTADOR = :PRODCONTADOR",
        {"EMPCODIGO": emp, "PRODCONTADOR": prod}).first()
