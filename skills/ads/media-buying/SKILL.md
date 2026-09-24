---
name: media-buying
description: Use ao planejar, escalar, diagnosticar ou auditar tráfego pago em qualquer plataforma. Dispara em "tráfego pago", "media buying", "escalar campanha", "CPA subiu", "ROAS caiu", "estrutura de campanha", "orçamento", "lance", "público frio", "remarketing", "criativo fadigado", "CAC", "atribuição", "conversão não bate", "pixel", "CAPI", "teste A/B de anúncio". Complementa google-ads e meta-ads (que cobrem a operação de cada plataforma) com a decisão de investimento que é comum às duas.
metadata:
  version: 1.0.0
---

# Mídia paga (tráfego)

Decisão de investimento em anúncio. As skills `ads/google-ads` e `ads/meta-ads` cobrem a mecânica de cada plataforma; esta cobre o que decide **onde e quanto colocar dinheiro** — e é agnóstica de plataforma.

## Antes de qualquer campanha

Três números. Sem eles não existe decisão de mídia, só aposta.

1. **Ticket médio** e **margem de contribuição** — quanto sobra por venda depois do custo do produto
2. **Taxa de conversão** de cada etapa do funil, medida, não estimada
3. **LTV** e janela de repetição — se não houver histórico, trabalhe com a primeira compra e diga que é o piso

Daí saem os tetos:

```
CPA máximo (1ª compra)  = margem de contribuição
CPA alvo                = margem × (1 - lucro desejado)
ROAS mínimo             = 1 / margem %
```

Exemplo: ticket R$ 200, margem 40% (R$ 80). CPA máximo R$ 80 é empate. CPA alvo com 50% de lucro: R$ 40. ROAS mínimo 1/0,40 = **2,5**.

Campanha com ROAS 3 e margem de 20% dá prejuízo. "ROAS bom" não existe fora da margem.

## Medição antes de escala

Escalar com medição quebrada multiplica o erro. Verifique nesta ordem:

- [ ] Evento de conversão dispara **uma vez** por conversão (deduplicação por `event_id`)
- [ ] Server-side (CAPI / Conversions API) ativo e deduplicado com o pixel do navegador
- [ ] Valor da conversão enviado, não só o evento
- [ ] Plataforma × analytics × backend comparados. Divergência acima de 10% é problema de medição, não de mídia.
- [ ] Janela de atribuição declarada e a mesma em toda comparação
- [ ] UTM padronizada e imutável
- [ ] Consentimento respeitado no rastreamento (ver `compliance/lgpd-audit` — isso é obrigação legal, não detalhe)

**Nunca some conversão de plataformas diferentes.** Meta e Google reivindicam a mesma venda. A soma sempre supera a receita real.

Referência de verdade: receita no backend. Plataforma serve para otimizar, não para prestar contas.

## Estrutura

Princípio: **consolidar para o algoritmo aprender, segmentar só quando a decisão exigir**.

- Poucas campanhas com orçamento suficiente batem muitas campanhas famintas
- Cada conjunto precisa de volume para sair do aprendizado (referência comum: ~50 conversões/semana). Abaixo disso, consolide.
- Separe por **decisão de orçamento**, não por curiosidade de relatório. Segmentação para "ver o desempenho" vai no relatório, não na estrutura.
- Frio, morno e quente separados — intenção e CPA esperado são diferentes demais para competir no mesmo leilão

## Criativo é a alavanca principal

Em plataforma com segmentação automatizada, o criativo virou o principal vetor de segmentação. É onde está o maior ganho, não no lance.

- Teste **ângulo**, não variação de cor de botão. Ângulo = promessa, dor, prova, formato, público implícito.
- Um criativo por hipótese. Testar cinco variáveis juntas não ensina nada.
- **Fadiga**: frequência subindo com CTR caindo e CPM subindo. Troque o ângulo, não só a arte.
- Biblioteca de anúncios do concorrente mostra o que está no ar há muito tempo — anúncio velho e ativo costuma ser anúncio lucrativo
- Prove afirmação com evidência real. Promessa que o produto não cumpre reprova na política e queima a conta.

## Escala

Escalar é achar mais volume ao mesmo CPA, não gastar mais.

**Vertical** — subir orçamento no que funciona:
- Incrementos de 20-30% a cada 2-3 dias; salto grande reinicia o aprendizado
- Observe se o CPA sobe junto: se sobe proporcional, o público saturou

**Horizontal** — abrir frentes novas:
- Públicos novos com o mesmo criativo campeão
- Plataformas novas
- Formatos novos
- Geografia nova

Horizontal costuma escalar mais longe. Vertical bate no teto do público.

**Sinais de saturação**: frequência alta, CPM subindo sem mudança de leilão, CPA subindo com taxa de conversão estável (o problema está no tráfego, não na página).

## Diagnóstico

Isole a etapa antes de mexer. O funil dá o diagnóstico:

| Sintoma | Etapa | Causa provável |
|---|---|---|
| CPM alto | Leilão | Público estreito, sazonalidade, qualidade do anúncio |
| CTR baixo | Criativo | Ângulo errado ou público errado |
| CPC alto com CTR ok | Leilão | Concorrência |
| Muito clique, pouca conversão | Página | Promessa do anúncio ≠ página, lentidão, atrito no checkout |
| Converte mas não fecha | Oferta/comercial | Preço, objeção, follow-up |
| CPA subiu de repente | Medição | Verifique o rastreamento **antes** de culpar a mídia |

Ordem certa: medição → oferta → página → criativo → público → lance. Quase todo mundo começa pelo lance, que é o de menor alavanca.

## Orçamento

- Regra de partida: ~70% no que comprovadamente funciona, ~20% em variação do que funciona, ~10% em aposta de ângulo novo
- Orçamento de teste tem que ser suficiente para significância. Teste subfinanciado produz ruído, e ruído vira decisão errada com cara de dado.
- Antes de decidir, exija volume mínimo. Diferença entre 3 e 5 conversões não é sinal.

## Antipadrões

1. **Julgar por ROAS de plataforma** sem cruzar com receita real.
2. **Somar conversão de Meta e Google.** Dupla contagem garantida.
3. **Matar campanha em 24h.** Não saiu do aprendizado.
4. **Dobrar o orçamento de uma vez** no que está funcionando. Reinicia o aprendizado e quebra o desempenho.
5. **Testar cinco variáveis juntas.** Nenhuma conclusão é atribuível.
6. **Escalar com medição quebrada.** Multiplica o erro.
7. **Usar base comprada para público personalizado.** Sem base legal (ver `compliance/lgpd-audit`) e ainda costuma performar mal.
8. **Otimizar para clique** quando o objetivo é venda.

## Relacionadas

Operação por plataforma em `ads/google-ads` e `ads/meta-ads`. Página de destino em `content/copywriting`. Conformidade do rastreamento em `compliance/lgpd-audit`. Público em `research/target-audience`.
