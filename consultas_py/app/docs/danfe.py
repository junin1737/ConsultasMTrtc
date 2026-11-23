"""DANFE (NF-e / compra) e cupom NFC-e gerados a partir do XML autorizado.

No Delphi isso e feito pelo ACBr (TACBrNFeDANFeFPDF) e UNfceXmlResolver.pas; aqui o XML e lido do banco
(NOTAFISCALNFE.NFNFEESTRUTURAXML, ENTRADACOMPRA.ENTCXMLCORPO, VENDARAPIDANFCE.VENRNFCEESTRUTURAXML),
com busca complementar no banco do terminal e em pastas de XML, e renderizado com ReportLab em layout
simplificado (nao e a fiel reproducao do .fr3/ACBr).
"""
from __future__ import annotations

import datetime as _dt
import glob
import os
import re
import xml.etree.ElementTree as ET
from typing import Any, Callable, Dict, List, Optional, Tuple

from reportlab.graphics.barcode import code128

from app.docs.pxcanvas import PX, PxCanvas
from app.docs.viewer import open_file, temp_pdf_path
from app.util import fmt

# ---------------------------------------------------------------- obtencao do XML


def _blob_texto(v: Any) -> str:
    if v is None:
        return ""
    if isinstance(v, (bytes, bytearray)):
        for enc in ("utf-8", "cp1252"):
            try:
                t = bytes(v).decode(enc)
                break
            except UnicodeDecodeError:
                t = ""
        v = t
    return str(v).strip()


def xml_valido(x: str) -> bool:
    return bool(x) and "<NFe" in x and ("</NFe>" in x or "<nfeProc" in x)


def _query_xml(ctx, alias: str, sql: str, params: Dict[str, Any]) -> str:
    try:
        r = ctx.query(alias, sql, params).first()
    except Exception:  # noqa: BLE001
        return ""
    if not r:
        return ""
    return _blob_texto(next(iter(r.values())))


def xml_nota_fiscal(ctx, alias: str, emp: int, nf: int) -> str:
    return _query_xml(ctx, alias,
                      "SELECT FIRST 1 NF.NFNFEESTRUTURAXML FROM NOTAFISCALNFE NF "
                      "WHERE NF.EMPCODIGO = :EMPCODIGO AND NF.NFCONTADOR = :NFCONTADOR",
                      {"EMPCODIGO": emp, "NFCONTADOR": nf})


def xml_compra(ctx, alias: str, emp: int, entc: int) -> str:
    return _query_xml(ctx, alias,
                      "SELECT FIRST 1 E.ENTCXMLCORPO FROM ENTRADACOMPRA E "
                      "WHERE E.EMPCODIGO = :EMPCODIGO AND E.ENTCCONTADOR = :ENTCCONTADOR",
                      {"EMPCODIGO": emp, "ENTCCONTADOR": entc})


_SQL_XML_NFCE = (
    "SELECT FIRST 1 N.VENRNFCEESTRUTURAXML FROM VENDARAPIDANFCE N "
    "WHERE N.EMPCODIGO = :EMPCODIGO AND N.VENNUMERO = :VENNUMERO "
    "AND N.TERNUMERO = :TERNUMERO AND N.VENRNFCENUMEROFISCAL = :VENRNFCENUMEROFISCAL"
)

_SUBPASTAS_NFCE = ["", "NFCe\\Autorizadas", "ArquivosNFe\\NFCe\\Autorizadas", "XML\\NFCe\\Autorizadas",
                   "NFe\\NFCe\\Autorizadas", "Dados\\NFCe\\Autorizadas", "NFCe", "XML\\NFCe", "ArquivosNFe\\NFCe"]


def _separar_host_path(caminho: str) -> Optional[Tuple[str, str]]:
    """'host/porta:C:\\pasta\\x.fdb' -> ('host/porta', 'C:\\pasta\\x.fdb')."""
    m = re.search(r"^(.+?):([A-Za-z]:\\.+)$", (caminho or "").strip())
    return (m.group(1).strip(), m.group(2)) if m else None


