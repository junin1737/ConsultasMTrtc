"""SQL/regras de Contas a Receber e Boleto (port de UMapaReceber.pas + UBoletoImpressao.pas)."""
from __future__ import annotations

import datetime as _dt
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

from app.maps import pessoas
from app.util import fmt

SITUACAO_RECEBER = {0: "Em aberto", 1: "Recebido", 2: "Cancelado"}
SITUACAO_BOLETO = {0: "Em aberto", 1: "Liquidado", 2: "Cancelado"}


def descricao_situacao_receber(v: Any) -> str:
    return SITUACAO_RECEBER.get(fmt.to_int(v, -1), "" if v is None else str(v))


def descricao_situacao_boleto(v: Any) -> str:
    return SITUACAO_BOLETO.get(fmt.to_int(v, -1), "" if v is None else str(v))


# --- lista ---------------------------------------------------------------------
def _cond_situacao(f: str) -> str:
    return {
        "recebidas": "CR.CRSITUACAO = 1",
        "aberto": "(CR.CRSITUACAO = 0 AND CR.CRVALORABERTO > 0)",
        "atrasadas": "(CR.CRSITUACAO = 0 AND CR.CRVALORABERTO > 0 AND CR.CRDTVENCTO < CURRENT_DATE)",
    }.get(f or "", "")


def _cond_boleto(f: str) -> str:
    if f == "com":
        return ("EXISTS (SELECT 1 FROM CRBOLETO CB "
                "WHERE CB.EMPCODIGO = CR.EMPCODIGO AND CB.CRNUMERO = CR.CRNUMERO)")
    if f == "sem":
        return ("NOT EXISTS (SELECT 1 FROM CRBOLETO CB "
                "WHERE CB.EMPCODIGO = CR.EMPCODIGO AND CB.CRNUMERO = CR.CRNUMERO)")
    return ""


def cond_periodo(campo: str, p_ini: str, p_fim: str, periodo, params: Dict[str, Any]) -> str:
    """periodo = None | (date, date)  (MontarCondicaoPeriodo)."""
    if not periodo:
        return ""
    params[p_ini], params[p_fim] = periodo
    return f"CAST({campo} AS DATE) BETWEEN :{p_ini} AND :{p_fim}"


