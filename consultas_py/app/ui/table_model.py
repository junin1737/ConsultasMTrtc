"""Modelo de tabela generico com colunas declarativas."""
from __future__ import annotations

import datetime as _dt
from decimal import Decimal
from typing import Any, Callable, Dict, List, Optional

from PySide6.QtCore import QAbstractTableModel, QModelIndex, QSortFilterProxyModel, Qt
from PySide6.QtGui import QBrush, QColor

from app.modules.spec import RIGHT_ALIGNED, ColumnSpec

BASE_KEY = "Base"
BASE_COLUMN = ColumnSpec(BASE_KEY, "Base", "text", 90)


class RowsModel(QAbstractTableModel):
    def __init__(self, columns: List[ColumnSpec], show_base: bool = False,
                 row_color: Optional[Callable[[Dict[str, Any]], Optional[str]]] = None, parent=None):
        super().__init__(parent)
        self._all_columns = list(columns)
        self._show_base = show_base
        self._row_color = row_color
        self._rows: List[Dict[str, Any]] = []
        self._cache: List[List[str]] = []
        self._colors: List[Optional[QBrush]] = []
        self._rebuild_columns()

    def _rebuild_columns(self) -> None:
        cols = [c for c in self._all_columns if not c.hidden]
        if self._show_base:
            cols = [BASE_COLUMN] + cols
        self._cols = cols

    def set_show_base(self, show: bool) -> None:
        self.beginResetModel()
        self._show_base = show
        self._rebuild_columns()
        self._reformat()
        self.endResetModel()

    @property
    def columns(self) -> List[ColumnSpec]:
        return self._cols

    def _reformat(self) -> None:
        self._cache = [[c.format(r.get(c.key)) for c in self._cols] for r in self._rows]
        self._colors = []
        for r in self._rows:
            color = self._row_color(r) if self._row_color else None
            self._colors.append(QBrush(QColor(color)) if color else None)  # type: ignore[arg-type]

    def set_rows(self, rows: List[Dict[str, Any]]) -> None:
        self.beginResetModel()
        self._rows = rows
        self._reformat()
        self.endResetModel()

    def row_at(self, i: int) -> Optional[Dict[str, Any]]:
        if 0 <= i < len(self._rows):
            return self._rows[i]
        return None

    def rows(self) -> List[Dict[str, Any]]:
        return self._rows

    # --- Qt ----------------------------------------------------------
    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: B008
        return 0 if parent.isValid() else len(self._rows)

    def columnCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: B008
        return 0 if parent.isValid() else len(self._cols)

    def headerData(self, section, orientation, role=Qt.DisplayRole):
        if orientation == Qt.Horizontal and role == Qt.DisplayRole and 0 <= section < len(self._cols):
            return self._cols[section].title
        return None

    def data(self, index: QModelIndex, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        r, c = index.row(), index.column()
        col = self._cols[c]
        if role == Qt.DisplayRole:
            return self._cache[r][c]
        if role == Qt.UserRole:
            v = self._rows[r].get(col.key)
            if isinstance(v, Decimal):
                return float(v)
            if isinstance(v, (_dt.date, _dt.datetime)):
                return v.isoformat()
            return v
        if role == Qt.TextAlignmentRole:
            if col.kind in RIGHT_ALIGNED:
                return int(Qt.AlignRight | Qt.AlignVCenter)
            return int(Qt.AlignLeft | Qt.AlignVCenter)
        if role == Qt.ForegroundRole:
            return self._colors[r]
        return None


class SortProxy(QSortFilterProxyModel):
    def lessThan(self, left: QModelIndex, right: QModelIndex) -> bool:
        a = left.data(Qt.UserRole)
        b = right.data(Qt.UserRole)
        if a is None and b is None:
            return False
        if a is None:
            return True
        if b is None:
            return False
        try:
            return a < b
        except TypeError:
            return str(a) < str(b)