def _xml_banco_terminal(ctx, alias: str, emp: int, ven: int, ter: int, numero: int) -> str:
    from app.config import BaseConfig
    from app.db.connection import FirebirdConnection

    try:
        r = ctx.query(alias, "SELECT FIRST 1 T.TERCAMINHO FROM TERMINAL T "
                             "WHERE T.EMPCODIGO = :EMPCODIGO AND T.TERNUMERO = :TERNUMERO",
                      {"EMPCODIGO": emp, "TERNUMERO": ter}).first()
    except Exception:  # noqa: BLE001
        return ""
    sep = _separar_host_path(fmt.texto(next(iter(r.values()))) if r else "")
    if not sep:
        return ""
    host, database = sep
    server, _, porta = host.partition("/")
    base = ctx.conn(alias).cfg
    cfg = BaseConfig(alias=f"terminal{ter}", database=database, server=server, port=porta or base.port,
                     user=base.user, password=base.password, charset=base.charset,
                     client_library=base.client_library, wire_crypt=base.wire_crypt)
    con = FirebirdConnection(cfg)
    try:
        con.connect()
        row = con.query(_SQL_XML_NFCE, {"EMPCODIGO": emp, "VENNUMERO": ven, "TERNUMERO": ter,
                                        "VENRNFCENUMEROFISCAL": numero}).first()
        return _blob_texto(next(iter(row.values()))) if row else ""
    except Exception:  # noqa: BLE001
        return ""
    finally:
        con.close()


def _xml_arquivo(ctx, alias: str, chave: str) -> str:
    """Procura <chave>*.xml perto do banco (pasta do .fdb e subpastas tipicas do NEO)."""
    if not chave:
        return ""
    db = ctx.conn(alias).cfg.database
    base = os.path.dirname(db)
    bases = [base]
    if os.path.basename(base).lower() == "dados":
        bases.append(os.path.dirname(base))
    bases.append(os.path.dirname(base))
    vistos = set()
    for b in bases:
        for sub in _SUBPASTAS_NFCE:
            pasta = os.path.normpath(os.path.join(b, sub))
            if pasta in vistos or not os.path.isdir(pasta):
                continue
            vistos.add(pasta)
            padrao = os.path.join(pasta, "**", chave + "*.xml")
            for arq in glob.glob(padrao, recursive=True):
                for enc in ("utf-8", "cp1252"):
                    try:
                        with open(arq, encoding=enc) as fh:
                            t = fh.read().strip()
                    except (OSError, UnicodeDecodeError):
                        continue
                    if xml_valido(t):
                        return t
    return ""


def xml_nfce(ctx, alias: str, emp: int, ven: int, ter: int, numero: int, chave: str = "") -> str:
    p = {"EMPCODIGO": emp, "VENNUMERO": ven, "TERNUMERO": ter, "VENRNFCENUMEROFISCAL": numero}
    x = _query_xml(ctx, alias, _SQL_XML_NFCE, p)
    if xml_valido(x):
        return x
    x = _xml_banco_terminal(ctx, alias, emp, ven, ter, numero)
    if xml_valido(x):
        return x
    return _xml_arquivo(ctx, alias, chave)


# ---------------------------------------------------------------- parse


class _Doc:
    """Acesso simples ao XML ignorando namespaces."""

    def __init__(self, xml: str):
        xml = re.sub(r"^<\?xml[^>]*\?>", "", xml.strip())
        xml = re.sub(r'\sxmlns(:\w+)?="[^"]*"', "", xml)
        self.root = ET.fromstring(xml)
        self.inf = self.root.find(".//infNFe")
        if self.inf is None:
            raise ValueError("XML sem o grupo infNFe.")

    def t(self, path: str, base: Optional[ET.Element] = None, default: str = "") -> str:
        el = (base if base is not None else self.inf).find(path)
        return (el.text or "").strip() if el is not None and el.text else default

    def all(self, path: str, base: Optional[ET.Element] = None) -> List[ET.Element]:
        return (base if base is not None else self.inf).findall(path)

    @property
    def chave(self) -> str:
        ident = self.inf.get("Id", "")
        c = re.sub(r"\D", "", ident)
        if c:
            return c
        return self.t("../protNFe/infProt/chNFe") or ""


def _num(v: str) -> float:
    try:
        return float(v)
    except ValueError:
        return 0.0


def _data_xml(s: str) -> str:
    """'2026-04-09T14:24:37-03:00' -> '09/04/2026'."""
    try:
        return fmt.data(_dt.date.fromisoformat((s or "")[:10]))
    except ValueError:
        return ""


def _fmt_chave(ch: str) -> str:
    return " ".join(ch[i:i + 4] for i in range(0, len(ch), 4))


