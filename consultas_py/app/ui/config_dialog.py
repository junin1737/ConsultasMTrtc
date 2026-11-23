"""Configuracoes: modo (uma base / varias bases) e cadastro das conexoes."""
from __future__ import annotations

import copy
from typing import List, Optional

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QAbstractItemView,
    QCheckBox,
    QDialog,
    QDialogButtonBox,
    QFileDialog,
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QRadioButton,
    QApplication,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from app.config import MODO_UMA, MODO_VARIAS, AppConfig, BaseConfig
from app.db import detect_fb
from app.db.connection import FirebirdConnection, client_library_loaded


def test_base(parent: QWidget, base: BaseConfig) -> None:
    QApplication.setOverrideCursor(Qt.BusyCursor)
    try:
        msg = FirebirdConnection(base).test()
        QApplication.restoreOverrideCursor()
        QMessageBox.information(parent, "Testar conexão", f"{base.label()}: {msg}")
    except Exception as exc:  # noqa: BLE001
        QApplication.restoreOverrideCursor()
        QMessageBox.warning(parent, "Testar conexão", f"{base.label()}:\n\n{exc}")


class BaseEditDialog(QDialog):
    """Edita uma conexao (apelido, caminho .fdb, servidor, porta, usuario, senha...)."""

    def __init__(self, base: Optional[BaseConfig] = None, parent=None, title: str = "Base de dados"):
        super().__init__(parent)
        self.setWindowTitle(title)
        self.resize(560, 10)
        b = base or BaseConfig()
        form = QFormLayout(self)

        self.edt_alias = QLineEdit(b.alias)
        self.edt_db = QLineEdit(b.database)
        btn_db = QPushButton("...")
        btn_db.setFixedWidth(32)
        btn_db.clicked.connect(self._browse_db)
        row = QHBoxLayout()
        row.addWidget(self.edt_db, 1)
        row.addWidget(btn_db)
        self.edt_server = QLineEdit(b.server)
        self.edt_port = QLineEdit(b.port)
        self.edt_port.setPlaceholderText("automática (detectada pelo serviço Firebird)")
        self.edt_user = QLineEdit(b.user)
        self.edt_pass = QLineEdit(b.password)
        self.edt_pass.setEchoMode(QLineEdit.Password)
        self.edt_charset = QLineEdit(b.charset)
        self.edt_client = QLineEdit(b.client_library)
        self.edt_client.setPlaceholderText("automático (fbclient.dll detectado)")
        btn_cl = QPushButton("...")
        btn_cl.setFixedWidth(32)
        btn_cl.clicked.connect(self._browse_client)
        row2 = QHBoxLayout()
        row2.addWidget(self.edt_client, 1)
        row2.addWidget(btn_cl)

        form.addRow("Apelido:", self.edt_alias)
        form.addRow("Banco (.fdb):", row)
        form.addRow("Servidor:", self.edt_server)
        form.addRow("Porta:", self.edt_port)
        form.addRow("Usuário:", self.edt_user)
        form.addRow("Senha:", self.edt_pass)
        form.addRow("Charset:", self.edt_charset)
        form.addRow("fbclient.dll:", row2)

        btns = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        self.btn_test = QPushButton("Testar conexão")
        self.btn_test.clicked.connect(self._test)
        btns.addButton(self.btn_test, QDialogButtonBox.ActionRole)
        btns.accepted.connect(self._accept)
        btns.rejected.connect(self.reject)
        form.addRow(btns)
        self._base = b

    def _browse_db(self) -> None:
        p, _ = QFileDialog.getOpenFileName(self, "Banco Firebird", self.edt_db.text(),
                                           "Firebird (*.fdb *.gdb);;Todos (*.*)")
        if p:
            self.edt_db.setText(p.replace("/", "\\"))
            if not self.edt_alias.text().strip():
                import os
                self.edt_alias.setText(os.path.splitext(os.path.basename(p))[0].lower())

    def _browse_client(self) -> None:
        p, _ = QFileDialog.getOpenFileName(self, "fbclient.dll", self.edt_client.text(), "DLL (*.dll);;Todos (*.*)")
        if p:
            self.edt_client.setText(p.replace("/", "\\"))

    def value(self) -> BaseConfig:
        b = copy.copy(self._base)
        b.alias = self.edt_alias.text().strip()
        b.database = self.edt_db.text().strip()
        b.server = self.edt_server.text().strip() or "127.0.0.1"
        b.port = self.edt_port.text().strip()
        b.user = self.edt_user.text().strip() or "SYSDBA"
        b.password = self.edt_pass.text() or "masterkey"
        b.charset = self.edt_charset.text().strip() or "WIN1252"
        b.client_library = self.edt_client.text().strip()
        return b

    def _test(self) -> None:
        test_base(self, self.value())

    def _accept(self) -> None:
        if not self.edt_db.text().strip():
            QMessageBox.warning(self, "Base", "Informe o caminho do banco (.fdb).")
            return
        self.accept()


