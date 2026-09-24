# Revisar trabalho de outro agente

Outro agente (CLI paralelo, worker de board, sessão do usuário) commitou no mesmo repositório e o
usuário pergunta se aquilo faz sentido. Não é leitura de diff: é auditoria, com o mesmo portão de
verificação de qualquer achado — **execute, não leia o relatório dele**.

A assimetria a vencer: o autor teve contexto que você não tem, e por isso a tentação é aprovar
pela qualidade da narrativa. Comentário datado, autocrítica no commit e mensagem detalhada são
sinais de cuidado, não prova de correção.

## 1. Confirme que nada foi perdido antes de alarmar

`git reflog` cheio de `rebase (start)` / `rebase (pick)` / `rebase (finish)` parece reescrita de
histórico, e `git log` com um commit novo no topo empurrando o que você conhecia parece perda.
Quase sempre é `pull --rebase` normal. **Nunca anuncie perda de commit sem testar ancestralidade:**

```bash
git branch --show-current
for c in <commits que você conhecia>; do
  printf "%s: " $c
  git merge-base --is-ancestor $c HEAD && echo "ancestral de HEAD (ok)" || echo "*** FORA do histórico ***"
done
git reflog -12
```

Alarme falso de perda de trabalho custa confiança na mesma moeda que achado falso.

## 2. Números do commit são auto-relato

Rodapé de commit com "N ficheiros · M testes verdes · tsc limpo · build limpo" descreve a máquina
do autor no momento em que ele escreveu — não o seu checkout depois do merge. Rode você:

```bash
cd apps/api && npx vitest run            # suíte inteira, não só o arquivo novo
cd apps/web && npx tsc --noEmit && npx vite build && npx eslint src
```

A contagem divergir para cima (mais testes que o commit declara) é normal e esperado — outros
commits entraram. Divergir para baixo, ou falhar, é achado.

Comando de build/preview disparado em foreground é recusado como processo de longa duração:
rode em background com notificação de término e colete o resultado depois, em vez de reformular
o comando várias vezes.

## 3. Verifique a correção no mecanismo, não no texto do arquivo

O teste do autor pode passar e o defeito continuar de pé. Duas formas frequentes:

- **Assertion de existência em vez de comportamento.** `expect(fonte).toMatch(/nomeDaGuarda/)`
  confirma que o símbolo aparece no arquivo; não confirma que a guarda funciona nem que é
  liberada. Ao revisar teste que lê fonte com `readFileSync`, pergunte a cada assertion: isto
  falharia se o comportamento estivesse errado? Se não, o teste é decorativo.
- **Edição parcial que o compilador não vê.** Script que move um bloco de JSX e aborta no meio
  deixa a cópia nova no destino e a antiga na origem. `tsc` aceita (é JSX válido) e a assertion
  "está fora do bloco" também passa. Conte as ocorrências:

```bash
grep -c "<NomeDoComponente" <arquivo>   # 1 import + 1 uso; mais que isso é duplicata montada duas vezes
```

## 4. Guarda nova: enumere as saídas antes de aprovar

A classe de bug mais fácil de introduzir ao corrigir duplo-clique, dupla submissão ou corrida:
travar com flag (`useRef`, booleano de módulo, semáforo) e liberar só no caminho felizmente
concluído. Cada `return`/`throw` antecipado **depois** do ponto em que travou deixa a trava presa —
e o efeito para o usuário é pior que o bug original: botão morto sem mensagem, e a pessoa conclui
que o sistema quebrou.

Verifique mecanicamente, não de olho:

```python
# no corpo da função: onde trava, onde libera, e quantas saídas há entre as duas
import re
corpo = fonte[fonte.find("async function <nome>"):]
for m in re.finditer(r".*<nomeDaFlag>.*", corpo):  print(m.group(0).strip())
print("tem finally?", "finally" in corpo)
print("saídas após travar:", len(re.findall(r"\n\s+(return|throw)\b", corpo[corpo.find("<flag> = true"):])))
```

A correção certa é `try/finally` com a liberação no `finally` — libera em erro, em validação
recusada e em exceção, sem depender de enumerar caminhos futuros. Validação que roda **antes** de
travar não tem o problema; recomendar mover a trava para depois das validações locais também
resolve.

A mesma verificação vale para qualquer recurso com par de aquisição/liberação: cursor de banco,
`AbortController`, lock de arquivo, estado de "salvando" que desabilita botão.

## 5. Separe o que aprovar do que devolver

Aprove nomeando o mecanismo, não o esforço: *"tirou o `setData(null)`, moveu o modal para fora do
bloco e contou as ocorrências no teste"* prova que você leu. Devolva com o caminho exato
(`arquivo:linha`), o sintoma que o usuário sentiria e a correção mínima — uma linha que ele possa
colar na janela do outro agente.

Não edite o arquivo de outro agente com sessão viva: a segunda escrita ganha em silêncio. Entregue
o recado ao usuário ou publique no canal de documentos que os dois leem.
