# Retomar auditoria interrompida

Auditoria longa é interrompida: tecla errada, sessão nova, contexto compactado, máquina reiniciada.
Retomar do zero desperdiça o trabalho já feito e faz o usuário repetir o que já respondeu.

O objetivo desta receita é responder três perguntas antes de escrever qualquer coisa ao usuário:
**o que já foi auditado**, **onde exatamente parou**, e **o bloqueio ainda é real?**

## 1. Recupere a sessão anterior

`session_search` tem quatro formas, escolhidas pelos argumentos:

| objetivo | chamada |
|---|---|
| descobrir a sessão | `session_search(query="<termo do projeto>")` |
| ler janela ao redor de um ponto | `session_search(session_id=..., around_message_id=...)` |
| ler a sessão inteira | `session_search(session_id=...)` |
| listar sessões recentes | `session_search()` sem argumentos |

Comece pela descoberta. O resultado traz `match_message_id` e já hidrata o topo e o rodapé
(`bookend_end`) da sessão — o rodapé costuma ser exatamente o ponto de parada.

### Armadilhas da rolagem

- **`around_message_id` tem de ser um id que existe naquela sessão.** Um número alto "para ir ao
  fim" é recusado com `not in session_id`. Use o `match_message_id` da descoberta, ou um id visto
  numa janela anterior.
- **Para avançar, rerole com o id da ÚLTIMA mensagem da janela**; para voltar, com o da primeira.
  A mensagem de borda se repete como marcador de orientação — não é duplicata.
- **`messages_after: 0` significa fim da sessão.** É o sinal de que você chegou ao ponto de parada,
  e não precisa de mais uma rolagem.
- **Uma janela traz o conteúdo inteiro das ferramentas**, inclusive arquivos longos lidos na
  sessão antiga. Rolar sem necessidade enche seu contexto com o que você já sabe — role até achar
  o ponto de parada e pare.

## 2. Reconstrua o inventário do que já foi coberto

Da sessão recuperada, liste em duas colunas: **lido/medido** e **pendente**. Arquivo lido na
sessão anterior não precisa ser relido se o `mtime` não mudou; achado já verificado não precisa
ser reverificado. Escreva esse inventário na sua primeira mensagem ao usuário — é o que prova
que você retomou em vez de recomeçar.

## 3. Verifique o estado externo, não a sua lembrança dele

O mundo continuou girando enquanto a sessão estava morta. Antes de repetir qualquer pedido,
meça o estado real:

- Processo/servidor ainda no ar? Bata no endpoint de saúde ou na porta.
- Navegador ainda aberto na mesma página? Liste as abas e leia a URL corrente.
- Sessão autenticada? Cheque cookie/sessão de fato — presença de página logada, não a URL.
- Artefatos de trabalho (scripts auxiliares, diretórios temporários) ainda existem? Se existem,
  reutilize; recriar do zero introduz divergência com o que a sessão anterior mediu.

Ferramenta auxiliar que você escreveu na sessão anterior costuma sobreviver no diretório temporário
do sistema. Procure por ela antes de reescrevê-la.

### Outro agente pode estar escrevendo neste exato momento

Interrupção não suspende os outros. Antes de tocar em qualquer arquivo, descubra se o checkout
está sozinho — e compare **mtime contra a hora atual**, não contra a sua lembrança:

```bash
find apps docs tasks -newermt "-25 minutes" -type f | grep -v node_modules
ls -la --time-style=+%H:%M <arquivos em causa>; date +%H:%M
```

- **Arquivo tocado há minutos é trabalho vivo, não estrago da interrupção.** A diferença entre
  "o reboot corrompeu" e "outro agente está no meio da edição" é só o mtime; sem essa checagem
  você "conserta" o que ainda está sendo escrito.
- **Conte os processos agentes antes de editar.** Vários deles no mesmo checkout sem worktree
  separado significam sobrescrita silenciosa: a segunda escrita ganha e a primeira some sem erro.
  Quando houver mais de um, fique na metade somente-leitura e diga ao usuário por que não editou.
- **Suíte vermelha em repositório com agente vivo costuma ser a fase RED de TDD, não defeito.**
  Teste que falha citando chaves/símbolos que ainda não existem é teste escrito primeiro. Confirme
  pelo mtime do arquivo de teste antes de chamar de quebra — "corrigir" um RED alheio destrói o
  ciclo dele e reintroduz o bug que o teste prendia.
- **Type-check passando com suíte vermelha confirma a leitura acima**: o código compila, só falta
  a implementação que o teste exige. Rode os dois; um sozinho não distingue os casos.

Ao revisar trabalho alheio em curso, reporte defeito de conteúdo (comentário truncado, nome de
função faltando) como recado ao usuário, não como edição sua.

## 4. Retome no ponto, não no começo

A primeira mensagem ao usuário tem três partes e nada mais:

1. onde parou, em uma linha;
2. o que já está coberto e o que falta;
3. o único gesto que você precisa dele agora — se houver.

Se houver gesto humano pendente, dispare em paralelo a metade da auditoria que não depende dele
e diga que está rodando. Ver a seção "Auditoria que depende de um gesto humano" no SKILL.md.