class ConfigDialog(QDialog):
    """Arquivo → Configurações."""

    COLS = ["Apelido", "Banco (.fdb)", "Servidor", "Porta", "Usuário"]

    def __init__(self, cfg: AppConfig, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Configurações")
        self.resize(780, 520)
        self._bases: List[BaseConfig] = [copy.copy(b) for b in cfg.bases]
        self._cfg = cfg

        root = QVBoxLayout(self)

        grp_mode = QGroupBox("Modo de conexão")
        ml = QVBoxLayout(grp_mode)
        self.rb_one = QRadioButton("Uma base — conecta somente a uma base por vez")
        self.rb_multi = QRadioButton("Várias bases — escolha quais conectar; as consultas unem os resultados (coluna Base)")
        (self.rb_one if cfg.mode == MODO_UMA else self.rb_multi).setChecked(True)
        ml.addWidget(self.rb_one)
        ml.addWidget(self.rb_multi)
        self.chk_ask = QCheckBox("Perguntar quais bases conectar ao iniciar o aplicativo")
        self.chk_ask.setChecked(cfg.ask_on_start)
        ml.addWidget(self.chk_ask)
        root.addWidget(grp_mode)

        grp_bases = QGroupBox("Bases cadastradas")
        bl = QVBoxLayout(grp_bases)
        self.table = QTableWidget(0, len(self.COLS))
        self.table.setHorizontalHeaderLabels(self.COLS)
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SingleSelection)
        self.table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table.horizontalHeader().setStretchLastSection(True)
        self.table.verticalHeader().setVisible(False)
        self.table.doubleClicked.connect(lambda _=None: self._edit())
        bl.addWidget(self.table)
        row = QHBoxLayout()
        for label, fn in (("Adicionar...", self._add), ("Editar...", self._edit), ("Remover", self._remove),
                          ("Testar conexão", self._test)):
            b = QPushButton(label)
            b.clicked.connect(fn)
            row.addWidget(b)
        row.addStretch(1)
        bl.addLayout(row)
        root.addWidget(grp_bases, 1)

        self.lbl_fb = QLabel()
        self.lbl_fb.setWordWrap(True)
        self.lbl_fb.setStyleSheet("color: #55657a;")
        root.addWidget(self.lbl_fb)
        self._fill_fb_info()

        btns = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        btns.accepted.connect(self._accept)
        btns.rejected.connect(self.reject)
        root.addWidget(btns)
        self._refresh()

    def _fill_fb_info(self) -> None:
        servicos = detect_fb.detectar_servicos_firebird()
        parts = [f"{s.nome_servico} (porta {s.porta}, {s.pasta})" for s in servicos]
        lib = detect_fb.resolver_cliente_fb("", servicos)
        loaded = client_library_loaded()
        txt = "Serviços Firebird detectados: " + ("; ".join(parts) if parts else "nenhum") + "\n"
        txt += "fbclient.dll em uso/detectado: " + (loaded or lib or "NÃO ENCONTRADO (coloque um fbclient.dll compatível em consultas_py\\dll)")
        self.lbl_fb.setText(txt)

    def _refresh(self) -> None:
        self.table.setRowCount(len(self._bases))
        for r, b in enumerate(self._bases):
            vals = [b.alias, b.database, b.server, b.port or "auto", b.user]
            for c, v in enumerate(vals):
                self.table.setItem(r, c, QTableWidgetItem(v))
        self.table.resizeColumnToContents(0)

    def _current(self) -> int:
        return self.table.currentRow()

    def _add(self) -> None:
        dlg = BaseEditDialog(None, self, "Nova base")
        if dlg.exec() == QDialog.Accepted:
            self._bases.append(dlg.value())
            self._refresh()

    def _edit(self) -> None:
        i = self._current()
        if i < 0:
            return
        dlg = BaseEditDialog(self._bases[i], self, "Editar base")
        if dlg.exec() == QDialog.Accepted:
            self._bases[i] = dlg.value()
            self._refresh()

    def _remove(self) -> None:
        i = self._current()
        if i < 0:
            return
        if QMessageBox.question(self, "Remover", f"Remover a base '{self._bases[i].label()}'?") == QMessageBox.Yes:
            del self._bases[i]
            self._refresh()

    def _test(self) -> None:
        i = self._current()
        if i < 0:
            QMessageBox.information(self, "Testar conexão", "Selecione uma base.")
            return
        test_base(self, self._bases[i])

    def _accept(self) -> None:
        if not self._bases:
            QMessageBox.warning(self, "Configurações", "Cadastre ao menos uma base.")
            return
        cfg = self._cfg
        cfg.mode = MODO_UMA if self.rb_one.isChecked() else MODO_VARIAS
        cfg.ask_on_start = self.chk_ask.isChecked()
        cfg.bases = self._bases
        cfg.normalize()
        self.accept()
