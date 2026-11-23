"""DAV (port de UMapaDav.pas + UDavImpressao.CarregarCabecalho)."""
from __future__ import annotations

from typing import Any, Dict, Optional, Tuple

from app.maps.common import (
    Where, cond_periodo, cond_texto_numero, nome_usuario, observacao_documento,
    select_codigo_produto, select_codigo_servico, vencimento_30_dias,
)
from app.util import fmt


def sql_lista(f: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
    params: Dict[str, Any] = {}
    w = Where()
    w.add(cond_texto_numero(f.get("text", ""), "D.DAVNUMERO", "P.PESNOME", params))
    w.add(cond_periodo("D.DAVEMISSAO", "DATA_INICIO", "DATA_FIM", f.get("periodo"), params))
    sql = (
        "SELECT FIRST 2000 "
        "D.EMPCODIGO, D.DAVCONTADOR, D.DAVNUMERO, D.DAVEMISSAO, P.PESNOME AS NOME_CLIENTE, "
        "CASE WHEN D.DAVEMISSAO IS NOT NULL THEN D.DAVEMISSAO + 30 ELSE D.DAVDATAENTREGA END AS DAVDATAENTREGA, "
        "D.DAVTOTALLIQUIDO "
        "FROM DAV D "
        "LEFT JOIN CLIENTE C ON C.CLICODIGO = D.CLICODIGO AND C.EMPCODIGO = D.EMPCODIGO "
        "LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO " + w.sql() +
        " ORDER BY D.DAVEMISSAO DESC, D.DAVNUMERO DESC"
    )
    return sql, params


def sql_produtos(conn) -> str:
    return (
        "SELECT DI.DAVITEMORDEM, " + select_codigo_produto(conn) +
        "P.PRODDESCRICAO, DI.DAVITEMQTDE, DI.DAVITEMUNITARIO, DI.DAVITEMTOTALLIQUIDO "
        "FROM DAVITEM DI "
        "LEFT JOIN PRODUTO P ON P.PRODCONTADOR = DI.PRODCONTADOR AND P.EMPCODIGO = DI.EMPCODIGO "
        "WHERE DI.EMPCODIGO = :EMPCODIGO AND DI.DAVCONTADOR = :DAVCONTADOR ORDER BY DI.DAVITEMORDEM")


def sql_servicos(conn) -> str:
    return (
        "SELECT DS.DAVITEMSERVORDEM, " + select_codigo_servico(conn) +
        "S.SERVDESCRICAO, DS.DAVITEMSERVQTDE, DS.DAVITEMSERVUNITARIO, DS.DAVITEMSERVTOTALLIQUIDO "
        "FROM DAVITEMSERVICO DS "
        "LEFT JOIN SERVICO S ON S.SERVCONTADOR = DS.SERVCONTADOR AND S.EMPCODIGO = DS.EMPCODIGO "
        "WHERE DS.EMPCODIGO = :EMPCODIGO AND DS.DAVCONTADOR = :DAVCONTADOR ORDER BY DS.DAVITEMSERVORDEM")


_SQL_CAB = (
    "SELECT D.*, P.PESNOME, COALESCE(PU.PESNOME, U.USUNOME, U.USULOGIN) AS USUARIO_NOME "
    "FROM DAV D "
    "LEFT JOIN CLIENTE C ON C.CLICODIGO = D.CLICODIGO AND C.EMPCODIGO = D.EMPCODIGO "
    "LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO "
    "LEFT JOIN USUARIO U ON U.USUCODIGO = D.USUCODIGO AND U.EMPCODIGO = D.EMPCODIGO "
    "LEFT JOIN PESSOA PU ON PU.PESCODIGO = U.PESCODIGO "
    "WHERE D.EMPCODIGO = :EMPCODIGO AND D.DAVCONTADOR = :DAVCONTADOR"
)
_SQL_CAB_FALLBACK = (
    "SELECT D.*, P.PESNOME FROM DAV D "
    "LEFT JOIN CLIENTE C ON C.CLICODIGO = D.CLICODIGO AND C.EMPCODIGO = D.EMPCODIGO "
    "LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO "
    "WHERE D.EMPCODIGO = :EMPCODIGO AND D.DAVCONTADOR = :DAVCONTADOR"
)


def carregar_cabecalho(ctx, alias: str, emp: int, dav: int) -> Optional[Dict[str, Any]]:
    p = {"EMPCODIGO": emp, "DAVCONTADOR": dav}
    try:
        r = ctx.query(alias, _SQL_CAB, p).first()
    except Exception:  # noqa: BLE001
        r = ctx.query(alias, _SQL_CAB_FALLBACK, p).first()
    if not r:
        return None
    usuario = fmt.texto(r.get("USUARIO_NOME")) or nome_usuario(ctx, alias, emp, fmt.to_int(r.get("USUCODIGO")))
    obs = observacao_documento(ctx, alias, r, ["DAVOBS", "DAVINFORMACOESADICIONAIS", "DAVOBSERVACAO",
                                               "OBSERVACAO", "OBS"], "DAV", "DAVCONTADOR", emp, dav)
    return {
        "numero": fmt.texto(r.get("DAVNUMERO")),
        "emissao": fmt.data(r.get("DAVEMISSAO")),
        "cliente": fmt.texto(r.get("PESNOME")),
        "vencimento": vencimento_30_dias(r.get("DAVEMISSAO")),
        "valor_total": fmt.moeda(r.get("DAVTOTALLIQUIDO")),
        "usuario": usuario,
        "observacao": obs,
    }
