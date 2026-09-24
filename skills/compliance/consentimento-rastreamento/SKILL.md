---
name: consentimento-rastreamento
description: Use ao implementar banner de cookie ou gate de pixel.
metadata:
  version: 1.0.0
---

# Consentimento que bloqueia de verdade

Use ao implementar banner de cookie, gate de consentimento, ou ao condicionar pixel do Meta,
Google Analytics, GTM, hotjar ou qualquer terceiro à escolha do visitante. Dispara em "banner de
cookie", "LGPD/GDPR no site", "pixel antes do consentimento", "cookie consent", "condicionar
rastreamento".

Auditar consentimento é outro trabalho (`compliance/lgpd-audit`, `process/auditoria-verificada`).
Esta skill é o procedimento de **construir** o gate, com as decisões que a maioria das
implementações erra.

## Regra número um

**O gate só vale se for medido no browser, contra o build de produção, nos quatro cenários do
passo 8 — aceite incluído.** Este é código que "parece certo" e falha por ordem de montagem,
snippet que se auto-enfileira ou cookie gravado por script de terceiro. Ler o diff não substitui.

## 1. Determine a jurisdição antes de escrever o texto

A sede do controlador decide a lei — não o idioma do site, não onde está o servidor. Ache o
CNPJ/CIF/NIF no rodapé, nos termos e na política antes de citar artigo. Controlador em país da UE
= **GDPR + ePrivacy + lei nacional** (na Espanha, LSSI-CE art. 22.2, autoridade AEPD), não
LGPD/ANPD. Muda o artigo citado, o teto da multa (GDPR: 4% do faturamento global) e o rigor —
autoridades como a AEPD atuam por denúncia individual.

## 2. O pixel sai do HTML estático

Snippet inline no `<head>` é a causa raiz: ele dispara antes de qualquer React/Vue montar, então
nenhuma lógica de consentimento no app consegue impedi-lo. Mova a injeção para o código do app,
dentro do efeito que observa o estado de consentimento.

**Leve o `<noscript><img>` junto.** É a mesma coleta por outro caminho, sem JS e portanto sem
qualquer possibilidade de gate. Remover só o `<script>` deixa o furo aberto.

Deixe no lugar do snippet removido um comentário dizendo **onde ele foi e por quê** — sem isso o
próximo desenvolvedor recola o código do painel do Meta no `<head>`, que é onde a documentação
dele manda colar.

## 3. O estado tem três valores, não dois

```
'pendente' | 'aceite' | 'recusa'
```

Booleano ou `null` não distingue **quem ainda não respondeu** de **quem respondeu que não** — e é
exatamente essa diferença que decide se o banner reaparece na próxima visita. Com dois estados, ou
o banner persegue quem já recusou, ou a recusa é lida como pendência e o banner volta sempre.

Grave **escolha + versão + timestamp ISO**. A versão é o mecanismo de revogação em massa: mudando
a política materialmente, incremente a constante e todos voltam a `pendente`, que é o que o GDPR
exige quando a finalidade muda. Sem ela, um consentimento vale para sempre. Nenhum dado pessoal
vai nesse registro — só a escolha.

**Armazenamento indisponível cai para `pendente`, nunca para `aceite`.** Modo privado, storage
bloqueado por política de terceiros ou JSON corrompido são ausência de prova de consentimento.
Envolva a leitura em `try/catch` e falhe para o lado que não rastreia.

Leia o estado na **inicialização** do estado (lazy initializer), não num efeito pós-montagem: num
efeito existe um intervalo em que quem já aceitou é tratado como pendente, e o banner pisca.

## 4. Aceitar e recusar têm o mesmo peso visual

Dois botões, mesmo tamanho, lado a lado. "Aceitar" em destaque com "recusar" num link cinza
escondido é o padrão que as autoridades europeias tratam como **consentimento inválido** — e é o
que mais gera multa por denúncia individual. Recusar deve custar um clique, igual a aceitar.

**Mesmo tamanho não é mesmo peso.** Botão preenchido em cor de marca ao lado de um apenas
contornado passa qualquer verificação programática de dimensão e ainda assim puxa o clique — as
autoridades leem desequilíbrio visual como indício de consentimento não-livre. Confira olhando a
captura, não o `getComputedStyle`, e ou iguale o tratamento dos dois ou **entregue a ressalva
explicitamente**: mudar aparência é decisão do usuário, deixar de avisar não é.

