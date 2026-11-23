"""Conexao com uma base Firebird (firebird-driver) + deteccao automatica de cliente/porta."""
from __future__ import annotations

import re
import threading
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Sequence, Tuple

from app.config import BaseConfig, FB_PORTA_PADRAO
from app.db import detect_fb

_client_lib_loaded: Optional[str] = None
_client_lock = threading.Lock()


class DbError(Exception):
    """Erro de conexao/consulta com mensagem amigavel."""


@dataclass
class QueryResult:
    columns: List[str] = field(default_factory=list)
    rows: List[Tuple[Any, ...]] = field(default_factory=list)

    def dicts(self) -> List[Dict[str, Any]]:
        return [dict(zip(self.columns, r)) for r in self.rows]

    def first(self) -> Optional[Dict[str, Any]]:
        if not self.rows:
            return None
        return dict(zip(self.columns, self.rows[0]))


_PARAM_RE = re.compile(r"'(?:[^']|'')*'|:([A-Za-z_][A-Za-z0-9_]*)")


def named_to_positional(sql: str, params: Optional[Dict[str, Any]]) -> Tuple[str, List[Any]]:
    """Converte ``:NOME`` em ``?`` (ordem de aparicao), ignorando literais entre aspas."""
    params = {k.upper(): v for k, v in (params or {}).items()}
    values: List[Any] = []

    def repl(m: "re.Match[str]") -> str:
        name = m.group(1)
        if name is None:
            return m.group(0)
        key = name.upper()
        if key not in params:
            raise DbError(f"Parametro nao informado: {name}")
        values.append(params[key])
        return "?"

    return _PARAM_RE.sub(repl, sql), values


def _configure_client(path: str) -> None:
    """A biblioteca cliente e carregada uma vez por processo."""
    global _client_lib_loaded
    from firebird.driver import driver_config

    with _client_lock:
        if _client_lib_loaded is not None:
            return
        if path:
            driver_config.fb_client_library.value = path
        _client_lib_loaded = path or ""


def client_library_loaded() -> Optional[str]:
    return _client_lib_loaded


class FirebirdConnection:
    """Uma conexao ativa (uma base)."""

    def __init__(self, cfg: BaseConfig):
        self.cfg = cfg
        self._con = None
        self._lock = threading.RLock()
        self.port_used = ""
        self.client_used = ""

    # ------------------------------------------------------------------
    @property
    def alias(self) -> str:
        return self.cfg.label()

    @property
    def connected(self) -> bool:
        return self._con is not None and not self._con.is_closed()

    def _candidate_ports(self, servicos) -> List[str]:
        if self.cfg.port.strip():
            return [self.cfg.port.strip()]
        ports: List[str] = []
        pref = detect_fb.detectar_servico_preferido(servicos)
        if pref:
            ports.append(pref.porta)
        for s in servicos:
            if s.porta not in ports:
                ports.append(s.porta)
        if FB_PORTA_PADRAO not in ports:
            ports.append(FB_PORTA_PADRAO)
        return ports

    def connect(self) -> None:
        """Conecta; sem porta configurada tenta a(s) porta(s) detectada(s)."""
        from firebird.driver import connect as fb_connect
        from firebird.driver import DatabaseError

        if self.connected:
            return
        if not self.cfg.database.strip():
            raise DbError("Caminho do banco (.fdb) nao informado.")

        servicos = detect_fb.detectar_servicos_firebird()
        ports = self._candidate_ports(servicos)
        lib = detect_fb.resolver_cliente_fb(self.cfg.client_library, servicos, ports[0] if ports else "")
        if _client_lib_loaded is None:
            _configure_client(lib)
        self.client_used = _client_lib_loaded or lib

        server = self.cfg.effective_server()
        last_err = ""
        for port in ports:
            dsn = f"{server}/{port}:{self.cfg.database.strip()}"
            try:
                self._con = fb_connect(
                    dsn,
                    user=self.cfg.user or "SYSDBA",
                    password=self.cfg.password,
                    charset=self.cfg.effective_charset(),
                )
                self.port_used = port
                return
            except (DatabaseError, Exception) as exc:  # noqa: BLE001
                last_err = str(exc)
        raise DbError(
            f"Nao foi possivel conectar a '{self.alias}' ({self.cfg.database}):\n{last_err}\n\n"
            "Confirme: servico Firebird em execucao, porta, caminho do .fdb e usuario/senha."
        )

    def close(self) -> None:
        with self._lock:
            if self._con is not None:
                try:
                    self._con.close()
                except Exception:  # noqa: BLE001
                    pass
                self._con = None

    # ------------------------------------------------------------------
    def query(self, sql: str, params: Optional[Dict[str, Any]] = None,
              max_rows: Optional[int] = None) -> QueryResult:
        if not self.connected:
            raise DbError(f"Base '{self.alias}' nao conectada.")
        text, values = named_to_positional(sql, params)
        with self._lock:
            cur = self._con.cursor()
            try:
                cur.execute(text, values)
                cols = [(d[0] or "").strip() for d in cur.description or []]
                rows = cur.fetchmany(max_rows) if max_rows else cur.fetchall()
                result = QueryResult(cols, [tuple(r) for r in rows])
            except Exception as exc:  # noqa: BLE001
                raise DbError(f"[{self.alias}] {exc}") from exc
            finally:
                try:
                    cur.close()
                except Exception:  # noqa: BLE001
                    pass
            try:
                self._con.commit()
            except Exception:  # noqa: BLE001
                pass
            return result

    def test(self) -> str:
        """Conecta, le versao do servidor e fecha. Retorna texto informativo."""
        self.connect()
        try:
            r = self.query("SELECT RDB$GET_CONTEXT('SYSTEM','ENGINE_VERSION') AS V FROM RDB$DATABASE")
            ver = r.rows[0][0] if r.rows else "?"
            return f"Conectado (Firebird {ver}, porta {self.port_used})."
        finally:
            self.close()

    def table_columns(self, table: str) -> List[str]:
        r = self.query(
            "SELECT TRIM(R.RDB$FIELD_NAME) AS CAMPO FROM RDB$RELATION_FIELDS R "
            "WHERE R.RDB$RELATION_NAME = :T ORDER BY R.RDB$FIELD_POSITION",
            {"T": table.upper()},
        )
        return [str(row[0]).strip().upper() for row in r.rows]
