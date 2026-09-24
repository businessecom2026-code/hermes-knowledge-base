---
name: aeo-geo
description: Use quando o objetivo for aparecer em resposta de IA e não só em link azul. Dispara em "AEO", "GEO", "answer engine", "generative engine", "AI Overview", "SGE", "aparecer no ChatGPT", "ser citado pela IA", "Perplexity", "featured snippet", "People Also Ask", "busca por voz", "zero-click", "llms.txt", "schema markup", "dados estruturados", "entidade". Use junto de seo-audit quando a meta incluir tráfego orgânico clássico.
metadata:
  version: 1.0.0
---

# AEO e GEO

Otimização para mecanismos que **respondem** em vez de listar. São duas coisas distintas, frequentemente confundidas:

- **AEO** (Answer Engine Optimization) — ser a resposta extraída: AI Overview do Google, featured snippet, People Also Ask, assistente de voz. A fonte é o índice de busca.
- **GEO** (Generative Engine Optimization) — ser citado por LLM: ChatGPT, Claude, Perplexity, Gemini. A fonte é treino, RAG ou busca em tempo real.

Diferença que muda a tática: SEO clássico disputa **posição**; AEO/GEO disputa **inclusão**. Não existe "segundo lugar" numa resposta gerada — ou você foi citado, ou não existiu.

## O que muda em relação ao SEO clássico

| SEO clássico | AEO / GEO |
|---|---|
| Palavra-chave | Pergunta em linguagem natural |
| Ranquear a página | Ser extraído em trecho |
| Backlink como voto | Menção e consenso entre fontes |
| CTR para o site | Citação, mesmo sem clique |
| Título e meta description | Primeiro parágrafo e estrutura de resposta |
| Página como unidade | Passagem como unidade |

O que **não** muda: conteúdo raso continua invisível. AEO/GEO não é atalho para contornar falta de substância — os dois sistemas são mais exigentes que o ranking clássico, não menos.

## 1. Estrutura de resposta extraível

A unidade de otimização é a **passagem**, não a página.

- Cada seção responde **uma** pergunta, de forma completa, sem depender do resto da página
- Resposta direta nas primeiras 40-60 palavras da seção, **antes** do contexto. Enterrar a resposta depois de três parágrafos de introdução é o erro mais comum.
- Heading é a pergunta como a pessoa fala ("Quanto custa abrir um MEI?"), não o termo seco ("Custo MEI")
- Formatos que extraem bem: definição curta, lista numerada de passos, tabela de comparação, par pergunta-resposta
- Número, data e unidade explícitos. "Custa R$ 76,90 por mês em 2026" extrai; "custa pouco" não.

## 2. Sinais de entidade

Mecanismo generativo raciocina sobre **entidades**, não strings.

- Nome da marca, produto e pessoas usados de forma consistente em todo lugar
- Página "sobre" com fatos verificáveis: fundação, localização, responsáveis, credenciais
- Presença nas fontes que os modelos consomem com peso: Wikipedia/Wikidata quando houver notabilidade real, LinkedIn, Crunchbase, registros do setor
- Vínculo entre entidades explícito no texto ("X é uma ferramenta de Y fundada por Z")
- `sameAs` no schema apontando para os perfis oficiais

## 3. Dados estruturados

Schema.org em JSON-LD. Priorize por tipo de conteúdo:

- `FAQPage` — pares pergunta-resposta
- `HowTo` — processo com passos
- `Article` / `NewsArticle` com `author` e `datePublished` reais
- `Product` com `offers`, `aggregateRating` legítimo
- `Organization` com `sameAs`
- `BreadcrumbList`
- `Speakable` — trechos para voz

Regra dura: o schema precisa descrever o que está **visível na página**. Marcação que não corresponde ao conteúdo é motivo de penalização manual, não de ganho.

## 4. Acesso dos crawlers de IA

Decisão de negócio antes de decisão técnica: bloquear treino protege o conteúdo, mas custa citação. Decida por crawler, não no atacado.

No `robots.txt`, os agentes relevantes: `GPTBot`, `OAI-SearchBot`, `ChatGPT-User`, `ClaudeBot`, `Claude-User`, `PerplexityBot`, `Google-Extended`, `CCBot`, `Bytespider`, `Applebot-Extended`.

Separe o que é **treino** do que é **busca em tempo real**: `Google-Extended` e `GPTBot` afetam treino; `OAI-SearchBot` e `ChatGPT-User` afetam ser citado agora. Bloquear tudo para "proteger conteúdo" costuma eliminar a citação sem impedir o treino — o conteúdo já circula em outras fontes.

Verifique também que não há bloqueio acidental via WAF, Cloudflare bot fight mode ou rate limit agressivo.

### `llms.txt`
Convenção emergente: arquivo em markdown na raiz apontando as páginas canônicas para consumo por LLM. Adoção ainda irregular — vale o custo baixo de manter, não vale tratar como pilar.

## 5. Renderização e velocidade

- Conteúdo principal no HTML servido, não injetado por JS. Vários crawlers de IA **não executam JavaScript**. Isto sozinho explica a maioria dos casos de "meu conteúdo nunca é citado".
- Sem gate de cookie/login sobre o conteúdo que deve ser citado
- HTML semântico; conteúdo principal fora de `<nav>`, `<aside>`, `<footer>`

## 6. Autoridade e consenso

Modelo generativo pesa **concordância entre fontes independentes**.

- Mesmo fato afirmado de forma consistente em vários lugares
- Citação de fonte primária com link
- Autor com credencial verificável e página própria
- Data de atualização real e visível
- Dado original (pesquisa, benchmark, levantamento) — é o que gera citação de terceiros, que é o que gera citação de IA

## 7. Medição

Não existe Search Console para LLM. Monte a medição na mão:

- **Prompts de teste**: 20-50 perguntas que seu cliente faria, rodadas periodicamente em ChatGPT, Perplexity, Gemini e Claude. Registre: citou? qual URL? a informação está correta?
- **Log de servidor**: hits de `GPTBot`, `OAI-SearchBot`, `PerplexityBot`, `ClaudeBot` — é o sinal mais direto de que estão te lendo
- **Referral** de `chat.openai.com`, `perplexity.ai`, `gemini.google.com` no analytics
- **Search Console**: impressão subindo com CTR caindo = você está sendo usado em AI Overview sem clique. Isso é AEO funcionando, não SEO quebrando. Interprete certo antes de "consertar".
- **Menção de marca** sem link — passou a contar

## Antipadrões

1. **Enterrar a resposta** depois de introdução longa. Não extrai.
2. **Conteúdo só em JS.** Invisível para boa parte dos crawlers de IA.
3. **Bloquear todos os bots de IA no atacado** e depois reclamar que nunca é citado.
4. **Schema que mente** sobre o conteúdo visível.
5. **Escrever para o modelo, não para a pessoa.** Texto artificial e repetitivo perde nos dois jogos.
6. **Tratar AEO/GEO como substituto do SEO.** Índice de busca continua sendo a fonte do AEO.
7. **Medir só ranking.** Zero-click é o novo normal; ranking isolado não mostra mais o resultado.

## Relacionadas

Base técnica em `seo/seo-audit` e `seo/seo-coach`. Pesquisa de perguntas reais em `seo/keyword-research` e `seo/keyword-clustering`. Sinais de entidade se apoiam em `brand/brand-positioning`.
