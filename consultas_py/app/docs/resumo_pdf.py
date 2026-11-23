"""PDF-resumo de documentos (orcamento / DAV / compra / nota / O.S.) a partir de um DetailData.

Substitui o relatorio impresso do Delphi (UDavRelatorioImpressao.pas) por um layout simples e legivel:
cabecalho com os campos, memos e tabelas de itens com paginacao.

Formatos de papel (`formato`):
  * "a4"    - folha A4 retrato (210 x 297 mm)
  * "meia"  - meia folha A4 = A5 paisagem (210 x 148 mm)
  * "80mm"  - bobina termica / cupom de 80 mm, pagina unica com altura variavel
"""
from __future__ import annotations

import datetime as _dt
import io
import re
from dataclasses import dataclass
from typing import Callable, List, Optional, Tuple

from reportlab.lib.pagesizes import A4, landscape

from app.docs.pxcanvas import PX, PxCanvas
from app.docs.viewer import open_file, temp_pdf_path
from app.modules.spec import RIGHT_ALIGNED, ColumnSpec, DetailData

FORMATO_A4 = "a4"
FORMATO_MEIA = "meia"
FORMATO_80MM = "80mm"
FORMATOS: List[Tuple[str, str]] = [
    (FORMATO_A4, "Folha A4"),
    (FORMATO_MEIA, "Meia folha (A5 paisagem)"),
    (FORMATO_80MM, "Modelo 80mm (cupom / térmica)"),
]

_MM = 72.0 / 25.4
A5_PAISAGEM = landscape((148 * _MM, 210 * _MM))
_NUMERICAS = {"money", "qty", "num"}


@dataclass(frozen=True)
class _Layout:
    margin: int
    row_h: int
    fs: float          # fonte base
    fs_titulo: float
    fs_secao: float
    cols: int          # colunas de campos (0 = usa data.columns)
    lab_w: int
    rodape: int        # distancia do rodape ate o fim da pagina
    page: Tuple[float, float]


_LAYOUTS = {
    FORMATO_A4: _Layout(40, 17, 8.5, 16, 11, 0, 118, 30, A4),
    FORMATO_MEIA: _Layout(26, 14, 7.5, 13, 9.5, 3, 84, 22, A5_PAISAGEM),
}


def _wrap(c: PxCanvas, texto: str, largura: float) -> List[str]:
    linhas: List[str] = []
    for par in (texto or "").replace("\r", "").split("\n"):
        atual = ""
        for palavra in par.split(" "):
            # palavra maior que a largura: quebra por caractere
            while c.text_width(palavra) > largura and len(palavra) > 1:
                n = len(palavra)
                while n > 1 and c.text_width(palavra[:n]) > largura:
                    n -= 1
                if atual:
                    linhas.append(atual)
                    atual = ""
                linhas.append(palavra[:n])
                palavra = palavra[n:]
            teste = (atual + " " + palavra).strip()
            if c.text_width(teste) <= largura:
                atual = teste
            else:
                if atual:
                    linhas.append(atual)
                atual = palavra
        linhas.append(atual)
    return linhas or [""]


def _safe(s: str) -> str:
    """Helvetica padrao so cobre latin-1."""
    return s.encode("latin-1", "replace").decode("latin-1")


def _eh_valor(v: str) -> bool:
    return str(v or "").startswith("R$")


