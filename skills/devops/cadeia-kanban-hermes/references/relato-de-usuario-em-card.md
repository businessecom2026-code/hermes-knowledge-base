# Reclamação de usuário → card investigado

O utilizador relata em linguagem corrente, sem arquivo nem linha, várias queixas
de uma vez. O trabalho é transformar cada frase em card com achado verificado —
não em card que repete a queixa e manda o produtor descobrir.

## Ordem do trabalho

1. **Investigue no código antes de responder.** Uma resposta que só reorganiza a
   queixa em cards não adianta nada ao produtor; ele vai refazer a investigação
   que você podia ter feito em minutos.
2. **Separe confirmado de hipótese.** Achado seguido até o ponto exato da quebra
   entra como facto; suspeita entra marcada como «verifique antes de corrigir».
3. **Não abra card do que o código contradiz** — pergunte (ver «Quando perguntar»).
4. **Priorize por perda de dado.** Não salvar o que o utilizador escreveu é pior
   que qualquer defeito estético, e o card deve nascer com prioridade acima.

## Rastreie o dado camada a camada até ele parar

Quando a queixa é «escolhi X e não teve efeito», o defeito quase nunca está onde
se escolhe. Grepe o mesmo símbolo em cada camada e ache onde ele deixa de ser
passado:

```bash
grep -rn '<campo>' src/pages/ src/components/   # recolhe? envia?
grep -rn '<campo>' apps/api/src/routes/         # valida? grava? devolve?
grep -c  '<campo>' <componente que devia consumir>
```

Zero no consumidor, com um irmão na mesma página a receber o mesmo prop, é prova
direta: o dado chega e é ignorado. Cole as duas linhas lado a lado no card —
vale mais que qualquer descrição.

O padrão recorrente: um filtro aplicado a **parte** da tela (os anexos) e não à
outra (os campos), com o prop passado só a um dos componentes irmãos.

## A classe: dado descartado ou escondido em silêncio

Queixas diferentes costumam ter este mesmo pai. Procure as três formas:

- **Descarte por pacote incompleto.** Bloco de campos que só é enviado se todos
  os obrigatórios estiverem lá (`campo && campo2 && campo3 ? {...} : undefined`).
  A regra pode ser legítima — dado meio gravado é dado inútil — mas o utilizador
  tem de saber que aquele pedaço não foi, **antes** de guardar, e com o campo
  em falta nomeado.
- **Campo que parece preenchido e não está.** Busca com autocomplete mostra o
  texto digitado, mas o valor só conta depois de escolhido da lista. Quem digita
  e não clica vê um campo cheio e um estado vazio. Trate como defeito de
  interface, não como erro do utilizador.
- **Erro igualado a ausência.** `.catch(() => setX(null))` faz falha de rede,
  404 e permissão negada renderizarem exatamente como «não tem». O utilizador
  relata «sumiu» e ninguém encontra o bug porque o dado está lá. Todo estado
  carregado por rede precisa de três desfechos distintos na tela: tem, não tem,
  falhou a carregar.

Correção que conserta o caminho relatado e deixa o silêncio noutra porta não
fechou o problema. Escreva essa lente no card do revisor.

## Estado que só é mostrado dentro de outro estado

«Preencheu e sumiu» costuma ser dado gravado sem sítio para aparecer: o cartão só
é desenhado dentro do bloco da assinatura, o documento só dentro do processo.
Ter meio de pagamento e ter plano são factos independentes — quando a tela
aninha um no outro, quem tem só o primeiro vê vazio.

Antes de corrigir, decida com evidência **onde o dado está**: não gravou, ou
gravou e não é mostrado? São correções opostas, e o card muda de objeto conforme
a resposta. Mande o produtor responder isto antes de escrever código.

## Quando perguntar em vez de abrir card

Relato do utilizador + código que já faz o que ele pede = **falta informação,
não falta correção**. Exemplo: queixa de que a senha não fica visível, e o campo
tem `type={mostrar ? 'text' : 'password'}` com botão de olho nos dois sítios.

Pergunte qual tela, em uma linha, e diga que verificou. Card especulativo faz o
produtor mexer em código são e a queixa real continua viva.

## Tique que não faz nada sai da lista

Controlo que o utilizador escolhe e que não altera o resultado é pior que
controlo nenhum: ensina a desconfiar de toda a interface. Ao corrigir um filtro
parcial, exija a tabela item a item — quais passam a filtrar de facto e quais
não filtram e porquê. O que ficar decorativo é removido, não documentado.

## Mensagem genérica é metade do defeito

«Não foi possível salvar» sem nomear o campo não cumpre um pedido que tinha duas
partes (não salva **e** não explica). Save corrigido com a mesma mensagem é
reprovação no confirmador — escreva isso no card, e exija que o produtor cole a
mensagem antiga e a nova.

### Procure o handler irmão antes de escrever o novo

Um botão Guardar pode disparar **mais de um POST** (gravar o contacto, e depois
criar o cliente se um tique estiver marcado). Rotas diferentes costumam ter
convenções de erro diferentes — uma devolve `issues`, outra `details`, uma manda
código e outra frase — e o handler que trata a segunda tende a ser mais pobre,
porque foi escrito depois e nunca falhou em demonstração.

Antes de abrir card «melhorar a mensagem», grepe os handlers do mesmo formulário
e compare-os: quando um já desempacota o campo e o outro não, a correção é
**usar o utilitário que já existe nos dois**, não escrever tratamento novo. Diga
isso no card com o nome da função boa — senão nasce um terceiro formato de erro
e o próximo defeito destes fica com três sítios para corrigir.

Exija também o caso 500 no teste: handler que imprime o corpo do erro em vez de
uma frase mostra `CUSTOMER_SAVE_FAILED` a quem preenche o formulário. Código
cru na tela conta como mensagem genérica, não como diagnóstico.

### Nomear o campo não é o mesmo que aceitar o campo

Corrigir a tela para dizer qual campo o servidor recusou não responde se a
recusa era legítima. São dois cards: um de mensagem, outro — só depois de o
utilizador repetir o gesto e ler o campo nomeado — de regra de validação.
Fechar o primeiro a dizer «resolvido» faz o utilizador pensar que pode gravar, e
ele volta a bater na mesma parede com uma mensagem mais bonita.

## O confirmador confirma contra as palavras do utilizador

Cole as frases dele **verbatim** no card do confirmador e diga que o aceite é
contra elas, não contra o corpo do card. O card é a sua paráfrase; se ela
escorregou, toda a cadeia valida a coisa errada e o utilizador reencontra o bug.

Peça o veredito frase a frase: qual deixou de ser verdade, qual ainda é.

## Suíte verde não prova nenhum destes

São defeitos que um humano viu a usar o produto e que a suíte já não apanhava
antes. Exija do testador reprodução em navegador, com o gesto real, e mais de
uma combinação — um caso só prova coincidência, não filtro.
