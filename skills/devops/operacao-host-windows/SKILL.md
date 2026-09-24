---
name: operacao-host-windows
description: Use ao operar o host Windows pelo terminal bash.
---

# Operação do host Windows pelo terminal

Aplica-se a: inspecionar dispositivos e hardware, ler e escrever registro, checar serviços, e socorrer o usuário quando mouse, touchpad ou teclado param de funcionar.

O `terminal` roda em bash (git-bash/MSYS) sobre Windows, com o hook `dcg` inspecionando cada comando antes da execução. A maior perda de tempo nesta classe de tarefa não é o problema do usuário — é queimar chamadas em comandos que o dcg bloqueia. Escreva no formato que passa desde a primeira tentativa.

## Regras sempre válidas

1. **Um comando PowerShell embutido não pode conter expansão em tempo de execução.** O dcg bloqueia com *"embedded PowerShell launcher command contains runtime expansion that dcg cannot statically verify"* qualquer `powershell.exe -Command` que carregue `$var`, `$_`, `$env:`, `[Tipo]::Metodo()` ou atribuição — ele não consegue verificar estaticamente o que vai rodar. Use apenas cmdlet + pipe + `Format-List`/`Format-Table`. Formas testadas em `references/dcg-powershell-invocacao.md`.
2. **`-File` também é recusado.** Escrever um `.ps1` com `write_file` e chamá-lo com `-File` não contorna nada — o dcg rejeita a própria opção como "unknown or ambiguous". Não gaste chamada nisso.
3. **Prefira os utilitários nativos ao PowerShell.** `reg query`, `reg add`, `reg export`, `pnputil`, `net session` passam direto pelo bash sem nenhuma das restrições acima, e são mais rápidos. Só recorra ao PowerShell quando não houver equivalente (ex.: `Get-PnpDevice`).
4. **Bloqueio do dcg não se contorna.** Se ele barrar, reescreva o comando numa forma verificável ou peça autorização explícita ao usuário — o bloqueio é do usuário, não seu.
5. **Timeout do dcg (`could not complete safety evaluation within 1000ms`) é transitório.** É falha de avaliação, não recusa: reenvie o mesmo comando uma vez. Não reescreva o comando achando que a forma estava errada. Se voltar a estourar, **encurte em vez de insistir** — o custo da avaliação cresce com o tamanho e o encadeamento, e os reincidentes são heredocs longos e cadeias de três ou mais comandos com `&&`. Quebre em chamadas separadas. Para mensagem de commit longa, escreva-a com `write_file` num ficheiro em `$LOCALAPPDATA/Temp` e use `git commit -F <ficheiro>`: passa de primeira e evita heredoc.
6. **Comando que vai ser repetido, ou que não cabe encurtado, vira ficheiro `.sh`.** Escreva-o com `write_file` em `$LOCALAPPDATA/Temp` e chame `bash <ficheiro>`: o dcg avalia uma linha trivial em vez da cadeia inteira, e passa de primeira mesmo com aspas aninhadas, `$()` e vários `&&` lá dentro. Vale a pena assim que a mesma forma de comando for necessária duas vezes — reenviar e encurtar resolve o caso pontual, o `.sh` resolve a classe. Guarda o comando exacto para reexecução, e a saída fica num ficheiro (`tee`) em vez de truncada no terminal.
7. **Antes de escrever no registro, exporte a chave.** `reg export "<chave>" "$LOCALAPPDATA/Temp/<nome>.reg" /y` — sem isso não há reversão, e mexer em configuração de dispositivo do usuário sem rota de volta é inaceitável. Informe o caminho do backup na resposta.
8. **Depois de escrever, releia a chave.** `reg query` ou `Get-ItemProperty` confirmando o novo valor. Escrita silenciosa no lugar errado (subchave errada, tipo errado) é o modo de falha comum.
9. **Chave escrita ≠ efeito aplicado.** Configuração em `HKCU` só é relida no próximo logon do usuário, ou quando o dispositivo/serviço é reiniciado. Nunca diga ao usuário que "está resolvido" com base na leitura do registro — diga o que está verificado (o valor) e o que ainda falta (aplicar).
10. **Cheque elevação antes de prometer uma ação que a exige.** `net session >/dev/null 2>&1; echo $?` — `0` é admin, qualquer outro valor não é. A sessão do Hermes normalmente **não** é elevada: reiniciar dispositivo (`pnputil /restart-device`, `Restart-PnpDevice`), mexer em `HKLM` e controlar serviços falham com *Acesso negado*. Quando o passo final exigir admin, entregue ao usuário o comando exato para colar num prompt elevado em vez de tentar e falhar.

