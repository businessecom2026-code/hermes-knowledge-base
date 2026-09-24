---
name: entrega-autonoma-sem-supervisao
description: Use ao executar e relatar trabalho longo sem supervisão.
---

# Entrega autónoma sem supervisão

Use quando o utilizador delega um bloco longo e sai — foi dormir, mandou fazer o deploy, disse "quando eu acordar tem de estar pronto". Cobre a execução e, sobretudo, **como relatar** quando ele voltar.

O trabalho tem duas metades e a segunda é a que costuma falhar: executar, e relatar de forma que ele **reconheça o que pediu**.

## Regra que governa tudo

**Ancore no módulo de produto, nunca no commit.** Ele pensa e cobra por "o financeiro", "os contatos", "o calendário". Hash, nome de ficheiro e nome de branch são contabilidade interna, não a linguagem dele. Um relato que abre por commit lê-se como trabalho feito no sítio errado, mesmo quando está certo.

## Estimativa: sempre com HORA DE FIM, e sem esperar que a peçam

Ele cobra isto explicitamente quando falta. **Dê a estimativa ao INICIAR o trabalho e ao ENTREGÁ-LO**, sem ser pedida.

**Hora do relógio, nunca duração.** "termina ~14:57" e não "faltam 31 min" — ele não quer fazer a conta. Sempre par de números: caso típico e pior caso.

Uma linha por etapa, para ele saber onde está a espera:

| Se você mandar | Típico | Termina | Pior caso |
|---|---|---|---|
| commit + push | 2 min | **~11:02** | 11:05 |
| deploy completo no ar | 9 min | **~11:09** | 11:18 |

Regras:

- **Baseie em medição, nunca em chute.** Cronometre com `date "+%H:%M:%S"` antes e depois dos passos caros (`npm ci`, build, suite) e reutilize esses números. Sem base, diga que não há e meça.
- **Se o trabalho já acabou, diga a que HORAS acabou** e dê horário das opções seguintes (conferir, deploy). "Tempo restante: zero" é resposta válida; silêncio não é.
- **O deploy remoto é o item de maior variância** — é ele que empurra o pior caso, e é por isso que o pior caso quase dobra o típico.
- Se estourar a estimativa, **diga por quê** numa frase ao entregar. Ele aceita o atraso; não aceita descobri-lo sozinho.

## Durante a execução

### Processos em fundo: `notify=true`, não padrão de texto

Ao correr servidor de dev ou suite longa em fundo, prefira um aviso único ao sair. Padrões de texto amplos envenenam o resto da sessão:

- `"Error"` casa com **nome de coluna** (`lastTestError`, `errorCount`) em log de query SQL — alarme sem erro nenhum.
- Serviço com retry (WhatsApp, e-mail, pagamentos) dispara em rajada e o mecanismo silencia-se sozinho por excesso.
- O buffer drena **depois** e **fora de ordem**, já com o processo morto: chegam avisos de eventos de há uma hora.

Antes de analisar qualquer aviso, confirme se ainda é real: `status`/`exit_code` do processo (`-15` = morto por si) e o relógio da linha contra a hora atual.

**Resultado de suite iniciada ANTES da sua edição descreve o código antigo.** Uma corrida em fundo disparada há minutos chega com vermelho que você já corrigiu — e aceitá-lo faz reabrir trabalho fechado. Compare a hora de arranque (`Start at` do vitest) com a hora da edição; se for anterior, **re-corra** em vez de interpretar. Confirme e diga o resultado novo; não se limite a afirmar que o antigo está obsoleto.

### Ruído classificado uma vez fica classificado

Depois de identificar a causa de um aviso, **uma frase basta nas repetições**. Nunca gaste turnos seguidos a dissecar a mesma linha de log. Enquanto ele espera notícias do módulo, cada mensagem sobre infraestrutura afasta-o da resposta que quer — e acumuladas lêem-se como ter mexido na coisa errada.

Se um aviso obrigar a investigar, investigue e volte **na mesma mensagem** ao estado do trabalho principal.

### Ambiente partilhado: ele mexe enquanto você trabalha

- **Portas podem ficar em duelo.** Dois servidores de dev na mesma porta produzem sintomas absurdos (contexto React que "não existe" num harness que tem o Provider). Confirme com `netstat -ano | grep ':<porta>' | grep LISTENING | awk '{print $5}' | sort -u` — mais de um PID é duelo.
- **A branch remota anda.** Antes de publicar: `git fetch` e `git log --oneline HEAD..origin/main`. Se andou, **rebase por cima** do trabalho do outro, nunca force-push. Depois valide a suite **com o código integrado**, não só com o seu.
- **Contagem de testes a subir é boa notícia** quando entrou código de terceiro; reporte o salto para mostrar que não houve regressão entre integrações.

