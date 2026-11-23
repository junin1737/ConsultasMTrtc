"""Tela inicial (equivalente a Uprincipal.pas): tiles dos modulos + menu Arquivo."""
from __future__ import annotations

import os
from typing import List

from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import QAction, QIcon, QKeySequence
from PySide6.QtWidgets import (
    QApplication,
    QDialog,
    QGridLayout,
    QLabel,
    QMainWindow,
    QMessageBox,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

from app import APP_NAME, __version__
from app.config import MODO_UMA, AppConfig, save_config
from app.db.pool import ConnectionManager
from app.modules import MODULES
from app.ui.base_list import ConsultaWindow
from app.ui.config_dialog import ConfigDialog
from app.ui.connection_dialog import ConnectDialog
from app.ui.theme import icon_path

TILE_COLUMNS = 4


class MainWindow(QMainWindow):
    def __init__(self, cfg: AppConfig, manager: ConnectionManager):
        super().__init__()
        self.cfg = cfg
        self.manager = manager
        self._windows: List[ConsultaWindow] = []
        self.setWindowTitle(APP_NAME)
        self.resize(900, 520)

        self._build_menu()

        central = QWidget()
        self.setCentralWidget(central)
        root = QVBoxLayout(central)
        root.setContentsMargins(28, 22, 28, 18)

        t = QLabel("Consultas")
        t.setObjectName("titulo")
        s = QLabel("Consulta de clientes, estoque, orçamentos, financeiro e documentos fiscais.")
        s.setObjectName("subtitulo")
        self.lbl_conn = QLabel("")
        self.lbl_conn.setObjectName("subtitulo")
        root.addWidget(t)
        root.addWidget(s)
        root.addWidget(self.lbl_conn)
        root.addSpacing(14)

        grid = QGridLayout()
        grid.setSpacing(14)
        self.tiles: List[QToolButton] = []
        for i, spec in enumerate(MODULES):
            b = QToolButton()
            b.setObjectName("tile")
            b.setText(spec.tile_title)
            b.setToolTip(spec.hint)
            ip = icon_path(spec.icon)
            if os.path.isfile(ip):
                b.setIcon(QIcon(ip))
            b.setIconSize(QSize(56, 56))
            b.setToolButtonStyle(Qt.ToolButtonTextUnderIcon)
            b.setFixedSize(150, 124)
            b.clicked.connect(lambda _=False, sp=spec: self.open_module(sp))
            grid.addWidget(b, i // TILE_COLUMNS, i % TILE_COLUMNS)
            self.tiles.append(b)
        grid.setAlignment(Qt.AlignLeft | Qt.AlignTop)
        root.addLayout(grid)
        root.addStretch(1)
        foot = QLabel("MT Automações (34) 3674-1937 e o instagram @mtautomacoes")
        foot.setObjectName("subtitulo")
        root.addWidget(foot, 0, Qt.AlignRight)

        self.refresh_status()

    # ------------------------------------------------------------------
    def _build_menu(self) -> None:
        m = self.menuBar().addMenu("&Arquivo")
        self.act_connect = QAction("&Conectar bases...", self)
        self.act_connect.setShortcut(QKeySequence("Ctrl+K"))
        self.act_connect.triggered.connect(self.connect_flow)
        self.act_cfg = QAction("C&onfigurações...", self)
        self.act_cfg.setShortcut(QKeySequence("Ctrl+,"))
        self.act_cfg.triggered.connect(self.open_config)
        self.act_disc = QAction("&Desconectar", self)
        self.act_disc.triggered.connect(self.disconnect_all)
        act_exit = QAction("&Sair", self)
        act_exit.setShortcut(QKeySequence("Alt+F4"))
        act_exit.triggered.connect(self.close)
        m.addAction(self.act_connect)
        m.addAction(self.act_cfg)
        m.addAction(self.act_disc)
        m.addSeparator()
        m.addAction(act_exit)
        h = self.menuBar().addMenu("A&juda")
        a = QAction("&Sobre", self)
        a.triggered.connect(lambda: QMessageBox.information(
            self, "Sobre", f"{APP_NAME} {__version__}\nAplicativo desktop local (PySide6 + Firebird)."))
        h.addAction(a)

    def refresh_status(self) -> None:
        aliases = self.manager.aliases
        modo = "uma base" if self.cfg.mode == MODO_UMA else "várias bases"
        if aliases:
            txt = f"Modo: {modo} — conectado a: {', '.join(aliases)}"
        else:
            txt = f"Modo: {modo} — sem conexão (Arquivo → Conectar bases)"
        self.lbl_conn.setText(txt)
        self.statusBar().showMessage(txt)
        for b in self.tiles:
            b.setEnabled(bool(aliases))

    # ------------------------------------------------------------------
    def connect_flow(self) -> bool:
        """Mostra o dialogo de conexao (conforme o modo) e conecta. True se conectou ao menos uma base."""
        while True:
            dlg = ConnectDialog(self.cfg, self)
            r = dlg.exec()
            if r == 2:  # voltou das configuracoes (modo pode ter mudado)
                continue
            if r != QDialog.Accepted:
                return False
            break
        save_config(self.cfg)
        self.close_windows()
        QApplication.setOverrideCursor(Qt.BusyCursor)
        try:
            errors = self.manager.connect_all(dlg.selected)
        finally:
            QApplication.restoreOverrideCursor()
        self.refresh_status()
        if errors:
            QMessageBox.warning(
                self, "Conexão",
                "Falha ao conectar:\n\n" + "\n\n".join(f"{a}: {e}" for a, e in errors.items()))
        return self.manager.is_connected()

    def disconnect_all(self) -> None:
        self.close_windows()
        self.manager.disconnect_all()
        self.refresh_status()

    def open_config(self) -> None:
        dlg = ConfigDialog(self.cfg, self)
        if dlg.exec() == QDialog.Accepted:
            save_config(self.cfg)
            self.refresh_status()
            if QMessageBox.question(self, "Configurações",
                                    "Configurações salvas. Deseja reconectar agora?") == QMessageBox.Yes:
                self.connect_flow()

    def close_windows(self) -> None:
        for w in list(self._windows):
            w.close()
        self._windows.clear()

    def open_module(self, spec) -> None:
        if not self.manager.is_connected():
            if not self.connect_flow():
                return
        w = ConsultaWindow(self.manager, spec, None)
        w.setAttribute(Qt.WA_DeleteOnClose, True)
        w.destroyed.connect(lambda _=None, ww=w: self._windows.remove(ww) if ww in self._windows else None)
        self._windows.append(w)
        w.show()

    def closeEvent(self, event) -> None:  # noqa: N802
        self.close_windows()
        self.manager.disconnect_all()
        super().closeEvent(event)
