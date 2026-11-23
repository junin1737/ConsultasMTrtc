"""Configuracao local (JSON) com modo 'uma base' ou 'varias bases'.

O arquivo ``consultas_config.json`` fica ao lado de ``main.py`` (ou do executavel).
"""
from __future__ import annotations

import json
import os
import sys
from dataclasses import asdict, dataclass, field, fields
from typing import List, Optional

FB_USUARIO_PADRAO = "SYSDBA"
FB_SENHA_PADRAO = "masterkey"
FB_PORTA_PADRAO = "3050"
FB_CHARSET_PADRAO = "WIN1252"
FB_SERVIDOR_LOCAL = "127.0.0.1"

MODO_UMA = "one"
MODO_VARIAS = "multiple"


def is_frozen() -> bool:
    return bool(getattr(sys, "frozen", False))


def app_dir() -> str:
    """Pasta do aplicativo (ao lado do .exe quando congelado, senao raiz do projeto)."""
    if is_frozen():
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def resource_dir() -> str:
    """Pasta com recursos somente-leitura (assets/, dll/).

    Congelado (PyInstaller): ``sys._MEIPASS`` (``_internal`` no modo onedir); senao raiz do projeto.
    """
    if is_frozen():
        return getattr(sys, "_MEIPASS", None) or os.path.dirname(sys.executable)
    return app_dir()


def _dir_gravavel(pasta: str) -> bool:
    try:
        os.makedirs(pasta, exist_ok=True)
        probe = os.path.join(pasta, ".write_test")
        with open(probe, "w", encoding="utf-8") as fh:
            fh.write("x")
        os.remove(probe)
        return True
    except OSError:
        return False


def config_dir() -> str:
    """Pasta do ``consultas_config.json``.

    Em desenvolvimento: raiz do projeto. Congelado: ao lado do .exe se gravavel (instalacao por usuario /
    portatil); caso contrario ``%APPDATA%\\Consultas`` (ex.: instalado em Program Files).
    """
    base = app_dir()
    if not is_frozen() or _dir_gravavel(base):
        return base
    appdata = os.environ.get("APPDATA") or os.path.expanduser("~")
    return os.path.join(appdata, "Consultas")


def config_path() -> str:
    return os.path.join(config_dir(), "consultas_config.json")


@dataclass
class BaseConfig:
    """Uma conexao Firebird configurada."""

    alias: str = ""
    database: str = ""
    server: str = FB_SERVIDOR_LOCAL
    port: str = ""  # vazio = detectar pelo servico Firebird
    user: str = FB_USUARIO_PADRAO
    password: str = FB_SENHA_PADRAO
    charset: str = FB_CHARSET_PADRAO
    client_library: str = ""  # vazio = detectar
    wire_crypt: str = "Disabled"

    def effective_charset(self) -> str:
        c = (self.charset or "").strip()
        if not c or c.upper() == "UTF8":
            return FB_CHARSET_PADRAO
        return c

    def effective_server(self) -> str:
        return (self.server or "").strip() or FB_SERVIDOR_LOCAL

    def label(self) -> str:
        return self.alias or os.path.basename(self.database) or "base"


def _default_bases() -> List[BaseConfig]:
    return [
        BaseConfig(alias="treicon1", database=r"C:\treicon\TREICON1.FDB"),
        BaseConfig(alias="neo", database=r"C:\treicon\NEO.FDB"),
    ]


@dataclass
class AppConfig:
    mode: str = MODO_VARIAS
    bases: List[BaseConfig] = field(default_factory=_default_bases)
    # apelidos selecionados para conectar (modo varias bases)
    selected: List[str] = field(default_factory=list)
    # apelido da base usada no modo 'uma base'
    single: str = ""
    # pergunta ao abrir o app quais bases conectar
    ask_on_start: bool = True

    # ------------------------------------------------------------------
    def base_by_alias(self, alias: str) -> Optional[BaseConfig]:
        for b in self.bases:
            if b.alias == alias:
                return b
        return None

    def active_bases(self) -> List[BaseConfig]:
        """Bases que devem ser conectadas conforme o modo atual."""
        if self.mode == MODO_UMA:
            b = self.base_by_alias(self.single) or (self.bases[0] if self.bases else None)
            return [b] if b else []
        sel = [self.base_by_alias(a) for a in self.selected]
        return [b for b in sel if b]

    def normalize(self) -> None:
        if self.mode not in (MODO_UMA, MODO_VARIAS):
            self.mode = MODO_VARIAS
        seen = set()
        for b in self.bases:
            if not b.alias:
                b.alias = os.path.splitext(os.path.basename(b.database))[0] or "base"
            base_alias = b.alias
            n = 2
            while b.alias in seen:
                b.alias = f"{base_alias}_{n}"
                n += 1
            seen.add(b.alias)
        self.selected = [a for a in self.selected if a in seen]
        if self.single not in seen:
            self.single = self.bases[0].alias if self.bases else ""
        if not self.selected and self.bases:
            self.selected = [b.alias for b in self.bases]

    # ------------------------------------------------------------------
    def to_dict(self) -> dict:
        return {
            "mode": self.mode,
            "selected": list(self.selected),
            "single": self.single,
            "ask_on_start": self.ask_on_start,
            "bases": [asdict(b) for b in self.bases],
        }

    @classmethod
    def from_dict(cls, data: dict) -> "AppConfig":
        known = {f.name for f in fields(BaseConfig)}
        bases = []
        for raw in data.get("bases", []):
            bases.append(BaseConfig(**{k: str(v) for k, v in raw.items() if k in known}))
        cfg = cls(
            mode=data.get("mode", MODO_VARIAS),
            bases=bases,
            selected=list(data.get("selected", [])),
            single=data.get("single", ""),
            ask_on_start=bool(data.get("ask_on_start", True)),
        )
        cfg.normalize()
        return cfg


def load_config(path: Optional[str] = None) -> AppConfig:
    path = path or config_path()
    if os.path.isfile(path):
        try:
            with open(path, "r", encoding="utf-8") as fh:
                return AppConfig.from_dict(json.load(fh))
        except (OSError, ValueError, TypeError):
            pass
    cfg = AppConfig()
    cfg.normalize()
    return cfg


def save_config(cfg: AppConfig, path: Optional[str] = None) -> None:
    cfg.normalize()
    path = path or config_path()
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(cfg.to_dict(), fh, indent=2, ensure_ascii=False)