# ---------------------------------------------------------------------------------------------
# A4 e meia folha (paginado)
# ---------------------------------------------------------------------------------------------
def _gerar_paginado(data: DetailData, path: str, titulo: str, L: _Layout) -> str:
    c = PxCanvas(path, titulo, L.page)
    M = L.margin
    largura = c.page_w_px - 2 * M
    altura = c.page_h_px
    state = {"y": float(M), "page": 1}
    gap = L.row_h - 2  # altura de linha de memo

    def rodape() -> None:
        c.set_font(7, False)
        c.set_color((0.4, 0.4, 0.4))
        c.text(M, altura - L.rodape, f"Consultas - gerado em {_dt.datetime.now():%d/%m/%Y %H:%M}")
        c.text_right(c.page_w_px - M, altura - L.rodape, f"Página {state['page']}")
        c.set_color((0, 0, 0))

    def garantir(h: float) -> bool:
        if state["y"] + h > altura - L.rodape - 20:
            rodape()
            c.new_page()
            state["page"] += 1
            state["y"] = float(M)
            return True
        return False

    # titulo
    c.set_font(L.fs_titulo, True)
    c.text(M, state["y"], _safe(titulo))
    state["y"] += L.fs_titulo * 1.333 + 10
    c.hline(M, M + largura, state["y"])
    state["y"] += 8

    # campos em N colunas (todos os campos do documento)
    cols = L.cols or min(2, max(1, data.columns))  # A4 retrato: no maximo 2 colunas
    col_w = largura / cols
    lab_w = L.lab_w
    # monta as linhas: campos "largos" (ex.: Cliente) ocupam a linha inteira
    linhas_campos: List[List[Tuple[str, str, float]]] = []
    atual: List[Tuple[str, str, float]] = []
    for rot, val in data.fields:
        if rot in data.wide_fields:
            if atual:
                linhas_campos.append(atual)
                atual = []
            linhas_campos.append([(rot, val, largura)])
            continue
        atual.append((rot, val, col_w))
        if len(atual) >= cols:
            linhas_campos.append(atual)
            atual = []
    if atual:
        linhas_campos.append(atual)
    for grupo in linhas_campos:
        garantir(L.row_h)
        x = float(M)
        for rot, val, w in grupo:
            c.set_font(L.fs, True)
            c.text(x, state["y"], _safe(c.fit(rot + ":", lab_w - 4)))
            c.set_font(L.fs, False)
            c.text(x + lab_w, state["y"], _safe(c.fit(str(val), w - lab_w - 8)))
            x += w
        state["y"] += L.row_h + 1

    # memos
    for rot, txt in data.memos:
        if not (txt or "").strip():
            continue
        state["y"] += 5
        garantir(L.row_h * 2 + 4)
        c.set_font(L.fs + 0.5, True)
        c.text(M, state["y"], _safe(rot + ":"))
        state["y"] += L.row_h
        c.set_font(L.fs, False)
        for linha in _wrap(c, txt, largura):
            garantir(gap)
            c.text(M, state["y"], _safe(linha))
            state["y"] += gap

    # secoes
    for sec in data.sections:
        state["y"] += 12
        visiveis = [col for col in sec.columns if not col.hidden]
        total_w = sum(col.width or 100 for col in visiveis) or 1
        esc = largura / total_w
        larguras = [(col.width or 100) * esc for col in visiveis]

        def cabecalho_tabela() -> None:
            garantir(L.row_h * 2 + 6)
            c.fill(M, state["y"] - 2, M + largura, state["y"] + L.row_h, (0.9, 0.9, 0.9))
            c.set_font(L.fs - 0.5, True)
            x = M
            for col, w in zip(visiveis, larguras):
                if col.kind in RIGHT_ALIGNED:
                    c.text_right(x + w - 4, state["y"], _safe(col.title))
                else:
                    c.text(x + 4, state["y"], _safe(col.title))
                x += w
            state["y"] += L.row_h + 3

        garantir(L.row_h * 3 + 20)
        c.set_font(L.fs_secao, True)
        c.text(M, state["y"], _safe(sec.title))
        state["y"] += L.fs_secao * 1.333 + 8
        cabecalho_tabela()
        for r in sec.rows:
            if garantir(L.row_h):
                cabecalho_tabela()
            c.set_font(L.fs - 0.5, False)
            x = M
            for col, w in zip(visiveis, larguras):
                txt = _safe(c.fit(col.format(r.get(col.key)), w - 8))
                if col.kind in RIGHT_ALIGNED:
                    c.text_right(x + w - 4, state["y"], txt)
                else:
                    c.text(x + 4, state["y"], txt)
                x += w
            state["y"] += L.row_h
            c.hline(M, M + largura, state["y"] - 2)
    rodape()
    c.save()
    return path


