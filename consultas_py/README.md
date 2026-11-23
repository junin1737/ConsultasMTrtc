# Consultas (Python / PySide6)

Reescrita desktop do app Delphi "Consultas": consulta somente-leitura a bancos Firebird do ERP
(Clientes, Estoque, Orçamento, Receber, Pagar, DAV, Compras, Notas Fiscais). Os `.pas` da pasta pai
servem apenas de referência — o app roda sem Delphi.

## Como rodar

```
cd consultas_py
pip install -r requirements.txt
python main.py
```

Requisitos: Python 3.10+ (64 bits), Windows, servidor Firebird 3+ acessível (local ou rede).

## Instalador / executável (sem Python nem Delphi)

Para o usuário final basta executar o instalador:

* **Instalador:** `installer\output\ConsultasSetup.exe` (Inno Setup; instala por padrão em
  `%LOCALAPPDATA%\Programs\Consultas` sem precisar de admin, cria atalho no Menu Iniciar e opcionalmente na
  Área de Trabalho; há desinstalador).
* **Executável direto (sem instalar):** `dist\Consultas\Consultas.exe` (pasta `dist\Consultas` inteira — onedir).

### Como gerar de novo

```
cd consultas_py
build_installer.bat
```

O script instala as dependências de build (`requirements-build.txt`, inclui PyInstaller), roda
`pyinstaller Consultas.spec` e, se o Inno Setup 6 estiver instalado (`iscc` no PATH ou
`C:\Program Files (x86)\Inno Setup 6`), compila `installer\Consultas.iss`. Sem Inno Setup é gerado
`installer\output\Consultas-portable.zip`; extraia e rode `install_local.ps1` (copia para
`%LOCALAPPDATA%\Programs\Consultas` e cria atalhos).

O pacote inclui `assets/` e `dll/` (fbclient.dll x64 + `firebird.msg`, ICU e runtime VC) dentro de `_internal\`.
`consultas_config.json` fica ao lado do `Consultas.exe`; se a pasta não for gravável (ex.: instalado em
Program Files) usa `%APPDATA%\Consultas`. A configuração não é apagada ao atualizar/desinstalar.
Autoteste do pacote: `Consultas.exe --selftest resultado.txt` (grava `RESULT=OK` se assets, fbclient e
imports estiverem corretos).

## Configuração

`Arquivo → Configurações` (Ctrl+,) na tela inicial:

* **Uma base** – ao conectar, um único diálogo (escolha/edição da base).
* **Várias bases** – ao conectar, você marca quais bases abrir; as consultas rodam em cada uma e os
  resultados são unidos, com a coluna **Base**. Falha em uma base vira aviso, não derruba as demais.

As bases de exemplo são `C:\treicon\TREICON1.FDB` e `C:\treicon\NEO.FDB`. A configuração é gravada em
`consultas_config.json` (ao lado do app). Porta, servidor, usuário/senha, charset (WIN1252) e
biblioteca cliente são editáveis por base; porta e cliente vazios = detecção automática
(serviço Firebird no registro do Windows + `firebird.conf`, equivalente a `UdmConexao.pas`).

### Cliente Firebird (fbclient.dll)

O `firebird-driver` precisa de um `fbclient.dll` **da mesma arquitetura do Python** (64 bits) e Firebird 3+.
Uma cópia x64 (Firebird 5.0.2) acompanha o app em `dll/` e é usada quando nada compatível é encontrado.
A biblioteca é carregada uma vez por processo; clientes 32 bits são ignorados automaticamente.

## Módulos

| Tile | Lista | Detalhe | PDF |
|---|---|---|---|
| Clientes | sim | endereço/contatos | – |
| Estoque | sim | preços/estoque | – |
| Orçamento | sim | itens/serviços | resumo |
| Receber | sim (filtros, cores) | boletos | boleto (recibo + ficha + código ITF) |
| Pagar | sim (filtros, cores) | sim | – |
| DAV | sim | itens/serviços | resumo |
| Compras | sim (situação, período) | itens/serviços | resumo + DANFE do XML |
| NFe Venda | NF-e / NFC-e | itens | resumo + DANFE / cupom NFC-e do XML |

Atalhos: Enter pesquisa, F5 recarrega, Esc fecha, duplo clique abre os detalhes.

PDFs são gerados com ReportLab em uma pasta temporária e abertos no leitor padrão. O DANFE/cupom
são renderizados a partir do XML (banco; para NFC-e também banco do terminal e pastas do NEO) em layout
simplificado, não idêntico ao ACBr/FastReport do Delphi.

## Estrutura

```
main.py                 entrada
Consultas.spec          PyInstaller (onedir)  |  build_installer.bat  |  installer/Consultas.iss (Inno Setup)
app/config.py           configuração (modo uma/várias bases)
app/db/                 detecção Firebird, conexão, ConnectionManager (query_all + coluna Base)
app/maps/               SQL portado dos UMapa*.pas
app/modules/            definição declarativa de cada consulta (colunas, filtros, detalhe)
app/ui/                 janela inicial, configurações, conexão, lista/detalhe genéricos
app/docs/               PDFs (boleto, resumo, DANFE)
```
