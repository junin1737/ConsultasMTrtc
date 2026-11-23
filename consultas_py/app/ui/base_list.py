"""Janela de consulta generica (equivalente a UfrmConsultaBase.pas).

Executa o SQL do modulo em cada base conectada e une os resultados com a coluna Base.
"""
from __future__ import annotations

import datetime as _dt
from typing import Any, Dict, List, Optional

from PySide6.QtCore import QDate, Qt, Signal
from PySide6.QtGui import QKeySequence, QShortcut
from PySide6.QtWidgets import (
    QApplication,
    QButtonGroup,
    QCheckBox,
    QComboBox,
    QDateEdit,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QRadioButton,
    QTableView,
    QVBoxLayout,
    QWidget,
)

from app.db.pool import ConnectionManager
from app.modules.spec import ChoiceFilter, Ctx, ModuleSpec, PeriodFilter, SituacaoNotaFilter, TextFilter
from app.ui.detail_dialog import apply_column_widths, configure_table, show_detail
from app.ui.table_model import RowsModel
from app.ui.workers import FuncWorker


class _PeriodWidget(QWidget):
    def __init__(self, spec: PeriodFilter, on_change):
        super().__init__()
        lay = QHBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        self.chk = QCheckBox(spec.label)
        self.chk.setChecked(spec.active_by_default)
        self.de = QDateEdit()
        self.ate = QDateEdit()
        today = _dt.date.today()
        for w, d in ((self.de, today.replace(day=1)), (self.ate, today)):
            w.setCalendarPopup(True)
            w.setDisplayFormat("dd/MM/yyyy")
            w.setDate(QDate(d.year, d.month, d.day))
        lay.addWidget(self.chk)
        lay.addWidget(QLabel("De:"))
        lay.addWidget(self.de)
        lay.addWidget(QLabel("Até:"))
        lay.addWidget(self.ate)
        self._update()
        self.chk.toggled.connect(lambda _=False: (self._update(), on_change()))
        self.de.dateChanged.connect(lambda _=None: on_change())
        self.ate.dateChanged.connect(lambda _=None: on_change())

    def _update(self) -> None:
        on = self.chk.isChecked()
        self.de.setEnabled(on)
        self.ate.setEnabled(on)

    def value(self):
        if not self.chk.isChecked():
            return None
        a = self.de.date().toPython()
        b = self.ate.date().toPython()
        if a > b:
            a = b
            self.de.blockSignals(True)
            self.de.setDate(self.ate.date())
            self.de.blockSignals(False)
        return (a, b)


class _SituacaoNotaWidget(QGroupBox):
    """Todas / Transmitidas / Canceladas / Inutilizadas (Todas exclusivo das demais)."""

    ITEMS = (("transmitidas", "Transmitidas"), ("canceladas", "Canceladas"), ("inutilizadas", "Inutilizadas"))

    def __init__(self, spec: SituacaoNotaFilter, on_change):
        super().__init__(spec.label)
        self._busy = False
        self._on_change = on_change
        lay = QHBoxLayout(self)
        self.chk_todas = QCheckBox("Todas")
        self.chk_todas.setChecked(True)
        self.chk_todas.clicked.connect(self._todas)
        lay.addWidget(self.chk_todas)
        self.checks = {}
        for key, label in self.ITEMS:
            c = QCheckBox(label)
            c.clicked.connect(self._especifica)
            self.checks[key] = c
            lay.addWidget(c)

    def _todas(self) -> None:
        self._busy = True
        if self.chk_todas.isChecked():
            for c in self.checks.values():
                c.setChecked(False)
        elif not any(c.isChecked() for c in self.checks.values()):
            self.chk_todas.setChecked(True)
        self._busy = False
        self._on_change()

    def _especifica(self) -> None:
        self.chk_todas.setChecked(not any(c.isChecked() for c in self.checks.values()))
        self._on_change()

    def value(self):
        if self.chk_todas.isChecked():
            return []
        return [k for k, c in self.checks.items() if c.isChecked()]


# Threads de consulta ainda em execucao quando a janela foi fechada: mantidas vivas ate terminarem
# (destruir um QThread em execucao aborta o processo inteiro).
_ORPHAN_WORKERS: set = set()

TODAS_BASES = "Todas as bases"


def wait_orphan_workers(ms: int = 5000) -> None:
    """Aguarda (limitado) consultas em andamento de janelas ja fechadas; usado ao encerrar o app."""
    for w in list(_ORPHAN_WORKERS):
        try:
            w.wait(ms)
        except RuntimeError:
            pass


