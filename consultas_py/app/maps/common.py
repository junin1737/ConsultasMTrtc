"""Utilitarios compartilhados pelos mapas SQL (UCampoCodigoItem / UCampoObservacao / filtros)."""
from __future__ import annotations

from typing import Any, Dict, List, Optional, Sequence, Tuple

from app.util import fmt

_CACHE_CODIGO: Dict[Tuple[str, str], str] = {}
_CACHE_OBS: Dict[Tuple[str, str], List[str]] = {}


class Where:
    """TWhereBuilder do Delphi."""

    def __init__(self) -> None:
        self.parts: List[str] = []

    def add(self, cond: str) -> None:
        if cond and cond.strip():
            self.parts.append(cond)

    def sql(self) -> str:
        return ("WHERE " + " AND ".join(self.parts)) if self.parts else ""


def cond_periodo(campo: str, p_ini: str, p_fim: str, periodo, params: Dict[str, Any]) -> str:
    """periodo = None | (date, date)  (MontarCondicaoPeriodo)."""
    if not periodo:
        return ""
    params[p_ini], params[p_fim] = periodo
    return f"CAST({campo} AS DATE) BETWEEN :{p_ini} AND :{p_fim}"


def cond_texto_numero(filtro: str, campo_numero: str, campo_texto: str, params: Dict[str, Any],
                      extra_numero: str = "") -> str:
    """Pesquisa: so digitos -> numero; senao -> CONTAINING no nome."""
    filtro = (filtro or "").strip()
    if not filtro:
        return ""
    if fmt.so_digitos(filtro):
        params["DOCNUMERO"] = int(filtro)
        return f"{campo_numero} = :DOCNUMERO"
    params["FILTRO_TEXTO"] = filtro
    return f"{campo_texto} CONTAINING :FILTRO_TEXTO"


# --- campo de codigo do item (produto/servico) -------------------------------------
def _descobrir_codigo(conn, tabela: str, candidatos: Sequence[str], evitar: Sequence[str]) -> str:
    key = (conn.alias, tabela)
    if key in _CACHE_CODIGO:
        return _CACHE_CODIGO[key]
    campos = conn.table_columns(tabela)
    ev = {e.upper() for e in evitar}
    result = ""
    for c in candidatos:
        c = c.upper()
        if c in campos and c not in ev:
            result = c
            break
    if not result:
        for c in campos:
            if ("COD" in c or "REFER" in c) and c not in ev:
                result = c
                break
    _CACHE_CODIGO[key] = result
    return result


def select_codigo_produto(conn) -> str:
    c = _descobrir_codigo(
        conn, "PRODUTO",
        ["PRODCODIGO", "PRODCOD", "PRODREFERENCIA", "REFERENCIA", "CODPROD", "CODIGO", "COD"],
        ["PRODCONTADOR", "PRODDESCRICAO", "PRODNOME", "EMPCODIGO", "PRODUNIDADE"])
    return f"P.{c} AS CODIGO_ITEM, " if c else ""


def select_codigo_servico(conn) -> str:
    c = _descobrir_codigo(
        conn, "SERVICO", ["SERVCODIGO", "SERVCOD", "CODIGO", "COD", "REFERENCIA"],
        ["SERVCONTADOR", "SERVDESCRICAO", "SERVNOME", "EMPCODIGO"])
    return f"S.{c} AS CODIGO_ITEM, " if c else ""


# --- observacao -----------------------------------------------------------------
def _parece_obs(nome: str) -> bool:
    n = nome.upper().strip()
    if not n:
        return False
    if "OBSERV" in n or n in ("OBS", "OBSERVACAO"):
        return True
    if "INFORMACOESADICIONAIS" in n or "ADICIONAIS" in n:
        return True
    return len(n) > 3 and n.endswith("OBS")


def observacao_documento(ctx, alias: str, row: Optional[Dict[str, Any]], preferidos: Sequence[str],
                         tabela: str, campo_chave: str, emp: int, contador: int) -> str:
    """CarregarObservacaoDocumento: campos preferidos da linha; senao varre campos *OBS* da tabela."""
    if row:
        for n in preferidos:
            v = fmt.texto(row.get(n.upper()))
            if v:
                return v
    conn = ctx.conn(alias)
    key = (alias, tabela.upper())
    campos = _CACHE_OBS.get(key)
    if campos is None:
        campos = [c for c in conn.table_columns(tabela) if _parece_obs(c)]
        _CACHE_OBS[key] = campos
    for c in campos:
        try:
            r = ctx.query(alias, f"SELECT {c} AS OBS FROM {tabela.upper()} "
                                 f"WHERE EMPCODIGO = :EMPCODIGO AND {campo_chave} = :CONTADOR",
                          {"EMPCODIGO": emp, "CONTADOR": contador}).first()
        except Exception:  # noqa: BLE001
            continue
        if r and fmt.texto(r.get("OBS")):
            return fmt.texto(r.get("OBS"))
    return ""


