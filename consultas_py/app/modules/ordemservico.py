"""Modulo Ordens de Servico (O.S.): lista multi-base, detalhe e PDF-resumo."""
from __future__ import annotations

from typing import Any, Dict, List

from app.docs.resumo_pdf import acao_imprimir
from app.maps import ordemservico as mp
from app.modules.spec import (
    ChoiceFilter, ColumnSpec, Ctx, DetailData, DetailSection, ModuleSpec, PeriodFilter, TextFilter,
)
from app.util import fmt


def _build(conn, f: Dict[str, Any]):
    return mp.sql_lista(f)


def _rows(ctx: Ctx, alias: str, sql: str, p: Dict[str, Any]) -> List[Dict[str, Any]]:
    try:
        return ctx.query(alias, sql, p).dicts()
    except Exception:  # noqa: BLE001  (tabelas opcionais podem nao existir em bases antigas)
        return []


def _detail(ctx: Ctx, row: Dict[str, Any]):
    alias, emp, oc = row["Base"], fmt.to_int(row["EMPCODIGO"]), fmt.to_int(row["OSCONTADOR"])
    d = mp.carregar_cabecalho(ctx, alias, emp, oc)
    if not d:
        return None
    conn = ctx.conn(alias)
    p = {"EMPCODIGO": emp, "OSCONTADOR": oc}
    numero = fmt.texto(d.get("OSNUMERO"))

    hora = fmt.texto(d.get("OSHORA"))[:5]
    fields = [
        ("Número O.S.", numero),
        ("Situação", mp.descricao_situacao(d.get("OSSITUACAO"))),
        ("Emissão", (fmt.data(d.get("OSEMISSAO")) + (" " + hora if hora else "")).strip()),
        ("Previsão de entrega", fmt.data(d.get("OSPREVISAOENTREGA"))),
        ("Cliente", fmt.texto(d.get("CLIENTE_NOME"))),
        ("Fechamento", fmt.data(d.get("OSDATAFECHAMENTO"))),
        ("Tipo", fmt.texto(d.get("OSTIPODESCRICAO"))),
        ("Estágio", fmt.texto(d.get("OSESTDESCRICAO"))),
        ("Responsável", fmt.texto(d.get("FUNCIONARIO_NOME"))),
        ("Usuário", fmt.texto(d.get("USUARIO_NOME"))),
        ("Forma de pagamento", fmt.texto(d.get("FORPAGDESCRICAO"))),
        ("Total peças", fmt.moeda(d.get("OSVALORPECAS"))),
        ("Total serviços", fmt.moeda(d.get("OSVALORSERVICOS"))),
        ("Desconto", fmt.moeda(d.get("OSDESCONTO"))),
        ("Total", fmt.moeda(d.get("OSTOTAL"))),
        ("Total líquido", fmt.moeda(d.get("OSLIQUIDO"))),
    ]
    seg = _rows(ctx, alias, mp.SQL_SEGURADORA, p)
    if seg:
        fields.append(("Sinistro", fmt.texto(seg[0].get("OSSEGNUMEROSINISTRO"))))
        fields.append(("Seguradora", fmt.texto(seg[0].get("SEGURADORA"))))

    data = DetailData(
        title="Detalhes - Ordem de Serviço",
        fields=fields,
        memos=[
            ("Defeito reclamado", fmt.texto(d.get("OSDEFEITORECLAMADO"))),
            ("Defeito identificado", fmt.texto(d.get("OSDEFEITOIDENTIFICADO"))),
            ("Observação", fmt.texto(d.get("OSOBSERVACAO"))),
            ("Informações adicionais", fmt.texto(d.get("OSINFORMACOESADICIONAIS"))),
        ],
    )

    def sec(titulo: str, cols: List[ColumnSpec], rows: List[Dict[str, Any]]) -> None:
        if rows:
            data.sections.append(DetailSection(titulo, cols, rows))

    sec("Equipamentos / Veículos", [
        ColumnSpec("OSEQUIPDESCRICAO", "Descrição", "text", 300),
        ColumnSpec("OSEQUIPIDENTIFICACAO", "Identificação", "text", 160),
        ColumnSpec("OSTIPEQUIPDESCRICAO", "Tipo", "text", 140),
        ColumnSpec("PLACA", "Placa", "text", 90),
    ], _rows(ctx, alias, mp.SQL_EQUIPAMENTOS, p))
    sec("Serviços", [
        ColumnSpec("OSSERVCONTADOR", "Item", "int", 50),
        ColumnSpec("CODIGO_ITEM", "Código", "text", 100),
        ColumnSpec("SERVDESCRICAO", "Descrição", "text", 300),
        ColumnSpec("FUNCIONARIO", "Executante", "text", 140),
        ColumnSpec("OSSERVQUANTIDADE", "Qtde", "qty", 70),
        ColumnSpec("OSSERVUNITARIO", "Vl. unitário", "money", 95),
        ColumnSpec("OSSERVDESCONTO", "Desconto", "money", 85),
        ColumnSpec("OSSERVLIQUIDO", "Total", "money", 100),
    ], _rows(ctx, alias, mp.sql_servicos(conn), p))
    sec("Peças / Produtos", [
        ColumnSpec("OSPRODCONTADOR", "Item", "int", 50),
        ColumnSpec("CODIGO_ITEM", "Código", "text", 100),
        ColumnSpec("PRODDESCRICAO", "Descrição", "text", 340),
        ColumnSpec("OSPRODQUANTIDADE", "Qtde", "qty", 70),
        ColumnSpec("OSPRODUNITARIO", "Vl. unitário", "money", 95),
        ColumnSpec("OSPRODDESCONTO", "Desconto", "money", 85),
        ColumnSpec("OSPRODLIQUIDO", "Total", "money", 100),
    ], _rows(ctx, alias, mp.sql_produtos(conn), p))
    sec("DAVs vinculados", [
        ColumnSpec("DAVNUMERO", "Número DAV", "int", 110),
        ColumnSpec("DAVEMISSAO", "Emissão", "date", 100),
        ColumnSpec("DAVTOTALLIQUIDO", "Valor total", "money", 120),
    ], _rows(ctx, alias, mp.SQL_DAVS, p))
    sec("Histórico de estágios", [
        ColumnSpec("OSESTHISTDATA", "Data", "date", 90),
        ColumnSpec("OSESTHISTHORA", "Hora", "text", 60),
        ColumnSpec("OSESTDESCRICAO", "Estágio", "text", 180),
        ColumnSpec("PESNOME", "Responsável", "text", 180),
        ColumnSpec("OSESTHISTOBS", "Observação", "text", 300),
    ], _rows(ctx, alias, mp.SQL_HISTORICO, p))

    data.actions.append(acao_imprimir(data, f"os_{alias}_{numero}", f"Ordem de Serviço {numero}"))
    return data


