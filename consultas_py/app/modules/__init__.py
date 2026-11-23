"""Registro dos modulos de consulta (ordem = ordem dos tiles na tela inicial)."""
from __future__ import annotations

from typing import List

from app.modules.spec import ModuleSpec
from app.modules.clientes import SPEC as CLIENTES
from app.modules.estoque import SPEC as ESTOQUE
from app.modules.orcamento import SPEC as ORCAMENTO
from app.modules.receber import SPEC as RECEBER
from app.modules.pagar import SPEC as PAGAR
from app.modules.dav import SPEC as DAV
from app.modules.compra import SPEC as COMPRA
from app.modules.notafiscal import SPEC as NOTAFISCAL
from app.modules.ordemservico import SPEC as ORDEMSERVICO

MODULES: List[ModuleSpec] = [CLIENTES, ESTOQUE, ORCAMENTO, RECEBER, PAGAR, DAV, COMPRA, NOTAFISCAL, ORDEMSERVICO]
