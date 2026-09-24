---
name: motion-web-stack
description: Use ao animar web ou instalar GSAP/Motion/3D/shadcn.
---

# Stack de motion e UI para web

Catálogo verificado de bibliotecas de animação/3D e registries shadcn, com o que
quebra na prática. Cobre GSAP, Motion (ex-Framer Motion), anime.js, Three.js/R3F,
Lenis, Spline, SplitType e os registries React Bits, Cult UI, Bklit, MicroKit,
Unlumen, Spell, Skiper e 21st.dev.

Kit de referência funcionando: `C:/Users/judon/Documents/IGOR/motion-ui-kit`
(Vite + React 19 + TS + Tailwind v4, build verde, testado em navegador real).

## Escolha da lib — decida antes de instalar

| Preciso de | Use | Não use |
|---|---|---|
| Scroll-linked, timeline complexa, SVG morph, texto letra a letra | **GSAP + ScrollTrigger** | Motion (timeline mais fraca) |
| Animação declarativa em React, gestos, layout/shared-element | **Motion** (`motion/react`) | GSAP (imperativo demais em React) |
| Loop decorativo, stagger, sem React | **anime.js v4** | GSAP (peso maior) |
| 3D de verdade, shaders, partículas | **Three.js + @react-three/fiber + drei** | Spline (menos controle) |
| Cena 3D feita por designer, sem código | **Spline** (`@splinetool/react-spline`) | R3F (custo de autoria) |
| Inércia no scroll da página | **Lenis** | libs de smooth-scroll antigas |
| Quebrar texto em chars/words | **SplitType** | alternativas mais pesadas |

Não empilhe GSAP + Motion + anime.js no mesmo projeto sem motivo. Cada uma é um
runtime; três engines de animação no bundle é desperdício, não sofisticação.

## Instalação verificada

```bash
# motion / 3D (runtime)
npm i gsap @gsap/react motion animejs three @react-three/fiber @react-three/drei \
      @splinetool/react-spline @splinetool/runtime lenis split-type

# utilidades shadcn
npm i clsx tailwind-merge class-variance-authority lucide-react

# tailwind v4
npm i -D tailwindcss @tailwindcss/vite tw-animate-css
```

Versões confirmadas funcionando juntas: gsap 3.15, @gsap/react 2.1.2, motion 13.4,
animejs 4.5, three 0.186, @react-three/fiber 9.8, drei 10.7, lenis 1.3, split-type 0.3.4.

**Não instale `@types/animejs`** — é stub deprecado; anime.js v4 já traz os próprios tipos.

## Registries shadcn — descoberta e status

**A CLI publica um índice oficial com score de saúde de todos os registries públicos:**

```bash
curl -s https://ui.shadcn.com/r/registries.json
```

382 registries, cada um com `health.status` (healthy / degraded / unavailable / observing),
`health.score` e a URL canônica. É a fonte de verdade — consulte-a antes de sair procurando
em blog post ou lista "awesome". Filtre por `status == "healthy"` e ausência de
`headers`/`params` (esses dois campos indicam registry que exige credencial).

A URL do índice também corrige URL errada: `@cult-ui` é `cult-ui.com` (sem `www`),
`@skiper-ui` usa `/registry/` e não `/r/`.

### Instalados e verificados neste kit