SPEC = ModuleSpec(
    key="os",
    title="Ordens de Serviço",
    tile_title="Ordens de Serviço",
    hint="Ordens de serviço (O.S.)",
    icon="OS.png",
    search_label="Pesquisar por número, cliente, equipamento ou defeito (Enter pesquisa):",
    columns=[
        ColumnSpec("EMPCODIGO", "Empresa", "int", hidden=True),
        ColumnSpec("OSCONTADOR", "Contador", "int", hidden=True),
        ColumnSpec("OSSITUACAO", "Situação", "int", hidden=True),
        ColumnSpec("OSNUMERO", "Número", "int", 80),
        ColumnSpec("OSEMISSAO", "Emissão", "date", 90),
        ColumnSpec("OSPREVISAOENTREGA", "Previsão", "date", 90),
        ColumnSpec("OSDATAFECHAMENTO", "Fechamento", "date", 90),
        ColumnSpec("CODIGO_CLIENTE", "Código", "int", 70),
        ColumnSpec("NOME_CLIENTE", "Cliente", "text", 260),
        ColumnSpec("TIPO_OS", "Tipo", "text", 130),
        ColumnSpec("ESTAGIO", "Estágio", "text", 130),
        ColumnSpec("OSTOTAL", "Total", "money", 105),
        ColumnSpec("OSDESCONTO", "Desconto", "money", 95),
        ColumnSpec("OSLIQUIDO", "Líquido", "money", 105),
    ],
    build=_build,
    detail=_detail,
    filters=[
        ChoiceFilter("situacao", "Situação",
                     [("Todas", ""), ("Abertas", "0"), ("Finalizadas", "1"), ("Canceladas", "2")], ""),
        TextFilter("codigo_cliente", "Código cliente", 90),
        PeriodFilter("emissao", "Emissão"),
        PeriodFilter("previsao", "Previsão entrega"),
    ],
    row_color=mp.cor_linha,
    wide=True,
)
