"""Formatadores (port de UFormatacaoMoeda.pas)."""
from __future__ import annotations

import datetime as _dt
from decimal import Decimal
from typing import Any, Optional


def to_float(v: Any) -> float:
    if v is None or v == "":
        return 0.0
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def _br_number(value: float, decimals: int) -> str:
    s = f"{value:,.{decimals}f}"
    return s.replace(",", "X").replace(".", ",").replace("X", ".")


def moeda(v: Any) -> str:
    if v is None or v == "":
        return ""
    return "R$ " + _br_number(to_float(v), 2)


def quantidade(v: Any) -> str:
    if v is None or v == "":
        return ""
    s = _br_number(to_float(v), 3)
    if "," in s:
        s = s.rstrip("0").rstrip(",")
    return s


def numero(v: Any, casas: int = 2) -> str:
    if v is None or v == "":
        return ""
    return _br_number(to_float(v), casas)


def digitos(texto: Any) -> str:
    return "".join(c for c in str(texto or "") if c.isdigit())


def cpf_cnpj(v: Any) -> str:
    if v is None:
        return ""
    d = digitos(v)
    if len(d) == 11:
        return f"{d[0:3]}.{d[3:6]}.{d[6:9]}-{d[9:11]}"
    if len(d) == 14:
        return f"{d[0:2]}.{d[2:5]}.{d[5:8]}/{d[8:12]}-{d[12:14]}"
    return str(v).strip()


def telefone(v: Any) -> str:
    if v is None:
        return ""
    d = digitos(v)
    if len(d) == 10:
        return f"({d[0:2]}) {d[2:6]}-{d[6:10]}"
    if len(d) == 11:
        return f"({d[0:2]}) {d[2:7]}-{d[7:11]}"
    return str(v).strip()


def cep(v: Any) -> str:
    if v is None:
        return ""
    d = digitos(v)
    if len(d) == 8:
        return f"{d[0:5]}-{d[5:8]}"
    return str(v).strip()


def documento(v: Any) -> str:
    """Equivalente a FormatarDocumentoConsulta ('/' -> '-')."""
    return str(v or "").strip().replace("/", "-")


def data(v: Any) -> str:
    if v is None or v == "":
        return ""
    if isinstance(v, _dt.datetime):
        return v.strftime("%d/%m/%Y")
    if isinstance(v, _dt.date):
        return v.strftime("%d/%m/%Y")
    return str(v)


def data_hora(v: Any) -> str:
    if v is None or v == "":
        return ""
    if isinstance(v, _dt.datetime):
        return v.strftime("%d/%m/%Y %H:%M")
    return data(v)


def texto(v: Any) -> str:
    if v is None:
        return ""
    if isinstance(v, bytes):
        return v.decode("latin-1", errors="replace").strip()
    if isinstance(v, (Decimal, float)):
        return str(v)
    return str(v).strip()


def sim_nao(v: Any) -> str:
    if v is None or v == "":
        return ""
    return "Sim" if str(v).strip() in ("1", "S", "s", "True", "true") else "Não"


def so_digitos(txt: str) -> bool:
    return bool(txt) and txt.isdigit()


def to_int(v: Any, default: int = 0) -> int:
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


def as_date(v: Any) -> Optional[_dt.date]:
    if isinstance(v, _dt.datetime):
        return v.date()
    if isinstance(v, _dt.date):
        return v
    return None