| Registry | Itens | URL |
|---|---|---|
| `@react-bits` | 828 | `https://reactbits.dev/r/{name}.json` |
| `@animate-ui` | 580 | `https://animate-ui.com/r/{name}.json` |
| `@ui-layouts` | 327 | `https://ui-layouts.com/r/{name}.json` |
| `@aceternity` | 284 | `https://ui.aceternity.com/registry/{name}.json` |
| `@magicui` | 250 | `https://magicui.design/r/{name}` — **sem `.json`** |
| `@motiq` | 100 | `https://motiq.dev/r/{name}.json` |
| `@kokonutui` | 51 | `https://kokonutui.com/r/{name}.json` |
| `@tween-ui` | 39 | `https://tween-ui.vercel.app/r/{name}.json` |
| `@motion-primitives` | 33 | `https://motion-primitives.com/c/{name}.json` — **`/c/`** |
| `@paceui-gsap` | 29 | `https://gsap.paceui.com/r/{name}.json` |
| `@threecn` | 28 | `https://threecn.dev/r/{name}.json` — R3F pronto |
| `@bklit` | — | `https://ui.bklit.com/r/{name}.json` — charts |
| `@microkit` | — | `https://microkit.co/r/{name}.json` |
| `@unlumen-ui` | — | `https://ui.unlumen.com/r/{name}.json` |
| `@spell-ui` | — | `https://spell.sh/r/{name}.json` |

Repare que o padrão `/r/{name}.json` **não é universal**: magicui omite a extensão,
motion-primitives usa `/c/`, aceternity usa `/registry/`. Copie a URL do índice oficial,
não presuma.

### Bloqueados

| Registry | Status | Causa |
|---|---|---|
| `@cult-ui` | 429 | rate-limit por IP; `health.status: unavailable` no índice oficial — confirma que é problema do servidor deles, não local |
| `@skiper-ui` | 401 | `SKIPER_LICENSE_KEY`, produto pago |
| `@21st` | 403 | `API_KEY_21ST` (cadastro gratuito gera) |

Registries com credencial declaram no `components.json`:

```json
"@skiper-ui": {
  "url": "https://skiper-ui.com/registry/{name}.json",
  "headers": { "Authorization": "Bearer ${SKIPER_LICENSE_KEY}" }
},
"@21st": {
  "url": "https://21st.dev/r/{name}.json",
  "params": { "api_key": "${API_KEY_21ST}" }
}
```

### ui.shadcn.com é formato, não depósito

O shadcn oficial serve apenas os próprios componentes base (`button`, `card`…).
Cada registry hospeda os próprios arquivos no próprio domínio — `texture-card` do
Cult UI dá 404 em `ui.shadcn.com`. O que o shadcn fornece é a CLI, o schema
`registry-item.json` e a convenção (`cn()`, Tailwind, estrutura de pastas).
Instale o base (`npx shadcn add button`) porque muitos componentes de terceiros
declaram `registryDependencies: ["button"]`.

Instalar: `npx shadcn@latest add @microkit/cursor-edge-glow-button`

## Taxa de defeito medida (amostra de 120 itens reais, 10 registries)

Baixando o JSON de 120 componentes reais e instalando 36, os números:

| Padrão no código | % da amostra | Gravidade fora do Next.js |
|---|---|---|
| `"use client"` | 44% | nenhuma — Vite ignora a diretiva |
| `window.`/`document.` | 40% | nenhuma se dentro de `useEffect` (era o caso) |
| cor fixa (`bg-slate-900`) | 22% | **alta** — ignora o tema do projeto |
| tipo importado sem `type` | 19% | média — `TS1484` com `verbatimModuleSyntax` |
| `import ... from "next/..."` | 1% | alta, mas raro |
| `<style jsx>` | <1% | alta, mas raro |

**A crença de que "registry shadcn quebra porque é Next.js" está errada.** Só 1%
importa `next/*`. O que realmente dá trabalho é cor fixa (22%) e acessibilidade.

### O defeito real: 75% dos componentes que animam ignoram reduced-motion

Dos 120 itens, 82 animam. Só 21 respeitam `prefers-reduced-motion`. E a
distribuição não é uniforme — é quase binária por registry:

| Registry | respeita / anima |
|---|---|
| `@tween-ui` | 12/12 — **100%** |
| `@motiq` | 9/9 — **100%** |
| `@magicui`, `@kokonutui`, `@motion-primitives`, `@animate-ui`, `@ui-layouts`, `@threecn` | **0%** |

