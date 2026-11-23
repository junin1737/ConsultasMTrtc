"""Canvas ReportLab com coordenadas em 'pixels' (96 dpi, origem no topo-esquerdo),
espelhando o TCanvas usado nos relatorios Delphi (794 px = largura A4).
"""
from __future__ import annotations

from typing import Sequence, Tuple

from reportlab.lib.pagesizes import A4
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.pdfgen import canvas as rl_canvas

PX = 0.75  # 1 px = 0.75 pt


class PxCanvas:
    def __init__(self, path: str, title: str = ""):
        self.c = rl_canvas.Canvas(path, pagesize=A4)
        if title:
            self.c.setTitle(title)
        self.page_w_px = A4[0] / PX
        self.page_h_px = A4[1] / PX
        self.font = "Helvetica"
        self.size = 8.0
        self.bold = False
        self.color = (0, 0, 0)
        self.set_font(8, False)

    # --- pagina ---------------------------------------------------------
    def new_page(self) -> None:
        self.c.showPage()
        self.set_font(self.size, self.bold)

    def save(self) -> None:
        self.c.save()

    # --- helpers ----------------------------------------------------------
    def _y(self, y: float) -> float:
        return (self.page_h_px - y) * PX

    def set_font(self, size: float, bold: bool = False) -> None:
        self.size, self.bold = size, bold
        self.font = "Helvetica-Bold" if bold else "Helvetica"
        self.c.setFont(self.font, size)

    def set_color(self, rgb: Tuple[float, float, float]) -> None:
        self.color = rgb
        self.c.setFillColorRGB(*rgb)
        self.c.setStrokeColorRGB(*rgb)

    def text_width(self, s: str) -> float:
        """Largura em px."""
        return stringWidth(s, self.font, self.size) / PX

    def text(self, x: float, y: float, s: str) -> None:
        """Texto com o topo da celula em y (como TextOut)."""
        if not s:
            return
        self.c.setFillColorRGB(*self.color)
        baseline = y + self.size * 1.333 * 0.85
        self.c.drawString(x * PX, self._y(baseline), s)

    def text_right(self, x_right: float, y: float, s: str) -> None:
        self.text(x_right - self.text_width(s), y, s)

    def text_center(self, x1: float, x2: float, y: float, s: str) -> None:
        self.text(x1 + ((x2 - x1) - self.text_width(s)) / 2, y, s)

    def fit(self, s: str, max_px: float) -> str:
        """Corta o texto para caber em max_px."""
        if self.text_width(s) <= max_px:
            return s
        while s and self.text_width(s + "...") > max_px:
            s = s[:-1]
        return s + "..."

    def hline(self, x1: float, x2: float, y: float, dashed: bool = False) -> None:
        self.c.setStrokeColorRGB(0, 0, 0)
        self.c.setLineWidth(0.75)
        self.c.setDash(3, 3) if dashed else self.c.setDash()
        self.c.line(x1 * PX, self._y(y), x2 * PX, self._y(y))
        self.c.setDash()

    def box(self, x1: float, y1: float, x2: float, y2: float, width: float = 0.75) -> None:
        self.c.setStrokeColorRGB(0, 0, 0)
        self.c.setLineWidth(width)
        self.c.rect(x1 * PX, self._y(y2), (x2 - x1) * PX, (y2 - y1) * PX, stroke=1, fill=0)

    def fill(self, x1: float, y1: float, x2: float, y2: float, rgb=(0, 0, 0)) -> None:
        self.c.setFillColorRGB(*rgb)
        self.c.rect(x1 * PX, self._y(y2), (x2 - x1) * PX, (y2 - y1) * PX, stroke=0, fill=1)
        self.c.setFillColorRGB(*self.color)

    def polygon(self, pts: Sequence[Tuple[float, float]], rgb=(0, 0, 0)) -> None:
        p = self.c.beginPath()
        p.moveTo(pts[0][0] * PX, self._y(pts[0][1]))
        for x, y in pts[1:]:
            p.lineTo(x * PX, self._y(y))
        p.close()
        self.c.setFillColorRGB(*rgb)
        self.c.setStrokeColorRGB(*rgb)
        self.c.drawPath(p, stroke=1, fill=1)
        self.c.setFillColorRGB(*self.color)
        self.c.setStrokeColorRGB(0, 0, 0)
