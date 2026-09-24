---
name: llm-council-omniroute
description: Use ao rodar o LLM Council no OmniRoute local.
---

# LLM Council + opencode sobre OmniRoute

Dois usos distintos do mesmo router local (`http://127.0.0.1:20128/v1`):

- **LLM Council** — deliberacao em 3 etapas (respostas paralelas -> peer review anonimo -> sintese do chairman). Serve para decisao de arquitetura de alto risco, onde uma segunda opiniao real vale mais que velocidade.
- **opencode `--agent plan`** — leitura de codebase read-only, sem risco de mutacao. Serve para mapear codigo antes de implementar.

Instalacao local: `C:\Users\judon\Documents\IGOR\llm-council`, sobe com `./start-omniroute.sh`.

## Trocar OpenRouter por OmniRoute

O repo original fala com OpenRouter. Tres pontos em `backend/config.py`:

1. `OPENROUTER_API_KEY` deve ler `OMNIROUTE_API_KEY` do `.env` do Hermes (`$LOCALAPPDATA/hermes/.env`), nao um `.env` local vazio.
2. `OPENROUTER_API_URL` vira `http://127.0.0.1:20128/v1/chat/completions`.
3. `COUNCIL_MODELS` precisa de IDs que o router realmente serve.

## Nunca confie no catalogo: teste cada modelo antes

`GET /v1/models` lista centenas de IDs, e boa parte **nao responde**. Falhas reais observadas: `dva/*` (erro de sandbox), `antigravity/*` (cota esgotada), `zc/*` e `aug/*` (CLI nao instalada), `oc/*` (so dentro do opencode), `tllm/*` (IP bloqueado), `ddgw/*` (anti-abuso), varios `nvidia/*` (fora do catalogo vivo).

Antes de montar o conselho, faca um POST de `"responda apenas: ok"` em cada candidato e use so quem devolveu `choices`. Combinacao validada, uma por familia de modelo:

```python
COUNCIL_MODELS = [
    "cc/claude-opus-5",
    "cx/gpt-5.6-terra-high",
    "cfp/zai-org/glm-5.2",
    "cfp/deepseek-ai/deepseek-v4-pro-0813",
]
```

Diversidade de familia e o ponto: quatro modelos do mesmo treino concordam por vies compartilhado, e o peer review vira teatro.

## Retry e fallback sao obrigatorios

O conselho dispara 4 chamadas em paralelo e depois mais 4 de ranking. Sob essa concorrencia o Opus falha intermitentemente, e o repo original trata qualquer excecao como fatal — o resultado e `"Error: Unable to generate final synthesis."` depois de ja ter gasto todas as chamadas das etapas 1 e 2.

Em `backend/openrouter.py`: `query_model` com `attempts=3` e backoff exponencial (`await asyncio.sleep(2 ** attempt)`), mais `query_model_with_fallback(models, ...)` que percorre uma cadeia ate alguem responder. O chairman usa a cadeia, nunca um modelo so.

O titulo da conversa vem hardcoded como `google/gemini-2.5-flash` em `council.py` — troque por uma constante `TITLE_MODEL` apontando para um modelo barato do router, senao todo titulo cai no fallback `"New Conversation"` com 401 no log.

## Armadilhas de Windows

**`npm install` pula o vite.** O ambiente exporta `NODE_ENV=production`, entao o npm omite as devDependencies e `npm run dev` morre com `'vite' nao e reconhecido`. O sintoma engana: o install diz que instalou 87 pacotes e sai com codigo 0. Diagnostique com `ls node_modules/.bin` (ausente = devDeps puladas). Corrija com `export NODE_ENV=development` antes do install.

**Porta e CORS se quebram juntos.** Quando 5173 esta ocupada o Vite escorrega para 5174, 5175... e o CORS do backend, que lista origens fixas, passa a barrar tudo silenciosamente. Fixe `port: 5180, strictPort: true` no `vite.config.js` e troque `allow_origins` por `allow_origin_regex=r"http://(localhost|127\.0\.0\.1):\d+"`.

**`start.sh` do repo nao serve** — use um launcher que checa o router antes de subir e exporta `NODE_ENV=development`.

## opencode no mesmo router

`~/.config/opencode/opencode.json` com provider `@ai-sdk/openai-compatible` apontando para o `baseURL` do OmniRoute e os mesmos IDs validados. Uso read-only:

```bash
opencode run --agent plan --model omniroute/cc/claude-opus-5 "..."
```

O agente `plan` recusa edicao e pede permissao para bash — e a forma segura de deixar um modelo externo ler o repositorio.

## Verificacao de que esta mesmo funcionando

Nao basta o servidor subir. Um POST em `/api/conversations/{id}/message` deve devolver: `stage1` com uma entrada por modelo (campo e `response`, nao `content`), `stage2` com o mesmo numero de avaliacoes, `metadata.aggregate_rankings` com `average_rank` por modelo, e `stage3.response` sem a string `Error:`. Uma rodada leva de 3 a 6 minutos — rode em background com notify, nao em foreground.
