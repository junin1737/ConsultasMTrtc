"""Tema claro forcado (Fusion + paleta + folha de estilo).

O app NAO acompanha o modo escuro do Windows: paleta e QSS definem cores explicitas
(texto escuro sobre fundo claro) para todos os widgets, garantindo contraste.
"""
from __future__ import annotations

import os

from PySide6.QtCore import Qt
from PySide6.QtGui import QColor, QFont, QIcon, QPalette
from PySide6.QtWidgets import QApplication

from app.config import resource_dir

# --- cores base ----------------------------------------------------------------
BG = "#f4f6f9"          # janelas / dialogs
BASE = "#ffffff"        # campos, tabelas
ALT = "#f1f4f9"         # linhas alternadas
TEXT = "#1a1a1a"        # texto principal
TEXT_MUTED = "#55657a"  # texto secundario
BORDER = "#c3ccd8"
HEADER_BG = "#e3e9f1"
ACCENT = "#2f6fb5"      # selecao
DISABLED = "#8a94a3"

STYLE = """
QWidget { color: %(TEXT)s; }
QMainWindow, QDialog, QMessageBox, QStatusBar { background-color: %(BG)s; }

QLabel { background: transparent; color: %(TEXT)s; }
QLabel#titulo { font-size: 26px; font-weight: 600; color: #1f3a5f; }
QLabel#subtitulo { color: %(TEXT_MUTED)s; }

QToolButton#tile {
    background-color: white; border: 1px solid #d5dbe4; border-radius: 10px;
    padding: 10px; font-weight: 600; color: #1f3a5f;
}
QToolButton#tile:hover { background-color: #e8f1fb; border-color: #5b9bd5; }
QToolButton#tile:disabled { color: #9aa5b3; }
QToolButton { color: %(TEXT)s; }

QGroupBox { font-weight: 600; border: 1px solid #d5dbe4; border-radius: 6px; margin-top: 8px;
            padding-top: 8px; color: %(TEXT)s; background-color: transparent; }
QGroupBox::title { subcontrol-origin: margin; left: 10px; padding: 0 4px; color: %(TEXT)s; }

QCheckBox, QRadioButton { background: transparent; color: %(TEXT)s; spacing: 6px; }
QCheckBox:disabled, QRadioButton:disabled { color: %(DISABLED)s; }
QCheckBox::indicator, QRadioButton::indicator { width: 14px; height: 14px; background-color: %(BASE)s;
    border: 1px solid #7d8795; }
QCheckBox::indicator { border-radius: 2px; }
QRadioButton::indicator { border-radius: 8px; }
QCheckBox::indicator:checked, QRadioButton::indicator:checked {
    background-color: %(ACCENT)s; border: 1px solid %(ACCENT)s; }
QCheckBox::indicator:checked { border-radius: 2px; }
QCheckBox::indicator:disabled, QRadioButton::indicator:disabled { background-color: #eceff3; border-color: #c3ccd8; }

QLineEdit, QPlainTextEdit, QTextEdit, QTextBrowser, QSpinBox, QDoubleSpinBox, QDateEdit,
QDateTimeEdit, QTimeEdit {
    background-color: %(BASE)s; color: %(TEXT)s; border: 1px solid %(BORDER)s; border-radius: 3px;
    padding: 2px 4px; selection-background-color: %(ACCENT)s; selection-color: white;
}
QLineEdit:disabled, QPlainTextEdit:disabled, QTextEdit:disabled, QSpinBox:disabled,
QDateEdit:disabled, QComboBox:disabled { background-color: #eceff3; color: %(DISABLED)s; }
QLineEdit:focus, QPlainTextEdit:focus, QTextEdit:focus, QSpinBox:focus, QDateEdit:focus,
QComboBox:focus { border: 1px solid %(ACCENT)s; }
QLineEdit[readOnly="true"], QPlainTextEdit[readOnly="true"], QTextEdit[readOnly="true"] {
    background-color: %(BASE)s; color: %(TEXT)s;
}

QComboBox {
    background-color: %(BASE)s; color: %(TEXT)s; border: 1px solid %(BORDER)s; border-radius: 3px;
    padding: 2px 6px; min-height: 20px;
}
QComboBox QAbstractItemView {
    background-color: %(BASE)s; color: %(TEXT)s; border: 1px solid %(BORDER)s;
    selection-background-color: %(ACCENT)s; selection-color: white; outline: 0;
}

QPushButton {
    background-color: #e9eef5; color: %(TEXT)s; border: 1px solid %(BORDER)s; border-radius: 4px;
    padding: 4px 14px; min-height: 20px;
}
QPushButton:hover { background-color: #dce7f4; border-color: #5b9bd5; }
QPushButton:pressed { background-color: #c9dcf0; }
QPushButton:default { border: 1px solid %(ACCENT)s; }
QPushButton:disabled { background-color: #eceff3; color: %(DISABLED)s; border-color: #d9dee6; }

QTableView, QTableWidget, QTreeView, QTreeWidget, QListView, QListWidget {
    background-color: %(BASE)s; alternate-background-color: %(ALT)s; color: %(TEXT)s;
    gridline-color: #e3e8ef; border: 1px solid %(BORDER)s;
    selection-background-color: %(ACCENT)s; selection-color: white;
}
QTableView::item:selected, QTableWidget::item:selected, QTreeView::item:selected,
QListView::item:selected, QListWidget::item:selected {
    background-color: %(ACCENT)s; color: white;
}
QTableView::item:selected:!active, QTableWidget::item:selected:!active, QTreeView::item:selected:!active,
QListView::item:selected:!active, QListWidget::item:selected:!active {
    background-color: %(ACCENT)s; color: white;
}
QTableCornerButton::section { background-color: %(HEADER_BG)s; border: 0; }
QHeaderView { background-color: %(HEADER_BG)s; }
QHeaderView::section {
    background-color: %(HEADER_BG)s; color: %(TEXT)s; padding: 4px 6px; border: 0;
    border-right: 1px solid #d5dbe4; border-bottom: 1px solid #d5dbe4; font-weight: 600;
}

QMenuBar { background-color: %(BG)s; color: %(TEXT)s; }
QMenuBar::item { background: transparent; color: %(TEXT)s; padding: 4px 10px; }
QMenuBar::item:selected { background-color: #dce7f4; color: %(TEXT)s; }
QMenu { background-color: %(BASE)s; color: %(TEXT)s; border: 1px solid %(BORDER)s; }
QMenu::item { background-color: transparent; color: %(TEXT)s; padding: 5px 24px; }
QMenu::item:selected { background-color: %(ACCENT)s; color: white; }
QMenu::item:disabled { color: %(DISABLED)s; }
QMenu::separator { height: 1px; background: %(BORDER)s; margin: 3px 6px; }

QStatusBar { color: %(TEXT)s; }
QStatusBar QLabel { color: %(TEXT)s; }
QToolTip { background-color: #ffffe1; color: #000000; border: 1px solid #767676; padding: 2px; }

QTabWidget::pane { border: 1px solid %(BORDER)s; background-color: %(BG)s; }
QTabBar::tab { background-color: %(HEADER_BG)s; color: %(TEXT)s; padding: 5px 12px;
               border: 1px solid %(BORDER)s; }
QTabBar::tab:selected { background-color: %(BASE)s; }

QScrollArea { background-color: transparent; border: 0; }
QScrollBar:vertical { background: #eef1f5; width: 14px; margin: 0; }
QScrollBar:horizontal { background: #eef1f5; height: 14px; margin: 0; }
QScrollBar::handle:vertical, QScrollBar::handle:horizontal { background: #b7c1ce; border-radius: 4px; min-height: 24px; min-width: 24px; }
QScrollBar::handle:hover { background: #9aa8ba; }
QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; }
QProgressBar { background-color: %(BASE)s; color: %(TEXT)s; border: 1px solid %(BORDER)s; text-align: center; }
QProgressBar::chunk { background-color: %(ACCENT)s; }
""" % {
    "BG": BG, "BASE": BASE, "ALT": ALT, "TEXT": TEXT, "TEXT_MUTED": TEXT_MUTED,
    "BORDER": BORDER, "HEADER_BG": HEADER_BG, "ACCENT": ACCENT, "DISABLED": DISABLED,
}


