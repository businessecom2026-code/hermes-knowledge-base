---
name: threat-modeling
description: Use ao desenhar sistema, feature ou integração nova, antes de escrever código. Dispara em "modelagem de ameaça", "threat model", "STRIDE", "superfície de ataque", "quem pode atacar isso", "que dado sensível passa aqui", "arquitetura segura", "risco de design". Também use ao adicionar integração com terceiro, ao expor dado para fora, e ao revisar arquitetura existente que nunca passou por análise de segurança.
metadata:
  version: 1.0.0
---

# Modelagem de ameaça

Achar falha de **design** antes que ela vire código. Falha de design não se corrige com patch — se corrige reescrevendo, e por isso custa 100x mais tarde.

## Quatro perguntas

Toda modelagem responde estas, nesta ordem:

1. **O que estamos construindo?** — diagrama de fluxo de dados
2. **O que pode dar errado?** — enumerar ameaças
3. **O que vamos fazer?** — mitigação por ameaça
4. **Fizemos um bom trabalho?** — validar cobertura

## 1. Diagrama de fluxo de dados

Desenhe antes de teorizar. Elementos:

- **Entidade externa** — usuário, sistema de terceiro, atacante
- **Processo** — serviço, função, endpoint
- **Armazenamento** — banco, cache, fila, bucket, log
- **Fluxo** — dado transitando, com o protocolo
- **Fronteira de confiança** — onde o nível de confiança muda

A fronteira de confiança é o que importa. Toda ameaça séria cruza uma. Marque cada uma:
- Internet → sua API
- Seu backend → banco
- Seu código → dependência de terceiro
- Usuário comum → área administrativa
- Tenant A → tenant B (multi-tenant)

## 2. STRIDE por elemento

Para cada processo, armazenamento e fluxo que cruza fronteira:

| Letra | Ameaça | Pergunta | Propriedade violada |
|---|---|---|---|
| **S** | Spoofing | Dá para se passar por outro? | Autenticidade |
| **T** | Tampering | Dá para alterar dado em trânsito ou repouso? | Integridade |
| **R** | Repudiation | Dá para negar que fez? | Não-repúdio |
| **I** | Information disclosure | Dá para ler o que não deveria? | Confidencialidade |
| **D** | Denial of service | Dá para derrubar ou exaurir? | Disponibilidade |
| **E** | Elevation of privilege | Dá para virar admin? | Autorização |

Não pule letra por parecer improvável. Escreva "não aplicável porque X" — a justificativa é o valor.

## 3. Perfis de atacante

Modelar sem atacante concreto produz lista genérica. Escolha os que cabem:

- **Usuário legítimo curioso** — tem conta, mexe no DevTools, troca ID na URL. Mais comum de todos.
- **Ex-funcionário** — conhece a arquitetura, pode ter credencial não revogada
- **Concorrente** — quer sua base de clientes, seu preço, seu criativo
- **Automatizado em massa** — scanner, credential stuffing, scraping. Não te escolheu, só varreu a internet.
- **Insider com acesso** — suporte que consulta dado de cliente sem motivo
- **Comprometimento de cadeia** — dependência, agência com acesso ao seu ads, ferramenta SaaS integrada

Para cada um: o que ele quer, o que ele já tem, o que o separa do objetivo.

## 4. Priorização

Não trate tudo. Ordene por **impacto × probabilidade**, e resolva primeiro o que é barato de mitigar.

| Impacto | Exemplo |
|---|---|
| Catastrófico | Base inteira vazada, controle total do sistema |
| Alto | Dado sensível de um grupo, fraude financeira |
| Médio | Dado de um usuário, indisponibilidade temporária |
| Baixo | Informação pública exposta de outro jeito |

Quatro respostas possíveis por ameaça: **mitigar**, **transferir** (seguro, terceiro), **aceitar** (documentado, com dono) ou **eliminar** (remover a feature). "Aceitar" sem dono e sem data de revisão é o mesmo que ignorar.

## 5. Padrões de mitigação

- **Defesa em profundidade** — nenhuma camada única sustenta a segurança
- **Menor privilégio** — cada componente com o mínimo para funcionar
- **Falha fechada** — erro nega acesso, não libera. `if (erro) return allow` é falha crítica disfarçada.
- **Mediação completa** — toda requisição verificada, não só a primeira
- **Separação de responsabilidade** — quem pede não é quem aprova
- **Design aberto** — a segurança está na chave, não no segredo do algoritmo

## Gatilhos de re-modelagem

Refaça quando:
- Entrar fronteira de confiança nova (integração, subdomínio, novo tipo de usuário)
- Feature passar a tratar dado sensível
- Autenticação ou autorização mudar
- Dado passar a sair da sua infraestrutura

## Formato de saída

```
## Fluxo de dados
<diagrama ou lista de elementos e fronteiras>

## Ameaças
| # | Elemento | STRIDE | Ameaça | Atacante | Impacto | Prob. | Resposta |

## Mitigações
| # | Ameaça | Mitigação | Onde implementa | Dono |

## Riscos aceitos
| # | Risco | Justificativa | Dono | Revisar em |
```

## Antipadrões

1. **Modelar depois de codar.** Vira justificativa do que já existe, não análise.
2. **Lista de ameaças sem atacante.** Genérica, ninguém prioriza.
3. **Toda ameaça vira "mitigar".** Sem priorização, nada é feito.
4. **Ignorar o usuário legítimo como atacante.** A maioria dos IDOR vem daí.
5. **Fronteira de confiança implícita.** Se não está no diagrama, ninguém defende.

## Relacionadas

Depois de modelar, a verificação no código é `security/appsec-audit`. Se o fluxo carrega dado pessoal, cruze com `compliance/lgpd-audit`.
