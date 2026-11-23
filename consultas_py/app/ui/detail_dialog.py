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
    QSplitter,
    QTableView,
    QTabWidget,
    QVBoxLayout,
    QHeaderView,
    QWidget,
)

from app.modules.spec import DetailData
from app.ui.table_model import RowsModel, SortProxy

# largura dos campos de valor: cabe "R$ 9.999.999,99" (~12 digitos) sem ocupar a linha toda
MONEY_SAMPLE = "R$ 999.999.999,99"


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


def _is_money(value: str | None) -> bool:
    return bool(value) and str(value).startswith("R$")


class DetailDialog(QDialog):
    def __init__(self, data: DetailData, parent=None):
        super().__init__(parent)
        self.setWindowTitle(data.title)
        self._models = []
        if data.tabs:
            self.resize(1020, 740)
        else:
            self.resize(900, 640 if data.sections
                        else (260 + 34 * ((len(data.fields) + 1) // 2) + 130 * len(data.memos)))
        root = QVBoxLayout(self)
        if data.tabs:
            root.setContentsMargins(8, 8, 8, 8)
            root.setSpacing(6)

        self._money_w = self.fontMetrics().horizontalAdvance(MONEY_SAMPLE) + 20
        if data.tabs:
            self._build_compact(data, root)
        else:
            self._build_classic(data, root)

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

    # ------------------------------------------------------------------ helpers
    def _make_edit(self, value: str, compact: bool = False) -> QLineEdit:
        edit = QLineEdit(value or "")
        edit.setReadOnly(True)
        edit.setCursorPosition(0)
        if compact:
            edit.setFixedHeight(22)
        if _is_money(value):
            edit.setFixedWidth(self._money_w)
            edit.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        return edit

    @staticmethod
    def _make_label(label: str) -> QLabel:
        lbl = QLabel(label + ":")
        lbl.setStyleSheet("font-weight: 600;")
        return lbl

    def _add_table(self, sec) -> QTableView:
        view = QTableView()
        model = RowsModel(sec.columns)
        model.set_rows(sec.rows)
        configure_table(view, model)
        apply_column_widths(view, model)
        self._models.append(model)
        return view

    # ------------------------------------------------------------------ layout classico
    def _build_classic(self, data: DetailData, root: QVBoxLayout) -> None:
        grid = QGridLayout()
        grid.setHorizontalSpacing(10)
        grid.setVerticalSpacing(6)
        ncols = max(1, data.columns)
        for i, (label, value) in enumerate(data.fields):
            r, c = divmod(i, ncols)
            grid.addWidget(self._make_label(label), r, c * 2, Qt.AlignRight | Qt.AlignVCenter)
            if _is_money(value):
                # campo de valor estreito, alinhado a esquerda da celula
                grid.addWidget(self._make_edit(value), r, c * 2 + 1, Qt.AlignLeft)
            else:
                grid.addWidget(self._make_edit(value), r, c * 2 + 1)
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

        for sec in data.sections:
            box = QGroupBox(sec.title)
            lay = QVBoxLayout(box)
            lay.addWidget(self._add_table(sec))
            root.addWidget(box, 1)

        root.addStretch(0)

    # ------------------------------------------------------------------ layout compacto (O.S.)
    def _build_compact(self, data: DetailData, root: QVBoxLayout) -> None:
        ncols = max(1, data.columns)
        texto = [(l, v) for l, v in data.fields if not _is_money(v)]
        valores = [(l, v) for l, v in data.fields if _is_money(v)]

        # cabecalho compacto: textos em ncols colunas; campos largos (cliente) ocupam a linha toda
        grid = QGridLayout()
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setHorizontalSpacing(6)
        grid.setVerticalSpacing(3)
        wide = set(data.wide_fields)
        row = col = 0
        for label, value in texto:
            if label in wide:
                if col:
                    row, col = row + 1, 0
                grid.addWidget(self._make_label(label), row, 0, Qt.AlignRight | Qt.AlignVCenter)
                grid.addWidget(self._make_edit(value, True), row, 1, 1, ncols * 2 - 1)
                row += 1
                continue
            grid.addWidget(self._make_label(label), row, col * 2, Qt.AlignRight | Qt.AlignVCenter)
            grid.addWidget(self._make_edit(value, True), row, col * 2 + 1)
            col += 1
            if col >= ncols:
                row, col = row + 1, 0
        for c in range(ncols):
            grid.setColumnStretch(c * 2 + 1, 1)
        root.addLayout(grid)

        # faixa de valores (campos estreitos lado a lado)
        if valores:
            strip = QHBoxLayout()
            strip.setSpacing(6)
            for label, value in valores:
                strip.addWidget(self._make_label(label))
                strip.addWidget(self._make_edit(value, True))
                strip.addSpacing(8)
            strip.addStretch(1)
            root.addLayout(strip)

        # secoes em abas (grade grande) + memos em abas num painel menor; divisor arrastavel
        split = QSplitter(Qt.Vertical)
        split.setChildrenCollapsible(False)
        if data.sections:
            tabs = QTabWidget()
            for sec in data.sections:
                tabs.addTab(self._add_table(sec), f"{sec.title} ({len(sec.rows)})")
            split.addWidget(tabs)
        memos = [(l, t) for l, t in data.memos]
        if memos:
            mtabs = QTabWidget()
            for label, text in memos:
                memo = QPlainTextEdit(text or "")
                memo.setReadOnly(True)
                mtabs.addTab(memo, label + (" •" if (text or "").strip() else ""))
            split.addWidget(mtabs)
            split.setStretchFactor(0, 5)
            split.setStretchFactor(1, 1)
            if data.sections:
                split.setSizes([480, 110])
        root.addWidget(split, 1)


def show_detail(data: DetailData, parent: QWidget | None = None) -> None:
    DetailDialog(data, parent).exec()
