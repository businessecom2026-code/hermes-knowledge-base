---
name: llm-council
description: Executar consultas, auditorias e decisões por um conselho de múltiplos LLMs usando o aplicativo karpathy/llm-council instalado localmente. Usar quando o usuário pedir LLM Council, conselho de modelos, auditoria multiperspectiva, opiniões independentes com ranking cruzado ou síntese por um chairman.
---

# LLM Council

Usar a instalação global em `C:/Users/judon/.agents/tools/llm-council`, fixada no commit documentado em `references/installation.md`.

## Procedimento obrigatório

1. Definir uma pergunta autocontida. Incluir objetivo, contexto verificável, restrições, critérios e formato esperado.
2. Não enviar segredos, dados pessoais, arquivos privados ou conteúdo fora do escopo. O prompt é transmitido aos modelos configurados via OpenRouter.
3. Verificar apenas a presença de `OPENROUTER_API_KEY`; nunca imprimir seu valor.
4. Salvar o prompt num arquivo de trabalho e executar:

   ```powershell
   uv run python C:/Users/judon/.agents/skills/llm-council/scripts/run_council.py --prompt-file <arquivo> --output <resultado.json>
   ```

5. Preservar no resultado as três etapas: opiniões independentes, avaliações/rankings anonimizados e síntese do chairman.
6. Conferir a síntese contra as evidências locais. O conselho apoia julgamento; não substitui testes, inspeção visual ou fontes primárias.
7. Entregar consensos, divergências, prioridades e riscos. Identificar claramente qualquer modelo que tenha falhado.

## Bloqueios

- Se `OPENROUTER_API_KEY` não estiver configurada, interromper antes da auditoria e pedir que o usuário a configure localmente. Não aceitar nem repetir a chave no chat quando houver alternativa segura.
- Não executar `start.sh`; usar o runner isolado da skill.
- Não alterar a lista de modelos ou gerar custos adicionais sem informar o usuário quando a mudança for material.

Para instalação, modelos padrão e limitações, ler `references/installation.md`.
