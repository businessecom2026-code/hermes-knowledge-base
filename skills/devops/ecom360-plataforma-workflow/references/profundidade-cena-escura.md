# Profundidade e ambiente em cena escura

Esta home é fundo near-black com linha verde-jade. Toda tentativa de construir
profundidade aqui esbarra nas mesmas armadilhas de física de luz — elas não são
questão de gosto e o laudo visual sempre volta com a mesma frase: *"parece um
cartão colado por cima da cena"*.

## Ordem de correção para ancorar um objeto no espaço

1. **Em cena escura o que ancora é a LUZ que o objeto lança, não a sombra.**
   Sombra preta sobre fundo preto não tem contraste para existir. Inverta:
   facho da cor da marca em alta opacidade junto à base, decaindo para fora.

2. **`filter: blur` sobre elemento rotacionado dissipa a luz até ela sumir.**
   O blur é aplicado depois da projeção e espalha o mesmo alfa por uma área
   muito maior. Ponha a suavidade nas paradas do próprio `radial-gradient`
   (várias paradas com alfa decrescente) e deixe o elemento sem `filter`.
   Medido nesta home: com `filter: blur(16px)` o brilho abaixo do card caía
   28 → 14; movendo a suavidade para o gradiente, subiu para 47.

3. **Pseudo-elemento com `z-index: -1` some dentro de pai que tem `transform`.**
   O `transform` cria stacking context, então o pseudo fica atrás do fundo do
   próprio pai em vez de atrás do card. Envolva o objeto num wrapper sem
   `transform` e pendure luz e sombra no wrapper.

4. **`bottom: -Npx` + `rotateX` colapsa a projeção para dentro do objeto.**
   Ancore em `top: 100%` para o facho nascer na borda inferior e projetar para
   fora, com `transform-origin: top center`.

5. **Inclinação sutil** do objeto (`rotateX` 5-6° sob `perspective` do pai)
   alinha-o ao eixo da cena. Frontal e chapado lê como overlay de UI.

## Construir o volume (corredor, palco, interior)

- **Piso em grade só lê como plano com linhas nos DOIS eixos.** Uma listra
  sozinha lê como listra, não como chão em perspectiva.
- **O túnel precisa terminar numa parede de fundo.** Dissolver no preto deixa
  a cena aberta e desfaz a sensação de interior.
- **Vinheta forte apaga justamente as bordas** do chão e das paredes que
  constroem a perspectiva. Se usar, deixe só nos cantos extremos.
- Chão e teto devem correr com o scroll (`backgroundPosition` em sentidos
  opostos, com lerp) — cenário parado lê como papel de parede.

## Movimento que se sustenta com o dedo parado

Cenário amarrado ao scroll morre quando o visitante para de rolar — e ele para
o tempo todo, para ler. Uma cena que só vive durante o gesto é relatada como
"imóvel", mesmo com o código a correr perfeitamente.

- **Separe as duas fontes de movimento.** O avanço (para onde a câmara vai) é
  função do progresso de scroll e tem de ser reversível. A **vida** (deriva
  lenta, respiração da luz, partícula a flutuar) corre no relógio e nunca para.
  São camadas distintas: somar tempo ao ângulo de progresso reintroduz o defeito
  de voltas acumuladas que `GIRO_LIVRE = 0` resolveu.
- **O laço tem de continuar depois do último evento de scroll.** `requestAnimationFrame`
  agendado só dentro do handler de scroll congela a cena no repouso. Mantenha o
  laço vivo enquanto a secção estiver visível (`IntersectionObserver` liga e
  desliga) e respeite `prefers-reduced-motion`.
- **Grade a deslizar sob `rotateX` alto foge para o horizonte em vez de avançar.**
  O olho lê textura a escorrer, não profundidade percorrida. O que dá avanço é
  elemento com escala e opacidade a crescer enquanto se aproxima — um objeto que
  passa por si, não um padrão que corre por baixo.

### Prova de movimento percebido

Amostrar a variável CSS não prova nada: `--e360-corredor-y` foi de 0 a 990px numa
cena que o dono chamou de estática. A medição honesta é **dois screenshots
separados no tempo, SEM scroll entre eles** — se forem idênticos, a cena está
parada para quem está a ler. Compare também dois screenshots com scroll entre
eles para confirmar que o avanço existe. As duas provas são obrigatórias e
respondem a perguntas diferentes.

## Como provar que a luz existe

Julgar pelo screenshot sozinho falha: o laudo diz "não vejo sombra" tanto quando
o efeito não foi desenhado quanto quando foi desenhado escuro demais. Meça.

Amostre o brilho médio em faixas horizontais logo abaixo do objeto, via
`getImageData` sobre um recorte do screenshot. **Série decrescente desde a
primeira faixa = o efeito não está sendo desenhado onde você pensa**, por mais
plausível que o CSS pareça. O esperado é pico na base e decaimento suave.

Recorte pela geometria real do alvo (`getBoundingClientRect().bottom`), não por
coordenada fixa — a estação visível muda com o scroll.

## Diagnóstico antes de prototipar

Antes de propor direção visual nova para uma seção que o dono chamou de
"abstrata" ou "sem direção", **leia as cenas que ela usa e compare-as entre si**.
A queixa de "repetitivo" costuma ser literal: capítulos que parecem quatro
momentos distintos podem ser o mesmo sistema de partículas em quatro arranjos
(`scatter`, `mesh`, `pulse`, `return` — os mesmos pontos). Nesse caso o problema
é estrutural e nenhuma correção de cor, contraste ou tipografia resolve.

Do mesmo modo, **procure no código o que a narrativa promete antes de construir
do zero**: o mergulho para dentro do celular (`e360-phone-portal`, máscara que
abre o miolo do canvas + "Você está dentro") já existia e estava bem feito. O
defeito era o que vinha DEPOIS dele — o visitante entra, lê uma frase e volta
imediatamente para o campo de partículas do lado de fora. Propor um portal novo
seria reconstruir o que já funciona e deixar o defeito real intacto.
