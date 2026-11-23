"""Abre PDFs no visualizador padrao do sistema."""
from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import time


def temp_pdf_path(prefix: str) -> str:
    folder = os.path.join(tempfile.gettempdir(), "consultas_py")
    os.makedirs(folder, exist_ok=True)
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", prefix)[:60] or "doc"
    return os.path.join(folder, f"{safe}_{int(time.time() * 1000)}.pdf")


def open_file(path: str) -> None:
    if sys.platform == "win32":
        os.startfile(path)  # type: ignore[attr-defined]  # noqa: S606
    elif sys.platform == "darwin":
        subprocess.Popen(["open", path])  # noqa: S603,S607
    else:
        subprocess.Popen(["xdg-open", path])  # noqa: S603,S607