def _end(d: _Doc, grupo: str) -> str:
    g = d.inf.find(grupo)
    if g is None:
        return ""
    partes = [d.t("xLgr", g), d.t("nro", g), d.t("xCpl", g), d.t("xBairro", g)]
    end = ", ".join(p for p in partes if p)
    cep = d.t("CEP", g)
    cid = " - ".join(p for p in (d.t("xMun", g), d.t("UF", g)) if p)
    return " | ".join(p for p in (end, cid, f"CEP {fmt.cep(cep)}" if cep else "") if p)


def _icms(d: _Doc, det: ET.Element) -> Dict[str, str]:
    im = det.find("imposto/ICMS")
    out = {"cst": "", "bc": "", "aliq": "", "v": ""}
    if im is not None and len(list(im)):
        g = list(im)[0]
        out["cst"] = (d.t("orig", g) + (d.t("CST", g) or d.t("CSOSN", g)))
        out["bc"], out["aliq"], out["v"] = d.t("vBC", g), d.t("pICMS", g), d.t("vICMS", g)
    return out


def _barcode(c: PxCanvas, chave: str, x: float, y_top: float, w: float, h: float) -> None:
    if not chave:
        return
    b = code128.Code128(chave, barHeight=h * PX, barWidth=0.5, quiet=False)
    escala = (w * PX) / b.width if b.width else 1
    c.c.saveState()
    c.c.translate(x * PX, c._y(y_top + h))  # noqa: SLF001
    c.c.scale(escala, 1)
    b.drawOn(c.c, 0, 0)
    c.c.restoreState()


def _safe(s: str) -> str:
    return (s or "").encode("latin-1", "replace").decode("latin-1")


# ---------------------------------------------------------------- DANFE A4


