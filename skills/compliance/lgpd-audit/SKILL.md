---
name: lgpd-audit
description: Use quando houver tratamento de dados pessoais em qualquer produto, site, campanha, formulário, CRM, pixel de rastreamento, base de leads ou integração. Dispara em "LGPD", "dados pessoais", "consentimento", "política de privacidade", "titular", "DPO", "encarregado", "anonimização", "vazamento", "incidente de segurança", "base legal", "cookies", "opt-in", "descadastro", "retenção de dados", "transferência internacional", "ANPD". Também use antes de subir formulário que coleta dado, antes de importar base de leads comprada, e ao revisar pixel/tag de rastreamento.
metadata:
  version: 1.0.0
---

# Auditoria LGPD

Auditoria de conformidade com a Lei 13.709/2018 (LGPD). Aplica-se a qualquer tratamento de dado pessoal de titular no Brasil — independente de onde a empresa ou o servidor estejam.

## Limite importante

Isto é análise técnica de conformidade, não parecer jurídico. Achados de risco alto ou qualquer coisa envolvendo incidente de segurança, transferência internacional ou dado de criança/adolescente devem ir para advogado ou para o encarregado (DPO) antes de virar decisão. Diga isso no relatório — não o omita para parecer mais conclusivo.

## O que conta como dado pessoal

Mais amplo do que a maioria supõe. Inclui qualquer informação que identifique ou torne identificável uma pessoa natural:

- Óbvios: nome, CPF, RG, e-mail, telefone, endereço
- Menos óbvios: IP, cookie ID, device ID, `_fbp`/`_fbc`, Google Client ID, fingerprint de navegador, geolocalização, foto, voz, comportamento de navegação vinculável
- **Dado sensível** (art. 5º, II — regime mais rígido): origem racial/étnica, convicção religiosa, opinião política, filiação a sindicato ou organização religiosa/filosófica/política, dado referente à saúde, à vida sexual, genético ou biométrico

Dado sensível praticamente só se trata com **consentimento específico e destacado** ou hipótese legal restrita. Não vale "legítimo interesse" para dado sensível.

## As 10 bases legais (art. 7º)

Todo tratamento precisa de exatamente uma base legal declarada. Não existe tratamento sem base.

| Base | Quando cabe | Armadilha comum |
|---|---|---|
| Consentimento | Titular escolheu, livre e informado | Checkbox pré-marcado **não** é consentimento. Consentimento genérico também não. |
| Cumprimento de obrigação legal | Lei obriga (fiscal, trabalhista) | Só vale a obrigação real; não serve como curinga |
| Execução de contrato | Dado necessário para entregar o que foi contratado | Não cobre marketing para o cliente |
| Exercício regular de direito | Processo, defesa em juízo | — |
| Proteção da vida | Emergência | — |
| Tutela da saúde | Por profissional de saúde | — |
| **Legítimo interesse** | Interesse do controlador, sem sobrepor direitos do titular | Exige **teste de balanceamento documentado**. Não é base "coringa". |
| Proteção do crédito | Score, cadastro positivo | — |
| Pesquisa por órgão de estudo | Anonimizado sempre que possível | — |
| Garantia da prevenção à fraude | Segurança do titular | — |

Se o único argumento para tratar é "a gente sempre fez assim" ou "o concorrente faz", não há base legal.

## Checklist de auditoria

Rode na ordem. Cada item vira achado com severidade.

### 1. Mapeamento (o que existe)
- [ ] Inventário de dados: quais campos, coletados onde, guardados em que sistema
- [ ] Fluxo: quem coleta, quem acessa, para onde transita, quem é operador
- [ ] Base legal declarada **por finalidade**, não por sistema
- [ ] Prazo de retenção definido por finalidade + gatilho de descarte

### 2. Coleta
- [ ] Formulários pedem só o necessário para a finalidade declarada (minimização, art. 6º, III)
- [ ] Consentimento, quando usado: livre, informado, inequívoco, **destacado**, por finalidade específica
- [ ] Zero checkbox pré-marcado; zero consentimento agrupado com "aceito os termos"
- [ ] Registro do consentimento: quem, quando, qual texto exato, qual versão da política
- [ ] Menor de 16: consentimento específico de ao menos um dos pais/responsável (art. 14)

