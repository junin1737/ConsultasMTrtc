"""Dialogo de conexao ao iniciar.

* Modo "uma base": dialogo de conexao unica (escolhe/edita a base e conecta).
* Modo "varias bases": lista com checkboxes; minimo 1 base marcada.
"""
from __future__ import annotations

from typing import List

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFileDialog,
    QFormLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMessageBox,
    QPushButton,
    QVBoxLayout,
)

from app.config import MODO_UMA, AppConfig, BaseConfig
from app.ui.config_dialog import BaseEditDialog, ConfigDialog, test_base


class ConnectDialog(QDialog):
    def __init__(self, cfg: AppConfig, parent=None):
        super().__init__(parent)
        self.cfg = cfg
        self.one = cfg.mode == MODO_UMA
        self.setWindowTitle("Conectar à base" if self.one else "Conectar às bases")
        self.resize(520, 380 if not self.one else 330)
        root = QVBoxLayout(self)
        self.selected: List[BaseConfig] = []

        if self.one:
            self._build_one(root)
        else:
            self._build_multi(root)

        row = QHBoxLayout()
        btn_cfg = QPushButton("Configurações...")
        btn_cfg.clicked.connect(self._open_config)
        row.addWidget(btn_cfg)
        row.addStretch(1)
        root.addLayout(row)

        btns = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        btns.button(QDialogButtonBox.Ok).setText("Conectar")
        btns.accepted.connect(self._accept)
        btns.rejected.connect(self.reject)
        root.addWidget(btns)

    # --- uma base ---------------------------------------------------------
    def _build_one(self, root: QVBoxLayout) -> None:
        root.addWidget(QLabel("Modo: <b>uma base</b>. Informe a conexão:"))
        form = QFormLayout()
        self.cmb = QComboBox()
        for b in self.cfg.bases:
            self.cmb.addItem(b.label(), b.alias)
        idx = self.cmb.findData(self.cfg.single)
        self.cmb.setCurrentIndex(max(idx, 0))
        self.cmb.currentIndexChanged.connect(self._load_one)
        self.edt_db = QLineEdit()
        btn = QPushButton("...")
        btn.setFixedWidth(32)
        btn.clicked.connect(self._browse)
        r = QHBoxLayout()
        r.addWidget(self.edt_db, 1)
        r.addWidget(btn)
        self.edt_server = QLineEdit()
        self.edt_port = QLineEdit()
        self.edt_port.setPlaceholderText("automática")
        self.edt_user = QLineEdit()
        self.edt_pass = QLineEdit()
        self.edt_pass.setEchoMode(QLineEdit.Password)
        form.addRow("Base (apelido):", self.cmb)
        form.addRow("Banco (.fdb):", r)
        form.addRow("Servidor:", self.edt_server)
        form.addRow("Porta:", self.edt_port)
        form.addRow("Usuário:", self.edt_user)
        form.addRow("Senha:", self.edt_pass)
        root.addLayout(form)
        btn_test = QPushButton("Testar conexão")
        btn_test.clicked.connect(lambda: test_base(self, self._one_value()))
        root.addWidget(btn_test, 0, Qt.AlignLeft)
        root.addStretch(1)
        self._load_one()

    def _current_alias(self) -> str:
        return self.cmb.currentData() or ""

    def _load_one(self) -> None:
        b = self.cfg.base_by_alias(self._current_alias())
        if not b:
            return
        self.edt_db.setText(b.database)
        self.edt_server.setText(b.server)
        self.edt_port.setText(b.port)
        self.edt_user.setText(b.user)
        self.edt_pass.setText(b.password)

    def _browse(self) -> None:
        p, _ = QFileDialog.getOpenFileName(self, "Banco Firebird", self.edt_db.text(),
                                           "Firebird (*.fdb *.gdb);;Todos (*.*)")
        if p:
            self.edt_db.setText(p.replace("/", "\\"))

    def _one_value(self) -> BaseConfig:
        b = self.cfg.base_by_alias(self._current_alias()) or BaseConfig()
        import copy
        b = copy.copy(b)
        b.database = self.edt_db.text().strip()
        b.server = self.edt_server.text().strip() or "127.0.0.1"
        b.port = self.edt_port.text().strip()
        b.user = self.edt_user.text().strip() or "SYSDBA"
        b.password = self.edt_pass.text() or "masterkey"
        return b

    # --- varias bases -------------------------------------------------------
    def _build_multi(self, root: QVBoxLayout) -> None:
        root.addWidget(QLabel("Modo: <b>várias bases</b>. Marque as bases a conectar (mínimo 1):"))
        self.lst = QListWidget()
        for b in self.cfg.bases:
            it = QListWidgetItem(f"{b.label()}   —   {b.database}")
            it.setData(Qt.UserRole, b.alias)
            it.setFlags(it.flags() | Qt.ItemIsUserCheckable)
            it.setCheckState(Qt.Checked if b.alias in self.cfg.selected else Qt.Unchecked)
            self.lst.addItem(it)
        root.addWidget(self.lst, 1)
        row = QHBoxLayout()
        b_all = QPushButton("Marcar todas")
        b_none = QPushButton("Desmarcar todas")
        b_all.clicked.connect(lambda: self._check_all(Qt.Checked))
        b_none.clicked.connect(lambda: self._check_all(Qt.Unchecked))
        row.addWidget(b_all)
        row.addWidget(b_none)
        row.addStretch(1)
        root.addLayout(row)

    def _check_all(self, state) -> None:
        for i in range(self.lst.count()):
            self.lst.item(i).setCheckState(state)

    # --- comum --------------------------------------------------------------
    def _open_config(self) -> None:
        dlg = ConfigDialog(self.cfg, self)
        if dlg.exec() == QDialog.Accepted:
            from app.config import save_config
            save_config(self.cfg)
            # reabre o dialogo no (possivelmente novo) modo
            self.done(2)

    def _accept(self) -> None:
        if self.one:
            b = self._one_value()
            if not b.database:
                QMessageBox.warning(self, "Conectar", "Informe o caminho do banco (.fdb).")
                return
            orig = self.cfg.base_by_alias(self._current_alias())
            if orig:
                orig.database, orig.server, orig.port = b.database, b.server, b.port
                orig.user, orig.password = b.user, b.password
            self.cfg.single = self._current_alias()
            self.selected = [orig or b]
        else:
            aliases = [self.lst.item(i).data(Qt.UserRole) for i in range(self.lst.count())
                       if self.lst.item(i).checkState() == Qt.Checked]
            if not aliases:
                QMessageBox.warning(self, "Conectar", "Marque ao menos uma base.")
                return
            self.cfg.selected = aliases
            self.selected = [b for b in self.cfg.bases if b.alias in aliases]
        self.accept()