Use isso para escolher: quando dois registries têm o componente equivalente,
`@tween-ui` e `@motiq` chegam prontos; os outros exigem patch manual em cada `add`.

### A causa nº1 de falha de instalação é o nome, não o registry

Das 38 instalações tentadas, 11 falharam — e **as 11 foram nome que eu inventei**,
zero por defeito de registry. Nomes não seguem convenção adivinhável:
`@animate-ui` usa `components-animate-tabs` (caminho achatado com hífen),
`@react-bits` usa `Squares-TS-TW` (CamelCase + sufixo de stack), e `@kokonutui`
não tem nenhum item com prefixo `btn-` (são `command-button`, `card-flip`, ...).

Nunca deduza o nome. Puxe do índice antes:

```bash
curl -s https://<registry>/r/registry.json | node -e "
  let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{
    const d=JSON.parse(s);(d.items??d).forEach(i=>console.log(i.name))})"
```

O script `scripts/add-component.sh` do kit já faz essa checagem antes de instalar,
lista os arquivos e as dependências npm que entraram, roda `tsc` e a auditoria.

### Erros de TS por registry (27 componentes instalados)

| Registry | comp. | erros TS |
|---|---|---|
| `@magicui` | 6 | **0** |
| `@threecn` | 3 | **0** |
| `@tween-ui` | 3 | **0** |
| `@motiq` | 2 | **0** |
| `@motion-primitives` | 4 | 7 |
| `@ui-layouts` | 3 | 3 |
| `@react-bits` | 1 | 3 |
| `@animate-ui` | 2 | 3 |
| `@aceternity` | 2 | 2 |
| `@kokonutui` | 1 | 1 |

Cruzando com a tabela de acessibilidade: **`@tween-ui` e `@motiq` são os únicos
limpos nos dois eixos** (0 erro TS e 100% reduced-motion). São a primeira escolha
quando existe componente equivalente.

**6 dos 8 erros de TS são mecânicos** — `scripts/fix-registry-component.mjs` corrige
sozinho (medido: 8 → 2). Os 2 que sobram são sempre o mesmo caso: componente
genérico de `motion.create()` cujo tipo colapsa em `never`. Esse exige decisão
humana sobre as props; não automatize.

## Armadilhas que já custaram tempo

### Componentes de terceiros são escritos para Next.js

Num scaffold Vite + TS estrito eles quebram de forma previsível. Todos triviais:

| Erro | Causa | Correção |
|---|---|---|
| `TS6133: 'React' is declared but never read` | import legado; o JSX transform novo não precisa | apague a linha `import React from 'react'` |
| `TS1484: 'X' is a type and must be imported using a type-only import` | `verbatimModuleSyntax` | `import { motion, type Transition }` |
| `Property 'jsx' does not exist on type ... StyleHTMLAttributes` | `<style jsx>` é styled-jsx do Next | troque por `<style>` puro |
| `TS2322: Type 'Ref<never>' is not assignable to type 'never'` | componente dinâmico (`motion.create(...)`) colapsa o tipo do ref | tipe o **componente**: `as React.ComponentType<AnyProps>` |

O último merece atenção: a tentação é castar o *ref* (`as React.Ref<never>`), e isso
**não resolve** — `null` continua incompatível com `never`. A causa é o tipo do
componente, então é o componente que precisa de tipo.

### Dependências que chegam sem pedir

Componente de registry arrasta runtime próprio. Medido neste kit: `ogl`
(React Bits/Aurora), `opentype.js` (Spell), e `@number-flow/react` + 7 pacotes
`@visx/*` + `d3-array` + `d3-shape` só pelo `area-chart` do Bklit. Confira o
`package.json` depois de cada `add` — um componente de gráfico pode custar 10 pacotes.

**React Bits exige sufixo de stack no nome.** `@react-bits/Aurora` devolve HTML
(erro `Unexpected token '<'`). O nome real é `Aurora-TS-TW` — padrão
`<Componente>-{JS|TS}-{CSS|TW}`. Índice completo (828 itens) em
`https://reactbits.dev/r/registry.json`.

