---
name: prospeccao-leads-locais
description: Use ao prospectar leads B2B locais de fontes públicas.
---

Dispara em: "lista de leads", "procurar clientes", "prospecção", "lead list", "quero ligar hoje", "achar empresas do nicho X", "cold call", "outbound".

Prospecção outbound local: transformar busca pública em lista de ligação com dor nomeada por lead. Entrega é lista acionável no mesmo dia, não relatório de mercado.

## Sempre, antes de coletar

Pergunte em UMA chamada de clarify (3 perguntas juntas, nunca em sequência):

1. **Praça/região** — define as queries do Maps.
2. **O que vai ser oferecido na ligação** — define QUAIS dores caçar. Sem isso a lista sai genérica e inútil.
3. **Porte-alvo** — pequeno/médio geralmente é o certo: o dono atende o telefone.

Coletar antes de saber a oferta produz lista errada. A dor só é dor em relação ao que você vende.

## Procedimento

### 1. Coletar no Google Maps (browser)

5-8 queries variando termo e bairro. Raspar o feed, scroll até o fim, dedupe por nome. Recipe com seletores e código: `references/google-maps-scraping.md`.

Meta: 200+ brutos para sobrar 25-40 qualificados. Salve o bruto em JSON no workspace e siga trabalhando em cima do arquivo — nunca segure a lista só em contexto.

### 2. Filtrar e pontuar por DOR, não por tamanho

Lead bom aqui é o **mal servido**, não o maior. Pontue:

| Sinal | Pontos | Por quê |
|---|---|---|
| Zero avaliações no Google | +3 | Ficha invisível no Maps, dor fácil de mostrar |
| <15 avaliações | +2 | Prova social fraca |
| Nota < 4,0 | +2 | Reputação pública ruim, dói ouvir |
| Telefone celular (`(XX) 9...`) | +2 | Linha do dono, sem secretária |
| Categoria bate com o nicho real (fábrica/facção, não revenda) | +3 | Evita varejo disfarçado |
| Muitas avaliações (100+) | −1 | Já tem movimento, menos urgência |

Descarte quem não tem telefone. Sem telefone não é lead de ligação.

### 3. Verificar presença digital — e duvidar do resultado

Para cada finalista: `web_search("<nome>" <nicho> <cidade> site OR instagram)`.

**Filtre diretórios antes de concluir que existe site.** Busca por nome de PME devolve majoritariamente agregador. Regex de descarte pronta em `references/google-maps-scraping.md`.

**Depois de filtrar, ainda valide semanticamente.** Um resultado sobrevivente pode ser blog aleatório ou PDF de diário oficial que só cita o nome. Confira se o domínio plausivelmente pertence à empresa antes de afirmar "tem site" — afirmar errado queima a credibilidade nos primeiros 30 segundos da ligação.

Abra o site que sobrou e classifique:
- **Template genérico** (`ueniweb.com`, construtores do Google Meu Negócio) → dor melhor que "sem site": ele já gastou e não converte.
- **HTTP 406/403** → WAF bloqueando bot, NÃO conclua que o site está quebrado.
- **Responde 200** → tem site, o gancho vira "investiu e não leva gente até lá".

### 4. Entregar três arquivos

Sempre os três, com caminhos absolutos no texto (TUI não tem anexo):

| Arquivo | Conteúdo |
|---|---|
| `leads_<nicho>_<praça>.md` | Ranqueado quente→morno, dores em negrito por lead, uma linha por dor |
| `leads_<nicho>_<praça>.csv` | Mesma lista, **UTF-8-BOM** (`encoding='utf-8-sig'`) senão o Excel come os acentos |
| `script_ligacao_<nicho>.md` | Abertura, diagnóstico, oferta com preço, quebra de objeção, fechamento |

No corpo da resposta, mostre os 8 primeiros em tabela — ele começa a discar sem abrir arquivo.

**Grave o endereço completo desde a primeira coleta**, mesmo quando o pedido é só "lista pra ligar". Ele vem de graça no card do Maps e é o que permite montar rota de visita depois sem recoletar nada.

### 5. Consolidar em planilha mestre quando a lista cresce

