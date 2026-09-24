# Copy multilíngue: provar que trocou e que cabe

Esta base serve 4 dicionários (`pt-BR`, `en-US`, `es-ES`, `it-IT`, mais `en-GB`)
em colunas estreitas sobre cena 3D. Dois modos de falha dominam, e nenhum dos
dois aparece em `tsc` ou `npm run build`: **o teste que nunca troca de idioma** e
**a frase que estoura a coluna só num idioma**.

## Os identificadores reais (errá-los produz teste falso-verde)

| Coisa | Valor | Onde |
|---|---|---|
| chave de persistência | `ecom360_lang` | `context/LanguageContext.tsx` |
| códigos de idioma | `pt-BR` `en-US` `en-GB` `es-ES` `it-IT` | idem, `export type Language` |

Os códigos são **completos, com região**. Gravar `'it'`, `'pt'` ou `'en'` não
casa com nenhum dicionário, o provider cai no padrão e a página continua em
português. Confirme os dois na fonte antes de automatizar — nomes de chave são
o detalhe que mais muda entre refactors:

```bash
grep -nE "Language =|ecom360_lang" context/LanguageContext.tsx
```

## Regra: imprima o texto renderizado junto de cada veredito

Um laço que troca o idioma e reporta `ok` para os 4 é **indistinguível** de um
laço que mediu a mesma página em português quatro vezes. Escrever numa chave
inexistente não lança erro: `setItem` aceita qualquer nome, o recarregamento
ignora-o, e o resultado sai verde e falso.

A prova de que o estado mudou é o **conteúdo**, não o valor relido do
`localStorage` — reler devolve o que você acabou de escrever, mesmo em chave que
ninguém consome. Em cada iteração, imprima o título do capítulo ao lado do
veredito:

```js
(document.querySelectorAll('.e360-chapter')[1]
  .querySelector('.e360-heading').textContent || '').trim().slice(0, 44)
```

Quatro títulos visivelmente diferentes (`Gestão espalhada…`, `Running on ten
tools…`, `Gestionar en diez…`, `Gestire su dieci…`) são o aceite. Títulos
repetidos reprovam o teste, não a copy.

## Medir transbordo, não "olhar se coube"

O corpo assenta em `width: min(580px, 90vw)`. Copy densa cabe em português e
estoura em italiano/espanhol, que são mais longos por construção. Compare
`scrollWidth` com `clientWidth` em título **e** corpo de cada capítulo, e a
página inteira contra a viewport:

```js
(() => {
  const o = [];
  const hScroll = document.documentElement.scrollWidth > window.innerWidth + 1;
  document.querySelectorAll('.e360-chapter').forEach((ch, i) => {
    if (i === 0) return;                       // capa nao tem corpo
    const h = ch.querySelector('.e360-heading');
    const b = ch.querySelector('.e360-body');
    if (!h) return;
    const bad = el => el ? (el.scrollWidth > el.clientWidth + 1 ||
                            el.scrollHeight > el.clientHeight + 1) : false;
    o.push(i + ':' + (bad(h) ? 'TIT_OVF' : 'ok') + '/' + (bad(b) ? 'CORPO_OVF' : 'ok'));
  });
  return 'scrollH_pagina=' + hScroll + '  ' + o.join('  ');
})()
```

`scrollH_pagina=true` é regressão de layout mesmo com todos os capítulos `ok`:
algo além do texto empurra a largura.

Cubra a matriz mínima: **desktop nos 4 idiomas** e **390×844 no mais longo
(`it-IT`) e no de referência (`pt-BR`)**. Telemóvel é onde a coluna estreita e a
frase longa se encontram.

## Emulação móvel numa página WebGL

Use `deviceScaleFactor=1` em `Emulation.setDeviceMetricsOverride`. Pedir 2 ou 3
manda a cena renderizar 4× a 9× mais pixels; o renderizador satura, as
avaliações CDP passam a exceder o tempo da ponte e a sessão morre a meio do
laço. A escala não afeta medida de layout em CSS pixels — é custo puro.

Limpe com `Emulation.clearDeviceMetricsOverride` ao terminar: o override
sobrevive à navegação e contamina a medição seguinte.

## `location.reload()` invalida o contexto de execução

Depois de recarregar, a avaliação seguinte pode falhar com
`SecurityError: Access is denied for this document` ao tocar `localStorage` — o
contexto antigo morreu antes de o novo estar ligado. Não interprete como
restrição de permissão: renavegue (`new_tab` + `wait_for_load`) e siga. Por
isso, prefira **uma navegação por idioma** a um laço de reloads encadeados.

## Portão estático que vale correr antes do navegador

```bash
npm run check:i18n     # paridade de chaves entre os 4 dicionarios
```

Ele acusa chave existente num idioma e ausente noutro — a falha que produz texto
em português no meio da página italiana. Não diz nada sobre caber na coluna;
não o trate como substituto da medição acima.

## Critério editorial (o que o dono cobra da copy)

A copy tem de responder, ao bater o olho, **o que a plataforma faz, para quem é e
como se começa**. O que funciona aqui é objeto concreto no lugar de adjetivo:
nomear a dor com coisas reais («venda no WhatsApp, conta na planilha») e mostrar
a integração com um exemplo encadeado («a venda que o Flow360 fecha cai no
Financeiro360») em vez de afirmar «integrado». Remova a objeção de entrada no
fecho (sem migração obrigatória, sem contrato de implantação).

Banido: «solução inovadora», «transforme seu negócio», «revolucionário» e
qualquer frase que sobreviva intacta no site de um concorrente.
