---
name: pesquisa-dossie-tecnico
description: Use ao produzir dossiê de pesquisa técnica multi-eixo.
---

# Dossiê técnico multi-eixo

Classe de trabalho: o usuário pede "pesquisa profunda sobre X", ou "faz a pesquisa de X do mesmo jeito que fez a de Y". O entregável NÃO é uma resposta no chat — é um diretório de relatórios em Markdown no repositório, mais uma skill destilada que carrega sozinha em tarefas futuras daquele domínio.

## Estrutura de saída (formato-casa, não negociar)

```
pesquisa/<tema-curto>/
  README.md              # tabela de eixos + "os 10 achados que mais mudam decisão"
  01-<eixo>.md ... NN-<eixo>.md
  raw/<eixo>.json        # cache bruto das extrações, um arquivo por eixo
```

Cada relatório de eixo segue exatamente esta forma (esqueleto em `templates/relatorio-eixo.md`):

```markdown
# <Tema do eixo> — Relatório Técnico (<faixa de anos>)

## 1. Regras acionáveis
**1. <Regra imperativa em negrito, uma frase.>** Explicação com NÚMEROS CONCRETOS. <url> · <url>

## 2. Antipadrões
- <bullet curto e específico>

## 3. Checklist
- [ ] <item verificável>
```

Regras do formato:
- A frase em negrito é a regra; o resto do parágrafo é a prova. Quem lê só os negritos já sai sabendo o que fazer.
- Toda afirmação carrega número verificado (ms, px, %, versão do browser, tamanho em KB) e a(s) URL(s) no fim do parágrafo, separadas por ` · `. Parágrafo sem número nem URL não entra.
- Antipadrões são o inverso das regras, escritos como o erro concreto que o dev comete, não como conselho genérico.
- Alvo por eixo: 20+ regras, 12+ antipadrões, 12+ itens de checklist.

## Procedimento

### 1. Fixar os eixos antes de pesquisar
Decompor o tema em 6–8 eixos independentes, cada um com escopo que não encosta no do vizinho. O último eixo é sempre **personalidades e fontes canônicas do campo** — é o que permite pesquisas futuras começarem já sabendo quem ler.

Se já existe um dossiê anterior no repositório, leia o README dele e copie a granularidade dos eixos: o usuário compara o novo com o antigo.

### 2. Coletar as fontes primárias você mesmo, antes de delegar
Não delegue a coleta inteira. Monte uma lista curada de URLs canônicas por eixo e rode `web_extract` em lotes de 3–4 URLs, gravando `raw/<eixo>.json` a cada lote.

- **Pule a busca genérica para topo de funil.** Query ampla em tema de design/frontend devolve fazenda de SEO com domínio inventado e conteúdo reciclado por IA. Use `web_search` só para *localizar a URL canônica* de uma fonte que você já sabe que existe; a lista de fontes vem da sua cabeça, não do ranking.
- Fontes primárias que valem: MDN, web.dev, Chrome for Developers, a spec, o repositório do projeto, o blog do autor da técnica. Ver `references/fontes-primarias-frontend.md` quando o tema for web.
- **Grave o JSON de cada eixo assim que o lote volta.** Uma chamada gigante que extrai tudo de uma vez pode ser interrompida e perder as horas de rede — com gravação incremental você retoma no eixo que faltou.

### 3. Recuperar as fontes que o extrator não lê
Quando `web_extract` devolve conteúdo de tamanho 0, a página não está morta — normalmente está atrás de JS ou de user-agent. Nessa ordem:
1. Reconferir a URL: sites reorganizam caminhos e o link famoso vira 404. Busque o título exato entre aspas para achar o caminho atual.
2. `curl -sL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" <url> -o pagina.html` e limpar as tags com um one-liner de `node`, depois ler o `.txt`.
3. **Não encadeie curl dentro de `for ... do ... $(...)` no terminal**: o guard de comando destrutivo recusa substituição de comando ambígua dentro de laço. Emita um `curl` por URL, encadeado com `&&`.

### 4. Delegar um eixo por subagente, em paralelo
Um `delegate_task` por eixo, todos no mesmo disparo. O contexto de cada filho precisa carregar, obrigatoriamente:
- **O caminho do relatório de referência** para ele ler com `read_file` ANTES de escrever. Descrever o formato em prosa não funciona; mandar copiar um arquivo existente, sim.
- **Os caminhos dos `raw/*.json` já coletados**, com uma linha dizendo o que tem dentro de cada um.
- **Uma lista de cobertura obrigatória** — os subtópicos que o relatório tem que endereçar. Sem ela o filho escreve o óbvio e ignora justamente o detalhe que diferencia.
- **A regra de ouro, literal: nunca inventar número, citação ou URL; todo número vem de fonte lida de verdade; se não conseguiu verificar, não escreve.** Sem essa frase o filho alucina benchmark plausível com URL que não existe.
- **Mínimo de fontes novas que ele deve extrair por conta própria** (8 costuma ser o certo) e o tamanho alvo do relatório.
- Pedir no resumo final: caminho do arquivo, contagem de regras, e as 5 descobertas que mais mudam a decisão — é o material do README.

O filho não enxerga a conversa. Repita em cada tarefa o contexto do usuário (quem é, qual o problema real que ele quer resolver), senão o relatório sai academicamente correto e praticamente inútil.

### 5. Fechar o dossiê
Depois que todos os eixos voltam:
1. Escrever o `README.md`: tabela `| # | Arquivo | Eixo |`, ponteiro para a destilação, e a seção **"os N achados que mais mudam decisão"** — os itens contraintuitivos, com número, não o resumo dos capítulos.
2. Destilar em skill persistente sob a categoria do domínio, para carregar automaticamente na próxima tarefa daquele tipo.
3. Copiar a destilação para o vault Obsidian em `06_OPERACAO\Skills Globais`.
4. Só então avisar o usuário, com o caminho absoluto do diretório.

## Pitfalls

- **Confirme o recorte antes de gastar rede.** "Pesquisa sobre frontend" pode ser performance ou craft visual — são bibliografias disjuntas. Uma pergunta de uma linha no começo economiza um dossiê inteiro escrito para o tema errado.
- **Número sem fonte é o defeito que mata o dossiê.** O valor do formato está em poder citar "232 ms → 30 ms" com o link. Um parágrafo bonito sem número é opinião e deve ser cortado na revisão.
- **Não misture eixos.** Se o dossiê anterior já cobriu performance, o novo sobre estética não repete performance — referencie o arquivo antigo e siga.
- **Relate progresso com horário estimado de término**, não contagem regressiva, e entregue o resultado fechado: nada de abrir preview ou servidor no meio da execução.

## Arquivos de apoio
- `templates/relatorio-eixo.md` — esqueleto do relatório de eixo, pronto para copiar.
- `references/fontes-primarias-frontend.md` — fontes canônicas por eixo para temas de frontend (performance e craft visual), com as que exigem fallback de curl marcadas.
