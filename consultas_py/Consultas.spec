# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec - Consultas (Win64, onedir, sem console).
#   pyinstaller --noconfirm --clean Consultas.spec
# Saida: dist\Consultas\Consultas.exe
import os

from PyInstaller.utils.hooks import collect_data_files, collect_submodules

ROOT = os.path.abspath(SPECPATH)

# fbclient.dll + dependencias (firebird.msg, icu*, vcruntime/msvcp) ficam em <app>\_internal\dll
# (app.db.detect_fb procura em resource_dir()\dll\fbclient.dll)
datas = [
    (os.path.join(ROOT, "assets"), "assets"),
    (os.path.join(ROOT, "dll"), "dll"),
]

datas += collect_data_files("reportlab")         # fontes padrao etc.

hiddenimports = []
hiddenimports += collect_submodules("reportlab")  # reportlab.graphics.barcode.* sao importados dinamicamente
hiddenimports += collect_submodules("firebird")  # firebird-driver / firebird-base (namespace packages)
hiddenimports += collect_submodules("app")       # modulos importados dinamicamente

# Qt: so Widgets/Gui/Core sao usados; exclui o resto para reduzir tamanho
excludes = [
    "PySide6.QtWebEngineCore", "PySide6.QtWebEngineWidgets", "PySide6.QtWebEngineQuick",
    "PySide6.QtWebChannel", "PySide6.QtWebSockets", "PySide6.QtWebView",
    "PySide6.QtQml", "PySide6.QtQuick", "PySide6.QtQuickWidgets", "PySide6.QtQuick3D",
    "PySide6.QtQuickControls2", "PySide6.QtPdf", "PySide6.QtPdfWidgets",
    "PySide6.Qt3DCore", "PySide6.Qt3DRender", "PySide6.Qt3DInput", "PySide6.Qt3DLogic",
    "PySide6.Qt3DAnimation", "PySide6.Qt3DExtras", "PySide6.QtMultimedia",
    "PySide6.QtMultimediaWidgets", "PySide6.QtCharts", "PySide6.QtDataVisualization",
    "PySide6.QtBluetooth", "PySide6.QtNfc", "PySide6.QtSensors", "PySide6.QtSerialPort",
    "PySide6.QtSerialBus", "PySide6.QtPositioning", "PySide6.QtLocation",
    "PySide6.QtRemoteObjects", "PySide6.QtScxml", "PySide6.QtSql", "PySide6.QtTest",
    "PySide6.QtDesigner", "PySide6.QtHelp", "PySide6.QtSvg", "PySide6.QtSvgWidgets",
    "PySide6.QtOpenGL", "PySide6.QtOpenGLWidgets", "PySide6.QtNetwork",
    "PySide6.QtTextToSpeech", "PySide6.QtSpatialAudio", "PySide6.QtGraphs",
    "tkinter", "matplotlib", "numpy", "scipy", "pandas", "PIL.ImageTk",
]

a = Analysis(
    [os.path.join(ROOT, "main.py")],
    pathex=[ROOT],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=excludes,
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="Consultas",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=os.path.join(ROOT, "assets", "Consultas_Icon.ico"),
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    name="Consultas",
)