def gerar_danfe(xml: str, path: str, titulo: str = "DANFE") -> str:
    d = _Doc(xml)
    c = PxCanvas(path, titulo)
    L, R = 30.0, c.page_w_px - 30.0
    W = R - L
    y = 30.0

    def caixa(x1, y1, x2, y2, rot, val, bold=False, align="l", size=8.5):
        c.box(x1, y1, x2, y2)
        c.set_font(6, False)
        c.text(x1 + 3, y1 + 1, _safe(rot))
        c.set_font(size, bold)
        v = _safe(c.fit(str(val), x2 - x1 - 8))
        if align == "r":
            c.text_right(x2 - 4, y1 + 12, v)
        else:
            c.text(x1 + 4, y1 + 12, v)

    chave = d.chave
    # --- emitente / DANFE / chave
    h = 92
    c.box(L, y, L + 270, y + h)
    c.set_font(11, True)
    c.text(L + 6, y + 6, _safe(c.fit(d.t("emit/xNome"), 258)))
    c.set_font(7.5, False)
    end = _end(d, "emit/enderEmit").split(" | ")
    yy = y + 26
    for linha in end:
        for sub in _wrap_txt(c, linha, 256):
            c.text(L + 6, yy, _safe(sub))
            yy += 10
    c.text(L + 6, yy, _safe(f"CNPJ: {fmt.cpf_cnpj(d.t('emit/CNPJ') or d.t('emit/CPF'))}   IE: {d.t('emit/IE')}"))

    c.box(L + 270, y, L + 370, y + h)
    c.set_font(13, True)
    c.text_center(L + 270, L + 370, y + 4, "DANFE")
    c.set_font(6.5, False)
    c.text_center(L + 270, L + 370, y + 22, "Documento Auxiliar da")
    c.text_center(L + 270, L + 370, y + 31, "Nota Fiscal Eletrônica".encode("latin-1", "replace").decode("latin-1"))
    c.set_font(8, False)
    c.text(L + 276, y + 46, "0 - Entrada")
    c.text(L + 276, y + 57, "1 - Saída")
    c.box(L + 345, y + 46, L + 362, y + 60)
    c.set_font(10, True)
    c.text_center(L + 345, L + 362, y + 46, d.t("ide/tpNF"))
    c.set_font(9, True)
    c.text_center(L + 270, L + 370, y + 66, f"Nº {d.t('ide/nNF')}")
    c.text_center(L + 270, L + 370, y + 78, f"Série {d.t('ide/serie')}")

    c.box(L + 370, y, R, y + h)
    _barcode(c, chave, L + 380, y + 6, W - 370 - 20, 38)
    c.set_font(6, False)
    c.text(L + 374, y + 50, "CHAVE DE ACESSO")
    c.set_font(8, True)
    c.text(L + 374, y + 59, _fmt_chave(chave))
    c.set_font(6, False)
    c.text(L + 374, y + 73, "Consulta de autenticidade no portal nacional da NF-e (www.nfe.fazenda.gov.br/portal)")
    y += h

    prot = d.root.find(".//protNFe/infProt")
    prot_txt = ""
    if prot is not None:
        prot_txt = f"{d.t('nProt', prot)} - {d.t('dhRecbto', prot)[:19].replace('T', ' ')}"
    caixa(L, y, L + 370, y + 26, "NATUREZA DA OPERAÇÃO", d.t("ide/natOp"))
    caixa(L + 370, y, R, y + 26, "PROTOCOLO DE AUTORIZAÇÃO DE USO", prot_txt)
    y += 26
    caixa(L, y, L + 250, y + 26, "INSCRIÇÃO ESTADUAL", d.t("emit/IE"))
    caixa(L + 250, y, L + 500, y + 26, "INSCRIÇÃO ESTADUAL DO SUBST. TRIBUTÁRIO", d.t("emit/IEST"))
    caixa(L + 500, y, R, y + 26, "CNPJ", fmt.cpf_cnpj(d.t("emit/CNPJ")))
    y += 34

    # --- destinatario
    c.set_font(8, True)
    c.text(L, y, "DESTINATÁRIO / REMETENTE")
    y += 12
    doc_dest = d.t("dest/CNPJ") or d.t("dest/CPF")
    caixa(L, y, L + 460, y + 26, "NOME / RAZÃO SOCIAL", d.t("dest/xNome"))
    caixa(L + 460, y, L + 640, y + 26, "CNPJ / CPF", fmt.cpf_cnpj(doc_dest))
    caixa(L + 640, y, R, y + 26, "DATA DA EMISSÃO", _data_xml(d.t("ide/dhEmi") or d.t("ide/dEmi")))
    y += 26
    caixa(L, y, L + 460, y + 26, "ENDEREÇO", _end(d, "dest/enderDest").replace(" | ", " - "))
    caixa(L + 460, y, L + 640, y + 26, "INSCRIÇÃO ESTADUAL", d.t("dest/IE"))
    dsai = d.t("ide/dhSaiEnt") or d.t("ide/dSaiEnt")
    caixa(L + 640, y, R, y + 26, "DATA SAÍDA/ENTRADA", _data_xml(dsai))
    y += 34

    # --- totais
    t = d.inf.find("total/ICMSTot")
    c.set_font(8, True)
    c.text(L, y, "CÁLCULO DO IMPOSTO")
    y += 12
    tot = lambda tag: fmt.moeda(_num(d.t(tag, t))) if t is not None else ""  # noqa: E731
    cw = W / 5
    linhas_tot = [
        [("BASE CÁLC. ICMS", "vBC"), ("VALOR DO ICMS", "vICMS"), ("BASE CÁLC. ICMS ST", "vBCST"),
         ("VALOR DO ICMS ST", "vST"), ("VALOR TOTAL PRODUTOS", "vProd")],
        [("VALOR DO FRETE", "vFrete"), ("VALOR DO SEGURO", "vSeg"), ("DESCONTO", "vDesc"),
         ("OUTRAS DESPESAS", "vOutro"), ("VALOR TOTAL DA NOTA", "vNF")],
    ]
    for lin in linhas_tot:
        for i, (rot, tag) in enumerate(lin):
            caixa(L + i * cw, y, L + (i + 1) * cw, y + 26, rot, tot(tag), bold=(tag == "vNF"), align="r")
        y += 26
    y += 8

    # --- itens
    c.set_font(8, True)
    c.text(L, y, "DADOS DOS PRODUTOS / SERVIÇOS")
    y += 12
    cols = [("CÓDIGO", 62, "l"), ("DESCRIÇÃO DO PRODUTO / SERVIÇO", 200, "l"), ("NCM", 54, "l"),
            ("CST", 34, "l"), ("CFOP", 34, "l"), ("UN", 26, "l"), ("QTDE", 48, "r"),
            ("V. UNIT.", 56, "r"), ("V. TOTAL", 58, "r"), ("BC ICMS", 54, "r"), ("V. ICMS", 48, "r"),
            ("%ICMS", 32, "r")]
    esc = W / sum(w for _, w, _ in cols)
    cols = [(n, w * esc, a) for n, w, a in cols]

    def cab_itens(yy: float) -> float:
        c.fill(L, yy, R, yy + 16, (0.88, 0.88, 0.88))
        c.box(L, yy, R, yy + 16)
        c.set_font(6, True)
        x = L
        for n, w, a in cols:
            (c.text_right(x + w - 2, yy + 4, n) if a == "r" else c.text(x + 2, yy + 4, n))
            x += w
        return yy + 16

    y = cab_itens(y)
    for det in d.all("det"):
        if y > c.page_h_px - 150:
            c.new_page()
            y = cab_itens(30.0)
        ic = _icms(d, det)
        vals = [
            d.t("prod/cProd", det), d.t("prod/xProd", det), d.t("prod/NCM", det), ic["cst"],
            d.t("prod/CFOP", det), d.t("prod/uCom", det),
            fmt.quantidade(_num(d.t("prod/qCom", det))), fmt.moeda(_num(d.t("prod/vUnCom", det))),
            fmt.moeda(_num(d.t("prod/vProd", det))),
            fmt.moeda(_num(ic["bc"])) if ic["bc"] else "", fmt.moeda(_num(ic["v"])) if ic["v"] else "",
            fmt.numero(_num(ic["aliq"])) if ic["aliq"] else "",
        ]
        c.set_font(6.5, False)
        x = L
        for (n, w, a), v in zip(cols, vals):
            v = _safe(c.fit(v, w - 4))
            (c.text_right(x + w - 2, y + 3, v) if a == "r" else c.text(x + 2, y + 3, v))
            x += w
        y += 14
        c.hline(L, R, y - 1)
    y += 12

    # --- adicionais
    if y > c.page_h_px - 110:
        c.new_page()
        y = 30.0
    inf_cpl = d.t("infAdic/infCpl")
    c.set_font(8, True)
    c.text(L, y, "DADOS ADICIONAIS")
    y += 12
    c.box(L, y, R, y + 70)
    c.set_font(6, False)
    c.text(L + 3, y + 1, "INFORMAÇÕES COMPLEMENTARES")
    c.set_font(7, False)
    yy = y + 12
    for linha in _wrap_txt(c, inf_cpl, W - 10)[:5]:
        c.text(L + 4, yy, _safe(linha))
        yy += 10
    c.save()
    return path


