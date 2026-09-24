# Leitura eficiente de uma codebase grande

Apoio a `auditoria-ui-de-modulo`. Objectivo: mapear dois módulos de milhares de
linhas em poucas chamadas, sem despejar ficheiros inteiros no contexto.

## Ordem de mapeamento

1. **Pesar antes de ler.** `wc -l` na lista de ficheiros candidatos decide o que
   se lê inteiro e o que se lê por `grep`. Um componente de 1.600 linhas nunca se
   lê todo numa auditoria — extrai-se a estrutura.
2. **Estrutura por `grep`, não por leitura.** As listas de abas, tipos de vista e
   entradas de menu são declarações curtas:
   ```bash
   grep -n "type Tab\|type View\|const tabs\|navItems\|id: '" src/pages/<Pagina>.tsx
   ```
   Isto dá o mapa de navegação inteiro em ~20 linhas de saída.
3. **Só depois `read_file` com `offset`/`limit`** nas regiões que o `grep`
   apontou. Ler a partir do número de linha do achado, com margem de ~60 linhas.

## Encontrar o que foi tocado recentemente

```bash
git log --name-only --oneline -8 -- apps/web | sort -u
```

Mais fiável que `mtime` de `node_modules` para saber onde o trabalho recente
aconteceu — `ls -t node_modules` reflecte instalações parciais e resolução de
dependências, não a intenção de quem editou.

Para datar a chegada de uma dependência, `-S` sobre o manifesto é exacto:

```bash
git log --oneline -S'"<lib>"' -- apps/web/package.json | tail -2
```

O último resultado do `tail` é o commit que a introduziu; os anteriores são
bumps e reversões de versão.

## Batching e granularidade das chamadas

- Agrupar leituras/greps **independentes** na mesma resposta; serializar só
  quando o segundo comando depende da saída do primeiro.
- Preferir várias chamadas médias a uma gigante: uma extracção longa que falha a
  meio perde tudo o que já tinha percorrido.

## Quando o hook de segurança interrompe um comando composto

Comandos de shell com muitos `&&`/`;` encadeados podem exceder o tempo de
avaliação do hook e voltar sem terem corrido. Não é recusa de permissão e não se
contorna desligando nada:

- **Partir o comando** em invocações mais curtas, ou
- **usar as ferramentas dedicadas** (`read_file`, `search_files`) em vez de
  `cat`/`grep`/`ls` no shell — são o caminho previsto para leitura e não passam
  pela mesma avaliação.

Repetir o mesmo comando composto sem o encurtar só gasta chamadas.

## Caminhos no host Windows

O shell é bash (MSYS) mas os programas nativos (`git`, `rg`, `node`) não traduzem
caminhos de estilo `/c/...`. Passar `C:/Users/...` com barras normais a qualquer
programa nativo; `cd /c/Users/...` funciona por ser builtin do bash.
