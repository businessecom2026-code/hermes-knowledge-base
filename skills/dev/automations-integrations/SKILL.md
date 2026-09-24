---
name: automations-integrations
description: Use ao integrar sistemas ou automatizar processo — webhook, fila, job agendado, worker, retry, sincronização entre sistemas, API de terceiro, WhatsApp, e-mail transacional, SMS, telefonia e chamada de voz, pagamento, CRM, planilha. Dispara em "webhook", "integração", "automação", "fila", "worker", "cron", "job", "retry", "idempotência", "sincronizar", "Twilio", "ligação", "discador", "URA", "IVR", "n8n", "Zapier", "Make", "callback", "polling", "rate limit de API", "sandbox".
metadata:
  version: 1.0.0
---

# Automações e integrações

Sistema que fala com outro sistema. A dificuldade nunca é a chamada HTTP — é o que acontece quando ela falha, duplica, chega fora de ordem ou chega duas vezes.

## As quatro leis

1. **Toda entrega acontece pelo menos uma vez, nunca exatamente uma.** Projete para receber duplicado.
2. **Toda chamada externa falha.** Não é hipótese, é agenda.
3. **Ordem não é garantida.** Webhook de "pago" pode chegar antes de "criado".
4. **O terceiro vai mudar sem avisar.** Versione e monitore.

Automação que ignora qualquer uma das quatro funciona na demo e quebra em produção.

## 1. Idempotência — a fundação

Sem isso, retry vira cobrança dupla, e-mail duplicado, ligação repetida.

**Recebendo:**
```js
// Chave vinda do evento do terceiro, não gerada por você
const chave = evento.id;               // ex: "evt_1a2b3c"
const novo = await db.eventoProcessado.createMany({
  data: [{ chave }],
  skipDuplicates: true,                 // insert que não explode em duplicata
});
if (novo.count === 0) return res.status(200).end();  // já processado, responda OK
// ... processa de verdade
```

Responder 200 para duplicata é obrigatório — se responder erro, o terceiro reenvia para sempre.

**Enviando:** mande `Idempotency-Key` quando a API suportar (Stripe, entre outras). A chave deve derivar da intenção (`pedido-123-cobranca`), não de um UUID novo a cada tentativa — senão o retry cria uma operação nova.

## 2. Webhook — recebendo

```
1. Verificar assinatura   → HMAC do corpo BRUTO, tempo constante
2. Verificar timestamp    → rejeitar evento com mais de ~5 min (replay)
3. Checar idempotência    → já vi este id? responde 200 e sai
4. Enfileirar             → grava o evento e responde 200 em < 1s
5. Processar              → no worker, fora do request
```

**Erros que aparecem sempre:**

- **Assinatura conferida no corpo já parseado.** O HMAC é do byte original; qualquer reserialização muda o hash. Guarde o raw body antes do middleware de JSON.
- **Processar dentro do request.** O terceiro tem timeout (5-30s). Estourou, ele reenvia — e agora você processa duas vezes em paralelo.
- **Responder erro para evento que você não entende.** Responda 200 e ignore; senão entra em loop de reenvio eterno.
- **Endpoint sem verificação de assinatura.** Qualquer um posta "pagamento aprovado" no seu webhook.

## 3. Retry e backoff

```js
// Backoff exponencial com jitter — sem jitter, todos os clientes
// voltam no mesmo instante e derrubam o terceiro de novo
const espera = Math.min(30000, 1000 * 2 ** tentativa) * (0.5 + Math.random() * 0.5);
```

**O que se repete:** timeout, erro de conexão, 429, 5xx.
**O que não se repete:** 4xx (menos 429). Payload inválido não melhora na terceira tentativa — mande para a dead letter.

Sempre: teto de tentativas, **dead letter queue** e alerta quando ela cresce. DLQ sem alerta é lixeira.

Respeite `Retry-After` quando o terceiro mandar.

## 4. Fila e worker

- Fila para tudo que pode demorar, falhar ou precisa de retry. Request HTTP não é lugar de trabalho lento.
- Um job faz **uma** coisa. Job que faz cinco falha no passo 4 e o retry refaz os passos 1 a 3.
- Job precisa ser idempotente pelo mesmo motivo do webhook.
- `visibility timeout` maior que o pior tempo de execução, senão dois workers pegam o mesmo job.
- Separe filas por criticidade. Job de relatório não pode atrasar job de cobrança.