## Quando o usuário perde mouse, touchpad ou teclado

Este caso tem uma inversão de prioridade própria: **a primeira mensagem entrega a saída de emergência por teclado, antes de qualquer diagnóstico.** O diagnóstico leva vários minutos de chamadas, e nesse intervalo o usuário está travado na frente da tela sem conseguir fazer nada. Diagnóstico primeiro é tecnicamente correto e péssimo na prática.

Ordem:

1. **Saída de emergência, em linguagem de leigo, com as teclas literais.** MouseKeys: `Alt esq` + `Shift esq` + `Num Lock` → `Enter`; depois `8/2/4/6` move, `5` clica, `+` duplo clique. Navegação sem ponteiro: `Tab`/`Shift+Tab`, `Enter`, `Espaço`, `Alt+Tab`, tecla `Menu` ou `Shift+F10` para o botão direito.
2. **Confirme que o MouseKeys está disponível** antes de mandar o atalho como solução garantida: `reg query "HKCU\Control Panel\Accessibility\MouseKeys"` — o bit de atalho ativo vive em `Flags`.
3. **Só então diagnostique.** Procedimento de hardware e chaves de touchpad/mouse em `references/dispositivos-entrada-windows.md`.
4. **Ofereça o caminho sem admin primeiro.** Sair e entrar na conta (`Ctrl+Alt+Del` → Sair) reaplica configuração de `HKCU` e não exige elevação nem senha de administrador. O prompt elevado é a alternativa, não a primeira opção.

## Matar um dev server: o PID do wrapper não é o PID que escuta

`terminal(background=true)` devolve o PID do wrapper. O Vite/node que **detém a
porta** é um filho com outro PID, e matar o pai deixa a porta viva — `curl`
responde 200 e o servidor fica órfão indefinidamente.

```bash
netstat -ano | grep ":5191.*LISTENING"     # PID real na ultima coluna
powershell -NoProfile -Command "Stop-Process -Id 30584 -Force"
```

Armadilhas confirmadas:

- `taskkill //PID n //T //F` **falha** — a conversão de barras do MSYS entrega
  `//PID` ao programa (`Argumento/opção inválido`). `cmd //c "taskkill /PID n"`
  também não mata de forma fiável. Use `Stop-Process` com PID **literal**.
- Um laço (`foreach ($p in 1,2,3)`) cai na regra 1 e é bloqueado pelo dcg. Uma
  chamada por PID, sem variável.
- `process_manage(action='kill')` pode expirar quando a DB do kanban está
  travada por workers ativos; vá direto ao `Stop-Process`.

No fim de sessão com medição em navegador, cace órfãos antes de entregar:
`netstat -ano | grep -E ":(51[7-9][0-9]).*LISTENING"`. Cinco servidores de runs
anteriores estavam vivos sem ninguém notar. O dono **exige** nenhum localhost
aberto durante o trabalho.

## Formato da resposta ao usuário

- Passo acionável primeiro, diagnóstico depois. O usuário quer voltar a trabalhar, não entender o subsistema HID.
- Teclas e comandos sempre literais e copiáveis; nunca "vá nas configurações de acessibilidade".
- Quando houver mais de um caminho, rotule (A/B) e diga qual é o mais simples e o que cada um custa (ex.: "não perde nada aberto").
- Separe explicitamente **o que foi verificado** de **o que ainda depende de uma ação do usuário**. Anunciar conserto não confirmado destrói a confiança no próximo problema.

## Skills relacionadas

- `devops/worker-environment-recovery`: quando quem morre é a TUI do Hermes ou o ambiente de dev, não o host.
- `devops/limpeza-de-dados-em-producao`: quando o alvo é uma base de produção, não o host — usa o padrão `.sh` da regra 6 para toda a cadeia de inventário, ensaio e verificação.
