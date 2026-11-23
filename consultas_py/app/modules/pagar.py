"""Modulo Contas a Pagar (UfrmPagar.pas / UfrmPagarDetalhe.pas)."""
from __future__ import annotations

from typing import Any, Dict

from app.maps import pagar as mp
from app.modules.spec import ChoiceFilter, ColumnSpec, Ctx, DetailData, ModuleSpec
from app.util import fmt


def _build(conn, f: Dict[str, Any]):
    return mp.sql_lista(f)


def _detail(ctx: Ctx, row: Dict[str, Any]):
    d = mp.carregar_detalhe(ctx, row["Base"], fmt.to_int(row["EMPCODIGO"]), fmt.to_int(row["CPNUMERO"]))
    if not d:
        return None
    return DetailData(
        title="Detalhes - Contas a Pagar",
        fields=[
            ("Documento", fmt.documento(fmt.texto(d.get("CPDOCUMENTO")))),
            ("Fornecedor", fmt.texto(d.get("PESNOME"))),
            ("Emissão", fmt.data(d.get("CPDTEMISSAO"))),
            ("Vencimento", fmt.data(d.get("CPDTVENCTO"))),
            ("Pagamento", fmt.data(d.get("CPDTPAGTO"))),
            ("Situação", mp.descricao_situacao(d.get("CPSITUACAO"))),
            ("Valor", fmt.moeda(d.get("CPVALOR"))),
            ("Valor pago", fmt.moeda(d.get("CPVALORPAGO"))),
            ("Valor em aberto", fmt.moeda(d.get("CPVALORABERTO"))),
        ],
        memos=[("Observação", fmt.texto(d.get("CPOBSERVACAO")))],
    )


SPEC = ModuleSpec(
    key="pagar",
    title="Contas a Pagar",
    tile_title="Pagar",
    hint="Contas a pagar",
    icon="Pagar.png",
    search_label="Pesquisar por número, documento ou fornecedor (Enter pesquisa):",
    columns=[
        ColumnSpec("EMPCODIGO", "Empresa", "int", hidden=True),
        ColumnSpec("CPNUMERO", "Número", "int", 80),
        ColumnSpec("CPDOCUMENTO", "Documento", "doc", 110),
        ColumnSpec("CPDTEMISSAO", "Emissão", "date", 90),
        ColumnSpec("CPDTVENCTO", "Vencimento", "date", 90),
        ColumnSpec("CPDTPAGTO", "Pagamento", "date", 90),
        ColumnSpec("NOME_PESSOA", "Fornecedor", "text", 300),
        ColumnSpec("CPVALOR", "Valor", "money", 110),
        ColumnSpec("CPVALORPAGO", "Valor pago", "money", 110),
        ColumnSpec("CPVALORABERTO", "Restante", "money", 110),
        ColumnSpec("CPSITUACAO", "Situação", "int", 90, formatter=mp.descricao_situacao),
    ],
    build=_build,
    detail=_detail,
    filters=[ChoiceFilter("situacao", "Situação",
                          [("Todas", ""), ("Pagas", "pagas"), ("Em aberto", "aberto"), ("Atrasadas", "atrasadas")], "")],
    row_color=mp.cor_linha,
)
