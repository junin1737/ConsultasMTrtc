"""Execucao de consultas em thread para nao travar a interface."""
from __future__ import annotations

from typing import Any, Callable

from PySide6.QtCore import QThread, Signal


class FuncWorker(QThread):
    done = Signal(object)
    failed = Signal(str)

    def __init__(self, fn: Callable[[], Any], parent=None):
        super().__init__(parent)
        self._fn = fn

    def run(self) -> None:  # noqa: D401
        try:
            self.done.emit(self._fn())
        except Exception as exc:  # noqa: BLE001
            self.failed.emit(str(exc))
