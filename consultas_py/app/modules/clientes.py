"""Modulo Clientes (UfrmClientes.pas + UfrmPessoaDetalhe.pas)."""
from __future__ import annotations

from typing import Any, Dict

from app.maps import pessoas
from app.modules.spec import ColumnSpec, DetailData, ModuleSpec


def _build(conn, filters: Dict[str, Any]):
    return pessoas.sql_lista(filters.get("text", ""))


def _detail(ctx, row: Dict[str, Any]):
    d = pessoas.carregar_detalhe(ctx, row["Base"], row["PESCODIGO"])
    if not d.encontrado:
        return None
    return DetailData(
        title="Detalhes - Clientes",
        fields=[
            ("Código", d.codigo),
            ("Nome", d.nome),
            ("CPF/CNPJ", d.cpf_cnpj),
            ("Inscrição estadual", d.ie),
            ("Endereço", d.endereco),
            ("Número", d.numero),
            ("Complemento", d.complemento),
            ("Bairro", d.bairro),
            ("Cidade", d.cidade),
            ("UF", d.uf),
            ("CEP", d.cep),
            ("Telefone", d.telefone),
            ("Celular", d.celular),
        ],
    )


SPEC = ModuleSpec(
    key="clientes",
    title="Clientes",
    tile_title="Clientes",
    hint="Consulta de clientes",
    icon="Clientes.png",
    search_label="Pesquisar em Clientes (Enter pesquisa; duplo clique abre detalhes):",
    columns=[
        ColumnSpec("PESCODIGO", "Código", "int", 80),
        ColumnSpec("PESNOME", "Nome", "text", 380),
        ColumnSpec("PESCNPJCPF", "CPF/CNPJ", "cpfcnpj", 150),
        ColumnSpec("PESIE", "Inscrição estadual", "text", 150),
    ],
    build=_build,
    detail=_detail,
)
