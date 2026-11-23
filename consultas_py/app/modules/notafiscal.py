"""Modulo Nota Fiscal de venda: NF-e e NFC-e (UfrmNotaFiscal.pas / UfrmNotaFiscalDetalhe.pas).

Na versao Delphi sao duas abas; aqui um seletor "Tipo" alterna entre NF-e e NFC-e.
"""
from __future__ import annotations

from typing import Any, Dict

from app.docs.resumo_pdf import acao_imprimir
from app.docs.danfe import acao_danfe
from app.maps import notafiscal as mp
from app.maps.common import cor_situacao_nota
from app.modules.helpers import item_columns, itens_section
from app.modules.spec import (
    ChoiceFilter, ColumnSpec, Ctx, DetailData, ModuleSpec, PeriodFilter, SituacaoNotaFilter,
)
from app.util import fmt


def _build(conn, f: Dict[str, Any]):
    if f.get("tipo") == "nfce":
        return mp.sql_lista_nfce(f)
    return mp.sql_lista_nfe(f)


def _detail(ctx: Ctx, row: Dict[str, Any]):
    alias, emp = row["Base"], fmt.to_int(row["EMPCODIGO"])
    nfce = row.get("VENNUMERO") is not None
    conn = ctx.conn(alias)
    if nfce:
        ven, ter, num = fmt.to_int(row["VENNUMERO"]), fmt.to_int(row["TERNUMERO"]), fmt.to_int(row["NFNUMEROFISCAL"])
        cab = mp.carregar_cabecalho_nfce(ctx, alias, emp, ven, ter, num)
        sec_srv, tot_srv = None, 0.0
        sec_prd, tot_prd = itens_section(
            ctx, alias, "Produtos", mp.sql_produtos_nfce(conn),
            {"EMPCODIGO": emp, "VENNUMERO": ven, "TERNUMERO": ter},
            item_columns("NFITEMCONTADOR", "PRODDESCRICAO", "NFITEMQTDE", "NFITEMUNITARIO", "NFITEMTOTALLIQUIDO"),
            "NFITEMTOTALLIQUIDO")
    else:
        nf = fmt.to_int(row["NFCONTADOR"])
        cab = mp.carregar_cabecalho_nfe(ctx, alias, emp, nf)
        p = {"EMPCODIGO": emp, "NFCONTADOR": nf}
        sec_srv, tot_srv = itens_section(
            ctx, alias, "Serviços", mp.sql_servicos_nfe(conn), p,
            item_columns("NFITEMSERVCONTADOR", "SERVDESCRICAO", "NFITEMSERVQTDE", "NFITEMSERVUNITARIO",
                         "NFITEMSERVTOTALLIQUIDO"), "NFITEMSERVTOTALLIQUIDO")
        sec_prd, tot_prd = itens_section(
            ctx, alias, "Produtos", mp.sql_produtos_nfe(conn), p,
            item_columns("NFITEMCONTADOR", "PRODDESCRICAO", "NFITEMQTDE", "NFITEMUNITARIO", "NFITEMTOTALLIQUIDO"),
            "NFITEMTOTALLIQUIDO")
    if not cab:
        return None
    rotulo = "NFC-e" if nfce else "NF-e"
    data = DetailData(
        title=f"Detalhes - {rotulo}",
        fields=[
            (f"Número {rotulo}", cab["numero"]),
            ("Emissão", cab["emissao"]),
            ("Saída/Transmissão", cab["saida"]),
            ("Cliente", cab["cliente"]),
            ("Valor total", cab["valor_total"]),
            ("Situação", fmt.texto(row.get("SITUACAO_NOTA"))),
            ("Total produtos", fmt.moeda(tot_prd)),
            ("Total serviços", fmt.moeda(tot_srv)),
            ("Chave de acesso", cab["chave"]),
        ],
        memos=[("Observação", cab["observacao"])],
    )
    data.sections = [s for s in (sec_prd, sec_srv) if s]
    data.actions.append(acao_imprimir(data, f"{rotulo}_{alias}_{cab['numero']}", f"{rotulo} {cab['numero']}"))
    data.actions.append(acao_danfe(ctx, row, rotulo, cab))
    return data


SPEC = ModuleSpec(
    key="notafiscal",
    title="Notas Fiscais de Venda",
    tile_title="NFe Venda",
    hint="NF-e e NFC-e de venda",
    icon="NotaFiscal.png",
    search_label="Pesquisar por número ou cliente (Enter pesquisa):",
    columns=[
        ColumnSpec("EMPCODIGO", "Empresa", "int", hidden=True),
        ColumnSpec("NFCONTADOR", "Contador", "int", hidden=True),
        ColumnSpec("VENNUMERO", "Venda", "int", hidden=True),
        ColumnSpec("TERNUMERO", "Terminal", "int", hidden=True),
        ColumnSpec("NFNUMEROFISCAL", "Nº fiscal", "int", 90),
        ColumnSpec("DOCFNUMERO", "Documento", "int", 90),
        ColumnSpec("NFDTEMISSAO", "Emissão", "date", 100),
        ColumnSpec("NFDTSAIDA", "Saída", "date", 100),
        ColumnSpec("NOME_CLIENTE", "Cliente", "text", 300),
        ColumnSpec("NFTOTALNOTA", "Valor total", "money", 120),
        ColumnSpec("SITUACAO_NOTA", "Situação", "text", 100),
        ColumnSpec("CHAVE_NFE", "Chave de acesso", "text", 340),
        ColumnSpec("NFSITUACAO", "Sit.", "int", hidden=True),
        ColumnSpec("NFSITUACAODOC", "Sit. doc.", "text", hidden=True),
    ],
    build=_build,
    detail=_detail,
    filters=[
        ChoiceFilter("tipo", "Tipo", [("NF-e", "nfe"), ("NFC-e", "nfce")], "nfe"),
        SituacaoNotaFilter(),
        PeriodFilter("periodo", "Emissão"),
    ],
    row_color=cor_situacao_nota,
    wide=True,
)