**Fechar pelo X = recusar**, não "decidir depois". Se fechar deixasse o estado pendente, a
pergunta se repetiria a cada visita; e como nada carrega enquanto está pendente, tratar o X como
recusa explícita é o comportamento honesto e o que para de incomodar.

## 5. Cheque onde o banner realmente renderiza

O componente de consentimento **não pode herdar a condição de exibição do rodapé**. Apps costumam
esconder o rodapé em telas de experiência, landing imersiva ou shells de tela cheia — e é
justamente essa página que dispara o pixel. O resultado clássico: a página que coleta é a única
sem link para a política de privacidade.

Grep as condições do layout (`!isHome && <Footer />` e parentes) e monte o banner **fora** do
wrapper condicional. Confira também colisão de posição com botão flutuante de WhatsApp/chat, que
mora no mesmo canto inferior com `z-index` alto.

## 6. Revogar tem de ser tão fácil quanto consentir

Art. 7.3 do GDPR. Exponha um `reabrir()` num ponto estável — rodapé serve — que limpa o registro
e volta o estado a `pendente`. Sem isso quem clicou uma vez não tem caminho de volta em lugar
nenhum do site, e a implementação inteira falha o requisito mesmo com o gate funcionando.

## 7. Varra os outros terceiros na mesma passada

O pixel raramente está sozinho. Procure chamadas de geolocalização por IP (`ipapi`, `ipinfo`,
`geojs`), fontes e mapas de terceiros, e qualquer `fetch` para domínio externo no arranque.
**IP é dado pessoal** (GDPR art. 4.1): enviar o IP do visitante a um terceiro fora da UE, antes de
escolha e sem base legal, é o mesmo problema do pixel com outra roupa.

Pergunte sempre **o que a chamada resolve**. Detecção de idioma entre poucos idiomas não precisa
de geo-IP: `navigator.language` é a preferência que a pessoa configurou, não uma inferência sobre
onde ela está, e não sai do browser. Trocar por ele **remove** o tratamento em vez de consenti-lo
— sempre a solução mais barata.

Ao remover, cace o que fica órfão (mapas de país→idioma, helpers de parsing). `tsc --noEmit` não
acusa constante não usada; `grep` o identificador. Esses mapas órfãos costumam conter bug latente
— código de idioma que não existe nas traduções — que morre junto; vale mencionar na entrega.

## 8. Prove no browser, contra o build de produção

Build de dev com HMR não serve — rode o preview do bundle real. Confirme primeiro que o pixel não
está no HTML servido (`grep` o domínio do terceiro em `dist/index.html`; 0 = limpo).

Meça os quatro cenários e apresente como tabela:

| cenário | função global do pixel | cookie | script do terceiro |
|---|---|---|---|
| sem escolha | `undefined` | ausente | nenhum |
| recusar | `undefined` | ausente | nenhum |
| recusar + reload | `undefined` | ausente | nenhum, e o banner **não** reaparece |
| aceitar | `function` | **gravado** | carregado |

Sondas, via avaliação de JS na página:

```js
typeof window.fbq                                  // undefined vs function
document.cookie.includes('_fbp')                   // o cookie de fato gravado
Array.from(document.querySelectorAll('script'))    // script do terceiro presente?
  .filter(s => s.src && s.src.includes('facebook')).map(s => s.src)
performance.getEntriesByType('resource')           // qualquer chamada indevida
  .map(r => r.name).filter(u => u.includes('ipapi'))
localStorage.getItem('<chave>')                    // escolha, versão e data
```

**O aceite tem de ser testado também.** Um gate que bloqueia sempre — inclusive depois do sim —
passa nos três primeiros cenários e quebra a medição de mídia sem ninguém notar. Confirme a função
global definida, o cookie gravado e o script carregado.

Teste o `reabrir()` **clicando no botão real** do rodapé, não chamando a função: o que se verifica
é que o caminho existe para o usuário.

