---
name: auditoria-de-experiencia-scroll-3d
description: Use ao auditar ou refinar scroll e cena 3D numa página.
---

# Auditoria de experiência de scroll e 3D

Para páginas em que a narrativa acontece por scroll e parte do movimento vive
dentro de um canvas (GSAP/ScrollTrigger, Three.js, laço `rAF` próprio). Cobre
medir antes de mexer, distinguir engasgo de GPU de engasgo de JS, e provar se
um trecho está mesmo parado antes de propor correção.

## Regra que governa tudo

**Nenhuma alteração antes de o instrumento reproduzir o defeito.** Coreografia
afinada parece quebrada quando medida errado, e a "correção" escrita em cima
disso briga com a animação que já existe. Se você já escreveu, reverta e
confirme com `grep` que nenhum identificador novo sobrou no código.

Quando a medição der negativo, **relate que deu negativo**. Dizer "não achei,
com evidência, o que refinar" é entrega legítima; inventar refino em cena
afinada custa regressão.

## Ordem de trabalho

1. **Leia os comentários do arquivo de fases antes de tudo.** Projetos assim
   costumam registrar cada reequilíbrio já feito e o porquê de cada número — o
   vão que você acha que descobriu pode já ter sido caçado três vezes.
2. **Mapeie a cobertura narrativa** de 0 a 100% do scroll: que bloco domina
   cada ponto. Repita no celular; a altura de scroll muda e o vão migra.
3. **Leia as variáveis da coreografia**, não só o layout — com quadros reais
   entre o scroll e a leitura (ver abaixo).
4. **Compare pixels do canvas** onde o DOM não muda.
5. **Meça performance** e classifique o engasgo (tabela abaixo).
6. **Só então proponha**, no vocabulário que o arquivo já usa (fases nomeadas,
   janelas de scroll), nunca com uma variável paralela concorrente.

## Deixe quadros correrem antes de ler

`window.scrollTo(...)` seguido de leitura imediata devolve o estado ANTERIOR:
quem escreve a coreografia é o laço `rAF`, que ainda não correu. Variáveis CSS
escritas por quadro leem `0` na página inteira e você conclui que a animação
está morta. Encadeie 2–3 `requestAnimationFrame` entre o scroll e a leitura.

Um valor **constante de 0% a 100%** é sinal de instrumento errado, não de
feature quebrada — nenhuma coreografia real fica fixa na página inteira.

## DOM parado não é tela parada

Opacidade e `getBoundingClientRect` imóveis provam apenas que o **DOM** não se
mexe; numa cena WebGL o movimento inteiro vive nos pixels do canvas. Antes de
chamar um trecho de "vazio", compare quadros do próprio canvas.

O mesmo vale para vários canvases com `opacity: 1` ao mesmo tempo: não prova
que todos desenham. Instrumente `drawArrays`/`drawElements` por contexto e
conte chamadas por posição — `IntersectionObserver` costuma já pausar os que
saíram do quadro.

## Classificar o engasgo

| Sinal | Leitura | Ação |
|---|---|---|
| `longtask` vazio no scroll, mas quadros de 60ms+ | GPU: compilação de shader ou upload de textura | Pré-compilar/aquecer material antes do primeiro quadro; não refatorar JS |
| Perfil com `idle` dominando | Há folga de CPU; gargalo não é o laço | Procurar no lado gráfico ou no layout |
| Heap estável, poucos GCs | Sem pressão de alocação | Não caçar `new` dentro do laço |

Engasgo que **se repete na mesma posição** em passagens sucessivas é custo
recorrente; o que some na segunda passagem era inicialização.

Meça FPS com `Emulation.setCPUThrottlingRate` em 4× e viewport de celular
antes de declarar problema de performance — mediana de 60fps ali significa que
não há o que otimizar.

## Peso real, não peso em disco

Compare sempre **gzip**, não bruto, e confirme no `dist/` o que o bundler de
fato emitiu: dependência duplicada em `node_modules` que ninguém importa por
caminho estático não gera chunk e não chega ao usuário. Import dinâmico num
componente nunca renderizado idem — verifique se existe chunk antes de propor
remoção.

Recipes prontas: `references/receitas-de-medicao-no-navegador.md`.

## Antipadrões

- Concluir "trecho vazio" a partir de seletor de texto sem olhar o canvas
- Escrever a correção antes de o instrumento reproduzir o defeito
- Propor otimização de JS com `longtask` vazio no perfil
- Somar peso de `node_modules` como se fosse peso de bundle
- Criar variável de progresso paralela à que a coreografia já escreve

## Relacionadas

- `dev/diagnosing-bugs` — laço de diagnóstico para bugs difíceis
- `design/motion-design` — princípios de movimento
