# Diagnóstico de mouse, touchpad e teclado no Windows

Ordem: hardware presente? → desativado por software? → aplicar.

## 1. O dispositivo existe e está saudável?

```bash
powershell.exe -NoProfile -Command "Get-PnpDevice -Class Mouse | Format-Table -AutoSize Status, FriendlyName | Out-String -Width 160"
powershell.exe -NoProfile -Command "Get-PnpDevice -Class HIDClass | Format-Table -AutoSize Status, FriendlyName | Out-String -Width 160"
```

`Status: OK` com o dispositivo listado significa **hardware e driver íntegros** — o problema é configuração, não defeito. Diga isso ao usuário logo: tira o medo de equipamento quebrado e direciona o resto da conversa.

Para pegar o `InstanceId` de um dispositivo específico:

```bash
powershell.exe -NoProfile -Command "Get-PnpDevice -FriendlyName 'ASUS Precision Touchpad' | Format-List Status, InstanceId, Present"
```

## 2. Está desativado por software?

Touchpad de precisão (Precision Touchpad) — **o valor que manda fica na subchave `Status`, não na chave-pai**:

```bash
powershell.exe -NoProfile -Command "Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad\Status' | Select-Object Enabled | Format-List"
```

`Enabled : 0` = desligado por software. Na chave-pai `...\PrecisionTouchPad` o campo `Enabled` costuma vir **vazio**, e ler só ela leva à conclusão errada de que não há nada configurado. Consulte sempre `\Status`.

Outras chaves úteis na mesma árvore: `TapsEnabled`, `LeaveOnWithMouse` (touchpad desliga sozinho quando há mouse USB — causa legítima de "touchpad morreu"), `CursorSpeed`.

Acessibilidade (pode ter sido ativada sem querer e mudar o comportamento):

```bash
reg query "HKCU\Control Panel\Accessibility\MouseKeys"
reg query "HKCU\Control Panel\Accessibility\StickyKeys"
reg query "HKCU\Control Panel\Mouse"      # SwapMouseButtons=1 inverte os botões
```

## 3. Causas comuns antes de mexer no registro

- **Tecla de atalho do fabricante.** Em notebooks ASUS, `Fn` + `F10` liga/desliga o touchpad; outros fabricantes usam `F5`/`F9`. É o culpado mais frequente e custa zero para testar.
- **`LeaveOnWithMouse`**: o touchpad é desligado automaticamente quando um mouse é conectado.
- Mouse USB sumindo é, quase sempre, pilha ou receptor — o registro do dispositivo continua `OK` mesmo assim.

## 4. Aplicar a mudança

```bash
reg export "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad" "$LOCALAPPDATA/Temp/touchpad_backup.reg" /y
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad\Status" /v Enabled /t REG_DWORD /d 1 /f
```

Escrever a chave **não** reativa o dispositivo na hora. Para o Windows reler:

- **Sem admin (preferir):** logoff/logon — `Ctrl+Alt+Del` → Sair. Reaplica todo o `HKCU`.
- **Com admin:** `pnputil /restart-device "<InstanceId>"`. Sem elevação retorna *Acesso negado*; entregue o comando pronto ao usuário para um prompt elevado (`Win` → `cmd` → `Ctrl+Shift+Enter`) em vez de tentar da sessão não elevada.

Não anuncie o conserto antes de o usuário confirmar que o ponteiro voltou.

## 5. Se voltar a desativar sozinho

Suspeite de software do fabricante reaplicando a configuração (em ASUS: serviços `ASUSOptimization`, `AsusAppService`). Liste com:

```bash
powershell.exe -NoProfile -Command "Get-Service | Where-Object Name -match 'asus' | Format-Table -AutoSize Status, Name, DisplayName | Out-String -Width 160"
```
