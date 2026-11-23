"""Consultas - ponto de entrada.

Uso:  pip install -r requirements.txt  &&  python main.py
"""
from __future__ import annotations

import os
import sys

# garante que o pacote 'app' seja encontrado ao executar de qualquer pasta
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def selftest(out_path: str) -> int:
    """Verifica recursos empacotados (assets, fbclient.dll, driver, config) e grava o resultado em arquivo."""
    import traceback

    lines = []
    ok = True
    try:
        from app.config import app_dir, config_path, resource_dir
        from app.db import detect_fb
        from app.ui.theme import assets_dir

        lines.append(f"frozen={getattr(sys, 'frozen', False)}")
        lines.append(f"app_dir={app_dir()}")
        lines.append(f"resource_dir={resource_dir()}")
        lines.append(f"config_path={config_path()}")
        icon_ok = os.path.isfile(os.path.join(assets_dir(), "Consultas_Icon.ico"))
        lines.append(f"assets_ok={icon_ok}")
        lib = detect_fb.resolver_cliente_fb("")
        lines.append(f"fbclient={lib}")
        import firebird.driver  # noqa: F401
        from firebird.driver import driver_config, get_api, load_api
        driver_config.fb_client_library.value = lib
        load_api(lib)
        get_api()
        lines.append("firebird_driver=ok (fbclient carregado)")
        import reportlab.pdfgen.canvas  # noqa: F401
        import app.ui.main_window  # noqa: F401
        lines.append("imports=ok")
        ok = icon_ok and bool(lib)
    except Exception:
        ok = False
        lines.append(traceback.format_exc())
    lines.append("RESULT=" + ("OK" if ok else "FAIL"))
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return 0 if ok else 1


def main() -> int:
    if len(sys.argv) >= 3 and sys.argv[1] == "--selftest":
        return selftest(sys.argv[2])
    from PySide6.QtCore import QTimer
    from PySide6.QtWidgets import QApplication

    from app.config import load_config
    from app.db.pool import ConnectionManager
    from app.ui.main_window import MainWindow
    from app.ui.theme import apply_theme

    qapp = QApplication(sys.argv)
    qapp.setApplicationName("Consultas")
    apply_theme(qapp)

    cfg = load_config()
    manager = ConnectionManager()
    win = MainWindow(cfg, manager)
    win.show()

    # Ao abrir: dialogo de conexao conforme o modo (uma base / varias bases)
    if cfg.ask_on_start:
        QTimer.singleShot(0, win.connect_flow)
    else:
        QTimer.singleShot(0, lambda: (manager.connect_all(cfg.active_bases()), win.refresh_status()))
    return qapp.exec()


if __name__ == "__main__":
    sys.exit(main())