# ---------------------------------------------------------------------------------------------
# Cupom 80 mm (pagina unica, altura calculada)
# ---------------------------------------------------------------------------------------------
_W80_PT = 80 * _MM
_M80 = 8       # margem em px
_FS80 = 7.5
_LH80 = 11     # altura de linha (px)


def _render_cupom(c: PxCanvas, data: DetailData, titulo: str) -> float:
    """Desenha o cupom e devolve o y final (px). Usado em duas passadas (medir e desenhar)."""
    M = _M80
    largura = c.page_w_px - 2 * M
    y = float(M)

    def linha_sep(pontilhada: bool = True) -> None:
        nonlocal y
        c.hline(M, M + largura, y + 2, dashed=pontilhada)
        y += 7

    def par(rot: str, val: str, negrito_valor: bool = False) -> None:
        """'Rotulo: valor' com quebra; valor alinhado a direita quando cabe na mesma linha."""
        nonlocal y
        rot_t = _safe(rot + ":")
        val_t = _safe(str(val))
        c.set_font(_FS80, True)
        wr = c.text_width(rot_t)
        c.set_font(_FS80, negrito_valor)
        if wr + 6 + c.text_width(val_t) <= largura:
            c.set_font(_FS80, True)
            c.text(M, y, rot_t)
            c.set_font(_FS80, negrito_valor)
            c.text_right(M + largura, y, val_t)
            y += _LH80
            return
        c.set_font(_FS80, True)
        c.text(M, y, rot_t)
        y += _LH80
        c.set_font(_FS80, negrito_valor)
        for ln in _wrap(c, val_t, largura - 6):
            c.text(M + 6, y, ln)
            y += _LH80

    # titulo
    c.set_font(10, True)
    for ln in _wrap(c, _safe(titulo), largura):
        c.text_center(M, M + largura, y, ln)
        y += 14
    y += 2
    linha_sep(False)

    # campos (valores monetarios ficam para o bloco de totais)
    normais = [(r, v) for r, v in data.fields if not _eh_valor(v) and str(v or "").strip() != ""]
    totais = [(r, v) for r, v in data.fields if _eh_valor(v)]
    for r, v in normais:
        par(r, v)

    # memos
    for rot, txt in data.memos:
        if not (txt or "").strip():
            continue
        y += 3
        linha_sep()
        c.set_font(_FS80, True)
        c.text(M, y, _safe(rot + ":"))
        y += _LH80
        c.set_font(_FS80, False)
        for ln in _wrap(c, _safe(txt), largura):
            c.text(M, y, ln)
            y += _LH80

    # secoes
    for sec in data.sections:
        y += 3
        linha_sep(False)
        c.set_font(8.5, True)
        c.text(M, y, _safe(sec.title.upper()))
        y += 14
        visiveis = [col for col in sec.columns if not col.hidden]
        desc = [col for col in visiveis if col.kind not in _NUMERICAS]
        nums = [col for col in visiveis if col.kind in _NUMERICAS]
        for r in sec.rows:
            partes = [col.format(r.get(col.key)) for col in desc]
            c.set_font(_FS80, True)
            for ln in _wrap(c, _safe(" - ".join(p for p in partes if p)), largura):
                c.text(M, y, ln)
                y += _LH80
            c.set_font(_FS80, False)
            if nums:
                txt = "  ".join(f"{col.title} {col.format(r.get(col.key))}" for col in nums
                                if r.get(col.key) is not None)
                for ln in _wrap(c, _safe(txt), largura - 6):
                    c.text(M + 6, y, ln)
                    y += _LH80
            c.hline(M, M + largura, y + 1, dashed=True)
            y += 4

    # totais
    if totais:
        y += 3
        linha_sep(False)
        c.set_font(8.5, True)
        c.text(M, y, "TOTAIS")
        y += 14
        for i, (r, v) in enumerate(totais):
            par(r, v, negrito_valor=(i == len(totais) - 1))

    y += 3
    linha_sep()
    c.set_font(6.5, False)
    c.set_color((0.35, 0.35, 0.35))
    c.text_center(M, M + largura, y, f"Consultas - {_dt.datetime.now():%d/%m/%Y %H:%M}")
    c.set_color((0, 0, 0))
    y += 12
    return y + M


