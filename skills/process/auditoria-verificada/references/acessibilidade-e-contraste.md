# Acessibilidade e contraste: medir sem inventar defeito

As duas sondas mais usadas em auditoria de interface são também as que mais produzem falso
positivo. Ambas falham na direção perigosa: acusam defeito onde não há. Valide o instrumento
contra caso conhecido antes de publicar contagem (armadilha 28 do SKILL.md).

## Nome acessível

### O erro: `innerText` não vê o que está oculto

`innerText` devolve **texto renderizado**. Conteúdo dentro de `<details>` fechado, painel de aba
inativa, `hidden`, ou qualquer ancestral com `display:none` sai como string vazia — mesmo com o
texto presente no DOM e perfeitamente disponível para o leitor de tela quando a seção abre.
Auditar com `innerText` transforma toda seção recolhida em lista de "controles sem rótulo".

Use `textContent`, e cheque a **cadeia inteira** de nome acessível, na ordem em que a plataforma
a resolve:

```js
(el) => (
  el.getAttribute('aria-label')?.trim() ||
  (el.getAttribute('aria-labelledby') || '')
    .split(/\s+/).filter(Boolean)
    .map(id => document.getElementById(id)?.textContent?.trim() || '').join(' ').trim() ||
  el.textContent?.trim() ||
  el.getAttribute('title')?.trim() ||
  el.getAttribute('alt')?.trim() ||
  // <label> envolvente ou associado: vale para input, select, textarea
  el.closest('label')?.textContent?.trim() ||
  (el.id && document.querySelector(`label[for="${CSS.escape(el.id)}"]`)?.textContent?.trim()) ||
  (el.tagName === 'INPUT' ? el.getAttribute('placeholder')?.trim() : '') ||
  ''
)
```

**Campo de formulário exige as duas últimas checagens.** `<label>Mês <input type="month"></label>`
nomeia o input sem nenhum atributo ARIA; sonda que só olha `aria-label` reprova markup correto —
e justamente o markup mais idiomático.

### Antes de reportar

- Rode contra um controle que você **sabe** que tem rótulo. Se ele reprovar, pare.
- Para cada suspeito, imprima `outerHTML` recortado. Um `<button>` com `23/09` dentro é prova
  imediata de que a sonda errou, e custa uma linha.
- Ícone decorativo com `aria-hidden="true"` dentro de um botão rotulado não é defeito.

## Contraste (WCAG 2.1 AA)

Mínimo 4.5:1 para texto normal, 3:1 para texto grande (≥18.66px negrito ou ≥24px).

### O erro: parar no primeiro fundo não-transparente

Subir a árvore até achar um `background-color` diferente de `transparent` e usar esse valor como
fundo é errado sempre que houver camada semitransparente no caminho. Um `rgba(255,255,255,0.05)`
sobre superfície escura é quase a superfície escura — mas lido como opaco vira branco, e todo
texto claro por cima é reportado como contraste desprezível. Uma única camada dessas gera dezenas
de reprovações falsas em tema escuro, onde esse padrão é comum.

Componha as camadas de baixo para cima, acumulando alpha:

```js
// devolve o fundo efetivo: sobe a árvore juntando camadas até saturar o alpha
function fundoEfetivo(el) {
  const camadas = [];
  for (let n = el; n; n = n.parentElement) {
    const bg = getComputedStyle(n).backgroundColor;
    const m = bg.match(/[\d.]+/g);
    if (!m) continue;
    const a = m.length > 3 ? parseFloat(m[3]) : 1;
    if (a === 0) continue;
    camadas.push([+m[0], +m[1], +m[2], a]);
    if (a === 1) break;                       // opaco: para aqui
  }
  camadas.reverse();                           // do fundo para a frente
  let [r, g, b] = camadas.length ? camadas[0].slice(0, 3) : [255, 255, 255];
  for (const [cr, cg, cb, ca] of camadas.slice(1)) {
    r = cr * ca + r * (1 - ca);
    g = cg * ca + g * (1 - ca);
    b = cb * ca + b * (1 - ca);
  }
  return [r, g, b];
}
```

A cor do **texto** também pode ter alpha — componha-a sobre o fundo efetivo antes de calcular a
luminância, ou um `slate-400/70` passa por aprovado.

### Antes de reportar

- Afira contra par conhecido: branco sobre preto deve dar **21:1**. Qualquer outro valor
  condena a sonda, não a tela.
- Ignore nó sem texto próprio: teste `node.childNodes` por `TEXT_NODE` não-vazio, senão você mede
  contêiner e conta o mesmo defeito várias vezes.
- Meça **nos dois temas**. Correção de contraste no escuro costuma estragar o claro.

## Da contagem para a tarefa

Agrupe por **causa**, não por ocorrência: "27 reprovações, 4 causas" é acionável; "27 reprovações"
parece um mês de trabalho. A causa é o par (classe de cor, superfície) que se repete.

**Meça a extensão no repositório antes de escrever o card.** `grep -rc` da classe ofensora em todo
o fonte responde se o defeito é local ou sistêmico — e a resposta muda o escopo da tarefa, não só
a estimativa. Centenas de ocorrências espalhadas por dezenas de arquivos não cabem num card:
ninguém revisa esse diff, e o revisor aprova no olho. Escope o card **ao que você mediu**, nomeie
o arquivo e as linhas, e registre no corpo que o resto do repositório tem o mesmo padrão e fica
para outra tarefa. Card honesto sobre o próprio recorte é revisável; card que promete varrer o
repositório inteiro volta pior do que foi.

Ao propor a cor nova, dê o valor e o contraste que ele atinge sobre a superfície real medida, e
exija que o texto secundário continue **visivelmente** secundário — subir cinza até passar no
medidor e fazer o secundário competir com o principal troca um defeito por outro, que o medidor
não pega. Essa é revisão de olho de marca, não de olho técnico.