class ConsultaWindow(QMainWindow):
    closed = Signal()

    def __init__(self, manager: ConnectionManager, spec: ModuleSpec, parent=None):
        super().__init__(parent)
        self._cursor_busy = False
        self.manager = manager
        self.spec = spec
        self.ctx = Ctx(manager, self)
        self._worker: Optional[FuncWorker] = None
        self._pending_reload = False
        self._filter_widgets: Dict[str, Any] = {}

        self.setWindowTitle(spec.title)
        self.resize(1500 if spec.wide else 1150, 720)

        central = QWidget()
        self.setCentralWidget(central)
        root = QVBoxLayout(central)

        # --- pesquisa -------------------------------------------------
        top = QHBoxLayout()
        top.addWidget(QLabel(spec.search_label))
        self.edt_search = QLineEdit()
        self.edt_search.setClearButtonEnabled(True)
        self.edt_search.returnPressed.connect(self.reload)
        top.addWidget(self.edt_search, 1)
        btn_search = QPushButton("Pesquisar")
        btn_search.clicked.connect(self.reload)
        top.addWidget(btn_search)
        # filtro por base (apelido) - herdado por todos os modulos
        top.addSpacing(12)
        top.addWidget(QLabel("Base:"))
        self.cmb_base = QComboBox()
        self.cmb_base.setMinimumWidth(170)
        self.cmb_base.setToolTip("Filtra os registros pela base (apelido) de origem")
        self._fill_bases()
        self.cmb_base.currentIndexChanged.connect(lambda _=0: self.reload())
        top.addWidget(self.cmb_base)
        root.addLayout(top)

        # --- filtros --------------------------------------------------
        if spec.filters:
            root.addWidget(self._build_filters())

        # --- grade ----------------------------------------------------
        self.model = RowsModel(spec.columns, show_base=len(manager.aliases) > 1, row_color=spec.row_color)
        self.table = QTableView()
        self.proxy = configure_table(self.table, self.model)
        self.table.doubleClicked.connect(lambda _=None: self.open_detail())
        self.table.selectionModel().selectionChanged.connect(lambda *_: self._update_actions())
        root.addWidget(self.table, 1)

        # --- rodape ---------------------------------------------------
        self.lbl_status = QLabel("")
        self.lbl_warn = QLabel("")
        self.lbl_warn.setStyleSheet("color: #b00020;")
        self.lbl_warn.setWordWrap(True)
        root.addWidget(self.lbl_warn)
        foot = QHBoxLayout()
        foot.addWidget(self.lbl_status, 1)
        self._action_buttons: List[tuple] = []
        for label, fn, enabled_fn in spec.actions:
            b = QPushButton(label)
            b.setEnabled(False)
            b.clicked.connect(lambda _=False, f=fn: self._run_action(f))
            foot.addWidget(b)
            self._action_buttons.append((b, enabled_fn))
        btn_detail = QPushButton("Detalhes")
        btn_detail.clicked.connect(self.open_detail)
        foot.addWidget(btn_detail)
        btn_close = QPushButton("Fechar")
        btn_close.clicked.connect(self.close)
        foot.addWidget(btn_close)
        root.addLayout(foot)

        QShortcut(QKeySequence(Qt.Key_Escape), self, activated=self.close)
        QShortcut(QKeySequence(Qt.Key_F5), self, activated=self.reload)

        if spec.search_on_open:
            self.reload()

    # ------------------------------------------------------------------
    def _build_filters(self) -> QWidget:
        box = QGroupBox("Filtros")
        lay = QVBoxLayout(box)
        row1 = QHBoxLayout()
        row2 = QHBoxLayout()
        lay.addLayout(row1)
        lay.addLayout(row2)
        for f in self.spec.filters:
            if isinstance(f, ChoiceFilter):
                g = QGroupBox(f.label)
                gl = QHBoxLayout(g)
                grp = QButtonGroup(g)
                for label, value in f.options:
                    rb = QRadioButton(label)
                    rb.setProperty("filter_value", value)
                    if value == f.default or (f.default is None and not grp.buttons()):
                        rb.setChecked(True)
                    grp.addButton(rb)
                    gl.addWidget(rb)
                grp.buttonClicked.connect(lambda _=None: self.reload())
                self._filter_widgets[f.key] = grp
                row1.addWidget(g)
            elif isinstance(f, TextFilter):
                row2.addWidget(QLabel(f.label + ":"))
                e = QLineEdit()
                e.setFixedWidth(f.width)
                e.returnPressed.connect(self.reload)
                self._filter_widgets[f.key] = e
                row2.addWidget(e)
            elif isinstance(f, PeriodFilter):
                w = _PeriodWidget(f, self._schedule_reload)
                self._filter_widgets[f.key] = w
                row2.addWidget(w)
            elif isinstance(f, SituacaoNotaFilter):
                w = _SituacaoNotaWidget(f, self._schedule_reload)
                self._filter_widgets[f.key] = w
                row1.addWidget(w)
        row1.addStretch(1)
        row2.addStretch(1)
        return box

    def _schedule_reload(self) -> None:
        self.reload()

    def _fill_bases(self) -> None:
        """Preenche o combo: 'Todas as bases' + cada base conectada (apelido)."""
        atual = self.cmb_base.currentData() if self.cmb_base.count() else None
        self.cmb_base.blockSignals(True)
        self.cmb_base.clear()
        self.cmb_base.addItem(TODAS_BASES, None)
        for a in self.manager.aliases:
            self.cmb_base.addItem(a, a)
        i = self.cmb_base.findData(atual) if atual else 0
        self.cmb_base.setCurrentIndex(max(i, 0))
        self.cmb_base.setEnabled(len(self.manager.aliases) > 1)
        self.cmb_base.blockSignals(False)

    def selected_base(self) -> Optional[str]:
        """Apelido da base escolhida no filtro (None = todas)."""
        return self.cmb_base.currentData()

    def filters(self) -> Dict[str, Any]:
        out: Dict[str, Any] = {"text": self.edt_search.text().strip()}
        for f in self.spec.filters:
            w = self._filter_widgets.get(f.key)
            if isinstance(f, ChoiceFilter):
                btn = w.checkedButton()
                out[f.key] = btn.property("filter_value") if btn else f.default
            elif isinstance(f, TextFilter):
                out[f.key] = w.text().strip()
            elif isinstance(f, (PeriodFilter, SituacaoNotaFilter)):
                out[f.key] = w.value()
        return out

    # ------------------------------------------------------------------
    def reload(self) -> None:
        if not self.manager.is_connected():
            QMessageBox.warning(self, self.spec.title, "Nenhuma base conectada. Use Arquivo → Conectar bases.")
            return
        if self._worker and self._worker.isRunning():
            self._pending_reload = True
            return
        filters = self.filters()
        spec = self.spec
        only = self.selected_base()
        if only and only not in self.manager.aliases:
            only = None
        self.lbl_status.setText("Consultando...")
        self.lbl_warn.setText("")
        QApplication.setOverrideCursor(Qt.BusyCursor)
        self._cursor_busy = True
        self._worker = FuncWorker(
            lambda: self.manager.query_all(lambda conn: spec.build(conn, filters), only=only), self)
        self._worker.done.connect(self._loaded)
        self._worker.failed.connect(self._failed)
        self._worker.start()

    def _finish(self) -> None:
        if self._cursor_busy:
            self._cursor_busy = False
            QApplication.restoreOverrideCursor()
        if self._pending_reload:
            self._pending_reload = False
            self.reload()

    def _failed(self, msg: str) -> None:
        self.lbl_status.setText("Erro")
        QMessageBox.critical(self, self.spec.title, f"Erro ao consultar:\n\n{msg}")
        self._finish()

    def _loaded(self, merged) -> None:
        self.model.set_show_base(len(self.manager.aliases) > 1)
        self.model.set_rows(merged.dicts())
        apply_column_widths(self.table, self.model)
        if self.spec.default_sort:
            for i, c in enumerate(self.model.columns):
                if c.key == self.spec.default_sort:
                    self.table.sortByColumn(i, Qt.AscendingOrder)
                    break
        n = len(merged.rows)
        only = self.selected_base()
        bases = only if only and only in self.manager.aliases else ", ".join(self.manager.aliases)
        self.lbl_status.setText(f"{n} registro(s) — base(s): {bases}")
        if merged.warnings:
            self.lbl_warn.setText("Avisos:\n" + "\n".join(merged.warnings))
        self._update_actions()
        self._finish()

    # ------------------------------------------------------------------
    def current_row(self) -> Optional[Dict[str, Any]]:
        idx = self.table.currentIndex()
        if not idx.isValid():
            return None
        src = self.proxy.mapToSource(idx)
        return self.model.row_at(src.row())

    def _update_actions(self) -> None:
        row = self.current_row()
        for btn, enabled_fn in self._action_buttons:
            btn.setEnabled(bool(row) and (enabled_fn(row) if enabled_fn else True))

    def _run_action(self, fn) -> None:
        row = self.current_row()
        if not row:
            return
        try:
            fn(self.ctx, row)
        except Exception as exc:  # noqa: BLE001
            QMessageBox.critical(self, self.spec.title, str(exc))

    def closeEvent(self, event) -> None:  # noqa: N802
        """Fecha somente esta janela; a tela inicial permanece aberta."""
        w, self._worker = self._worker, None
        if w is not None:
            for sig in (w.done, w.failed):
                try:
                    sig.disconnect()
                except (RuntimeError, TypeError):
                    pass
            if w.isRunning():
                w.setParent(None)  # sobrevive a janela; descartada quando terminar
                _ORPHAN_WORKERS.add(w)
                w.finished.connect(lambda ww=w: (_ORPHAN_WORKERS.discard(ww), ww.deleteLater()))
        if self._cursor_busy:
            self._cursor_busy = False
            QApplication.restoreOverrideCursor()
        self._pending_reload = False
        super().closeEvent(event)
        self.closed.emit()

    def open_detail(self) -> None:
        row = self.current_row()
        if not row or not self.spec.detail:
            return
        QApplication.setOverrideCursor(Qt.BusyCursor)
        try:
            data = self.spec.detail(self.ctx, row)
        except Exception as exc:  # noqa: BLE001
            QApplication.restoreOverrideCursor()
            QMessageBox.critical(self, self.spec.title, f"Erro ao carregar detalhes:\n\n{exc}")
            return
        QApplication.restoreOverrideCursor()
        if data is None:
            QMessageBox.information(self, self.spec.title, "Registro não encontrado.")
            return
        base = row.get("Base")
        if len(self.manager.aliases) > 1 and base:
            data.title = f"{data.title} [{base}]"
        show_detail(data, self)
