"""Boleto em PDF (port de TRenderBoleto em UBoletoImpressao.pas) - ReportLab, sem FastReport."""
from __future__ import annotations

from typing import List

from app.docs.pxcanvas import PxCanvas
from app.maps.receber import BoletoDados
from app.util import fmt

PAGE_W = 794
MARGEM = 24
COL_VALOR = 178
ALT_HEADER = 32
ALT_LINHA = 24
ALT_LINHA_ALTA = 72
ALT_BARCODE = 58
# TColor do Delphi e BGR: $0000A060 -> RGB(0x60,0xA0,0x00); $00804000 -> RGB(0x00,0x40,0x80)
SICOOB_VERDE = (0x60 / 255, 0xA0 / 255, 0x00 / 255)
SICOOB_AZUL = (0x00 / 255, 0x40 / 255, 0x80 / 255)

ITF = {
    "0": "nnwwn", "1": "wnnnw", "2": "nwnnw", "3": "wwnnn", "4": "nnwnw",
    "5": "wnwnn", "6": "nwwnn", "7": "nnnww", "8": "wnnwn", "9": "nwnwn",
}


class _Render:
    def __init__(self, pdf: PxCanvas):
        self.p = pdf
        self.w = PAGE_W - MARGEM * 2
        self.direita = PAGE_W - MARGEM
        self.col_valor = MARGEM + self.w - COL_VALOR

    # --- primitivas ------------------------------------------------------
    def celula(self, r, rotulo, valor, negrito=True, direita=False, alt_valor=9):
        x1, y1, x2, y2 = r
        p = self.p
        p.box(x1, y1, x2, y2)
        p.set_font(6, False)
        p.text(x1 + 3, y1 + 2, rotulo)
        p.set_font(8, negrito)
        valor = p.fit(valor or "", (x2 - x1) - 6)
        if direita:
            p.text_right(x2 - 3, y1 + 2 + alt_valor, valor)
        else:
            p.text(x1 + 3, y1 + 2 + alt_valor, valor)

    def celula_instrucoes(self, r, rotulo, textos: List[str]):
        x1, y1, x2, y2 = r
        p = self.p
        p.box(x1, y1, x2, y2)
        p.set_font(6, False)
        p.text(x1 + 3, y1 + 2, rotulo)
        y = y1 + 2 + 10
        p.set_font(7, False)
        for t in textos:
            t = (t or "").strip()
            if not t:
                continue
            p.text(x1 + 3, y, p.fit(t, (x2 - x1) - 6))
            y += 11
            if y > y2 - 12:
                break

    def logo_banco(self, r, d: BoletoDados):
        x1, y1, x2, y2 = r
        p = self.p
        p.box(*r)
        if fmt.digitos(d.banco_codigo) == "756":  # Sicoob
            cx = x1 + 28
            cy = y1 + (y2 - y1) / 2
            t = 10
            for dx, dy in ((0, 0), (-14, 4), (14, 4)):
                p.polygon([(cx + dx, cy - t + dy), (cx + dx - t, cy + t / 2 + dy), (cx + dx + t, cy + t / 2 + dy)],
                          SICOOB_VERDE)
            p.set_font(11, True)
            p.set_color(SICOOB_AZUL)
            p.text(x1 + 52, y1 + 8, "SICOOB")
            p.set_color((0, 0, 0))
        else:
            nome = d.banco_nome or "Banco"
            p.set_font(10, True)
            p.text(x1 + 8, y1 + 9, nome[:22])

    def cabecalho(self, top, d: BoletoDados) -> float:
        p = self.p
        logo = (MARGEM, top, MARGEM + 168, top + ALT_HEADER)
        cod = (logo[2], top, logo[2] + 58, top + ALT_HEADER)
        lin = (cod[2], top, self.direita, top + ALT_HEADER)
        self.logo_banco(logo, d)
        p.box(*cod)
        p.set_font(14, True)
        p.text_center(cod[0], cod[2], top + 8, d.banco_codigo_exibicao)
        p.box(*lin)
        from app.maps.receber import linha_digitavel_exibicao
        p.set_font(11, True)
        p.text_center(lin[0], lin[2], top + 9, linha_digitavel_exibicao(d.linha_digitavel))
        return top + ALT_HEADER

    def recibo_pagador(self, top, d: BoletoDados) -> float:
        p = self.p
        y = self.cabecalho(top, d)
        w, x, dr = self.w, MARGEM, self.direita
        c1, c2, c3, c4 = x + round(w * .12), x + round(w * .30), x + round(w * .58), x + round(w * .78)
        h = ALT_LINHA
        self.celula((x, y, c1, y + h), "Vencimento", d.vencimento)
        self.celula((c1, y, c2, y + h), "Agência/Código Beneficiário", d.agencia_codigo_beneficiario)
        self.celula((c2, y, c3, y + h), "Beneficiário", d.cedente)
        self.celula((c3, y, dr, y + h), "CNPJ/CPF do Beneficiário", d.cedente_cnpj)
        y += h
        self.celula((x, y, c4, y + h), "Endereço do Beneficiário", d.cedente_endereco)
        self.celula((c4, y, c4 + round(w * .08), y + h), "Espécie", d.especie_moeda)
        self.celula((c4 + round(w * .08), y, dr, y + h), "Quantidade", "")
        y += h
        c1, c2, c3, c4 = x + round(w * .16), x + round(w * .32), x + round(w * .48), x + round(w * .64)
        self.celula((x, y, c1, y + h), "(=) Valor do Documento", d.valor, True, True)
        self.celula((c1, y, c2, y + h), "(-) Desconto/Abatimento", "", True, True)
        self.celula((c2, y, c3, y + h), "(+) Juros/Multa", "", True, True)
        self.celula((c3, y, c4, y + h), "(=) Valor Cobrado", d.valor, True, True)
        self.celula((c4, y, dr, y + h), "Nosso Número", d.nosso_numero)
        y += h
        c2 = x + round(w * .22)
        self.celula((x, y, c2, y + h), "Nº do Documento", d.numero_documento)
        pagador = d.sacado + (f"  CPF/CNPJ: {d.sacado_cpf_cnpj}" if d.sacado_cpf_cnpj else "")
        self.celula((c2, y, dr, y + h), "Pagador", pagador)
        y += h
        p.set_font(6, False)
        p.text_right(dr, y + 4, "Autenticação Mecânica - Recibo do Pagador")
        return y + 16

    def linha_corte(self, top) -> float:
        self.p.hline(MARGEM, self.direita, top + 6, True)
        self.p.set_font(6, False)
        self.p.text(MARGEM, top + 10, "Corte na linha pontilhada")
        return top + 24

    def ficha_compensacao(self, top, d: BoletoDados) -> float:
        p = self.p
        y = self.cabecalho(top, d)
        x, dr, cv = MARGEM, self.direita, self.col_valor
        h = ALT_LINHA
        self.celula((x, y, cv - 1, y + h), "Local do Pagamento", d.local_pagamento)
        self.celula((cv, y, dr, y + h), "Vencimento", d.vencimento, True, True)
        y += h
        self.celula((x, y, cv - 1, y + h), "Beneficiário", f"{d.cedente}  {d.cedente_cnpj}")
        self.celula((cv, y, dr, y + h), "Agência/Código Beneficiário", d.agencia_codigo_beneficiario, True, True)
        y += h
        self.celula((x, y, cv - 1, y + h), "Endereço do Beneficiário", d.cedente_endereco)
        self.celula((cv, y, dr, y + h), "Nosso Número", d.nosso_numero, True, True)
        y += h
        L = cv - x
        c1, c2, c3, c4 = (x + round(L * f) for f in (.18, .38, .54, .68))
        self.celula((x, y, c1, y + h), "Data do Documento", d.emissao)
        self.celula((c1, y, c2, y + h), "Nº do Documento", d.numero_documento)
        self.celula((c2, y, c3, y + h), "Espécie Doc.", d.especie_doc)
        self.celula((c3, y, c4, y + h), "Aceite", d.aceite)
        self.celula((c4, y, cv - 1, y + h), "Data do Processamento", d.data_processamento)
        self.celula((cv, y, dr, y + h), "(=) Valor do Documento", d.valor, True, True)
        y += h
        c1, c2, c3, c4 = (x + round(L * f) for f in (.16, .32, .48, .64))
        self.celula((x, y, c1, y + h), "Uso do Banco", "")
        self.celula((c1, y, c2, y + h), "Carteira", d.carteira)
        self.celula((c2, y, c3, y + h), "Espécie", d.especie_moeda)
        self.celula((c3, y, c4, y + h), "Quantidade", "")
        self.celula((c4, y, cv - 1, y + h), "Valor", "")
        self.celula((cv, y, dr, y + h), "(-) Desconto/Abatimento", "", True, True)
        y += h

        instr: List[str] = []
        if d.instrucao1:
            instr.append(d.instrucao1)
        if d.instrucao2:
            instr.append(d.instrucao2)
        if d.observacao:
            instr.extend(s.strip() for s in d.observacao.split("|"))
        self.celula_instrucoes((x, y, cv - 1, y + ALT_LINHA_ALTA),
                               "Instruções (Texto de Responsabilidade do Beneficiário)", instr)
        self.celula((cv, y, dr, y + h), "(-) Outras Deduções", "", True, True)
        y += h
        self.celula((cv, y, dr, y + h), "(+) Juros/Multa", "", True, True)
        y += h
        self.celula((cv, y, dr, y + h), "(+) Outros Acréscimos", "", True, True)
        y += h
        self.celula((cv, y, dr, y + h), "(=) Valor Cobrado", d.valor, True, True)
        y = y - h * 3 + ALT_LINHA_ALTA

        pagador = d.sacado
        if d.sacado_cpf_cnpj:
            pagador += f"  CPF/CNPJ: {d.sacado_cpf_cnpj}"
        if d.sacado_endereco:
            pagador += f"  {d.sacado_endereco}"
        self.celula((x, y, dr, y + 34), "Pagador", pagador, False, False, 10)
        y += 34
        self.celula((x, y, cv - 1, y + 22), "Sacador/Avalista", "", False, False, 10)
        self.celula((cv, y, dr, y + 22), "Código de baixa", "", False, False, 10)
        y += 22
        p.set_font(6, False)
        p.text_right(dr, y + 2, "Autenticação Mecânica - Ficha de Compensação")
        y += 14
        r = (x, y, dr, y + ALT_BARCODE)
        p.box(*r)
        self.codigo_barras_itf(d.codigo_barras, r)
        return y + ALT_BARCODE

    def codigo_barras_itf(self, codigo: str, r) -> None:
        """Interleaved 2 of 5 (mesmo desenho do Delphi: estreito=2px, largo=5px)."""
        p = self.p
        codigo = fmt.digitos(codigo)
        if len(codigo) % 2:
            codigo = "0" + codigo
        if not codigo:
            return
        x1, y1, x2, y2 = r
        y_top, y_bot = y1 + 6, y2 - 6
        pos = [x1 + 10]

        def adv(barra: bool, largo: bool) -> None:
            m = 5 if largo else 2
            if barra:
                p.fill(pos[0], y_top, pos[0] + m, y_bot)
            pos[0] += m

        adv(True, False); adv(False, False); adv(True, False); adv(False, False)
        for i in range(len(codigo) // 2):
            p1, p2 = ITF[codigo[i * 2]], ITF[codigo[i * 2 + 1]]
            for j in range(5):
                adv(True, p1[j] == "w")
                adv(False, p2[j] == "w")
        adv(True, True); adv(False, False); adv(True, False)

    def render(self, d: BoletoDados) -> None:
        y = MARGEM
        y = self.recibo_pagador(y, d)
        y = self.linha_corte(y)
        self.ficha_compensacao(y, d)


def gerar_pdf(dados: List[BoletoDados], path: str, titulo: str = "Boleto") -> str:
    if not dados:
        raise ValueError("Nenhum boleto para gerar.")
    pdf = PxCanvas(path, titulo)
    render = _Render(pdf)
    for i, d in enumerate(dados):
        if i:
            pdf.new_page()
        render.render(d)
    pdf.save()
    return path
