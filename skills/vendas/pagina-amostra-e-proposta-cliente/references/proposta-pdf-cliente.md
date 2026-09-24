# Proposta em PDF para apresentar ao cliente

O PDF é o que vai na reunião. Ele precisa se sustentar sozinho, sem o agente explicando.
Gerado de HTML + CSS de impressão via Chrome `--print-to-pdf` (receita em
`references/captura-headless-chrome.md`).

## Estrutura que funciona — 7 páginas A4

| Página | Papel | Conteúdo |
|---|---|---|
| 1 Capa | promessa | Uma frase de benefício + mockup desktop e celular lado a lado |
| 2 Problema | por que agora | Números da auditoria real do mercado dele, com consequência comercial |
| 3 Primeira tela | a solução | Screenshot do hero + por que aquelas três respostas convertem |
| 4 Blocos | o escopo | As seções da página, uma legenda por bloco |
| 5 Celular | onde o cliente está | Captura mobile real, não simulação |
| 6 **Coringa** | a alavanca | A MESMA página em duas marcas, lado a lado |
| 7 Entrega | fechar | Prazo dia a dia, o que está incluso, próximo passo |

A página 6 é a mais forte: ela transforma "um site" em "um produto que você revende".
Não a corte por falta de tempo.

## CSS de impressão

```css
@page { size: A4; margin: 0; }
.pg { width: 210mm; height: 297mm; padding: 16mm 18mm;
      box-sizing: border-box; page-break-after: always; overflow: hidden; }
.pg:last-child { page-break-after: never; }
```

- Dimensione tudo em `mm`, não em `px` — a conversão do Chrome varia com escala.
- `overflow:hidden` no `.pg` corta o excesso em vez de gerar uma página fantasma no fim.
- `print-color-adjust: exact` nos blocos com fundo colorido, senão imprimem brancos.
- Mockup recortado precisa terminar num limite natural (fim de seção, fim de botão).
  Corte no meio de um CTA parece defeito de arquivo; reduza a altura do mockup até fechar.

## Regra dos números

Toda estatística citada precisa **fechar aritmeticamente na cara do leitor**. Categorias
que se sobrepõem ("sem site" e "site quebrado" contando a mesma empresa) produzem
"117 + 28 + 23" que não soma o total, e o cliente nota antes de você.

- Recalcule cada número da fonte de dados no momento de escrever o PDF, nunca de memória.
- Escolha um corte onde as partes somam o todo, ou diga o denominador em voz alta
  ("dos 168 sites que abriram").
- Depois de gerar, extraia o texto do PDF e confira cada número contra a planilha.

## O que NÃO inventar

Deixe em branco e **pergunte no final** em vez de chutar: preço, prazo contratual, nome do
cliente final, logo, dados de contato da agência, garantias. Número de preço inventado num
PDF que vai para a reunião é o pior erro possível deste trabalho — ele vira compromisso.

Termine a resposta ao usuário nomeando exatamente o que falta decidir, em uma linha.

## Tom

Mesma régua da página: linguagem de leigo, teste de 5 segundos, frase que ele possa falar
na reunião sem traduzir. Cada afirmação de dor vem com a consequência comercial colada.

- Sim: "Quem procura fornecedor no Google não acha você. Todo cliente novo vem de indicação."
- Não: "Baixa maturidade digital e ausência de presença orgânica indexada."
