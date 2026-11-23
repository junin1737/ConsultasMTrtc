"""Deteccao de servicos Firebird / fbclient.dll / porta.

Port de ``DetectarServicosFirebird`` e ``ResolverClienteFB`` (UdmConexao.pas).
"""
from __future__ import annotations

import os
import struct
import sys
from dataclasses import dataclass
from typing import List, Optional

from app.config import FB_PORTA_PADRAO, app_dir, resource_dir

CAMINHOS_FIXOS = [
    r"C:\Program Files\Firebird\Firebird_5_0\fbclient.dll",
    r"C:\Program Files\Firebird\Firebird_5_0\WOW64\fbclient.dll",
    r"C:\Program Files (x86)\Firebird\Firebird_5_0\fbclient.dll",
    r"C:\Program Files\Firebird\Firebird_4_0\fbclient.dll",
    r"C:\Program Files\Firebird\Firebird_3_0\fbclient.dll",
]


@dataclass
class ServicoFirebird:
    pasta: str
    fbclient: str
    porta: str
    wire_crypt: str
    nome_servico: str

    def versao_aproximada(self) -> str:
        low = (self.pasta + self.nome_servico).lower()
        for tag in ("5_0", "4_0", "3_0", "2_5"):
            if tag in low:
                return tag.replace("_", ".")
        return ""


def dll_compativel(caminho: str) -> bool:
    """True se o fbclient.dll tem a mesma arquitetura (32/64 bits) do Python em execucao."""
    try:
        with open(caminho, "rb") as fh:
            d = fh.read(1024)
        off = struct.unpack("<I", d[0x3C:0x40])[0]
        machine = struct.unpack("<H", d[off + 4:off + 6])[0]
    except (OSError, struct.error):
        return True  # nao conseguiu ler: deixa o driver decidir
    py64 = sys.maxsize > 2 ** 32
    return machine == (0x8664 if py64 else 0x14C)


def ler_valor_conf(arquivo: str, chave: str) -> str:
    """Le ``Chave = Valor`` de um firebird.conf (ultima ocorrencia vence)."""
    resultado = ""
    if not os.path.isfile(arquivo):
        return resultado
    try:
        with open(arquivo, "r", encoding="latin-1") as fh:
            for linha in fh:
                linha = linha.strip()
                if not linha or linha.startswith("#") or "=" not in linha:
                    continue
                k, v = linha.split("=", 1)
                if k.strip().lower() == chave.lower():
                    resultado = v.strip()
    except OSError:
        pass
    return resultado


def extrair_pasta_image_path(image_path: str) -> str:
    s = (image_path or "").strip()
    if s.startswith('"'):
        s = s[1:]
        p = s.find('"')
        if p >= 0:
            s = s[:p]
    else:
        p = s.find(" -")
        if p >= 0:
            s = s[:p].strip()
    return os.path.dirname(s)


def detectar_servicos_firebird() -> List[ServicoFirebird]:
    """Lista servicos Windows 'Firebird*' (exceto Guardian) com fbclient.dll valida."""
    resultado: List[ServicoFirebird] = []
    if sys.platform != "win32":
        return resultado
    try:
        import winreg
    except ImportError:  # pragma: no cover
        return resultado

    chave_base = r"SYSTEM\CurrentControlSet\Services"
    try:
        root = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, chave_base)
    except OSError:
        return resultado
    with root:
        i = 0
        nomes = []
        while True:
            try:
                nomes.append(winreg.EnumKey(root, i))
            except OSError:
                break
            i += 1
        for nome in nomes:
            if "Firebird" not in nome or "Guardian" in nome:
                continue
            try:
                with winreg.OpenKey(root, nome) as k:
                    image_path, _ = winreg.QueryValueEx(k, "ImagePath")
            except OSError:
                continue
            pasta = extrair_pasta_image_path(str(image_path))
            if not pasta:
                continue
            fbclient = os.path.join(pasta, "fbclient.dll")
            if not os.path.isfile(fbclient):
                continue
            conf = os.path.join(pasta, "firebird.conf")
            porta = ler_valor_conf(conf, "RemoteServicePort") or FB_PORTA_PADRAO
            wc = ler_valor_conf(conf, "WireCrypt") or "Disabled"
            resultado.append(ServicoFirebird(pasta, fbclient, porta, wc, nome))
    return resultado


def detectar_servico_preferido(servicos: Optional[List[ServicoFirebird]] = None) -> Optional[ServicoFirebird]:
    """Equivalente a ``DetectarServicoFirebird5``: prefere 'firebird.exe' (FB 3+)."""
    servicos = detectar_servicos_firebird() if servicos is None else servicos
    for s in servicos:
        if "firebird.exe" in (s.fbclient + s.pasta).lower() or os.path.isfile(
            os.path.join(s.pasta, "firebird.exe")
        ):
            return s
    return servicos[0] if servicos else None


def servico_por_porta(porta: str, servicos: Optional[List[ServicoFirebird]] = None) -> Optional[ServicoFirebird]:
    servicos = detectar_servicos_firebird() if servicos is None else servicos
    for s in servicos:
        if s.porta == str(porta):
            return s
    return None


def resolver_cliente_fb(caminho_config: str = "", servicos: Optional[List[ServicoFirebird]] = None,
                        porta: str = "") -> str:
    """Resolve o caminho do fbclient.dll (mesma ordem do Delphi)."""

    def se_existir(c: str) -> str:
        # ignora DLL de arquitetura diferente (ex.: fbclient 32 bits com Python 64 bits)
        return c if c and os.path.isfile(c) and dll_compativel(c) else ""

    r = se_existir((caminho_config or "").strip())
    if r:
        return r

    servicos = detectar_servicos_firebird() if servicos is None else servicos
    if porta:
        s = servico_por_porta(porta, servicos)
        if s:
            r = se_existir(s.fbclient)
            if r:
                return r
    for s in servicos:
        r = se_existir(s.fbclient)
        if r:
            return r

    # dll empacotada (PyInstaller: _MEIPASS/dll) ou ao lado do .exe / raiz do projeto
    pastas_app = []
    for p in (resource_dir(), app_dir()):
        if p not in pastas_app:
            pastas_app.append(p)
    for pasta_app in pastas_app:
        for rel in ("fbclient.dll", os.path.join("dll", "fbclient.dll"), os.path.join("Firebird", "fbclient.dll")):
            r = se_existir(os.path.join(pasta_app, rel))
            if r:
                return r

    for c in CAMINHOS_FIXOS:
        r = se_existir(c)
        if r:
            return r
    return se_existir(r"C:\Windows\System32\fbclient.dll")