**Depois de medir, mostre.** As sondas provam comportamento e nada mais; quem pediu preservação
estrutural vai querer ver a tela. Capture o banner sobre o conteúdo real, o rodapé com o botão de
reabrir, e a página com a recusa salva (para provar que o banner não reaparece) — receita de
captura e leitura em `process/auditoria-verificada`, `references/medicao-em-navegador.md`. É nessa
passada que aparece o desequilíbrio visual do passo 4 e texto rente à borda, que nenhuma sonda
acusa.

## 9. Diga o que o código não resolve

O encanamento pronto não é conformidade. Feche a entrega listando o que continua pendente e é
trabalho jurídico, não de implementação:

- a política de privacidade precisa **descrever o que passou a existir**: a finalidade, o prazo do
  cookie, o destinatário nomeado e a transferência internacional
- encarregado/DPO publicado e canal para os direitos do titular
- banner de categoria única cobre um propósito; entrando analytics depois, tem de virar
  **categoria separada**, não um sim/não global

Diga que é análise técnica e não parecer jurídico, e que esses itens pedem advogado antes da
primeira campanha paga. Entregar o gate sem essa ressalva faz o usuário acreditar que está
liberado para investir.

## Integrar mantendo a estrutura do projeto

Quando o pedido é "mantenha estruturalmente o que já existe", a entrega não é só funcionar — é não
introduzir um segundo padrão no projeto:

- **Copie a forma do context vizinho.** Se existe `ThemeContext`, o de consentimento usa o mesmo
  `createContext` + provider + hook, o mesmo prefixo de chave de storage, o mesmo estilo de tipo.
- **Nenhuma biblioteca nova** para banner de cookie. O gate são ~150 linhas; dependência externa
  traz peso, terceiro próprio e menos controle sobre o passo 3.
- **Reaproveite o vocabulário visual existente** (mesma biblioteca de ícones, mesma paleta, mesmo
  padrão de botão flutuante), e posicione no canto que ainda está livre.
- **Traduza em todos os idiomas que o projeto já suporta**, no mesmo bloco onde vivem as outras
  chaves. Banner monolíngue em site multilíngue é defeito de conformidade: consentimento tem de
  ser compreensível para quem consente.
- **Sem re-arquitetura**: não mexa em router, layout wrapper nem na ordem dos outros providers.
  Posicione o novo provider onde ele alcança o que precisa (dentro do de idioma, se o banner usa
  tradução) e pare aí.

**Mantenha o livro-caixa do que aparece na tela.** Quem pede preservação estrutural volta a
perguntar se você mexeu no visual — e a resposta que convence é uma tabela de um commit por linha
com a coluna "muda a tela?", separando metadado, correção invisível e o único elemento novo. Some
o custo visual real ("duas linhas de CSS e o banner") e nomeie o último commit de UX que **não**
foi seu, para deixar claro onde termina a sua fronteira. Prosa dizendo "não mexi" pesa menos que
o diff por assunto — e é por isso que o passo de commits separados por assunto existe: ele é o que
torna essa tabela possível depois.

## Commit e entrega

Commits separados por assunto — o gate de consentimento não entra no mesmo commit que correção de
crédito de asset ou ajuste de metadata. Na mensagem, descreva o **comportamento observável** que
mudou e por quê, não a lista de arquivos.

Na resposta ao usuário: a tabela dos quatro cenários, as decisões que não são cosméticas (três
estados, paridade dos botões, onde o banner renderiza) com o motivo em uma linha cada, e o bloco
do passo 9. Enquanto o confirmador não aceitou, a palavra é "entregue para revisão", não "pronto".

## Antipadrões

- Manter o snippet no `<head>` e tentar "desligar" o pixel depois que ele já subiu
- Remover o `<script>` e esquecer o `<noscript><img>`
- Estado booleano de consentimento
- Recusa escondida em link secundário, ou X que deixa a escolha pendente
- Banner dentro do wrapper que a página de coleta esconde
- Declarar paridade dos botões medindo só largura e altura, sem olhar o peso visual
- Declarar conformidade sem medir o cenário de **aceite**
- Responder "quero ver o front" com a tabela de medição em vez de capturar a tela
- Entregar o gate sem dizer que política, DPO e canal de direitos continuam pendentes

## Relacionadas

`compliance/lgpd-audit` para o checklist de conformidade · `process/auditoria-verificada` para
verificar achado antes de entregar · `ads/media-buying` quando a medição de mídia depende do pixel
· `security/appsec-audit` para terceiros no arranque.
