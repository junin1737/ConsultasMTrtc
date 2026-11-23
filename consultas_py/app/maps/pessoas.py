"""SQL/regras de Pessoas (port de UMapaPessoas.pas) - mapa de campos por base."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from app.util import fmt

_MAPAS: Dict[str, "MapaPessoa"] = {}


@dataclass
class MapaPessoa:
    chave: str = ""
    nome: str = ""
    cpf_cnpj: str = ""
    rg: str = ""
    ie: str = ""
    endereco: str = ""
    numero: str = ""
    bairro: str = ""
    cidade: str = ""
    uf: str = ""
    cep: str = ""
    telefone: str = ""
    celular: str = ""
    fax: str = ""
    email: str = ""
    limite: str = ""
    obs: str = ""


@dataclass
class Endereco:
    logradouro: str = ""
    numero: str = ""
    complemento: str = ""
    bairro: str = ""
    cidade: str = ""
    uf: str = ""
    cep: str = ""


@dataclass
class DetalhePessoa:
    codigo: str = ""
    nome: str = ""
    cpf_cnpj: str = ""
    ie: str = ""
    endereco: str = ""
    numero: str = ""
    complemento: str = ""
    bairro: str = ""
    cidade: str = ""
    uf: str = ""
    cep: str = ""
    telefone: str = ""
    celular: str = ""
    encontrado: bool = False


def _detectar(campos: List[str]) -> MapaPessoa:
    m = MapaPessoa()

    def contem(nome: str, lista) -> bool:
        return nome in [x.upper() for x in lista]

    for nome in campos:
        if not m.chave and (nome == "CODIGO" or "CODIGO" in nome):
            m.chave = nome
        if not m.nome and "NOME" in nome and "FANTASIA" not in nome:
            m.nome = nome
        if not m.cpf_cnpj and contem(nome, ["PESCNPJCPF", "CNPJ_CPF", "CPF_CNPJ", "CGC", "CNPJ", "CPF"]):
            m.cpf_cnpj = nome
        if not m.rg and contem(nome, ["RG", "PES_RG", "DOC_RG"]):
            m.rg = nome
        if not m.ie and contem(nome, ["INSCRICAO_ESTADUAL", "IE", "PES_IE", "INSC_ESTADUAL", "INSC_EST"]):
            m.ie = nome
        if not m.endereco and contem(nome, ["PESENDERECO", "ENDERECO", "ENDER", "LOGRADOURO", "RUA", "PES_ENDERECO"]):
            m.endereco = nome
        if not m.numero and contem(nome, ["PESNUMERO", "NUMERO", "NUM", "NRO", "NUM_END"]):
            m.numero = nome
        if not m.bairro and contem(nome, ["PESBAIRRO", "BAIRRO", "PES_BAIRRO"]):
            m.bairro = nome
        if not m.cidade and contem(nome, ["PESCIDADE", "CIDADE", "MUNICIPIO", "PES_CIDADE"]):
            m.cidade = nome
        if not m.uf and contem(nome, ["PESUF", "UF", "ESTADO", "PES_UF"]):
            m.uf = nome
        if not m.cep and contem(nome, ["PESCEP", "CEP", "PES_CEP"]):
            m.cep = nome
        if not m.telefone and contem(nome, ["PESFONE", "PESTELEFONE", "TELEFONE", "FONE", "TEL", "FONE1", "PES_FONE"]):
            m.telefone = nome
        if not m.celular and contem(nome, ["PESCELULAR", "CELULAR", "CEL", "FONE2", "PES_CELULAR"]):
            m.celular = nome
        if not m.fax and contem(nome, ["FAX", "PES_FAX"]):
            m.fax = nome
        if not m.email and contem(nome, ["EMAIL", "E_MAIL", "PES_EMAIL"]):
            m.email = nome
        if not m.limite and "LIMITE" in nome and "CRED" in nome:
            m.limite = nome
        if not m.obs and contem(nome, ["OBSERVACAO", "OBSERVACOES", "OBS", "PES_OBS", "OBSERV"]):
            m.obs = nome

    # campos padrao Realtec tem prioridade
    for attr, campo in (("chave", "PESCODIGO"), ("nome", "PESNOME"), ("cpf_cnpj", "PESCNPJCPF"), ("ie", "PESIE"),
                        ("telefone", "PESFONE"), ("celular", "PESCELULAR"), ("endereco", "PESENDERECO"),
                        ("numero", "PESNUMERO"), ("bairro", "PESBAIRRO"), ("cidade", "PESCIDADE"),
                        ("uf", "PESUF"), ("cep", "PESCEP")):
        if campo in campos:
            setattr(m, attr, campo)

    if not m.chave and campos:
        m.chave = campos[0]
    if not m.nome:
        for c in campos:
            if c in ("RAZAO_SOCIAL", "PES_NOME", "NOME"):
                m.nome = c
                break
    if not m.limite:
        for c in campos:
            if "LIMITE" in c or ("CRED" in c and "LIM" in c):
                m.limite = c
                break
    return m


def mapa(conn) -> MapaPessoa:
    key = conn.alias
    m = _MAPAS.get(key)
    if m is None:
        m = _detectar(conn.table_columns("PESSOA"))
        _MAPAS[key] = m
    return m


def limpar_cache() -> None:
    _MAPAS.clear()


# --- lista -------------------------------------------------------------------
def sql_lista(filtro: str):
    sql = "SELECT FIRST 2000 PESCODIGO, PESNOME, PESCNPJCPF, PESIE FROM PESSOA"
    params: Dict[str, Any] = {}
    if filtro:
        sql += " WHERE PESNOME CONTAINING :FILTRO"
        params["FILTRO"] = filtro
    sql += " ORDER BY PESNOME"
    return sql, params


# --- detalhe -------------------------------------------------------------------
_SQL_END = (
    "SELECT FIRST 1 "
    "L.LOGRLOGRADOURO, PE.PESENDNUMERO, PE.PESENDCOMPLEMENTO, "
    "B.BAIBAIRRO, M.MUNMUNICIPIO, M.MUNUF, PE.PESENDCEP "
    "FROM PESSOAENDERECO PE "
    "LEFT JOIN LOGRADOURO L ON L.LOGRCODIGO = PE.LOGRCODIGO "
    "LEFT JOIN BAIRRO B ON B.BAICODIGO = PE.BAICODIGO "
    "LEFT JOIN MUNICIPIO M ON M.MUNCODIGO = PE.MUNCODIGO "
    "WHERE PE.PESCODIGO = :PESCODIGO "
    "AND COALESCE(PE.PESENDATIVO, 1) = 1 "
    "{emp}"
    "ORDER BY PE.PESENDCONTADOR"
)


def carregar_endereco(ctx, alias: str, emp_codigo: int, pes_codigo: int) -> Endereco:
    e = Endereco()
    if pes_codigo <= 0:
        return e

    def preencher(r: Dict[str, Any]) -> Endereco:
        return Endereco(
            logradouro=fmt.texto(r.get("LOGRLOGRADOURO")),
            numero=fmt.texto(r.get("PESENDNUMERO")),
            complemento=fmt.texto(r.get("PESENDCOMPLEMENTO")),
            bairro=fmt.texto(r.get("BAIBAIRRO")),
            cidade=fmt.texto(r.get("MUNMUNICIPIO")),
            uf=fmt.texto(r.get("MUNUF")),
            cep=fmt.cep(fmt.texto(r.get("PESENDCEP"))),
        )

    if emp_codigo > 0:
        r = ctx.query(alias, _SQL_END.format(emp="AND PE.EMPCODIGO = :EMPCODIGO "),
                      {"PESCODIGO": pes_codigo, "EMPCODIGO": emp_codigo}).first()
        if r:
            return preencher(r)
    r = ctx.query(alias, _SQL_END.format(emp=""), {"PESCODIGO": pes_codigo}).first()
    return preencher(r) if r else e


def carregar_detalhe(ctx, alias: str, valor_chave: Any, emp_codigo: int = 0) -> DetalhePessoa:
    conn = ctx.conn(alias)
    m = mapa(conn)
    campos: List[str] = []
    for c in (m.chave, m.nome, m.cpf_cnpj, m.ie, m.telefone, m.celular, "EMPCODIGO"):
        if c and c.upper() not in [x.upper() for x in campos]:
            campos.append(c)
    # EMPCODIGO so se existir na tabela
    existentes = conn.table_columns("PESSOA")
    campos = [c for c in campos if c.upper() in existentes]
    sql = f"SELECT FIRST 1 {', '.join(campos)} FROM PESSOA WHERE {m.chave} = :CHAVE"
    r = ctx.query(alias, sql, {"CHAVE": valor_chave}).first()
    d = DetalhePessoa()
    if not r:
        return d

    def val(campo: str) -> str:
        return fmt.texto(r.get(campo.upper())) if campo else ""

    d.encontrado = True
    d.codigo = val(m.chave)
    d.nome = val(m.nome)
    d.cpf_cnpj = fmt.cpf_cnpj(val(m.cpf_cnpj))
    d.ie = val(m.ie)
    d.telefone = fmt.telefone(val(m.telefone))
    d.celular = fmt.telefone(val(m.celular))
    pes = fmt.to_int(d.codigo)
    emp = emp_codigo or fmt.to_int(val("EMPCODIGO"))
    try:
        end = carregar_endereco(ctx, alias, emp, pes)
    except Exception:  # noqa: BLE001  (tabelas de endereco podem nao existir)
        end = Endereco()
    d.endereco, d.numero, d.complemento = end.logradouro, end.numero, end.complemento
    d.bairro, d.cidade, d.uf, d.cep = end.bairro, end.cidade, end.uf, end.cep
    return d