def _wrap_txt(c: PxCanvas, texto: str, largura: float) -> List[str]:
    out: List[str] = []
    atual = ""
    for p in (texto or "").split():
        t = (atual + " " + p).strip()
        if c.text_width(t) <= largura:
            atual = t
        else:
            out.append(atual)
            atual = p
    if atual:
        out.append(atual)
    return out


# ---------------------------------------------------------------- cupom NFC-e


def gerar_cupom_nfce(xml: str, path: str, titulo: str = "NFC-e") -> str:
    d = _Doc(xml)
    c = PxCanvas(path, titulo)
    W = 300.0
    L = (c.page_w_px - W) / 2
    R = L + W
    y = 30.0

    def centro(txt: str, size=8, bold=False) -> None:
        nonlocal y
        c.set_font(size, bold)
        for linha in _wrap_txt(c, _safe(txt), W - 8) or [""]:
            c.text_center(L, R, y, linha)
            y += size * 1.45

    def esq(txt: str, size=7.5, bold=False) -> None:
        nonlocal y
        c.set_font(size, bold)
        c.text(L, y, _safe(c.fit(txt, W)))
        y += size * 1.5

    centro(d.t("emit/xNome"), 10, True)
    centro(f"CNPJ: {fmt.cpf_cnpj(d.t('emit/CNPJ'))}  IE: {d.t('emit/IE')}", 7.5)
    centro(_end(d, "emit/enderEmit").replace(" | ", " - "), 7)
    y += 4
    c.hline(L, R, y); y += 6
    centro("DANFE NFC-e - Documento Auxiliar da Nota Fiscal de Consumidor Eletrônica", 8, True)
    centro("Não permite aproveitamento de crédito de ICMS", 7)
    c.hline(L, R, y); y += 6

    c.set_font(7, True)
    x_cols = [(L, "Cód", "l", 38), (L + 38, "Descrição", "l", 100), (L + 138, "Qtd", "r", 36),
              (L + 174, "V.Unit", "r", 62), (L + 236, "Total", "r", 64)]
    for x, n, a, w in x_cols:
        (c.text_right(x + w, y, n) if a == "r" else c.text(x, y, n))
    y += 12
    c.hline(L, R, y - 2)
    for det in d.all("det"):
        c.set_font(7, False)
        vals = [d.t("prod/cProd", det), d.t("prod/xProd", det),
                fmt.quantidade(_num(d.t("prod/qCom", det))) + " " + d.t("prod/uCom", det),
                fmt.moeda(_num(d.t("prod/vUnCom", det))), fmt.moeda(_num(d.t("prod/vProd", det)))]
        for (x, n, a, w), v in zip(x_cols, vals):
            v = _safe(c.fit(v, w - 2))
            (c.text_right(x + w, y, v) if a == "r" else c.text(x, y, v))
        y += 11
        if y > c.page_h_px - 260:
            c.new_page()
            y = 30.0
    c.hline(L, R, y); y += 6

    t = d.inf.find("total/ICMSTot")
    esq(f"Qtd. total de itens: {len(d.all('det'))}")
    esq(f"Valor total: {fmt.moeda(_num(d.t('vProd', t)))}")
    if _num(d.t("vDesc", t)):
        esq(f"Desconto: {fmt.moeda(_num(d.t('vDesc', t)))}")
    esq(f"Valor a pagar: {fmt.moeda(_num(d.t('vNF', t)))}", 9, True)
    for pg in d.all("pag/detPag"):
        esq(f"Forma de pagamento {d.t('tPag', pg)}: {fmt.moeda(_num(d.t('vPag', pg)))}")
    y += 4
    c.hline(L, R, y); y += 6
    centro(f"NFC-e nº {d.t('ide/nNF')}  Série {d.t('ide/serie')}  Emissão {d.t('ide/dhEmi')[:19].replace('T', ' ')}", 7.5, True)
    centro("Consulte pela chave de acesso em www.nfce.fazenda.gov.br", 7)
    centro(_fmt_chave(d.chave), 7, True)
    y += 4
    _barcode(c, d.chave, L + 10, y, W - 20, 44)
    y += 54
    dest = d.t("dest/CPF") or d.t("dest/CNPJ")
    centro(f"CONSUMIDOR: {fmt.cpf_cnpj(dest)} {d.t('dest/xNome')}".strip() if dest else "CONSUMIDOR NÃO IDENTIFICADO", 7.5)
    prot = d.root.find(".//protNFe/infProt")
    if prot is not None:
        centro(f"Protocolo de autorização: {d.t('nProt', prot)}  {d.t('dhRecbto', prot)[:19].replace('T', ' ')}", 7)
    inf = d.t("infAdic/infCpl")
    if inf:
        y += 4
        centro(inf, 6.5)
    c.save()
    return path


