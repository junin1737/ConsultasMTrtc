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


def friendly_name(database: str) -> str:
    """Nome curto e amigavel derivado do arquivo (ex.: ``C:\\treicon\\TREICON1.FDB`` -> ``Treicon1``)."""
    stem = os.path.splitext(os.path.basename((database or "").replace("/", os.sep)))[0].strip()
    if not stem:
        return "Base"
    stem = stem.replace("_", " ").replace("-", " ")
    return stem.title() if stem.isupper() or stem.islower() else stem


@dataclass
class BaseConfig:
    """Uma conexao Firebird configurada.

    ``apelido`` e o nome exibido em toda a interface (coluna Base, filtro por base, dialogos) e tambem a
    chave de identificacao da conexao (unica). Persistido no JSON como ``apelido`` (le o legado ``alias``).
    """

    apelido: str = ""
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

    @property
    def alias(self) -> str:
        """Compatibilidade: identificador da conexao == apelido (ou nome amigavel se vazio)."""
        return self.label()

    @alias.setter
    def alias(self, value: str) -> None:
        self.apelido = value

    def label(self) -> str:
        """Texto exibido para a base: apelido ou, se vazio, nome curto derivado do arquivo."""
        return (self.apelido or "").strip() or friendly_name(self.database)


def _default_bases() -> List[BaseConfig]:
    return [
        BaseConfig(apelido="Treicon1", database=r"C:\treicon\TREICON1.FDB"),
        BaseConfig(apelido="Neo", database=r"C:\treicon\NEO.FDB"),
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
        seen_lower = set()
        for b in self.bases:
            b.apelido = (b.apelido or "").strip() or friendly_name(b.database)
            base_alias = b.apelido
            n = 2
            while b.apelido.lower() in seen_lower:
                b.apelido = f"{base_alias} ({n})"
                n += 1
            seen.add(b.apelido)
            seen_lower.add(b.apelido.lower())
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
            kw = {k: str(v) for k, v in raw.items() if k in known}
            if not kw.get("apelido") and raw.get("alias"):  # config antiga usava "alias"
                kw["apelido"] = str(raw["alias"])
            bases.append(BaseConfig(**kw))
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