### Prove no que o navegador executa

Suite verde e build local não provam entrega. Antes de dizer "está pronto": bundle mudou de hash, a correção aparece **minificada** no chunk certo, e a tela abre com `#root` preenchido. Quando o fluxo tem dados, exercite-o com dados reais e confira que os números fecham.

**"No chunk certo" é a parte que engana.** Vite parte o bundle por rota e por idioma: procurar o texto da correção em `index-*.js` dá ausente mesmo com o deploy correto no ar, porque ele vive em `<Tela>-<hash>.js` ou `pt-BR-<hash>.js`. Descubra o chunk no build local (`grep -lF '<texto>' dist/assets/*.js`), extraia o nome correspondente do `index` servido e baixe ESSE. Receita completa em `references/verificacao-de-deploy-no-ar.md`.

**Nunca monitore à espera do hash do seu build local.** O servidor builda noutro SO e gera hash diferente para o mesmo código — esperar por ele faz o monitor correr até ao limite sem nunca casar. Compare o commit remoto (`git ls-remote origin <branch>`) com o seu `HEAD`, e confirme o conteúdo por texto dentro do chunk.

A prova mais forte é reproduzir a **condição original da avaria** (ex.: intercetar a resposta da API e remover o campo que rebentava a tela) e mostrar que agora aguenta.

## Quando ele voltar: como relatar

1. **Abra pelo módulo, em uma frase.** "No Financeiro e nos Contatos, o que mudou foi X." Tabelas de teste vêm depois, nunca antes.
2. **Mostre as linhas, não o nome do commit.** O diff é o que prova que se mexeu no sítio certo:
   ```bash
   git show <commit> -- <ficheiro> | grep -E "^[-+].*<símbolo>"
   ```
3. **Separe principal de acessório.** Correções tropeçadas pelo caminho (serviço externo, script de smoke, ambiente) são nota de rodapé. Se abrem o relato, parece que o trabalho foi noutro sítio.
4. **Diga o que não é seu.** Se entrou commit de terceiro, aponte-o para ele não lhe atribuir uma mudança que você não fez.
5. **Termine com uma pergunta concreta**, oferecendo abrir uma tela específica. Não "qualquer coisa avise".

### Nome de commit e de branch mentem sobre âmbito

"Redesign" no nome engana: uma branch `release/candidato-redesign-*` costuma carregar as **correções sobre** o redesign, e commits chamados `redesign` podem ser de landing page. Para saber o que mudou num módulo, pergunte ao ficheiro dele — nunca à mensagem de commit:

```bash
git log --oneline -10 -- apps/web/src/components/<Modulo>.tsx
git merge-base --is-ancestor <commit> origin/main && echo "está na produção"
```

Quando ele perguntar "onde está o X?", responda com **datas e onde está**, não com defesa. Se o trabalho é anterior à sessão, diga isso de frente e mostre que está em produção.

## Bloqueios que não se contornam

- **Sessão dele não é sua sessão.** Estar logado na janela dele não dá acesso à sua. Sem credencial no cofre, **não adivinhe senha e não o acorde**: crie conta de teste descartável ou use o caminho de smoke test do projeto.
- **CAPTCHA a barrar automação é a proteção a funcionar.** Se o signup responde `captcha_failed` em produção mas o ambiente local passa, reporte como comportamento correto — não como avaria.
- **Script de verificação com dados do país errado** produz falso alarme de segurança (ex.: teste de isolamento que mede zero porque a entidade nunca chegou a ser criada). Confirme se o erro é guarda de negócio legítima antes de reportar falha.

## Antipadrões

- Começar ou entregar trabalho longo sem hora de fim, ou dar duração em vez de horário
- Abrir o relato por hash, ficheiro ou nome de branch
- Encadear mensagens sobre log de infraestrutura enquanto ele espera o estado do módulo
- Re-analisar ruído já classificado em vez de uma frase
- Aceitar vermelho de corrida iniciada antes da sua edição, em vez de re-correr
- Enfraquecer asserção de teste para fechar mais depressa antes de dormir
- Dizer "está pronto" com base em suite verde, sem confirmar o que o navegador executa
- Declarar deploy em falta por não achar o texto em `index-*.js` — procurar no chunk certo primeiro
- Tomar nome de commit como descrição fiável do que mudou

## Relacionadas

- `references/verificacao-de-deploy-no-ar.md` — validar o build a partir do índice antes do push, achar o chunk certo em produção, verificar lógica minificada
- `dev/verificacao-de-tela-com-navegador` — tela branca e checks de Playwright
- `dev/diagnosing-bugs` — laço para bugs difíceis
