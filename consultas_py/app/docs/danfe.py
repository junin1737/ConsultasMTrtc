"""DANFE (NF-e / compra) e cupom NFC-e gerados a partir do XML autorizado.

No Delphi isso e feito pelo ACBr (TACBrNFeDANFeFPDF) e UNfceXmlResolver.pas; aqui o XML e lido do banco
(NOTAFISCALNFE.NFNFEESTRUTURAXML, ENTRADACOMPRA.ENTCXMLCORPO, VENDARAPIDANFCE.VENRNFCEESTRUTURAXML),
com busca complementar no banco do terminal e em pastas de XML, e renderizado com ReportLab.
A NF-e usa o layout DANFE modelo nacional (retrato A4: canhoto, emitente/DANFE/chave, destinatario,
fatura, calculo do imposto, transportador, produtos, ISSQN e dados adicionais, multi-folha); a NFC-e
continua como cupom.
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
    cfg = BaseConfig(apelido=f"terminal{ter}", database=database, server=server, port=porta or base.port,
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


# ---------------------------------------------------------------- DANFE A4 (modelo nacional, retrato)

_MARG = 28.0  # margem lateral (px @96dpi)


def _dinheiro(v: Any) -> str:
    """Valor monetario sem prefixo (padrao DANFE): 1.234,56."""
    return "" if v is None or v == "" else fmt.numero(v)


def _unit(v: str) -> str:
    """Valor unitario com 2 a 4 casas (zeros a direita alem da 2a casa sao suprimidos)."""
    if not v:
        return ""
    s = fmt.numero(_num(v), 4)
    while s.endswith("0") and len(s.split(",")[-1]) > 2:
        s = s[:-1]
    return s


def _nf_fmt(n: str) -> str:
    """'1234' -> '000.001.234' (formato nacional do numero da NF-e)."""
    n = re.sub(r"\D", "", n or "") or "0"
    n = n.zfill(9)
    return f"{n[-9:-6]}.{n[-6:-3]}.{n[-3:]}"


def _hora_xml(s: str) -> str:
    m = re.search(r"T(\d{2}:\d{2}:\d{2})", s or "")
    return m.group(1) if m else ""


def _fone(s: str) -> str:
    s = re.sub(r"\D", "", s or "")
    return fmt.telefone(s) if s else ""


def _end_linha(d: _Doc, g: ET.Element) -> str:
    """Logradouro, numero, complemento."""
    return ", ".join(p for p in (d.t("xLgr", g), d.t("nro", g), d.t("xCpl", g)) if p)


_MOD_FRETE = {
    "0": "0-Emitente", "1": "1-Dest/Rem", "2": "2-Terceiros", "3": "3-Próprio Rem.",
    "4": "4-Próprio Dest.", "9": "9-Sem Frete",
}


def gerar_danfe(xml: str, path: Any, titulo: str = "DANFE") -> str:
    """DANFE NF-e - modelo nacional (retrato A4): canhoto, emitente/DANFE/chave, natureza/protocolo,
    destinatario, fatura, calculo do imposto, transportador, produtos, ISSQN e dados adicionais."""
    d = _Doc(xml)
    import io

    paginas = _render_danfe(d, io.BytesIO(), titulo, 0)  # 1a passada: conta as folhas
    _render_danfe(d, path, titulo, paginas)
    return path


def _render_danfe(d: _Doc, path: Any, titulo: str, total: int) -> int:  # noqa: C901
    c = PxCanvas(path, titulo)
    L = _MARG
    R = c.page_w_px - _MARG
    W = R - L
    PH = c.page_h_px
    BOTTOM = PH - 28.0
    chave = d.chave
    homolog = d.t("ide/tpAmb") == "2"
    pagina = 1

    def caixa(x1: float, y1: float, x2: float, y2: float, rot: str, val: str = "", bold: bool = False,
              align: str = "l", size: float = 7.5, wrap: bool = False) -> None:
        c.box(x1, y1, x2, y2)
        c.set_font(5.2, False)
        c.text(x1 + 2, y1 + 1, _safe(c.fit(rot, x2 - x1 - 4)))
        c.set_font(size, bold)
        if wrap:
            yy = y1 + 9
            for ln in _wrap_txt(c, val, x2 - x1 - 6)[: max(1, int((y2 - y1 - 9) // (size * 1.25)))]:
                c.text(x1 + 3, yy, _safe(ln))
                yy += size * 1.25
            return
        v = _safe(c.fit(str(val), x2 - x1 - 6))
        if align == "r":
            c.text_right(x2 - 3, y1 + 10, v)
        elif align == "c":
            c.text_center(x1, x2, y1 + 10, v)
        else:
            c.text(x1 + 3, y1 + 10, v)

    def linha(y: float, h: float, cels: List[tuple]) -> float:
        """cels: (peso, rotulo, valor, align, bold). Larguras proporcionais aos pesos."""
        tot = sum(p for p, *_ in cels)
        x = L
        for i, cel in enumerate(cels):
            p, rot, val = cel[0], cel[1], cel[2]
            al = cel[3] if len(cel) > 3 else "l"
            bd = cel[4] if len(cel) > 4 else False
            x2 = R if i == len(cels) - 1 else x + W * p / tot
            caixa(x, y, x2, y + h, rot, val, bold=bd, align=al)
            x = x2
        return y + h

    def titulo_sec(y: float, txt: str) -> float:
        c.set_font(6.5, True)
        c.text(L, y, _safe(txt))
        return y + 9

    def watermark() -> None:
        if not homolog:
            return
        c.c.saveState()
        c.c.setFillColorRGB(0.85, 0.85, 0.85)
        c.c.setFont("Helvetica-Bold", 60)
        c.c.translate(c.page_w_px * PX / 2, c.page_h_px * PX / 2)
        c.c.rotate(50)
        c.c.drawCentredString(0, 0, "SEM VALOR FISCAL")
        c.c.restoreState()

    prot = d.root.find(".//protNFe/infProt")
    prot_txt = ""
    if prot is not None:
        prot_txt = f"{d.t('nProt', prot)} - {_data_xml(d.t('dhRecbto', prot))} {_hora_xml(d.t('dhRecbto', prot))}".strip()
    cont = d.t("ide/tpEmis") in ("2", "3", "5", "6", "7", "9")  # contingencia
    t = d.inf.find("total/ICMSTot")

    def tot(tag: str) -> str:
        return _dinheiro(_num(d.t(tag, t))) if t is not None else ""

    # =========================================================== cabecalho (todas as folhas)
    def cabecalho(y: float, com_canhoto: bool) -> float:
        watermark()
        if com_canhoto:
            h = 58.0
            ww = W - 112
            c.box(L, y, L + ww, y + 29)
            c.set_font(6, False)
            txt = (f"RECEBEMOS DE {d.t('emit/xNome')} OS PRODUTOS E/OU SERVIÇOS CONSTANTES DA NOTA FISCAL "
                   f"ELETRÔNICA INDICADA AO LADO. EMISSÃO: {_data_xml(d.t('ide/dhEmi') or d.t('ide/dEmi'))} "
                   f"VALOR TOTAL: R$ {tot('vNF')} DESTINATÁRIO: {d.t('dest/xNome')}")
            yy = y + 3
            for ln in _wrap_txt(c, txt, ww - 8)[:3]:
                c.text(L + 4, yy, _safe(ln))
                yy += 8
            caixa(L, y + 29, L + 110, y + h, "DATA DE RECEBIMENTO")
            caixa(L + 110, y + 29, L + ww, y + h, "IDENTIFICAÇÃO E ASSINATURA DO RECEBEDOR")
            c.box(L + ww, y, R, y + h)
            c.set_font(10, True)
            c.text_center(L + ww, R, y + 6, "NF-e")
            c.set_font(8, True)
            c.text_center(L + ww, R, y + 24, f"Nº {_nf_fmt(d.t('ide/nNF'))}")
            c.text_center(L + ww, R, y + 38, f"SÉRIE {d.t('ide/serie')}")
            y += h + 5
            c.hline(L, R, y, dashed=True)
            y += 6

        h = 98.0
        # --- emitente
        xe, xd = L + 262, L + 262 + 108
        c.box(L, y, xe, y + h)
        c.set_font(5.2, False)
        c.text(L + 2, y + 1, "IDENTIFICAÇÃO DO EMITENTE")
        c.set_font(10, True)
        yy = y + 11
        for ln in _wrap_txt(c, d.t("emit/xNome"), xe - L - 10)[:2]:
            c.text_center(L, xe, yy, _safe(ln))
            yy += 12
        c.set_font(7, False)
        g = d.inf.find("emit/enderEmit")
        if g is not None:
            cep = d.t("CEP", g)
            linhas = [_end_linha(d, g), d.t("xBairro", g) + (f" - CEP {fmt.cep(cep)}" if cep else ""),
                      " - ".join(p for p in (d.t("xMun", g), d.t("UF", g)) if p)]
            fone = _fone(d.t("fone", g))
            if fone:
                linhas.append(f"Fone: {fone}")
            for ln in linhas:
                for sub in _wrap_txt(c, ln, xe - L - 10)[:2]:
                    c.text_center(L, xe, yy, _safe(sub))
                    yy += 9

        # --- DANFE
        c.box(xe, y, xd, y + h)
        c.set_font(12, True)
        c.text_center(xe, xd, y + 3, "DANFE")
        c.set_font(5.8, False)
        yy = y + 19
        for ln in ("Documento Auxiliar da", "Nota Fiscal Eletrônica"):
            c.text_center(xe, xd, yy, _safe(ln))
            yy += 7.5
        c.set_font(6.5, False)
        c.text(xe + 8, y + 40, "0 - ENTRADA")
        c.text(xe + 8, y + 49, "1 - SAÍDA")
        c.box(xd - 24, y + 40, xd - 10, y + 56)
        c.set_font(10, True)
        c.text_center(xd - 24, xd - 10, y + 42, d.t("ide/tpNF"))
        c.set_font(8, True)
        c.text_center(xe, xd, y + 62, f"Nº {_nf_fmt(d.t('ide/nNF'))}")
        c.text_center(xe, xd, y + 74, f"SÉRIE {d.t('ide/serie')}")
        c.set_font(7, True)
        c.text_center(xe, xd, y + 86, f"FOLHA {pagina}/{total or 1}")

        # --- codigo de barras / chave / consulta
        c.box(xd, y, R, y + 40)
        _barcode(c, chave, xd + 10, y + 4, R - xd - 20, 32)
        caixa(xd, y + 40, R, y + 66, "CHAVE DE ACESSO", _fmt_chave(chave), bold=True, align="c", size=8.2)
        c.box(xd, y + 66, R, y + h)
        c.set_font(6, False)
        yy = y + 70
        if cont and not prot_txt:
            c.set_font(6.5, True)
            c.text_center(xd, R, yy, "DANFE EM CONTINGÊNCIA - IMPRESSO EM DECORRÊNCIA")
            c.text_center(xd, R, yy + 8, "DE PROBLEMAS TÉCNICOS")
        else:
            for ln in ("Consulta de autenticidade no portal nacional da NF-e",
                       "www.nfe.fazenda.gov.br/portal ou no site da Sefaz Autorizadora"):
                c.text_center(xd, R, yy, _safe(ln))
                yy += 8
        y += h

        y = linha(y, 22, [(2.6, "NATUREZA DA OPERAÇÃO", d.t("ide/natOp")),
                          (1.6, "PROTOCOLO DE AUTORIZAÇÃO DE USO" if prot_txt or not cont else
                           "DADOS DA NF-e", prot_txt if prot_txt or not cont else "")])
        y = linha(y, 22, [(1, "INSCRIÇÃO ESTADUAL", d.t("emit/IE")),
                          (1, "INSCRIÇÃO ESTADUAL DO SUBST. TRIBUT.", d.t("emit/IEST")),
                          (1, "CNPJ / CPF", fmt.cpf_cnpj(d.t("emit/CNPJ") or d.t("emit/CPF")))])
        return y + 4

    y = cabecalho(24.0, True)

    # =========================================================== destinatario
    y = titulo_sec(y, "DESTINATÁRIO / REMETENTE")
    gd = d.inf.find("dest/enderDest")
    doc_dest = d.t("dest/CNPJ") or d.t("dest/CPF") or d.t("dest/idEstrangeiro")
    cep_d = d.t("CEP", gd) if gd is not None else ""
    dsai = d.t("ide/dhSaiEnt") or d.t("ide/dSaiEnt")
    y = linha(y, 22, [(4.2, "NOME / RAZÃO SOCIAL", d.t("dest/xNome")),
                      (1.8, "CNPJ / CPF", fmt.cpf_cnpj(doc_dest) if doc_dest.isdigit() else doc_dest),
                      (1.2, "DATA DA EMISSÃO", _data_xml(d.t("ide/dhEmi") or d.t("ide/dEmi")), "c")])
    y = linha(y, 22, [(3.2, "ENDEREÇO", _end_linha(d, gd) if gd is not None else ""),
                      (2.0, "BAIRRO / DISTRITO", d.t("xBairro", gd) if gd is not None else ""),
                      (1.0, "CEP", fmt.cep(cep_d) if cep_d else "", "c"),
                      (1.2, "DATA DA SAÍDA", _data_xml(dsai), "c")])
    y = linha(y, 22, [(3.2, "MUNICÍPIO", d.t("xMun", gd) if gd is not None else ""),
                      (1.6, "FONE / FAX", _fone(d.t("fone", gd)) if gd is not None else ""),
                      (0.5, "UF", d.t("UF", gd) if gd is not None else "", "c"),
                      (1.6, "INSCRIÇÃO ESTADUAL", d.t("dest/IE")),
                      (1.2, "HORA DA SAÍDA", _hora_xml(dsai), "c")])
    y += 4

    # =========================================================== fatura / duplicatas
    dups = d.all("cobr/dup")
    if dups:
        y = titulo_sec(y, "FATURA / DUPLICATAS")
        por_linha = 6
        cw = W / por_linha
        for i in range(0, len(dups), por_linha):
            for j, dp in enumerate(dups[i:i + por_linha]):
                x1 = L + j * cw
                x2 = R if j == por_linha - 1 else x1 + cw
                c.box(x1, y, x2, y + 22)
                c.set_font(5.2, False)
                c.text(x1 + 2, y + 1, "Núm.   Venc.   Valor")
                c.set_font(6.5, False)
                c.text(x1 + 3, y + 10, _safe(c.fit(
                    f"{d.t('nDup', dp)}  {_data_xml(d.t('dVenc', dp))}  {_dinheiro(_num(d.t('vDup', dp)))}", cw - 5)))
            y += 22
        y += 4

    # =========================================================== calculo do imposto
    y = titulo_sec(y, "CÁLCULO DO IMPOSTO")
    y = linha(y, 22, [(1, "BASE DE CÁLC. DO ICMS", tot("vBC"), "r"), (1, "VALOR DO ICMS", tot("vICMS"), "r"),
                      (1, "BASE DE CÁLC. ICMS SUBST.", tot("vBCST"), "r"),
                      (1, "VALOR DO ICMS SUBST.", tot("vST"), "r"),
                      (1, "V. IMP. IMPORTAÇÃO", tot("vII"), "r"),
                      (1.2, "VALOR TOTAL DOS PRODUTOS", tot("vProd"), "r")])
    y = linha(y, 22, [(1, "VALOR DO FRETE", tot("vFrete"), "r"), (1, "VALOR DO SEGURO", tot("vSeg"), "r"),
                      (1, "DESCONTO", tot("vDesc"), "r"), (1, "OUTRAS DESPESAS", tot("vOutro"), "r"),
                      (1, "VALOR DO IPI", tot("vIPI"), "r"),
                      (1.2, "VALOR TOTAL DA NOTA", tot("vNF"), "r", True)])
    y += 4

    # =========================================================== transportador / volumes
    y = titulo_sec(y, "TRANSPORTADOR / VOLUMES TRANSPORTADOS")
    tr = d.inf.find("transp")
    ttr = tr.find("transporta") if tr is not None else None
    vol = tr.find("vol") if tr is not None else None
    veic = tr.find("veicTransp") if tr is not None else None

    def tt(path: str, base: Optional[ET.Element]) -> str:
        return d.t(path, base) if base is not None else ""

    mod = tt("modFrete", tr)
    y = linha(y, 22, [(3.0, "NOME / RAZÃO SOCIAL", tt("xNome", ttr)),
                      (1.3, "FRETE", _MOD_FRETE.get(mod, mod)),
                      (1.0, "CÓDIGO ANTT", tt("RNTC", veic)),
                      (1.0, "PLACA DO VEÍCULO", tt("placa", veic)),
                      (0.4, "UF", tt("UF", veic), "c"),
                      (1.6, "CNPJ / CPF", fmt.cpf_cnpj(tt("CNPJ", ttr) or tt("CPF", ttr)))])
    y = linha(y, 22, [(3.0, "ENDEREÇO", tt("xEnder", ttr)), (2.0, "MUNICÍPIO", tt("xMun", ttr)),
                      (0.4, "UF", tt("UF", ttr), "c"), (1.6, "INSCRIÇÃO ESTADUAL", tt("IE", ttr))])

    def peso(v: str) -> str:
        return fmt.numero(_num(v)) if v else ""

    y = linha(y, 22, [(1.0, "QUANTIDADE", tt("qVol", vol)), (1.6, "ESPÉCIE", tt("esp", vol)),
                      (1.6, "MARCA", tt("marca", vol)), (1.6, "NUMERAÇÃO", tt("nVol", vol)),
                      (1.2, "PESO BRUTO", peso(tt("pesoB", vol)), "r"),
                      (1.2, "PESO LÍQUIDO", peso(tt("pesoL", vol)), "r")])
    y += 4

    # =========================================================== produtos
    cols = [("CÓD. PROD.", 50, "l"), ("DESCRIÇÃO DO PRODUTO / SERVIÇO", 168, "l"), ("NCM/SH", 42, "l"),
            ("O/CST", 28, "l"), ("CFOP", 26, "l"), ("UN", 20, "l"), ("QUANT.", 38, "r"),
            ("V. UNIT.", 42, "r"), ("V. DESC.", 34, "r"), ("V. TOTAL", 44, "r"), ("BC ICMS", 42, "r"),
            ("V. ICMS", 36, "r"), ("V. IPI", 32, "r"), ("%ICMS", 28, "r"), ("%IPI", 26, "r")]
    esc = W / sum(w for _, w, _ in cols)
    cols = [(n, w * esc, a) for n, w, a in cols]
    BOTTOM_H = 36 + 12 + 92 + 6  # ISSQN + titulo + dados adicionais

    def cab_itens(yy: float) -> float:
        yy = titulo_sec(yy, "DADOS DOS PRODUTOS / SERVIÇOS")
        c.fill(L, yy, R, yy + 14, (0.9, 0.9, 0.9))
        c.box(L, yy, R, yy + 14)
        c.set_font(5.2, True)
        x = L
        for n, w, a in cols:
            (c.text_right(x + w - 2, yy + 4, n) if a == "r" else c.text(x + 2, yy + 4, n))
            x += w
        return yy + 14

    def separadores(y_ini: float, y_fim: float) -> None:
        """Moldura do quadro de itens e divisorias de coluna."""
        c.box(L, y_ini, R, y_fim)
        x = L
        for _, w, _a in cols[:-1]:
            x += w
            c.c.setLineWidth(0.4)
            c.c.line(x * PX, c._y(y_ini), x * PX, c._y(y_fim))  # noqa: SLF001

    y = cab_itens(y)
    y_ini_itens = y
    dets = d.all("det")
    for k, det in enumerate(dets):
        ic = _icms(d, det)
        c.set_font(6, False)
        prod = d.t("prod/xProd", det)
        adic = d.t("infAdProd", det)
        desc_lin = _wrap_txt(c, prod + (f" - {adic}" if adic else ""), cols[1][1] - 5)[:8] or [""]
        rh = max(13.0, len(desc_lin) * 7.6 + 5)
        ultimo = k == len(dets) - 1
        if y + rh > BOTTOM - (BOTTOM_H if ultimo else 0):
            separadores(y_ini_itens, BOTTOM)
            c.new_page()
            pagina += 1
            y = cabecalho(24.0, False)
            y = cab_itens(y)
            y_ini_itens = y
            c.set_font(6, False)
        v_ipi = d.t("imposto/IPI/IPITrib/vIPI", det)
        p_ipi = d.t("imposto/IPI/IPITrib/pIPI", det)
        vals = [
            d.t("prod/cProd", det), None, d.t("prod/NCM", det), ic["cst"], d.t("prod/CFOP", det),
            d.t("prod/uCom", det), fmt.quantidade(_num(d.t("prod/qCom", det))),
            _unit(d.t("prod/vUnCom", det)),
            _dinheiro(_num(d.t("prod/vDesc", det))) if d.t("prod/vDesc", det) else "",
            _dinheiro(_num(d.t("prod/vProd", det))),
            _dinheiro(_num(ic["bc"])) if ic["bc"] else "", _dinheiro(_num(ic["v"])) if ic["v"] else "",
            _dinheiro(_num(v_ipi)) if v_ipi else "", fmt.numero(_num(ic["aliq"])) if ic["aliq"] else "",
            fmt.numero(_num(p_ipi)) if p_ipi else "",
        ]
        x = L
        for (n, w, a), v in zip(cols, vals):
            if v is None:  # descricao: varias linhas
                yy = y + 3
                for ln in desc_lin:
                    c.text(x + 2, yy, _safe(ln))
                    yy += 7.6
            else:
                v = _safe(c.fit(v, w - 4))
                (c.text_right(x + w - 2, y + 3, v) if a == "r" else c.text(x + 2, y + 3, v))
            x += w
        y += rh
    y = max(y, BOTTOM - BOTTOM_H + 6)  # quadro de itens preenche o espaco ate o bloco ISSQN/adicionais
    separadores(y_ini_itens, y)
    y += 4

    # =========================================================== ISSQN
    y = titulo_sec(y, "CÁLCULO DO ISSQN")
    iss = d.inf.find("total/ISSQNtot")
    y = linha(y, 22, [(1, "INSCRIÇÃO MUNICIPAL", d.t("emit/IM")),
                      (1, "VALOR TOTAL DOS SERVIÇOS", _dinheiro(_num(d.t("vServ", iss))) if iss is not None and d.t("vServ", iss) else "", "r"),
                      (1, "BASE DE CÁLCULO DO ISSQN", _dinheiro(_num(d.t("vBC", iss))) if iss is not None and d.t("vBC", iss) else "", "r"),
                      (1, "VALOR DO ISSQN", _dinheiro(_num(d.t("vISS", iss))) if iss is not None and d.t("vISS", iss) else "", "r")])
    y += 4

    # =========================================================== dados adicionais
    y = titulo_sec(y, "DADOS ADICIONAIS")
    h_ad = max(60.0, BOTTOM - y)
    h_ad = min(h_ad, 92.0)
    xs = L + W * 0.70
    c.box(L, y, xs, y + h_ad)
    c.box(xs, y, R, y + h_ad)
    c.set_font(5.2, False)
    c.text(L + 2, y + 1, "INFORMAÇÕES COMPLEMENTARES")
    c.text(xs + 2, y + 1, "RESERVADO AO FISCO")
    c.set_font(6.5, False)
    inf = d.t("infAdic/infCpl")
    if homolog:
        inf = "NF-e EMITIDA EM AMBIENTE DE HOMOLOGAÇÃO - SEM VALOR FISCAL. " + inf
    inf_fisco = d.t("infAdic/infAdFisco")
    yy = y + 9
    max_l = int((h_ad - 10) // 7.8)
    for ln in _wrap_txt(c, inf, xs - L - 8)[:max_l]:
        c.text(L + 3, yy, _safe(ln))
        yy += 7.8
    yy = y + 9
    for ln in _wrap_txt(c, inf_fisco, R - xs - 8)[:max_l]:
        c.text(xs + 3, yy, _safe(ln))
        yy += 7.8
    paginas = c.c.getPageNumber()
    c.save()
    return paginas


def _wrap_txt(c: PxCanvas, texto: str, largura: float) -> List[str]:
    out: List[str] = []
    atual = ""
    for p in (texto or "").split():
        while c.text_width(p) > largura and len(p) > 1:  # palavra maior que a coluna: quebra
            n = len(p)
            while n > 1 and c.text_width(p[:n]) > largura:
                n -= 1
            if atual:
                out.append(atual)
                atual = ""
            out.append(p[:n])
            p = p[n:]
        t = (atual + " " + p).strip()
        if c.text_width(t) <= largura:
            atual = t
        else:
            if atual:
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