### 3. Rastreamento e cookies
- [ ] Banner de cookies bloqueia scripts **antes** do aceite, não depois
- [ ] Categorias separadas (necessário / analytics / marketing) com recusa tão fácil quanto aceite
- [ ] Pixels (Meta, Google, TikTok) mapeados: que dado sai, com que hash, sob qual base
- [ ] Advanced Matching / Conversions API: e-mail e telefone hasheados, base legal declarada
- [ ] Server-side tagging não usado para contornar recusa do titular

### 4. Bases de terceiros
- [ ] **Lista comprada ou raspada não tem base legal.** Marque como risco alto, sempre.
- [ ] Lead de parceiro: contrato prevê compartilhamento? O titular foi informado no momento da coleta?
- [ ] Enriquecimento de base (Clearbit, Apollo e similares): qual base legal para cruzar?

### 5. Direitos do titular (art. 18)
Todos precisam de canal funcionando e prazo de resposta:
- [ ] Confirmação de tratamento e acesso aos dados
- [ ] Correção
- [ ] Anonimização, bloqueio ou eliminação de dado desnecessário/excessivo/ilícito
- [ ] Portabilidade
- [ ] Eliminação de dado tratado com consentimento
- [ ] Informação sobre com quem foi compartilhado
- [ ] Revogação de consentimento — tão fácil quanto foi dar
- [ ] Revisão de decisão automatizada (art. 20) — relevante se há score, segmentação algorítmica ou recusa automática

### 6. Operadores e terceiros
- [ ] Contrato com cada operador (agência, CRM, cloud, ferramenta de e-mail) com cláusula de proteção de dados
- [ ] Sub-operadores mapeados
- [ ] Transferência internacional: país com nível adequado, cláusulas-padrão ou consentimento específico (arts. 33-36)

### 7. Segurança e incidente
- [ ] Criptografia em trânsito e em repouso para dado pessoal
- [ ] Controle de acesso por menor privilégio; log de acesso a dado sensível
- [ ] Plano de resposta a incidente com prazo de comunicação à ANPD e ao titular
- [ ] Backup também respeita política de retenção e eliminação

### 8. Governança
- [ ] Encarregado (DPO) nomeado e publicado com canal de contato
- [ ] Política de privacidade em linguagem clara, versionada, com data
- [ ] RIPD (Relatório de Impacto) para tratamento de alto risco
- [ ] Registro das operações de tratamento (art. 37)

## Formato do achado

```
[SEVERIDADE] area/item
Problema: o que está errado, em uma frase factual
Artigo: dispositivo da LGPD tocado
Evidência: arquivo:linha, URL, print do formulário, nome do campo
Risco: consequência concreta (sanção, exposição, ação de titular)
Correção: ação específica, não "adequar-se à LGPD"
```

Severidades:
- **CRÍTICO** — dado sensível sem base, base comprada em uso, vazamento ativo, ausência total de base legal
- **ALTO** — consentimento inválido, ausência de canal de direitos, transferência internacional sem salvaguarda
- **MÉDIO** — retenção indefinida, política desatualizada, operador sem contrato
- **BAIXO** — redação da política, granularidade de cookie, melhoria de registro

## Antipadrões que aparecem sempre

1. **Política de privacidade copiada** de outro site, citando serviços que a empresa não usa e omitindo os que usa. É pior que não ter — vira prova de que ninguém mapeou nada.
2. **"Legítimo interesse" como carimbo** em todo tratamento, sem teste de balanceamento escrito.
3. **Banner de cookie decorativo** que carrega o pixel no `onload` e só registra a escolha depois.
4. **Descadastro que não descadastra** — remove da lista de campanha mas mantém no CRM para "reativação".
5. **Retenção "para sempre"** porque ninguém definiu gatilho de descarte.
6. **Dado sensível coletado por acidente** — campo aberto de "observações" onde o atendente escreve condição de saúde.

## Relacionadas

Para a auditoria de segurança técnica que sustenta o item 7, use `security/appsec-audit`. Para o risco de exposição de dado em campanha paga, use `ads/media-buying` junto com esta.
