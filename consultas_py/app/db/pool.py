"""ConnectionManager: conecta 1..N bases e executa a mesma consulta em cada uma."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable, Dict, List, Optional, Tuple

from app.config import BaseConfig
from app.db.connection import DbError, FirebirdConnection, QueryResult

BASE_COL = "Base"


@dataclass
class MergedResult:
    """Resultado unificado; a primeira coluna e sempre ``Base``."""

    columns: List[str] = field(default_factory=list)  # sem a coluna Base
    rows: List[Tuple[Any, ...]] = field(default_factory=list)  # (base, *valores)
    warnings: List[str] = field(default_factory=list)

    def dicts(self) -> List[Dict[str, Any]]:
        cols = [BASE_COL] + self.columns
        return [dict(zip(cols, r)) for r in self.rows]


class ConnectionManager:
    def __init__(self) -> None:
        self._conns: Dict[str, FirebirdConnection] = {}
        self.errors: Dict[str, str] = {}

    # --- estado -------------------------------------------------------
    @property
    def aliases(self) -> List[str]:
        return [a for a, c in self._conns.items() if c.connected]

    def connection(self, alias: str) -> Optional[FirebirdConnection]:
        return self._conns.get(alias)

    def connections(self) -> List[FirebirdConnection]:
        return [c for c in self._conns.values() if c.connected]

    def is_connected(self) -> bool:
        return bool(self.aliases)

    def status(self) -> Dict[str, bool]:
        return {a: c.connected for a, c in self._conns.items()}

    # --- conexao ------------------------------------------------------
    def connect_all(self, bases: List[BaseConfig],
                    progress: Optional[Callable[[str], None]] = None) -> Dict[str, str]:
        """Desconecta tudo e conecta as bases informadas.

        Falha em uma base nao derruba as demais. Retorna {alias: erro}.
        """
        self.disconnect_all()
        self.errors = {}
        for cfg in bases:
            conn = FirebirdConnection(cfg)
            if progress:
                progress(f"Conectando {conn.alias}...")
            try:
                conn.connect()
                self._conns[conn.alias] = conn
            except DbError as exc:
                self.errors[conn.alias] = str(exc)
            except Exception as exc:  # noqa: BLE001
                self.errors[conn.alias] = str(exc)
        return dict(self.errors)

    def disconnect_all(self) -> None:
        for c in self._conns.values():
            c.close()
        self._conns.clear()

    # --- consultas ----------------------------------------------------
    def query_one(self, alias: str, sql: str, params: Optional[Dict[str, Any]] = None,
                  max_rows: Optional[int] = None) -> QueryResult:
        conn = self._conns.get(alias)
        if conn is None:
            raise DbError(f"Base '{alias}' nao esta conectada.")
        return conn.query(sql, params, max_rows)

    def query_all(self, builder: Callable[[FirebirdConnection], Tuple[str, Dict[str, Any]]],
                  max_rows: Optional[int] = None) -> MergedResult:
        """Executa ``builder(conn) -> (sql, params)`` em cada base ativa e une os resultados."""
        merged = MergedResult()
        for conn in self.connections():
            try:
                sql, params = builder(conn)
                r = conn.query(sql, params, max_rows)
            except Exception as exc:  # noqa: BLE001
                merged.warnings.append(f"{conn.alias}: {exc}")
                continue
            if not merged.columns:
                merged.columns = list(r.columns)
            for row in r.rows:
                merged.rows.append((conn.alias,) + tuple(row))
        return merged
