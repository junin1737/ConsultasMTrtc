"""Compras / entrada de NF (port de UMapaCompra.pas + UCompraImpressao.CarregarCabecalho)."""
from __future__ import annotations

from typing import Any, Dict, Optional, Tuple

from app.maps.common import (
    Where, cond_periodo, cond_texto_numero, select_codigo_produto, select_codigo_servico,
    select_situacao_nota, cond_situacao_nota,
)
from app.util import fmt


def sql_lista(f: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
    params: Dict[str, Any] = {}
    w = Where()
    w.add(cond_texto_numero(f.get("text", ""), "E.ENTCNUMERO", "P.PESNOME", params))
    w.add(cond_periodo("COALESCE(E.ENTCDTENTRADA, E.ENTCDTEMISSAO)", "DATA_INICIO", "DATA_FIM",
                       f.get("periodo"), params))
    w.add(cond_situacao_nota("E.ENTCSITUACAODOCUMENTO", f.get("situacao")))
    sql = (
        "SELECT FIRST 2000 "
        "E.EMPCODIGO, E.ENTCCONTADOR, E.ENTCNUMERO, E.ENTCSERIE, "
        "E.ENTCDTEMISSAO, E.ENTCDTENTRADA, P.PESNOME AS NOME_FORNECEDOR, "
        "E.ENTCVRTOTAL, E.ENTCSITUACAO, E.ENTCSITUACAODOCUMENTO, E.ENTCCHAVENFE, "
        + select_situacao_nota("E.ENTCSITUACAODOCUMENTO") + " "
        "FROM ENTRADACOMPRA E "
        "LEFT JOIN FORNECEDOR F ON F.FORCODIGO = E.FORCODIGO AND F.EMPCODIGO = E.EMPCODIGO "
        "LEFT JOIN PESSOA P ON P.PESCODIGO = F.PESCODIGO " + w.sql() +
        " ORDER BY E.ENTCDTEMISSAO DESC, E.ENTCNUMERO DESC"
    )
    return sql, params


def sql_produtos(conn) -> str:
    return (
        "SELECT EI.ENTCINUMEROITEM, " + select_codigo_produto(conn) +
        "P.PRODDESCRICAO, EI.ENTCIQTDE, EI.ENTCIVRUNITARIO, EI.ENTCIVRTOTALLIQUIDO "
        "FROM ENTRADACOMPRAITEM EI "
        "LEFT JOIN PRODUTO P ON P.PRODCONTADOR = EI.PRODCONTADOR AND P.EMPCODIGO = EI.EMPCODIGO "
        "WHERE EI.EMPCODIGO = :EMPCODIGO AND EI.ENTCCONTADOR = :ENTCCONTADOR ORDER BY EI.ENTCINUMEROITEM")


def sql_servicos(conn) -> str:
    return (
        "SELECT ES.ENTCISERVITEM, " + select_codigo_servico(conn) +
        "S.SERVDESCRICAO, ES.ENTCISERVQTDE, ES.ENTCISERVUNITARIO, ES.ENTCISERVTOTALLIQUIDO "
        "FROM ENTRADACOMPRAITEMSERVICO ES "
        "LEFT JOIN SERVICO S ON S.SERVCONTADOR = ES.SERVCONTADOR AND S.EMPCODIGO = ES.EMPCODIGO "
        "WHERE ES.EMPCODIGO = :EMPCODIGO AND ES.ENTCCONTADOR = :ENTCCONTADOR ORDER BY ES.ENTCISERVITEM")


def carregar_cabecalho(ctx, alias: str, emp: int, entc: int) -> Optional[Dict[str, Any]]:
    r = ctx.query(
        alias,
        "SELECT E.ENTCNUMERO, E.ENTCSERIE, E.ENTCDTEMISSAO, E.ENTCDTENTRADA, E.ENTCVRTOTAL, "
        "E.ENTCCHAVENFE, E.ENTCOBSDOCUMENTO, P.PESNOME "
        "FROM ENTRADACOMPRA E "
        "LEFT JOIN FORNECEDOR F ON F.FORCODIGO = E.FORCODIGO AND F.EMPCODIGO = E.EMPCODIGO "
        "LEFT JOIN PESSOA P ON P.PESCODIGO = F.PESCODIGO "
        "WHERE E.EMPCODIGO = :EMPCODIGO AND E.ENTCCONTADOR = :ENTCCONTADOR",
        {"EMPCODIGO": emp, "ENTCCONTADOR": entc}).first()
    if not r:
        return None
    return {
        "numero": fmt.texto(r.get("ENTCNUMERO")),
        "serie": fmt.texto(r.get("ENTCSERIE")),
        "emissao": fmt.data(r.get("ENTCDTEMISSAO")),
        "entrada": fmt.data(r.get("ENTCDTENTRADA")),
        "fornecedor": fmt.texto(r.get("PESNOME")),
        "valor_total": fmt.moeda(r.get("ENTCVRTOTAL")),
        "chave": fmt.texto(r.get("ENTCCHAVENFE")),
        "observacao": fmt.texto(r.get("ENTCOBSDOCUMENTO")),
    }
