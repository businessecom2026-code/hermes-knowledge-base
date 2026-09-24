# Jurisdição de proteção de dados

Nota de apoio para auditoria: decidir **qual lei se aplica** antes de citar artigo.
Para o checklist de conformidade em si, use `compliance/lgpd-audit`.

## Determine a jurisdição antes de escrever o nome da lei

**Primeiro passo de toda auditoria que toca dado pessoal: descubra quem é o controlador e onde ele
está.** Procure razão social, CNPJ/CIF/VAT e endereço nas páginas de política de privacidade, termos
e rodapé — é onde vivem, e um `grep` por essas páginas resolve em um comando.

Chamar de LGPD o que é GDPR (ou o contrário) invalida o relatório inteiro: muda a autoridade,
os artigos citados, o teto da sanção e a urgência da correção. **Produto em português e público
brasileiro não implicam controlador brasileiro** — esse é exatamente o erro que passa despercebido.

| | LGPD (Brasil) | GDPR + ePrivacy (UE) |
|---|---|---|
| Autoridade | ANPD | autoridade nacional — AEPD (ES), CNIL (FR), Garante (IT) |
| Teto | 2% do faturamento no Brasil, até R$ 50 mi por infração | 4% do faturamento **global** |
| Cookie não essencial | exige base legal | exige **opt-in prévio** expresso |
| Gatilho típico de fiscalização | denúncia, incidente | denúncia individual — barreira baixa |

Os dois regimes podem incidir ao mesmo tempo (controlador na UE atendendo titulares no Brasil).
Quando incidirem, **audite pelo mais restritivo** e diga no relatório que ambos se aplicam.
A ePrivacy é mais dura que a LGPD em cookie: script não essencial não pode disparar antes do aceite,
sem exceção de "legítimo interesse".

## Armadilhas de rastreamento que a leitura de DOM sozinha não pega

1. **Política que existe mas é inalcançável.** Antes de escrever "não há política de privacidade",
   procure a **rota** e o **componente**, não só o DOM da página auditada. O padrão comum é a página
   existir e o rodapé que a linka não ser renderizado justamente na landing que dispara o pixel.
   O achado continua válido, mas a correção é renderizar o link — não redigir política do zero.

2. **Política em idioma que o titular não lê.** Site multi-idioma com páginas legais fixas em uma
   única língua descumpre o dever de informação clara (LGPD art. 9º; GDPR art. 12). Cheque se os
   rótulos legais passam pela camada de tradução ou são string fixa no componente.

3. **Geolocalização por IP vendida internamente como "detecção de idioma".** Chamada a serviço de
   geo-IP de terceiro trata dado pessoal e em geral é transferência internacional, mas quase nunca
   aparece no inventário porque quem escreveu pensou nela como UX, não como tratamento.

4. **Pixel inline no `<head>` roda antes de qualquer consentimento** — antes do framework montar,
   antes do banner existir. Nenhuma solução em JavaScript de aplicação conserta isso: o script
   precisa sair do `<head>` ou ficar condicionado ao aceite. Verifique também o fallback
   `<noscript><img>`, que rastreia com JS desligado e escapa de toda auditoria feita só no DOM vivo.

5. **`<html lang>` fixo em site multi-idioma** é simultaneamente falha de acessibilidade
   (WCAG 3.1.1, nível A — leitor de tela escolhe a voz e a pronúncia por esse atributo) e sinal
   errado para busca. Confirme com `grep documentElement.lang` que alguém de fato o atualiza.