def nome_usuario(ctx, alias: str, emp: int, usu: int) -> str:
    if emp <= 0 or usu <= 0:
        return ""
    # Esquemas variam: USUARIO pode ou nao ter EMPCODIGO/PESCODIGO (ex.: NEO/TREICON1 nao tem).
    tentativas = (
        ("SELECT FIRST 1 COALESCE(P.PESNOME, U.USUNOME, U.USULOGIN) AS NOME "
         "FROM USUARIO U LEFT JOIN PESSOA P ON P.PESCODIGO = U.PESCODIGO "
         "WHERE U.EMPCODIGO = :EMPCODIGO AND U.USUCODIGO = :USUCODIGO",
         {"EMPCODIGO": emp, "USUCODIGO": usu}),
        ("SELECT FIRST 1 COALESCE(U.USUNOME, U.USULOGIN) AS NOME FROM USUARIO U WHERE U.USUCODIGO = :USUCODIGO",
         {"USUCODIGO": usu}),
    )
    for sql, params in tentativas:
        try:
            r = ctx.query(alias, sql, params).first()
        except Exception:  # noqa: BLE001
            continue
        return fmt.texto(r.get("NOME")) if r else ""
    return ""


def soma(rows: List[Dict[str, Any]], campo: str) -> float:
    return sum(fmt.to_float(r.get(campo)) for r in rows)


def vencimento_30_dias(d) -> str:
    import datetime as _dt
    dd = fmt.as_date(d)
    return fmt.data(dd + _dt.timedelta(days=30)) if dd else ""


# --- situacao de notas -----------------------------------------------------------
def select_situacao_nota(campo_doc: str, compra: bool = False) -> str:
    """compra=True: so 'Confirmada' / 'Cancelada' (compras nao sao transmitidas/inutilizadas)."""
    doc = f"TRIM(COALESCE({campo_doc}, ''))"
    if compra:
        return (
            "CAST(CASE "
            f"WHEN {doc} = '02' THEN 'Cancelada' "
            "ELSE 'Confirmada' "
            "END AS VARCHAR(20) CHARACTER SET WIN1252) AS SITUACAO_NOTA")
    return (
        "CAST(CASE "
        f"WHEN {doc} IN ('04', '05') THEN 'Inutilizada' "
        f"WHEN {doc} = '02' THEN 'Cancelada' "
        "ELSE 'Transmitida' "
        "END AS VARCHAR(20) CHARACTER SET WIN1252) AS SITUACAO_NOTA")


def cond_situacao_nota(campo_doc: str, filtro: Optional[Sequence[str]], compra: bool = False) -> str:
    """filtro: None/[] = todas; senao subconjunto de {'transmitidas','canceladas','inutilizadas'}.

    compra=True: 'transmitidas' significa Confirmada (qualquer documento diferente de cancelado).
    """
    if not filtro:
        return ""
    doc = f"TRIM(COALESCE({campo_doc}, ''))"
    partes = []
    if "transmitidas" in filtro:
        partes.append(f"({doc} <> '02')" if compra else f"({doc} NOT IN ('02', '04', '05'))")
    if "canceladas" in filtro:
        partes.append(f"{doc} = '02'")
    if "inutilizadas" in filtro:
        partes.append(f"{doc} IN ('04', '05')")
    return "(" + " OR ".join(partes) + ")" if partes else "1 = 0"


def cor_situacao_nota(row: Dict[str, Any]) -> Optional[str]:
    doc = ""
    for k in ("NFSITUACAODOC", "ENTCSITUACAODOCUMENTO"):
        if row.get(k) is not None:
            doc = fmt.texto(row.get(k))
    if doc in ("04", "05"):
        return "#808080"
    if doc == "02":
        return "#cc0000"
    sit = fmt.texto(row.get("SITUACAO_NOTA"))
    if sit.lower() == "cancelada":
        return "#cc0000"
    if sit.lower() == "inutilizada":
        return "#808080"
    return "#008800"
