# Instalação local

- Origem: https://github.com/karpathy/llm-council
- Caminho: `C:/Users/judon/.agents/tools/llm-council`
- Branch: `master`
- Commit fixado: `92e1fccb1bdcf1bab7221aa9ed90f9dc72529131`
- Backend: FastAPI, httpx, pydantic e python-dotenv, instalados por `uv sync --locked`.
- Frontend: React e Vite, instalados por `npm ci`.
- O runner da skill usa apenas o backend; não precisa iniciar a interface web.

## Fluxo original

1. Os modelos respondem de forma independente.
2. Cada modelo avalia respostas anonimizadas e gera um ranking.
3. O chairman sintetiza a resposta final.

## Modelos definidos pelo repositório

- `openai/gpt-5.1`
- `google/gemini-3-pro-preview`
- `anthropic/claude-sonnet-4.5`
- `x-ai/grok-4`
- Chairman: `google/gemini-3-pro-preview`

Os identificadores podem deixar de existir no OpenRouter. Se uma execução falhar por modelo indisponível, registrar a falha e pedir autorização antes de alterar a composição do conselho.

## Segurança e limitações

- O repositório não possui licença declarada na raiz; manter uso local e não redistribuir código derivado sem esclarecer licença.
- O próprio autor descreve o projeto como experimental e sem suporte.
- `npm ci` reportou 12 vulnerabilidades no frontend em 2026-08-31; o runner não inicia nem utiliza o frontend.
- Toda consulta é enviada ao OpenRouter e pode gerar cobrança.