def sql_lista(f: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
    params: Dict[str, Any] = {}
    conds: List[str] = []
    conds.append(_cond_situacao(f.get("situacao", "")))
    conds.append(_cond_boleto(f.get("boleto", "")))

    texto = (f.get("text") or "").strip()
    if texto:
        if fmt.so_digitos(texto):
            conds.append("CR.CRNUMERO = :DOCNUMERO")
            params["DOCNUMERO"] = int(texto)
        else:
            conds.append(
                "(COALESCE(NULLIF(TRIM(P.PESNOME), ''), NULLIF(TRIM(PC.PCDESCRICAO), '')) "
                "CONTAINING :FILTRO_TEXTO OR CR.CRDOCUMENTO CONTAINING :FILTRO_TEXTO)")
            params["FILTRO_TEXTO"] = texto

    cod = (f.get("codigo_cliente") or "").strip()
    if cod:
        conds.append("COALESCE(C.CLICODIGO, CR.PCCODIGO) = :CODIGO_CLIENTE")
        params["CODIGO_CLIENTE"] = fmt.to_int(cod)

    nosso = (f.get("nosso_numero") or "").strip()
    if nosso:
        conds.append(
            "EXISTS (SELECT 1 FROM CRBOLETO CB "
            "JOIN BOLETO B ON B.EMPCODIGO = CB.EMPCODIGO AND B.BOLCONTADOR = CB.BOLCONTADOR "
            "WHERE CB.EMPCODIGO = CR.EMPCODIGO AND CB.CRNUMERO = CR.CRNUMERO "
            "AND B.BOLNOSSONUMERO CONTAINING :NOSSO_NUMERO)")
        params["NOSSO_NUMERO"] = nosso

    conds.append(cond_periodo("CR.CRDTEMISSAO", "EMI_INICIO", "EMI_FIM", f.get("emissao"), params))
    conds.append(cond_periodo("CR.CRDTVENCTO", "VEN_INICIO", "VEN_FIM", f.get("vencimento"), params))
    conds.append(cond_periodo("CR.CRDTRECEBIMENTO", "REC_INICIO", "REC_FIM", f.get("recebimento"), params))
    conds = [c for c in conds if c]
    where = ("WHERE " + " AND ".join(conds)) if conds else ""

    sql = (
        "SELECT FIRST 2000 "
        "CR.EMPCODIGO, CR.CRNUMERO, "
        "REPLACE(CAST(CR.CRDOCUMENTO AS VARCHAR(40) CHARACTER SET WIN1252), '/', '-') AS CRDOCUMENTO, "
        "CR.CRDTEMISSAO, CR.CRDTVENCTO, CR.CRDTRECEBIMENTO, "
        "COALESCE(C.CLICODIGO, CR.PCCODIGO) AS CODIGO_CLIENTE, "
        "CAST(TRIM(COALESCE(NULLIF(TRIM(P.PESNOME), ''), NULLIF(TRIM(PC.PCDESCRICAO), ''), '')) "
        "AS VARCHAR(250) CHARACTER SET WIN1252) AS NOME_PESSOA, "
        "CAST(TRIM(COALESCE(P.PESCNPJCPF, '')) AS VARCHAR(20) CHARACTER SET WIN1252) AS CPF_CNPJ, "
        "CR.CRVALOR, CR.CRVALORRECEBIDO, CR.CRVALORABERTO, CR.CRSITUACAO, "
        "CASE WHEN EXISTS (SELECT 1 FROM CRBOLETO CB "
        "WHERE CB.EMPCODIGO = CR.EMPCODIGO AND CB.CRNUMERO = CR.CRNUMERO) "
        "THEN 1 ELSE 0 END AS TEM_BOLETO "
        "FROM CONTASRECEBER CR "
        "LEFT JOIN PESSOA P ON P.PESCODIGO = CR.PCCODIGO "
        "LEFT JOIN CLIENTE C ON C.PESCODIGO = P.PESCODIGO AND C.EMPCODIGO = CR.EMPCODIGO "
        "LEFT JOIN PLANOCONTAS PC ON PC.PCCODIGO = CR.PCCODIGO AND PC.EMPCODIGO = CR.EMPCODIGO "
        f"{where} "
        "ORDER BY CR.CRDTVENCTO DESC, CR.CRNUMERO DESC"
    )
    return sql, params


def cor_linha(row: Dict[str, Any]) -> Optional[str]:
    sit = fmt.to_int(row.get("CRSITUACAO"), -1)
    if sit == 1:
        return "#008800"
    if sit == 2:
        return "#888888"
    if sit == 0:
        if fmt.to_float(row.get("CRVALORABERTO")) <= 0:
            return "#008800"
        v = fmt.as_date(row.get("CRDTVENCTO"))
        if v and v < _dt.date.today():
            return "#cc0000"
    return None


# --- detalhe -------------------------------------------------------------------
def tem_boleto(ctx, alias: str, emp: int, cr: int) -> bool:
    r = ctx.query(alias, "SELECT FIRST 1 1 AS TEM FROM CRBOLETO CB "
                         "WHERE CB.EMPCODIGO = :EMPCODIGO AND CB.CRNUMERO = :CRNUMERO",
                  {"EMPCODIGO": emp, "CRNUMERO": cr})
    return bool(r.rows)


def carregar_boletos(ctx, alias: str, emp: int, cr: int) -> List[Dict[str, Any]]:
    r = ctx.query(
        alias,
        "SELECT B.BOLCONTADOR, B.BOLNOSSONUMERO, B.BOLNUMERO, B.BOLVENCIMENTO, B.BOLVALOR, "
        "B.BOLSITUACAO, B.BOLDATAPAGAMENTO, B.BOLNUMERODOCUMENTO, B.BOLLINHADIGITAVEL, "
        "B.BOLCODBARRAS, B.BOLOBSERVACAO "
        "FROM CRBOLETO CB "
        "JOIN BOLETO B ON B.EMPCODIGO = CB.EMPCODIGO AND B.BOLCONTADOR = CB.BOLCONTADOR "
        "WHERE CB.EMPCODIGO = :EMPCODIGO AND CB.CRNUMERO = :CRNUMERO "
        "ORDER BY B.BOLVENCIMENTO DESC, B.BOLCONTADOR DESC",
        {"EMPCODIGO": emp, "CRNUMERO": cr})
    out = r.dicts()
    for d in out:
        d["SITUACAO_TXT"] = descricao_situacao_boleto(d.get("BOLSITUACAO"))
    return out


def carregar_detalhe(ctx, alias: str, emp: int, cr: int) -> Optional[Dict[str, Any]]:
    r = ctx.query(
        alias,
        "SELECT FIRST 1 CR.*, "
        "CAST(TRIM(COALESCE(NULLIF(TRIM(P.PESNOME), ''), NULLIF(TRIM(PC.PCDESCRICAO), ''), '')) "
        "AS VARCHAR(250) CHARACTER SET WIN1252) AS PESNOME "
        "FROM CONTASRECEBER CR "
        "LEFT JOIN PESSOA P ON P.PESCODIGO = CR.PCCODIGO "
        "LEFT JOIN PLANOCONTAS PC ON PC.PCCODIGO = CR.PCCODIGO AND PC.EMPCODIGO = CR.EMPCODIGO "
        "WHERE CR.EMPCODIGO = :EMPCODIGO AND CR.CRNUMERO = :CRNUMERO",
        {"EMPCODIGO": emp, "CRNUMERO": cr})
    return r.first()


# --- dados para impressao do boleto ------------------------------------------------
@dataclass
class BoletoDados:
    documento: str = ""
    sacado: str = ""
    sacado_cpf_cnpj: str = ""
    sacado_endereco: str = ""
    cedente: str = ""
    cedente_cnpj: str = ""
    cedente_endereco: str = ""
    banco_codigo: str = ""
    banco_codigo_exibicao: str = ""
    banco_nome: str = ""
    agencia: str = ""
    conta: str = ""
    agencia_codigo_beneficiario: str = ""
    carteira: str = ""
    codigo_cedente: str = ""
    nosso_numero: str = ""
    numero_documento: str = ""
    numero_boleto: str = ""
    emissao: str = ""
    vencimento: str = ""
    data_processamento: str = ""
    valor: str = ""
    valor_numerico: float = 0.0
    local_pagamento: str = ""
    instrucao1: str = ""
    instrucao2: str = ""
    linha_digitavel: str = ""
    codigo_barras: str = ""
    observacao: str = ""
    situacao: str = ""
    especie_moeda: str = "R$"
    especie_doc: str = "DM"
    aceite: str = "N"


def montar_endereco(logradouro, numero, bairro, cidade, uf, cep) -> str:
    partes = []
    logradouro, numero, bairro = (logradouro or "").strip(), (numero or "").strip(), (bairro or "").strip()
    cidade, uf, cep = (cidade or "").strip(), (uf or "").strip(), (cep or "").strip()
    if logradouro:
        partes.append(f"{logradouro}, {numero}" if numero else logradouro)
    if bairro:
        partes.append(bairro)
    if cidade:
        partes.append(f"{cidade}/{uf}" if uf else cidade)
    if cep:
        partes.append("CEP: " + fmt.cep(cep))
    return " - ".join(partes)


def linha_digitavel_exibicao(linha: str) -> str:
    d = fmt.digitos(linha)
    if len(d) < 47:
        return (linha or "").strip()
    return f"{d[0:5]}.{d[5:10]} {d[10:15]}.{d[15:21]} {d[21:26]}.{d[26:32]} {d[32:33]} {d[33:47]}"


def linha_digitavel_para_codigo_barras(linha: str) -> str:
    d = fmt.digitos(linha)
    if len(d) != 47:
        return ""
    return d[0:4] + d[32:33] + d[33:47] + d[4:9] + d[10:20] + d[21:31]


def codigo_banco_exibicao(codigo_banco: str, linha: str) -> str:
    d = fmt.digitos(linha)
    if len(d) >= 4:
        return f"{d[0:3]}-{d[3:4]}"
    cod = fmt.digitos(codigo_banco)
    if len(cod) >= 3:
        return f"{cod[0:3]}-0"
    return f"{cod}-0" if cod else ""


def agencia_codigo_beneficiario(agencia: str, conta: str, cod_cedente: str) -> str:
    r = (agencia or "").strip()
    if cod_cedente:
        return f"{r} / {cod_cedente}" if r else cod_cedente
    if conta:
        return f"{r} / {conta}" if r else conta
    return r


def _expr_campo(campos: List[str], alias: str, nomes: List[str], alias_sql: str) -> str:
    for n in nomes:
        if n in campos:
            return f"{alias}.{n} AS {alias_sql}"
    return f"CAST(NULL AS VARCHAR(120) CHARACTER SET WIN1252) AS {alias_sql}"


def carregar_dados_boleto(ctx, alias: str, emp: int, bol_contador: int) -> BoletoDados:
    campos = ctx.conn(alias).table_columns("PESSOA")
    cpf_nomes = ["PESCNPJCPF", "CNPJ_CPF", "CPF_CNPJ"]
    sql = (
        "SELECT FIRST 1 "
        "CR.CRDOCUMENTO, CR.PCCODIGO, B.BOLCONTADOR, B.BOLNOSSONUMERO, B.BOLNUMERO, B.BOLVENCIMENTO, "
        "B.BOLVALOR, B.BOLDATA, "
        "B.BOLLINHADIGITAVEL, B.BOLCODBARRAS, B.BOLNUMERODOCUMENTO, B.BOLSITUACAO, B.BOLOBSERVACAO, "
        "CART.CARTLOCALPAGAMENTO, CART.CARTINSTRUCAO1, CART.CARTINSTRUCAO2, CART.CARTCODIGOCEDENTE, CART.CARTNUMERO, "
        "CBAN.CBAGENCIA, CBAN.CBCONTA, BN.BANCOCODIGO, BN.BANCODESCRICAO, "
        "SAC.PCDESCRICAO AS SACADO, "
        + _expr_campo(campos, "SAC_P", cpf_nomes, "SACADO_CPF") + ", "
        "COALESCE(SAC_P.PESCODIGO, C.PESCODIGO) AS SACADO_PESCODIGO, "
        "CED.PESNOME AS CEDENTE, "
        + _expr_campo(campos, "CED", cpf_nomes, "CEDENTE_CNPJ") + ", "
        "CED.PESCODIGO AS CEDENTE_PESCODIGO "
        "FROM BOLETO B "
        "JOIN CRBOLETO CB ON CB.EMPCODIGO = B.EMPCODIGO AND CB.BOLCONTADOR = B.BOLCONTADOR "
        "JOIN CONTASRECEBER CR ON CR.EMPCODIGO = CB.EMPCODIGO AND CR.CRNUMERO = CB.CRNUMERO "
        "JOIN CARTEIRA CART ON CART.EMPCODIGO = CB.EMPCODIGO AND CART.CONTCCODIGO = CB.CONTCCODIGO "
        "AND CART.CARTCODIGO = CB.CARTCODIGO "
        "LEFT JOIN CONTABANCARIA CBAN ON CBAN.EMPCODIGO = CB.EMPCODIGO AND CBAN.CONTCCODIGO = CB.CONTCCODIGO "
        "LEFT JOIN BANCO BN ON BN.BANCOCODIGO = CBAN.BANCOCODIGO "
        "LEFT JOIN PLANOCONTAS SAC ON SAC.EMPCODIGO = CR.EMPCODIGO AND SAC.PCCODIGO = CR.PCCODIGO "
        "LEFT JOIN PESSOA SAC_P ON SAC_P.PESCODIGO = CR.PCCODIGO "
        "LEFT JOIN CLIENTE C ON C.EMPCODIGO = CR.EMPCODIGO AND C.CLICODIGO = CR.PCCODIGO "
        "LEFT JOIN EMPRESAPESSOA EP ON EP.EMPCODIGO = CR.EMPCODIGO "
        "LEFT JOIN PESSOA CED ON CED.PESCODIGO = EP.PESCODIGO "
        "WHERE B.EMPCODIGO = :EMPCODIGO AND B.BOLCONTADOR = :BOLCONTADOR"
    )
    r = ctx.query(alias, sql, {"EMPCODIGO": emp, "BOLCONTADOR": bol_contador}).first()
    d = BoletoDados()
    if not r:
        return d
    t = fmt.texto
    d.documento = fmt.documento(t(r.get("CRDOCUMENTO")))
    d.sacado = t(r.get("SACADO"))
    d.sacado_cpf_cnpj = fmt.cpf_cnpj(t(r.get("SACADO_CPF")))
    try:
        e = pessoas.carregar_endereco(ctx, alias, emp, fmt.to_int(r.get("SACADO_PESCODIGO")))
        d.sacado_endereco = montar_endereco(e.logradouro, e.numero, e.bairro, e.cidade, e.uf, e.cep)
    except Exception:  # noqa: BLE001
        pass
    d.cedente = t(r.get("CEDENTE"))
    d.cedente_cnpj = fmt.cpf_cnpj(t(r.get("CEDENTE_CNPJ")))
    try:
        e = pessoas.carregar_endereco(ctx, alias, emp, fmt.to_int(r.get("CEDENTE_PESCODIGO")))
        d.cedente_endereco = montar_endereco(e.logradouro, e.numero, e.bairro, e.cidade, e.uf, e.cep)
    except Exception:  # noqa: BLE001
        pass
    d.banco_codigo = t(r.get("BANCOCODIGO"))
    d.banco_nome = t(r.get("BANCODESCRICAO"))
    d.agencia = t(r.get("CBAGENCIA"))
    d.conta = t(r.get("CBCONTA"))
    d.carteira = t(r.get("CARTNUMERO"))
    d.codigo_cedente = t(r.get("CARTCODIGOCEDENTE"))
    d.agencia_codigo_beneficiario = agencia_codigo_beneficiario(d.agencia, d.conta, d.codigo_cedente)
    d.nosso_numero = t(r.get("BOLNOSSONUMERO"))
    d.numero_documento = t(r.get("BOLNUMERODOCUMENTO")) or d.documento
    d.numero_boleto = t(r.get("BOLNUMERO"))
    d.emissao = fmt.data(r.get("BOLDATA"))
    d.vencimento = fmt.data(r.get("BOLVENCIMENTO"))
    d.data_processamento = d.emissao
    d.valor_numerico = fmt.to_float(r.get("BOLVALOR"))
    d.valor = fmt.moeda(d.valor_numerico)
    d.local_pagamento = t(r.get("CARTLOCALPAGAMENTO")) or "Pagável em qualquer agência bancária até o vencimento"
    d.instrucao1 = t(r.get("CARTINSTRUCAO1"))
    d.instrucao2 = t(r.get("CARTINSTRUCAO2"))
    d.linha_digitavel = t(r.get("BOLLINHADIGITAVEL"))
    d.codigo_barras = t(r.get("BOLCODBARRAS")) or linha_digitavel_para_codigo_barras(d.linha_digitavel)
    d.observacao = t(r.get("BOLOBSERVACAO"))
    d.situacao = descricao_situacao_boleto(r.get("BOLSITUACAO"))
    d.banco_codigo_exibicao = codigo_banco_exibicao(d.banco_codigo, d.linha_digitavel)
    return d


def carregar_dados_titulo(ctx, alias: str, emp: int, cr: int) -> List[BoletoDados]:
    boletos = carregar_boletos(ctx, alias, emp, cr)
    if not boletos:
        raise ValueError("Nenhum boleto encontrado para este título.")
    dados = [carregar_dados_boleto(ctx, alias, emp, fmt.to_int(b["BOLCONTADOR"])) for b in boletos]
    if not dados:
        raise ValueError("Não foi possível carregar os dados do boleto.")
    return dados
