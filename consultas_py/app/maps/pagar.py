"""Contas a Pagar (port de UMapaPagar.pas)."""
from __future__ import annotations

import datetime as _dt
from typing import Any, Dict, Optional, Tuple

from app.maps.common import Where
from app.util import fmt

SITUACAO_PAGAR = {0: "Em aberto", 1: "Pago", 2: "Cancelado"}


def descricao_situacao(v: Any) -> str:
    return SITUACAO_PAGAR.get(fmt.to_int(v, -1), "" if v is None else str(v))


def _cond_situacao(f: str) -> str:
    return {
        "pagas": "CP.CPSITUACAO = 1",
        "aberto": "(CP.CPSITUACAO = 0 AND CP.CPVALORABERTO > 0)",
        "atrasadas": "(CP.CPSITUACAO = 0 AND CP.CPVALORABERTO > 0 AND CP.CPDTVENCTO < CURRENT_DATE)",
    }.get(f or "", "")


def sql_lista(f: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
    params: Dict[str, Any] = {}
    w = Where()
    w.add(_cond_situacao(f.get("situacao", "")))
    texto = (f.get("text") or "").strip()
    if texto:
        if fmt.so_digitos(texto):
            w.add("CP.CPNUMERO = :DOCNUMERO")
            params["DOCNUMERO"] = int(texto)
        else:
            w.add("(COALESCE(NULLIF(TRIM(P.PESNOME), ''), NULLIF(TRIM(PC.PCDESCRICAO), '')) "
                  "CONTAINING :FILTRO_TEXTO OR CP.CPDOCUMENTO CONTAINING :FILTRO_TEXTO)")
            params["FILTRO_TEXTO"] = texto
    sql = (
        "SELECT FIRST 2000 CP.EMPCODIGO, CP.CPNUMERO, "
        "REPLACE(CAST(CP.CPDOCUMENTO AS VARCHAR(40) CHARACTER SET WIN1252), '/', '-') AS CPDOCUMENTO, "
        "CP.CPDTEMISSAO, CP.CPDTVENCTO, CP.CPDTPAGTO, "
        "CAST(TRIM(COALESCE(NULLIF(TRIM(P.PESNOME), ''), NULLIF(TRIM(PC.PCDESCRICAO), ''), '')) "
        "AS VARCHAR(250) CHARACTER SET WIN1252) AS NOME_PESSOA, "
        "CP.CPVALOR, CP.CPVALORPAGO, CP.CPVALORABERTO, CP.CPSITUACAO "
        "FROM CONTASPAGAR CP "
        "LEFT JOIN PESSOA P ON P.PESCODIGO = CP.PCCODIGO "
        "LEFT JOIN PLANOCONTAS PC ON PC.PCCODIGO = CP.PCCODIGO AND PC.EMPCODIGO = CP.EMPCODIGO "
        + w.sql() + " ORDER BY CP.CPDTVENCTO DESC, CP.CPNUMERO DESC"
    )
    return sql, params


def cor_linha(row: Dict[str, Any]) -> Optional[str]:
    sit = fmt.to_int(row.get("CPSITUACAO"), -1)
    if sit == 1:
        return "#008800"
    if sit == 2:
        return "#888888"
    if sit == 0:
        if fmt.to_float(row.get("CPVALORABERTO")) <= 0:
            return "#008800"
        v = fmt.as_date(row.get("CPDTVENCTO"))
        if v and v < _dt.date.today():
            return "#cc0000"
    return None


def carregar_detalhe(ctx, alias: str, emp: int, cp: int) -> Optional[Dict[str, Any]]:
    return ctx.query(
        alias,
        "SELECT FIRST 1 CP.*, "
        "CAST(TRIM(COALESCE(NULLIF(TRIM(P.PESNOME), ''), NULLIF(TRIM(PC.PCDESCRICAO), ''), '')) "
        "AS VARCHAR(250) CHARACTER SET WIN1252) AS PESNOME "
        "FROM CONTASPAGAR CP "
        "LEFT JOIN PESSOA P ON P.PESCODIGO = CP.PCCODIGO "
        "LEFT JOIN PLANOCONTAS PC ON PC.PCCODIGO = CP.PCCODIGO AND PC.EMPCODIGO = CP.EMPCODIGO "
        "WHERE CP.EMPCODIGO = :EMPCODIGO AND CP.CPNUMERO = :CPNUMERO",
        {"EMPCODIGO": emp, "CPNUMERO": cp}).first()
