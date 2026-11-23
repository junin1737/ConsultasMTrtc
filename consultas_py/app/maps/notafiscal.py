"""Nota fiscal de venda: NF-e (UMapaNotaFiscal.pas) e NFC-e (UMapaNfce.pas)."""
from __future__ import annotations

from typing import Any, Dict, Optional, Tuple

from app.maps.common import (
    Where, cond_periodo, cond_situacao_nota, select_codigo_produto, select_situacao_nota,
)
from app.util import fmt

NFCE_CONSUMIDOR_FINAL = "Consumidor final"

_NOME_CLIENTE_NFCE = (
    "CAST(CASE "
    "WHEN VC.CLICODIGO IS NULL OR C.PESCODIGO IS NULL OR C.PESCODIGO = 0 THEN 'Consumidor final' "
    "ELSE COALESCE(NULLIF(TRIM(P.PESNOME), ''), 'Consumidor final') END "
    "AS VARCHAR(120) CHARACTER SET WIN1252) AS NOME_CLIENTE"
)


def sql_lista_nfe(f: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
    params: Dict[str, Any] = {}
    w = Where()
    texto = (f.get("text") or "").strip()
    if texto:
        if fmt.so_digitos(texto):
            w.add("N.NFNUMEROFISCAL = :DOCNUMERO")
            params["DOCNUMERO"] = int(texto)
        else:
            w.add("P.PESNOME CONTAINING :FILTRO_TEXTO")
            params["FILTRO_TEXTO"] = texto
    w.add(cond_periodo("COALESCE(N.NFDTEMISSAO, N.NFDTSAIDA)", "DATA_INICIO", "DATA_FIM", f.get("periodo"), params))
    w.add(cond_situacao_nota("N.NFSITUACAODOC", f.get("situacao")))
    sql = (
        "SELECT FIRST 2000 "
        "N.EMPCODIGO, N.NFCONTADOR, CAST(NULL AS INTEGER) AS VENNUMERO, CAST(NULL AS INTEGER) AS TERNUMERO, "
        "N.NFNUMEROFISCAL, N.DOCFNUMERO, "
        "N.NFDTEMISSAO, N.NFDTSAIDA, P.PESNOME AS NOME_CLIENTE, "
        "N.NFTOTALNOTA, N.NFSITUACAO, N.NFSITUACAODOC, NFEN.NFNFECHAVE AS CHAVE_NFE, "
        + select_situacao_nota("N.NFSITUACAODOC") + " "
        "FROM NOTAFISCAL N "
        "LEFT JOIN PESSOA P ON P.PESCODIGO = N.PESCODIGO "
        "LEFT JOIN NOTAFISCALNFE NFEN ON NFEN.EMPCODIGO = N.EMPCODIGO AND NFEN.NFCONTADOR = N.NFCONTADOR "
        + w.sql() + " ORDER BY N.NFDTEMISSAO DESC, N.NFNUMEROFISCAL DESC"
    )
    return sql, params


def sql_lista_nfce(f: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
    params: Dict[str, Any] = {}
    w = Where()
    texto = (f.get("text") or "").strip()
    if texto:
        if fmt.so_digitos(texto):
            w.add("(N.VENRNFCENUMEROFISCAL = :DOCNUMERO OR V.VENNUMEROCUPOM = :DOCNUMERO)")
            params["DOCNUMERO"] = int(texto)
        else:
            w.add("(P.PESNOME CONTAINING :FILTRO_TEXTO OR 'Consumidor final' CONTAINING :FILTRO_TEXTO)")
            params["FILTRO_TEXTO"] = texto
    w.add(cond_periodo("COALESCE(V.VENDTEMISSAO, N.VENRNFCEDTTRANSMISSAO)", "DATA_INICIO", "DATA_FIM",
                       f.get("periodo"), params))
    w.add(cond_situacao_nota("N.VENRNFCESITUACAODOC", f.get("situacao")))
    sql = (
        "SELECT FIRST 2000 "
        "N.EMPCODIGO, N.VENRNFCENUMEROFISCAL AS NFCONTADOR, V.VENNUMERO, V.TERNUMERO, "
        "N.VENRNFCENUMEROFISCAL AS NFNUMEROFISCAL, V.VENNUMEROCUPOM AS DOCFNUMERO, "
        "V.VENDTEMISSAO AS NFDTEMISSAO, N.VENRNFCEDTTRANSMISSAO AS NFDTSAIDA, "
        + _NOME_CLIENTE_NFCE + ", V.VENVALORLIQUIDO AS NFTOTALNOTA, "
        "N.VENRNFCESITUACAO AS NFSITUACAO, N.VENRNFCESITUACAODOC AS NFSITUACAODOC, "
        "N.VENRNFCECHAVE AS CHAVE_NFE, "
        + select_situacao_nota("N.VENRNFCESITUACAODOC") + " "
        "FROM VENDARAPIDANFCE N "
        "JOIN VENDARAPIDA V ON V.EMPCODIGO = N.EMPCODIGO AND V.VENNUMERO = N.VENNUMERO AND V.TERNUMERO = N.TERNUMERO "
        "LEFT JOIN VENDARAPIDACLIENTE VC ON VC.EMPCODIGO = V.EMPCODIGO "
        "AND VC.VENNUMERO = V.VENNUMERO AND VC.TERNUMERO = V.TERNUMERO "
        "LEFT JOIN CLIENTE C ON C.EMPCODIGO = VC.EMPCODIGO AND C.CLICODIGO = VC.CLICODIGO "
        "LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO "
        + w.sql() + " ORDER BY V.VENDTEMISSAO DESC, N.VENRNFCENUMEROFISCAL DESC"
    )
    return sql, params


def sql_produtos_nfe(conn) -> str:
    return (
        "SELECT NI.NFITEMCONTADOR, " + select_codigo_produto(conn) +
        "P.PRODDESCRICAO, NI.NFITEMQTDE, NI.NFITEMUNITARIO, NI.NFITEMTOTALLIQUIDO "
        "FROM NOTAFISCALITEM NI "
        "LEFT JOIN PRODUTO P ON P.PRODCONTADOR = NI.PRODCONTADOR AND P.EMPCODIGO = NI.EMPCODIGO "
        "WHERE NI.EMPCODIGO = :EMPCODIGO AND NI.NFCONTADOR = :NFCONTADOR ORDER BY NI.NFITEMCONTADOR")


def sql_servicos_nfe(conn) -> str:
    from app.maps.common import select_codigo_servico
    return (
        "SELECT NS.NFITEMSERVCONTADOR, " + select_codigo_servico(conn) +
        "S.SERVDESCRICAO, NS.NFITEMSERVQTDE, NS.NFITEMSERVUNITARIO, NS.NFITEMSERVTOTALLIQUIDO "
        "FROM NOTAFISCALITEMSERVICO NS "
        "LEFT JOIN SERVICO S ON S.SERVCONTADOR = NS.SERVCONTADOR AND S.EMPCODIGO = NS.EMPCODIGO "
        "WHERE NS.EMPCODIGO = :EMPCODIGO AND NS.NFCONTADOR = :NFCONTADOR ORDER BY NS.NFITEMSERVCONTADOR")


def sql_produtos_nfce(conn) -> str:
    return (
        "SELECT I.ITEMNUMEROITEM AS NFITEMCONTADOR, " + select_codigo_produto(conn) +
        "P.PRODDESCRICAO, I.ITEMQTDE AS NFITEMQTDE, I.ITEMUNITARIO AS NFITEMUNITARIO, "
        "I.ITEMTOTALLIQUIDO AS NFITEMTOTALLIQUIDO "
        "FROM ITEMVENDARAPIDA I "
        "LEFT JOIN PRODUTO P ON P.PRODCONTADOR = I.PRODCONTADOR AND P.EMPCODIGO = I.EMPCODIGO "
        "WHERE I.EMPCODIGO = :EMPCODIGO AND I.VENNUMERO = :VENNUMERO AND I.TERNUMERO = :TERNUMERO "
        "ORDER BY I.ITEMNUMEROITEM")


def carregar_cabecalho_nfe(ctx, alias: str, emp: int, nf: int) -> Optional[Dict[str, Any]]:
    r = ctx.query(
        alias,
        "SELECT N.NFNUMEROFISCAL, N.NFDTEMISSAO, N.NFDTSAIDA, N.NFTOTALNOTA, N.NFADCIONAIS, P.PESNOME, NFEN.NFNFECHAVE "
        "FROM NOTAFISCAL N LEFT JOIN PESSOA P ON P.PESCODIGO = N.PESCODIGO "
        "LEFT JOIN NOTAFISCALNFE NFEN ON NFEN.EMPCODIGO = N.EMPCODIGO AND NFEN.NFCONTADOR = N.NFCONTADOR "
        "WHERE N.EMPCODIGO = :EMPCODIGO AND N.NFCONTADOR = :NFCONTADOR",
        {"EMPCODIGO": emp, "NFCONTADOR": nf}).first()
    if not r:
        return None
    return {
        "numero": fmt.texto(r.get("NFNUMEROFISCAL")),
        "emissao": fmt.data(r.get("NFDTEMISSAO")),
        "saida": fmt.data(r.get("NFDTSAIDA")),
        "cliente": fmt.texto(r.get("PESNOME")),
        "valor_total": fmt.moeda(r.get("NFTOTALNOTA")),
        "chave": fmt.texto(r.get("NFNFECHAVE")),
        "observacao": fmt.texto(r.get("NFADCIONAIS")),
    }


def carregar_cabecalho_nfce(ctx, alias: str, emp: int, ven: int, ter: int, numero: int) -> Optional[Dict[str, Any]]:
    r = ctx.query(
        alias,
        "SELECT N.VENRNFCENUMEROFISCAL, V.VENDTEMISSAO, N.VENRNFCEDTTRANSMISSAO, V.VENVALORLIQUIDO, "
        "N.VENRNFCEADICIONAIS, " + _NOME_CLIENTE_NFCE + ", N.VENRNFCECHAVE, C.PESCODIGO "
        "FROM VENDARAPIDANFCE N "
        "JOIN VENDARAPIDA V ON V.EMPCODIGO = N.EMPCODIGO AND V.VENNUMERO = N.VENNUMERO AND V.TERNUMERO = N.TERNUMERO "
        "LEFT JOIN VENDARAPIDACLIENTE VC ON VC.EMPCODIGO = V.EMPCODIGO "
        "AND VC.VENNUMERO = V.VENNUMERO AND VC.TERNUMERO = V.TERNUMERO "
        "LEFT JOIN CLIENTE C ON C.EMPCODIGO = VC.EMPCODIGO AND C.CLICODIGO = VC.CLICODIGO "
        "LEFT JOIN PESSOA P ON P.PESCODIGO = C.PESCODIGO "
        "WHERE N.EMPCODIGO = :EMPCODIGO AND N.VENNUMERO = :VENNUMERO AND N.TERNUMERO = :TERNUMERO "
        "AND N.VENRNFCENUMEROFISCAL = :VENRNFCENUMEROFISCAL",
        {"EMPCODIGO": emp, "VENNUMERO": ven, "TERNUMERO": ter, "VENRNFCENUMEROFISCAL": numero}).first()
    if not r:
        return None
    return {
        "numero": fmt.texto(r.get("VENRNFCENUMEROFISCAL")),
        "emissao": fmt.data(r.get("VENDTEMISSAO")),
        "saida": fmt.data(r.get("VENRNFCEDTTRANSMISSAO")),
        "cliente": fmt.texto(r.get("NOME_CLIENTE")) or NFCE_CONSUMIDOR_FINAL,
        "valor_total": fmt.moeda(r.get("VENVALORLIQUIDO")),
        "chave": fmt.texto(r.get("VENRNFCECHAVE")),
        "observacao": fmt.texto(r.get("VENRNFCEADICIONAIS")),
    }
