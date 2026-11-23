"""Estruturas declarativas dos modulos de consulta (equivalente a UfrmConsultaBase + UMapa*)."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional, Tuple

from app.util import fmt

# tipos de coluna -> formatador
KIND_FORMATTERS: Dict[str, Callable[[Any], str]] = {
    "text": fmt.texto,
    "int": lambda v: "" if v is None else str(v),
    "money": fmt.moeda,
    "qty": fmt.quantidade,
    "num": fmt.numero,
    "date": fmt.data,
    "datetime": fmt.data_hora,
    "cpfcnpj": fmt.cpf_cnpj,
    "doc": fmt.documento,
    "phone": fmt.telefone,
    "cep": fmt.cep,
    "yesno": fmt.sim_nao,
}
RIGHT_ALIGNED = {"money", "qty", "num", "int"}


@dataclass
class ColumnSpec:
    key: str
    title: str
    kind: str = "text"
    width: int = 0  # 0 = automatico
    formatter: Optional[Callable[[Any], str]] = None
    hidden: bool = False

    def format(self, value: Any) -> str:
        if value is None:
            return ""
        f = self.formatter or KIND_FORMATTERS.get(self.kind, fmt.texto)
        try:
            return f(value)
        except Exception:  # noqa: BLE001
            return str(value)


# --- filtros ---------------------------------------------------------------
@dataclass
class ChoiceFilter:
    """Grupo de opcoes exclusivas (botoes de radio)."""

    key: str
    label: str
    options: List[Tuple[str, Any]]  # (rotulo, valor)
    default: Any = None


@dataclass
class TextFilter:
    key: str
    label: str
    width: int = 120


@dataclass
class SituacaoNotaFilter:
    """Checkboxes Todas/Transmitidas/Canceladas/Inutilizadas (UFiltroSituacaoNotaFiscal).

    Valor: lista com subconjunto de 'transmitidas', 'canceladas', 'inutilizadas' (vazia = todas).
    """

    key: str = "situacao"
    label: str = "Situação"


@dataclass
class PeriodFilter:
    """Periodo De/Ate com checkbox de ativacao. Valor: None ou (date, date)."""

    key: str
    label: str
    active_by_default: bool = False


@dataclass
class ModuleSpec:
    key: str
    title: str  # titulo da janela
    tile_title: str
    hint: str
    icon: str  # arquivo em assets/icons
    search_label: str
    columns: List[ColumnSpec]
    # (conexao, filtros) -> (sql, params); filtros inclui a chave 'text'
    build: Callable[[Any, Dict[str, Any]], Tuple[str, Dict[str, Any]]]
    # (contexto, linha) -> DetailData | None
    detail: Optional[Callable[[Any, Dict[str, Any]], Any]] = None
    filters: List[Any] = field(default_factory=list)
    row_color: Optional[Callable[[Dict[str, Any]], Optional[str]]] = None
    # botoes extras do rodape: (rotulo, funcao(contexto, linha), habilitado(linha))
    actions: List[Tuple[str, Callable[[Any, Dict[str, Any]], None], Optional[Callable[[Dict[str, Any]], bool]]]] = field(
        default_factory=list
    )
    default_sort: Optional[str] = None
    search_on_open: bool = True
    wide: bool = False


@dataclass
class DetailSection:
    title: str
    columns: List[ColumnSpec]
    rows: List[Dict[str, Any]]


@dataclass
class DetailData:
    title: str
    fields: List[Tuple[str, str]] = field(default_factory=list)
    memos: List[Tuple[str, str]] = field(default_factory=list)
    sections: List[DetailSection] = field(default_factory=list)
    # (rotulo, funcao() -> None, habilitado)
    actions: List[Tuple[str, Callable[[], None], bool]] = field(default_factory=list)
    columns: int = 2


class Ctx:
    """Contexto entregue as funcoes de detalhe/acao."""

    def __init__(self, manager, window=None):
        self.manager = manager
        self.window = window

    def query(self, alias: str, sql: str, params: Optional[Dict[str, Any]] = None, max_rows: Optional[int] = None):
        return self.manager.query_one(alias, sql, params, max_rows)

    def conn(self, alias: str):
        return self.manager.connection(alias)