def _gerar_cupom(data: DetailData, path: str, titulo: str) -> str:
    # 1a passada: mede a altura necessaria numa pagina "infinita"
    medida = PxCanvas(io.BytesIO(), titulo, (_W80_PT, 30000 * PX))
    altura = _render_cupom(medida, data, titulo)
    # 2a passada: pagina com a altura exata
    c = PxCanvas(path, titulo, (_W80_PT, max(altura, 120) * PX))
    _render_cupom(c, data, titulo)
    c.save()
    return path


# ---------------------------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------------------------
def gerar_resumo(data: DetailData, path: str, titulo: str = "", formato: str = FORMATO_A4) -> str:
    titulo = titulo or data.title
    if formato == FORMATO_80MM:
        return _gerar_cupom(data, path, titulo)
    return _gerar_paginado(data, path, titulo, _LAYOUTS.get(formato, _LAYOUTS[FORMATO_A4]))


def escolher_formato(parent=None) -> Optional[str]:
    """Dialogo 'Imprimir': escolhe A4 / meia folha / 80mm. Devolve a chave do formato ou None (cancelado).

    A ultima escolha e lembrada (QSettings) e vem pre-selecionada na proxima vez.
    """
    from PySide6.QtCore import QSettings
    from PySide6.QtWidgets import (
        QApplication, QButtonGroup, QDialog, QDialogButtonBox, QLabel, QRadioButton, QVBoxLayout,
    )

    if parent is None:
        parent = QApplication.activeWindow()
    st = QSettings("Consultas", "Consultas")
    ultimo = str(st.value("print/formato", FORMATO_A4))

    dlg = QDialog(parent)
    dlg.setWindowTitle("Imprimir")
    lay = QVBoxLayout(dlg)
    lay.addWidget(QLabel("Escolha o formato de impressão:"))
    grupo = QButtonGroup(dlg)
    botoes = {}
    for chave, rotulo in FORMATOS:
        rb = QRadioButton(rotulo)
        rb.setChecked(chave == ultimo)
        grupo.addButton(rb)
        botoes[chave] = rb
        lay.addWidget(rb)
    if not any(b.isChecked() for b in botoes.values()):
        botoes[FORMATO_A4].setChecked(True)
    bb = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
    bb.button(QDialogButtonBox.Ok).setText("Gerar PDF")
    bb.button(QDialogButtonBox.Cancel).setText("Cancelar")
    bb.accepted.connect(dlg.accept)
    bb.rejected.connect(dlg.reject)
    lay.addWidget(bb)
    if dlg.exec() != QDialog.Accepted:
        return None
    escolhido = next((k for k, b in botoes.items() if b.isChecked()), FORMATO_A4)
    st.setValue("print/formato", escolhido)
    return escolhido


def acao_imprimir(data: DetailData, prefixo: str, titulo: str,
                  escolher: bool = False) -> Tuple[str, Callable[[], None], bool]:
    """Acao 'Imprimir / Ver PDF' para um DetailData. Com `escolher=True` pergunta o formato antes."""

    def _run() -> None:
        formato = FORMATO_A4
        if escolher:
            formato = escolher_formato()
            if formato is None:
                return
        nome = re.sub(r"[^\w\-]+", "_", f"{prefixo}_{formato}")
        path = gerar_resumo(data, temp_pdf_path(nome), titulo, formato)
        open_file(path)

    return ("Imprimir / Ver PDF", _run, True)
