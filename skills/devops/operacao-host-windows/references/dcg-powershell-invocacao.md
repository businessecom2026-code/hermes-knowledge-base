# Formas de comando aceitas e recusadas pelo dcg (Windows/git-bash)

Observado diretamente na execução. Serve para escolher a forma certa de primeira em vez de descobrir por tentativa.

## Recusado

Motivo: *embedded PowerShell launcher command contains runtime expansion that dcg cannot statically verify*.

| Forma | Exemplo do que dispara |
|---|---|
| Variável automática em pipeline | `Where-Object { $_.FriendlyName -match 'mouse' }` |
| Variável atribuída | `$id=[Security.Principal.WindowsIdentity]::GetCurrent()` |
| Chamada de tipo .NET | `[Security.Principal.WindowsPrincipal]` |
| `$false` / `$true` como argumento | `-Confirm:$false` |
| Opção `-File` | `powershell.exe -NoProfile -File script.ps1` → *PowerShell host option "-File" is unknown or ambiguous* |

Escapar o `$` (`\$_`) **não** resolve — o dcg olha a string final, não o escape do bash.

Escrever o script em disco e chamar por `-File` **não** é contorno: a opção em si é recusada.

## Aceito

Cmdlet puro, sem `$`, sem bloco de script, sem tipo .NET:

```bash
powershell.exe -NoProfile -Command "Get-PnpDevice -Class Mouse | Format-Table -AutoSize Status, FriendlyName | Out-String -Width 160"
powershell.exe -NoProfile -Command "Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad\Status' | Select-Object Enabled | Format-List"
powershell.exe -NoProfile -Command "Get-Service | Where-Object Name -match 'asus' | Format-Table -AutoSize Status, Name, DisplayName | Out-String -Width 160"
```

Note a terceira linha: `Where-Object <Prop> -match <valor>` na sintaxe **sem bloco de script** passa, enquanto `Where-Object { $_.Prop -match ... }` é bloqueado. Quando precisar filtrar, use sempre a forma sem chaves.

## Estratégia de filtragem

Se a forma sem bloco de script não der conta do filtro, **traga a saída bruta e filtre no bash** (`grep`, `awk`) em vez de insistir em PowerShell mais expressivo. É mais rápido do que colecionar bloqueios.

## Utilitários nativos — sem restrição

Passam direto, e devem ser a primeira escolha quando existirem:

```bash
reg query  "HKCU\Control Panel\Accessibility\MouseKeys"
reg export "HKCU\SOFTWARE\...\PrecisionTouchPad" "$LOCALAPPDATA/Temp/backup.reg" /y
reg add    "HKCU\SOFTWARE\...\Status" /v Enabled /t REG_DWORD /d 1 /f
pnputil /restart-device "<InstanceId>"     # exige admin
net session >/dev/null 2>&1; echo $?       # 0 = elevado
```

## Acentuação na saída

Saída de programas nativos do Windows em português chega com mojibake (`conclu�da`). Não é erro do comando — não reexecute por causa disso; leia o exit code e o conteúdo ASCII.