**shadcn CLI lê `paths` do `tsconfig.json` raiz, não das referências.** Num scaffold
Vite moderno o raiz só tem `references`, então o CLI não resolve `@/` e cria uma pasta
literal chamada `@` na raiz do projeto. Antes de qualquer `shadcn add`, duplique o
`paths` no `tsconfig.json` raiz além do `tsconfig.app.json`.

**TypeScript 6 deprecou `baseUrl`** — `error TS5101`. Use só `paths` com caminhos
relativos (`"@/*": ["./src/*"]`), sem `baseUrl`.

**Componentes de registry chegam com imports errados.** O bklit gerou
`import { ShimmeringText } from "../components/shimmering-text"` dentro de
`src/components/charts/` — aponta para fora. Sempre rode o build logo após um
`shadcn add`; não confie no "✔ Created".

**anime.js v4 mudou a API.** Não é mais `anime({...})` default: são exports nomeados
`animate`, `stagger`, `createTimeline`. E `anim.revert()` devolve `JSAnimation`, não
`void` — num `useEffect` o cleanup precisa de corpo em bloco, senão `TS2345`.

**Spline pesa.** `@splinetool/runtime` sozinho passa de 1 MB. Carregue sempre com
`lazy()` + `Suspense`; nunca no bundle inicial.

**`NODE_ENV=production` no ambiente mata devDependencies.** `npm install` completa
"com sucesso" instalando só as deps de runtime e nem cria `node_modules/.bin`.
Exporte `NODE_ENV=development` antes de instalar em máquina de dev.

## Acessibilidade — obrigatório, não opcional

**Componente de registry quase nunca respeita `prefers-reduced-motion`.** Medido em
120 itens: 75% dos que animam não trazem a guarda (ver tabela por registry acima).
Trate como defeito a corrigir em cada `add`, não como opcional:

```bash
node scripts/audit-registry-component.mjs src/components   # auditoria completa
grep -L "prefers-reduced-motion\|useReducedMotion" src/components/ui/*.tsx
```

O CSS global que zera durações só alcança animação **CSS**. Não alcança:

| Runtime | Por que escapa | Guarda |
|---|---|---|
| Motion (`animate={...}`) | anima via WAAPI/JS | `animate={reduced ? {x:0} : {...}}` |
| GSAP / anime.js | timeline própria em rAF | `if (reduced) return` no efeito |
| R3F / Three.js | `useFrame` em rAF | `<Canvas frameloop={reduced ? 'demand' : 'always'}>` |
| `offset-path` (BorderTrail) | propriedade animada por JS | idem Motion |

Hook reutilizável (reage a mudança em tempo real, sem recarregar):

```ts
export function useReducedMotion(): boolean {
  const [reduced, setReduced] = useState(
    () => typeof window !== 'undefined' &&
          window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  )
  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)')
    const on = (e: MediaQueryListEvent) => setReduced(e.matches)
    mq.addEventListener('change', on)
    return () => mq.removeEventListener('change', on)
  }, [])
  return reduced
}
```

Regra de aceite: com reduced-motion ligado, **o conteúdo continua visível e legível**.
Se o texto só aparece por causa da animação, reduced-motion apaga a página.

Tilt/hover 3D precisa de equivalente por teclado: `tabIndex={0}` + `onFocus`/`onBlur`
com o mesmo destaque do `onMouseEnter`. Interação que só existe no mouse não existe.

## Verificação — o que provar antes de dizer "pronto"

Build passar não prova que anima. Checklist medido no navegador:

```js
// animacao viva: amostre em intervalos, o stagger atrasa o primeiro elemento
// (medir 2 vezes seguidas da falso negativo)
getComputedStyle(el).transform   // t0, t+0.4s, t+0.8s ...

document.querySelectorAll('h2 .char').length       // SplitType rodou
document.querySelector('canvas').getContext('webgl2')  // WebGL vivo
document.documentElement.scrollWidth > clientWidth  // overflow-x: deve ser false
```

