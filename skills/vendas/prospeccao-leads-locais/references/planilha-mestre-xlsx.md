# Planilha mestre do dossiê de leads (XLSX)

Entregável padrão quando a lista passa de ~50 leads ou já existem arquivos espalhados.
Um arquivo, várias abas, cada aba respondendo a UMA pergunta operacional.

## Abas — ordem fixa

| Aba | Pergunta que responde | Conteúdo |
|---|---|---|
| `PAINEL` | "o que esse mercado tem de buraco?" | Números agregados em blocos coloridos + barras `█` por bairro + guia das outras abas |
| `LIGAR HOJE` | "pra quem eu ligo agora?" | Só os de celular, ordem por score de dor, coluna **FALE ISTO** (frase de abertura) destacada em amarelo + 3 reforços |
| `ROTA DE VISITA` | "como monto meu dia de rua?" | Todos, agrupados cidade → bairro, com logradouro e CEP |
| `BASE COMPLETA` | "quero filtrar do meu jeito" | Todas as colunas da auditoria, com AutoFilter, `NÃO` em vermelho |
| `<RECORTE>` | o segmento mais vendável | Ex.: `SEM SITE` — quem não tem presença digital própria |
| `DORES` | "que oferta atinge mais gente?" | Ranking de problemas distintos × nº de empresas, por gravidade |

O `PAINEL` é a primeira aba e traz o guia — o usuário abre nele e não precisa perguntar o que é cada coisa.

## Dependência

`openpyxl` não vem no venv do Hermes. Instale no interpretador certo:

```bash
uv pip install --python "C:/Users/<user>/AppData/Local/hermes/hermes-agent/venv/Scripts/python.exe" openpyxl
```

## Gerador como arquivo, nunca como célula solta

Escreva o gerador em `<pasta_do_projeto>/_gerar_master.py` e rode com `python _gerar_master.py`.
O kernel do `execute_code` perde estado entre chamadas; um gerador de 300 linhas em célula morre no meio e você reconstrói tudo. Como arquivo, cada correção é um `patch` + rerun de 2 segundos.

## Parse de endereço do Maps

O campo vem como `Rua X, 123 - Bairro, Cidade - UF, 00000-000`. Quebre em colunas próprias
(Logradouro / Bairro / Cidade / UF / CEP) — sem isso não há rota nem importação em CRM.

```python
UF = r"(AC|AL|AP|AM|BA|CE|DF|ES|GO|MA|MT|MS|MG|PA|PB|PR|PE|PI|RJ|RN|RS|RO|RR|SC|SP|SE|TO)"
cep = re.search(r"(\d{5}-?\d{3})\s*$", e)          # tira o CEP do fim primeiro
m   = re.search(r"([^,\-]+?)\s*-\s*" + UF + r"\s*$", e)   # cidade + UF
# o que sobra, split ' - ': último pedaço é bairro, resto é logradouro
```

**Use a alternância completa de UF, não `- SP$`.** Toda coleta regional carrega alguns registros de outro estado (empresa com matriz fora da praça); ancorar na UF da praça joga esses endereços no balde "sem cidade" e some com eles da rota.

## Agrupar por bairro é o que dá valor à aba de rota

`Counter(bairro + cidade)` e ordene decrescente. A concentração é o insight comercial:
quando 3-4 bairros vizinhos somam 100+ empresas, isso é "um dia de rua a pé" e vale
uma linha em destaque no PAINEL. Ordene os bairros por densidade, não alfabeticamente.

## Legibilidade (padrão do usuário)

- Cabeçalho com `freeze_panes` na primeira linha de dados, sempre.
- `Table` + `TableStyleInfo` liga o AutoFilter — ele filtra sozinho sem pedir.
- `showGridLines = False` em todas as abas.
- Coluna de ação (a frase da ligação) com fundo destacado e negrito; ela é o produto.
- Link do Maps como hyperlink com texto `abrir ficha`, não a URL crua de 300 caracteres.
- Altura de linha fixa (`row_dimensions[r].height`) nas abas com `wrap_text`, senão o Excel mostra uma linha só.

## Verificação obrigatória antes de entregar

Reabra o arquivo salvo e compare com a fonte — não confie no script que acabou de rodar:

```python
wb = load_workbook(saida)
base = [r for r in wb['BASE COMPLETA'].iter_rows(min_row=PRIMEIRA_LINHA, values_only=True)]
assert len(base) == len(src)
assert {b[1] for b in base} == {r['Empresa'] for r in src}   # nenhum nome perdido
assert sum(b[IDX_DORES] for b in base) == sum(int(r['Qtd dores']) for r in src)
```

Rode também: nenhuma célula-chave vazia, nenhuma linha duplicada no ranking agregado,
e cada número citado no PAINEL igual ao `len()` da aba que ele descreve.
