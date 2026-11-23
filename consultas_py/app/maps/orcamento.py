"""Orcamento (port de UMapaOrcamento.pas + UOrcamentoImpressao.CarregarCabecalho)."""
from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from app.maps.common import (
    Where, cond_periodo, cond_texto_numero, nome_usuario, observacao_documento,
    select_codigo_produto, select_codigo_servico, vencimento_30_dias,
)
from app.util import fmt


def sql_lista(f: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
    params: Dict[str, Any] = {}
    w = Where()
    w.add(cond_texto_numero(f.get("text", ""), "O.ORCNUMERO", "O.PESNOME", params))
    w.add(cond_periodo("O.ORCEMISSAO", "DATA_INICIO", "DATA_FIM", f.get("periodo"), params))
    sql = (
        "SELECT FIRST 2000 "
        "O.EMPCODIGO, O.ORCCONTADOR, O.ORCNUMERO, O.ORCEMISSAO, O.PESNOME, "
        "CASE "
        "  WHEN O.ORCEMISSAO IS NOT NULL THEN O.ORCEMISSAO + 30 "
        "  WHEN O.ORCDATAENTREGA IS NOT NULL THEN O.ORCDATAENTREGA "
        "  WHEN O.ORCPRAZOVALIDADE > 0 AND O.ORCEMISSAO IS NOT NULL "
        "    THEN O.ORCEMISSAO + O.ORCPRAZOVALIDADE "
        "  ELSE NULL "
        "END AS DATA_VENCIMENTO, "
        "O.ORCTOTALLIQUIDO "
        "FROM ORCAMENTO O " + w.sql() + " ORDER BY O.ORCEMISSAO DESC, O.ORCNUMERO DESC"
    )
    return sql, params


def sql_produtos(conn) -> str:
    return (
        "SELECT DI.ORCITEMORDEM, " + select_codigo_produto(conn) +
        "P.PRODDESCRICAO, DI.ORCITEMQTDE, DI.ORCITEMUNITARIO, DI.ORCITEMTOTALLIQUIDO "
        "FROM ORCAMENTOITEM DI "
        "LEFT JOIN PRODUTO P ON P.PRODCONTADOR = DI.PRODCONTADOR AND P.EMPCODIGO = DI.EMPCODIGO "
        "WHERE DI.EMPCODIGO = :EMPCODIGO AND DI.ORCCONTADOR = :ORCCONTADOR ORDER BY DI.ORCITEMORDEM")


def sql_servicos(conn) -> str:
    return (
        "SELECT DS.ORCITEMSERVORDEM, " + select_codigo_servico(conn) +
        "S.SERVDESCRICAO, DS.ORCITEMSERVQTDE, DS.ORCITEMSERVUNITARIO, DS.ORCITEMSERVTOTALLIQUIDO "
        "FROM ORCAMENTOITEMSERVICO DS "
        "LEFT JOIN SERVICO S ON S.SERVCONTADOR = DS.SERVCONTADOR AND S.EMPCODIGO = DS.EMPCODIGO "
        "WHERE DS.EMPCODIGO = :EMPCODIGO AND DS.ORCCONTADOR = :ORCCONTADOR ORDER BY DS.ORCITEMSERVORDEM")


_SQL_CAB = (
    "SELECT O.*, O.PESNOME, COALESCE(PU.PESNOME, U.USUNOME, U.USULOGIN) AS USUARIO_NOME "
    "FROM ORCAMENTO O "
    "LEFT JOIN USUARIO U ON U.USUCODIGO = O.USUCODIGO AND U.EMPCODIGO = O.EMPCODIGO "
    "LEFT JOIN PESSOA PU ON PU.PESCODIGO = U.PESCODIGO "
    "WHERE O.EMPCODIGO = :EMPCODIGO AND O.ORCCONTADOR = :ORCCONTADOR"
)
_SQL_CAB_FALLBACK = (
    "SELECT O.ORCNUMERO, O.ORCEMISSAO, O.PESNOME, O.ORCTOTALLIQUIDO, O.ORCDATAENTREGA, "
    "O.ORCPRAZOVALIDADE, O.USUCODIGO FROM ORCAMENTO O "
    "WHERE O.EMPCODIGO = :EMPCODIGO AND O.ORCCONTADOR = :ORCCONTADOR"
)


def carregar_cabecalho(ctx, alias: str, emp: int, orc: int) -> Optional[Dict[str, Any]]:
    p = {"EMPCODIGO": emp, "ORCCONTADOR": orc}
    try:
        r = ctx.query(alias, _SQL_CAB, p).first()
    except Exception:  # noqa: BLE001
        r = ctx.query(alias, _SQL_CAB_FALLBACK, p).first()
    if not r:
        return None
    usuario = fmt.texto(r.get("USUARIO_NOME")) or nome_usuario(ctx, alias, emp, fmt.to_int(r.get("USUCODIGO")))
    obs = observacao_documento(ctx, alias, r, ["ORCOBSERVACAO", "ORCOBS", "OBSERVACAO", "OBS"],
                               "ORCAMENTO", "ORCCONTADOR", emp, orc)
    return {
        "numero": fmt.texto(r.get("ORCNUMERO")),
        "emissao": fmt.data(r.get("ORCEMISSAO")),
        "cliente": fmt.texto(r.get("PESNOME")),
        "vencimento": vencimento_30_dias(r.get("ORCEMISSAO")),
        "valor_total": fmt.moeda(r.get("ORCTOTALLIQUIDO")),
        "usuario": usuario,
        "observacao": obs,
    }
