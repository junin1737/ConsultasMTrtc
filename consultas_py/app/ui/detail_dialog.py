"""Janela de detalhe generica (campos somente leitura + grades + botoes)."""
from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QDialog,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPlainTextEdit,
    QPushButton,
    QTableView,
    QVBoxLayout,
    QHeaderView,
    QWidget,
)

from app.modules.spec import DetailData
from app.ui.table_model import RowsModel, SortProxy


def configure_table(view: QTableView, model: RowsModel) -> SortProxy:
    proxy = SortProxy(view)
    proxy.setSourceModel(model)
    view.setModel(proxy)
    view.setSelectionBehavior(QTableView.SelectRows)
    view.setSelectionMode(QTableView.SingleSelection)
    view.setEditTriggers(QTableView.NoEditTriggers)
    view.setAlternatingRowColors(True)
    view.setSortingEnabled(True)
    view.verticalHeader().setVisible(False)
    view.verticalHeader().setDefaultSectionSize(24)
    hh = view.horizontalHeader()
    hh.setStretchLastSection(True)
    hh.setSectionResizeMode(QHeaderView.Interactive)
    return proxy


def apply_column_widths(view: QTableView, model: RowsModel) -> None:
    view.resizeColumnsToContents()
    for i, col in enumerate(model.columns):
        w = view.columnWidth(i)
        if col.width:
            view.setColumnWidth(i, col.width)
        else:
            view.setColumnWidth(i, max(60, min(w + 16, 420)))


class DetailDialog(QDialog):
    def __init__(self, data: DetailData, parent=None):
        super().__init__(parent)
        self.setWindowTitle(data.title)
        self.resize(900, 640 if data.sections else (260 + 34 * ((len(data.fields) + 1) // 2) + 130 * len(data.memos)))
        root = QVBoxLayout(self)

        grid = QGridLayout()
        grid.setHorizontalSpacing(10)
        grid.setVerticalSpacing(6)
        ncols = max(1, data.columns)
        for i, (label, value) in enumerate(data.fields):
            r, c = divmod(i, ncols)
            lbl = QLabel(label + ":")
            lbl.setStyleSheet("font-weight: 600;")
            edit = QLineEdit(value or "")
            edit.setReadOnly(True)
            edit.setCursorPosition(0)
            grid.addWidget(lbl, r, c * 2, Qt.AlignRight | Qt.AlignVCenter)
            grid.addWidget(edit, r, c * 2 + 1)
        for c in range(ncols):
            grid.setColumnStretch(c * 2 + 1, 1)
        root.addLayout(grid)

        for label, text in data.memos:
            box = QGroupBox(label)
            lay = QVBoxLayout(box)
            memo = QPlainTextEdit(text or "")
            memo.setReadOnly(True)
            memo.setMaximumHeight(110)
            lay.addWidget(memo)
            root.addWidget(box)

        self._models = []
        for sec in data.sections:
            box = QGroupBox(sec.title)
            lay = QVBoxLayout(box)
            view = QTableView()
            model = RowsModel(sec.columns)
            model.set_rows(sec.rows)
            configure_table(view, model)
            apply_column_widths(view, model)
            lay.addWidget(view)
            root.addWidget(box, 1)
            self._models.append(model)

        root.addStretch(0)
        foot = QHBoxLayout()
        foot.addStretch(1)
        for label, fn, enabled in data.actions:
            b = QPushButton(label)
            b.setEnabled(enabled)
            b.clicked.connect(lambda _=False, f=fn: f())
            foot.addWidget(b)
        close = QPushButton("Fechar")
        close.clicked.connect(self.accept)
        close.setDefault(True)
        foot.addWidget(close)
        root.addLayout(foot)


def show_detail(data: DetailData, parent: QWidget | None = None) -> None:
    DetailDialog(data, parent).exec()
