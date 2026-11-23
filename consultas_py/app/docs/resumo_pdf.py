"""PDF-resumo de documentos (orcamento / DAV / compra / nota) a partir de um DetailData.

Substitui o relatorio impresso do Delphi (UDavRelatorioImpressao.pas) por um layout simples e legivel:
cabecalho com os campos, observacao e tabelas de itens com paginacao.
"""
from __future__ import annotations

import datetime as _dt
import re
from typing import Callable, List, Tuple

from app.docs.pxcanvas import PxCanvas
from app.docs.viewer import open_file, temp_pdf_path
from app.modules.spec import RIGHT_ALIGNED, ColumnSpec, DetailData

MARGIN = 40
ROW_H = 17


def _wrap(c: PxCanvas, texto: str, largura: float) -> List[str]:
    linhas: List[str] = []
    for par in (texto or "").replace("\r", "").split("\n"):
        atual = ""
        for palavra in par.split(" "):
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


def gerar_resumo(data: DetailData, path: str, titulo: str = "") -> str:
    titulo = titulo or data.title
    c = PxCanvas(path, titulo)
    largura = c.page_w_px - 2 * MARGIN
    altura = c.page_h_px
    state = {"y": float(MARGIN), "page": 1}

    def rodape() -> None:
        c.set_font(7, False)
        c.set_color((0.4, 0.4, 0.4))
        c.text(MARGIN, altura - 30, f"Consultas - gerado em {_dt.datetime.now():%d/%m/%Y %H:%M}")
        c.text_right(c.page_w_px - MARGIN, altura - 30, f"Página {state['page']}")
        c.set_color((0, 0, 0))

    def garantir(h: float) -> bool:
        if state["y"] + h > altura - 50:
            rodape()
            c.new_page()
            state["page"] += 1
            state["y"] = float(MARGIN)
            return True
        return False

    # titulo
    c.set_font(16, True)
    c.text(MARGIN, state["y"], _safe(titulo))
    state["y"] += 30
    c.hline(MARGIN, MARGIN + largura, state["y"])
    state["y"] += 10

    # campos em duas colunas
    cols = max(1, data.columns)
    col_w = largura / cols
    lab_w = 118
    campos = [(a, b) for a, b in data.fields if b != "" or True]
    for i in range(0, len(campos), cols):
        grupo = campos[i:i + cols]
        garantir(ROW_H)
        for j, (rot, val) in enumerate(grupo):
            x = MARGIN + j * col_w
            c.set_font(8.5, True)
            c.text(x, state["y"], _safe(rot + ":"))
            c.set_font(8.5, False)
            c.text(x + lab_w, state["y"], _safe(c.fit(str(val), col_w - lab_w - 8)))
        state["y"] += ROW_H + 2

    # memos
    for rot, txt in data.memos:
        if not (txt or "").strip():
            continue
        state["y"] += 6
        garantir(40)
        c.set_font(9, True)
        c.text(MARGIN, state["y"], _safe(rot + ":"))
        state["y"] += ROW_H
        c.set_font(8.5, False)
        for linha in _wrap(c, txt, largura):
            garantir(ROW_H)
            c.text(MARGIN, state["y"], _safe(linha))
            state["y"] += 15

    # secoes
    for sec in data.sections:
        state["y"] += 14
        visiveis = [col for col in sec.columns if not col.hidden]
        total_w = sum(col.width or 100 for col in visiveis) or 1
        esc = largura / total_w
        larguras = [(col.width or 100) * esc for col in visiveis]

        def cabecalho_tabela() -> None:
            garantir(ROW_H * 2 + 6)
            c.fill(MARGIN, state["y"] - 2, MARGIN + largura, state["y"] + ROW_H, (0.9, 0.9, 0.9))
            c.set_font(8, True)
            x = MARGIN
            for col, w in zip(visiveis, larguras):
                if col.kind in RIGHT_ALIGNED:
                    c.text_right(x + w - 4, state["y"], _safe(col.title))
                else:
                    c.text(x + 4, state["y"], _safe(col.title))
                x += w
            state["y"] += ROW_H + 3

        garantir(ROW_H * 3 + 20)
        c.set_font(11, True)
        c.text(MARGIN, state["y"], _safe(sec.title))
        state["y"] += 22
        cabecalho_tabela()
        c.set_font(8, False)
        for r in sec.rows:
            if garantir(ROW_H):
                cabecalho_tabela()
            c.set_font(8, False)
            x = MARGIN
            for col, w in zip(visiveis, larguras):
                txt = _safe(c.fit(col.format(r.get(col.key)), w - 8))
                if col.kind in RIGHT_ALIGNED:
                    c.text_right(x + w - 4, state["y"], txt)
                else:
                    c.text(x + 4, state["y"], txt)
                x += w
            state["y"] += ROW_H
            c.hline(MARGIN, MARGIN + largura, state["y"] - 2)
    rodape()
    c.save()
    return path


def acao_imprimir(data: DetailData, prefixo: str, titulo: str) -> Tuple[str, Callable[[], None], bool]:
    """Acao 'Imprimir / Ver PDF' para um DetailData."""

    def _run() -> None:
        nome = re.sub(r"[^\w\-]+", "_", prefixo)
        path = gerar_resumo(data, temp_pdf_path(nome), titulo)
        open_file(path)

    return ("Imprimir / Ver PDF", _run, True)
