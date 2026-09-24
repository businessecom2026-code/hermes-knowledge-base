# Receitas de medição no navegador

Snippets prontos para auditar scroll e cena WebGL. Todos assumem execução via
`js(...)` com retorno serializado.

## Varredura de progresso com quadros reais

```js
(() => new Promise(resolve => {
  const alvo = document.body.scrollHeight - innerHeight;
  const raiz = document.querySelector('.raiz-da-cena');
  const res = []; let pct = 0;
  const passo = () => {
    window.scrollTo(0, alvo * pct / 100);
    requestAnimationFrame(() => requestAnimationFrame(() => requestAnimationFrame(() => {
      const cs = getComputedStyle(raiz);
      res.push({ pct, q: cs.getPropertyValue('--progresso').trim() });
      pct += 4;
      pct <= 100 ? passo() : (window.scrollTo(0, 0), resolve(JSON.stringify(res)));
    })));
  };
  passo();
}))()
```

## Diferença visual entre quadros do canvas

```js
const tmp = document.createElement('canvas'); tmp.width = tmp.height = 48;
const ctx = tmp.getContext('2d');
// por amostra:
ctx.clearRect(0, 0, 48, 48); ctx.drawImage(canvasDaCena, 0, 0, 48, 48);
const d = ctx.getImageData(0, 0, 48, 48).data;
// soma |amostra - anterior| por pixel; ~0 = quadro idêntico
```

48×48 basta para detectar movimento e evita custo de leitura. `getImageData`
num canvas com textura de outra origem lança por CORS — trate a exceção e caia
para outro sinal em vez de concluir "não mudou".

## Quem está realmente desenhando

```js
HTMLCanvasElement.prototype.getContext = new Proxy(HTMLCanvasElement.prototype.getContext, {
  apply(alvo, self, args) {
    const ctx = Reflect.apply(alvo, self, args);
    if (ctx && ctx.drawElements && !ctx.__contado) {
      ctx.__contado = true; self.__draws = 0;
      for (const m of ['drawArrays', 'drawElements']) {
        const orig = ctx[m].bind(ctx);
        ctx[m] = (...a) => { self.__draws++; return orig(...a); };
      }
    }
    return ctx;
  }
});
// injete ANTES de a cena montar; depois leia canvas.__draws por posição de scroll
```

## Mapa de cobertura narrativa

Para cada ponto do scroll, qual bloco domina o quadro (opacidade > 0.5 e
dentro da faixa central da viewport). Renderize como faixas:

```
          0%   10   20   30   40   50   60   70   80   90  100%
hero      |######                                             |
cap-1     |              #############                        |
cap-2     |                     ##############                |
```

Sobreposição entre blocos consecutivos normalmente é **proposital** — é o que
dá continuidade. Faixa sem nenhum bloco só é vão real se o canvas também
estiver estático ali.

## Perfil: JS ou GPU

```js
const po = new PerformanceObserver(l => { for (const e of l.getEntries()) window.__lt.push(e.duration); });
window.__lt = []; po.observe({ entryTypes: ['longtask'] });
// rolar, depois ler window.__lt
```

Quadros longos com `__lt` vazio ⇒ GPU. Complemente com `Profiler.start` /
`Profiler.stop` via CDP e olhe a proporção de `(idle)`.

## Peso transferido

```python
import gzip, pathlib
p = pathlib.Path('dist/assets/arquivo.js'); raw = p.read_bytes()
print(len(raw)/1024, len(gzip.compress(raw, 6))/1024)
```

Compare gzip. Para saber se uma dependência chega ao usuário, procure o chunk
em `dist/` — ausência de chunk significa que o bundler já a eliminou.

## Nota de plataforma

Em Git Bash no Windows, `printf` e comandos com flags soltas dentro de
`for`/`while` podem disparar falso positivo no guardrail de comandos
destrutivos. Quando isso acontecer, faça a mesma conta em Python com
`execute_code` em vez de reescrever o shell.