def assets_dir() -> str:
    return os.path.join(resource_dir(), "assets")


def icon_path(name: str) -> str:
    return os.path.join(assets_dir(), "icons", name)


def _light_palette() -> QPalette:
    p = QPalette()
    c = QColor
    for group in (QPalette.Active, QPalette.Inactive):
        p.setColor(group, QPalette.Window, c(BG))
        p.setColor(group, QPalette.WindowText, c(TEXT))
        p.setColor(group, QPalette.Base, c(BASE))
        p.setColor(group, QPalette.AlternateBase, c(ALT))
        p.setColor(group, QPalette.Text, c(TEXT))
        p.setColor(group, QPalette.Button, c("#e9eef5"))
        p.setColor(group, QPalette.ButtonText, c(TEXT))
        p.setColor(group, QPalette.BrightText, c("#ffffff"))
        p.setColor(group, QPalette.ToolTipBase, c("#ffffe1"))
        p.setColor(group, QPalette.ToolTipText, c("#000000"))
        p.setColor(group, QPalette.Highlight, c(ACCENT))
        p.setColor(group, QPalette.HighlightedText, c("#ffffff"))
        p.setColor(group, QPalette.PlaceholderText, c("#7d8795"))
        p.setColor(group, QPalette.Link, c("#1a5fb4"))
    p.setColor(QPalette.Disabled, QPalette.Window, c(BG))
    p.setColor(QPalette.Disabled, QPalette.WindowText, c(DISABLED))
    p.setColor(QPalette.Disabled, QPalette.Base, c("#eceff3"))
    p.setColor(QPalette.Disabled, QPalette.Text, c(DISABLED))
    p.setColor(QPalette.Disabled, QPalette.Button, c("#eceff3"))
    p.setColor(QPalette.Disabled, QPalette.ButtonText, c(DISABLED))
    p.setColor(QPalette.Disabled, QPalette.Highlight, c("#9fb6d1"))
    p.setColor(QPalette.Disabled, QPalette.HighlightedText, c("#ffffff"))
    return p


def apply_theme(app: QApplication) -> None:
    app.setStyle("Fusion")
    # nao seguir o modo escuro do Windows (Qt >= 6.8)
    try:
        app.styleHints().setColorScheme(Qt.ColorScheme.Light)
    except Exception:
        pass
    app.setPalette(_light_palette())
    app.setFont(QFont("Segoe UI", 9))
    app.setStyleSheet(STYLE)
    ico = os.path.join(assets_dir(), "Consultas_Icon.ico")
    if os.path.isfile(ico):
        app.setWindowIcon(QIcon(ico))