## 5. Sincronização entre sistemas

- **Escolha a fonte da verdade por campo**, não por sistema. Sem isso, os dois lados sobrescrevem um ao outro em loop.
- Prefira eventos a polling. Se precisar de polling, use cursor/`updated_since`, nunca varredura completa.
- **Detecte o loop:** A atualiza B, B dispara webhook, A atualiza de novo. Marque a origem da escrita e ignore o eco.
- Guarde `external_id` do terceiro nos seus registros — é o que permite reconciliar.
- Reconciliação periódica: compare os dois lados e alerte divergência. Toda sincronização diverge com o tempo.

## 6. API de terceiro

- **Timeout sempre.** Sem timeout, um fornecedor lento trava seu processo.
- Respeite rate limit: leia os headers (`X-RateLimit-Remaining`, `Retry-After`) e desacelere antes de levar 429.
- Credencial em cofre, escopo mínimo, rotação possível.
- Fixe a versão da API. Atualize deliberadamente.
- Use sandbox do fornecedor para teste. Nunca aponte teste automatizado para produção de terceiro.
- Registre requisição e resposta (com segredo redigido) — sem isso, discutir com o suporte do fornecedor é impossível.

## 7. Telefonia e voz

Ligação tem particularidades que e-mail não tem:

- **Custa dinheiro por tentativa e incomoda uma pessoa real.** Idempotência aqui não é higiene, é evitar ligar três vezes para o mesmo cliente às 3h.
- **Janela legal de horário.** No Brasil, telemarketing tem restrição de horário e dia; respeite antes de discar. Verifique lista de bloqueio (Não Perturbe) quando aplicável.
- **Consentimento é obrigatório** para contato ativo. Base legal registrada, com origem e data — ver `compliance/lgpd-audit`.
- **Opt-out imediato e honrado em todos os canais.** Descadastro que só vale para um canal não é descadastro.
- Gravação de chamada: aviso no início, base legal, prazo de retenção definido.
- Webhook de status (`initiated`, `ringing`, `answered`, `completed`, `failed`, `busy`, `no-answer`) chega fora de ordem. Use máquina de estado com timestamp, não "último evento vence".
- Custo: teto diário e alerta. Loop de discagem com bug queima orçamento em minutos.

## 8. Observabilidade

Automação silenciosa é automação quebrada que ninguém viu.

- Log estruturado por execução: id de correlação, entrada, saída, duração, tentativa.
- **Alerte por ausência**, não só por erro. Job que deveria rodar às 3h e não rodou não gera erro nenhum.
- Métrica de DLQ, latência de fila e taxa de falha por integração.
- Painel com a última execução bem-sucedida de cada automação.

## Checklist antes de ligar em produção

- [ ] Idempotente na entrada e na saída
- [ ] Assinatura de webhook verificada no corpo bruto, tempo constante
- [ ] Responde rápido e processa no worker
- [ ] Retry com backoff + jitter, só em erro repetível
- [ ] DLQ com alerta
- [ ] Timeout em toda chamada externa
- [ ] Rate limit do terceiro respeitado
- [ ] Segredo em cofre, versão da API fixada
- [ ] Alerta por ausência de execução
- [ ] Teto de custo onde há custo por evento
- [ ] Base legal e opt-out, se toca pessoa (`compliance/lgpd-audit`)

## Antipadrões

1. **Processar webhook no request.** Timeout → reenvio → processamento duplicado concorrente.
2. **Retry sem jitter.** Manada sincronizada derruba o terceiro.
3. **Retry em 4xx.** Nunca melhora.
4. **Polling completo a cada minuto.** Queima rate limit e não escala.
5. **Sincronização bidirecional sem detecção de eco.** Loop infinito.
6. **Automação sem alerta de ausência.** Quebra em silêncio por semanas.
7. **Testar contra produção de terceiro.**
8. **Ligar sem consentimento e sem janela de horário.** Risco legal, não detalhe técnico.

## Relacionadas

Segurança do endpoint que recebe: `dev/backend-security`. Revisão do que foi escrito: `security/appsec-audit`. Dado pessoal e consentimento: `compliance/lgpd-audit`. WhatsApp: `ads/whatsapp-marketing`.