# ---------------------------------------------------------------- acoes


def _abrir(xml: str, nfce: bool, prefixo: str) -> str:
    if not xml_valido(xml):
        raise ValueError("XML da nota não encontrado no banco nem nas pastas conhecidas.\n"
                         "Use 'Imprimir / Ver PDF' para o resumo do documento.")
    nome = re.sub(r"[^\w\-]+", "_", prefixo)
    path = temp_pdf_path(nome)
    (gerar_cupom_nfce if nfce else gerar_danfe)(xml, path, prefixo)
    open_file(path)
    return path


def acao_danfe(ctx, row: Dict[str, Any], rotulo: str, cab: Dict[str, Any]) -> Tuple[str, Callable[[], None], bool]:
    """Acao 'Ver DANFE' (NF-e) / 'Ver cupom NFC-e'."""
    alias, emp = row["Base"], fmt.to_int(row["EMPCODIGO"])
    nfce = rotulo == "NFC-e"

    def _run() -> None:
        if nfce:
            xml = xml_nfce(ctx, alias, emp, fmt.to_int(row["VENNUMERO"]), fmt.to_int(row["TERNUMERO"]),
                           fmt.to_int(row["NFNUMEROFISCAL"]), cab.get("chave", ""))
        else:
            xml = xml_nota_fiscal(ctx, alias, emp, fmt.to_int(row["NFCONTADOR"]))
        _abrir(xml, nfce, f"{'DANFE NFC-e' if nfce else 'DANFE'}_{alias}_{cab.get('numero', '')}")

    return ("Ver cupom NFC-e" if nfce else "Ver DANFE", _run, True)


def acao_danfe_compra(ctx, row: Dict[str, Any], cab: Dict[str, Any]) -> Tuple[str, Callable[[], None], bool]:
    alias, emp = row["Base"], fmt.to_int(row["EMPCODIGO"])

    def _run() -> None:
        xml = xml_compra(ctx, alias, emp, fmt.to_int(row["ENTCCONTADOR"]))
        _abrir(xml, False, f"DANFE_compra_{alias}_{cab.get('numero', '')}")

    return ("Ver DANFE", _run, bool(cab.get("chave")))