Acima de ~50 leads, ou assim que existirem 3+ arquivos soltos na pasta, o entregável vira **um XLSX único com abas** — painel, lista de ligação, rota por bairro, base filtrável, recorte do segmento mais vendável, ranking de dores. Receita completa, dependência, parse de endereço e checklist de verificação: `references/planilha-mestre-xlsx.md`.

Não espere ele pedir: quando a pasta acumula CSV + MD + recortes, "quero um arquivo com tudo completo" é o próximo pedido.

## Como escrever a dor (regra do usuário)

Linguagem de leigo, frase que ele possa **falar no telefone sem traduzir**. Passa no teste de 5 segundos.

- Sim: "Sem site. Quem procura fornecedor no Google não acha ela. Todo cliente vem de indicação."
- Não: "Baixa maturidade digital, ausência de presença orgânica indexada."

Toda dor precisa da **consequência comercial** colada: não basta "zero avaliações", tem que ser "zero avaliações → afunda no Maps → o concorrente da rua de cima aparece primeiro".

## Script de ligação — estrutura fixa

Abertura em 15s dizendo **o que você viu**, não o que vende. Pergunta "de onde vem seu cliente novo hoje?" abre o jogo — a resposta é sempre "indicação", e aí a dor se prova sozinha.

Fechamento é **oferta de entrada barata** (ficha do Google, landing simples), não contrato anual. Ninguém fecha valor alto em ligação fria. Template completo: `references/script-cold-call.md`.

## Armadilhas

- **Não afirme ausência como fato.** "Não achei Instagram" ≠ "não tem Instagram". Marque como *não encontrado na busca* e instrua a confirmar na ligação perguntando.
- **Dedupe antes de contar.** Maps repete patrocinados e resultados entre queries; contar sem dedupe infla a entrega.
- **Não prometa volume que não entregou.** Reporte "X qualificados de Y coletados" com o critério explícito.
- **Compare o valor exato do dado, nunca uma versão normalizada de cabeça.** Contagem que filtra `"SIM"` quando o CSV grava `"Sim"` retorna zero acerto e o total vira igual ao subconjunto — o painel imprime "93 de 93" e parece estatística, não bug. Ao agregar, `print(Counter(col))` antes de escrever a regra de filtro.
- **Denominador de métrica de auditoria é por métrica, não global.** Checagens diferentes falham em conjuntos diferentes de sites; contar tudo sobre o total da base subestima a dor. Conte só onde a checagem foi possível e diga o denominador em voz alta ("93 de 169 sites medidos").
- **Todo número de resumo tem que bater com o `len()` da aba que ele descreve.** Texto-guia escrito à mão envelhece quando o critério da aba muda; derive do mesmo objeto que gera a aba.
- **Agrupe dores por causa, não por string.** Mensagens que carregam o erro técnico entre parênteses (`... (URLError: ...)`, `(HTTPError: 404)`) viram linhas distintas no ranking e a mesma dor aparece duas vezes. Normalize removendo o parêntese técnico antes de contar.
- **Cheque a hora ao entregar.** Fábrica e comércio atendem 9h-11h30 e 14h-16h30. Entregar lista às 17h sem avisar que a janela fechou desperdiça o dia do usuário.
- **Ofereça o próximo lote.** Enquanto ele liga nos 25, dá pra levantar outra praça. Termine perguntando isso.

## Depois da lista: a página de amostra

Quando ele passa de "quero ligar" para "quero mostrar o que vendo", o entregável muda:
página modelo configurável + PDF de proposta. Veja `vendas/pagina-amostra-e-proposta-cliente`.
A auditoria de presença digital desta skill vira a página de problema do PDF — reaproveite
os números, mas recalcule da fonte e confira se as partes somam o total antes de imprimir.

## Retomada de trabalho perdido

Quando o usuário volta dizendo que fechou o terminal / perdeu a conversa: **procure os arquivos no disco antes de qualquer outra coisa.** O trabalho quase sempre já está gravado — a sessão é que sumiu. Liste a pasta de entrega e só recorra ao histórico de sessões se o arquivo não estiver lá.

Responda pelo **nome do entregável e o que ele contém**, com o caminho absoluto — nunca por commit, hash ou narrativa do que foi feito. Ele quer saber onde clicar, não o que aconteceu.