**Meça o elemento que realmente anima, não o container.** O BorderTrail devolveu
`transform: none` nos filhos diretos e pareceu quebrado — quem anima é o `motion.div`
interno, e por `offsetDistance`, não por transform. Leia o código do componente antes
de concluir que está parado.

**Cena 3D com lazy mount não existe até entrar na viewport.** `SceneContainer` do
threecn monta o `<Canvas>` só a ~300px do viewport (economiza contexto WebGL, que o
browser limita a ~8-16). Role até a seção e espere antes de contar `canvas` — senão
parece que o componente falhou.

Mobile: emular 390x844 e conferir overflow horizontal e reflow dos cards.
Reduced-motion: `Emulation.setEmulatedMedia` com `prefers-reduced-motion: reduce`,
recarregar, confirmar que o transform congela e o texto segue visível. **Depois
volte para `no-preference` e confirme que voltou a animar** — uma guarda mal escrita
desliga o movimento para todo mundo.

## Sites de referência (inspiração, não instaláveis)

Catálogos/galerias — servem de fonte visual, não de pacote:
motionsites.ai (prompts de sites animados), unsection.com (seções),
60fps.design (micro-interações iOS/web), inspora.design,
styles.refero.design (2000+ DESIGN.md prontos para agente),
particles.casberry.in (gerador de swarm WebGL por prompt).

Docs oficiais: motion.dev, gsap.com, animejs.com, spline.design.

## Ferramentas do kit

Três scripts em `motion-ui-kit/scripts/`, todos verificados:

`add-component.sh @registry/nome` — instala com rede de segurança: confere o nome
no índice antes (a causa nº1 de falha), mostra arquivos criados e dependências npm
que entraram junto, roda `tsc` e a auditoria no que foi criado.

`audit-registry-component.mjs <caminho>` — audita arquivos já instalados em 11 regras,
separando BLOQUEIA (não compila) de CORRIGIR (roda com defeito: reduced-motion,
vazamento de listener/rAF, cor fixa, interação só de mouse). Sai 1 se houver
bloqueante, então serve em CI.

`fix-registry-component.mjs <caminho> [--dry]` — corrige o mecânico: `import React`
não usado, `TS1484` (tipo sem `type`), `<style jsx>`, parâmetro não usado em map.
Medido: 8 erros → 2. Rode sempre com `--dry` primeiro.

**Cubra as duas formas de importar React.** A primeira versão do fixer só tratava
`import React from 'react'` e passou batido em `import * as React from 'react'` —
que é a forma que o `@animate-ui` usa. Antes de remover, confirme que não sobrou
`React.` nem `<React.` no arquivo.

**Em bash no Windows, não passe caminho MSYS para binário nativo.** `curl -o /tmp/x`
falha com exit 23 e `node -e "require('/tmp/x')"` não acha o arquivo — ambos são
nativos e não traduzem `/c/...`. Use caminho relativo ao projeto. E `node -e` com
JSON inline dentro de script bash embaralha as aspas: ponha a lógica num `.mjs`
separado e chame por arquivo.

**Regra de auditoria que testa import relativo precisa resolver o caminho no disco.**
A primeira versão acusava todo `from '../x'` e deu 5 falsos positivos em imports
legítimos dentro da própria pasta. O defeito não é ser relativo — é apontar para
arquivo que não existe; teste com `existsSync` nas extensões `.ts/.tsx/index.*`.

## Skills relacionadas

`design/gsap-core`, `design/gsap-scrolltrigger`, `design/gsap-react`,
`design/threejs`, `design/motion-design`, `design/hallmark` (anti-slop),
`dev/accessibility-review`, `dev/fixing-motion-performance`.
