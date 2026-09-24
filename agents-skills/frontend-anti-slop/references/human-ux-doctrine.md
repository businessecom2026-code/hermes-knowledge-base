# Doutrina de UX humana e detecção de interfaces produzidas por IA

## Sumário

1. Objetivo
2. Definição operacional de slop
3. Conselho de especialistas
4. Catálogo de sinais de IA
5. Alternativas humanas
6. Método de auditoria
7. Regras por superfície
8. Gate de implementação

## 1. Objetivo

Produzir interfaces específicas ao produto, coerentes com a operação e visualmente refinadas. O resultado deve parecer decidido por uma equipe que conhece o negócio, não montado pela combinação automática de padrões populares.

O critério não é “bonito” versus “feio”. O critério é intenção verificável. Toda decisão visual precisa servir uma destas funções:

- orientar atenção;
- explicar uma relação;
- permitir uma ação;
- comunicar estado;
- sustentar confiança;
- expressar uma característica real da marca.

## 2. Definição operacional de slop

Slop é densidade de decisões sem justificativa. Aparece quando o sistema adiciona forma, cor, texto ou movimento para preencher espaço ou sinalizar artificialmente que houve design.

Há dois tipos principais:

### Slop por repetição

- muitas caixas com a mesma forma;
- grids de três ou quatro cards equivalentes;
- mesmo espaçamento em todas as seções;
- mesmos títulos, subtítulos e CTAs em sequência;
- todos os elementos com sombra, borda e raio;
- toda seção com eyebrow, headline e parágrafo curto;
- todo item acompanhado de ícone decorativo.

### Slop por ornamentação

- gradientes sem relação com fotografia ou marca;
- glow, blur, glassmorphism e reflexos gratuitos;
- texto em gradiente;
- pontos coloridos decorativos;
- pills para conteúdo que não é filtro, status ou seleção;
- números de seção, contadores e coordenadas fictícias;
- linhas, crosshairs e ruído usados apenas para “parecer design”;
- rotações e desalinhamentos aleatórios para imitar imperfeição humana.

## 3. Conselho de especialistas

Auditar a mesma superfície por sete lentes. Nenhuma lente substitui as outras.

### Product designer

Perguntar:

- Qual tarefa precisa ficar óbvia em cinco segundos?
- A hierarquia acompanha a decisão do usuário?
- Há ações concorrentes ou etapas escondidas?
- O layout prioriza o que gera valor ou o que é mais fácil de estilizar?

Rejeitar se a página parecer uma apresentação de componentes em vez de uma jornada.

### Diretor de arte

Perguntar:

- Existe uma tese visual única?
- A fotografia, tipografia, cor e espaço pertencem ao mesmo universo?
- As proporções variam por intenção ou por aleatoriedade?
- A marca seria reconhecível sem o logo?

Rejeitar se a identidade puder ser trocada por qualquer startup sem alterar o layout.

### Designer de interação

Perguntar:

- O movimento explica transição, prioridade ou feedback?
- Hover, foco, active, loading, vazio e erro estão cobertos?
- O componente se comporta corretamente com teclado e toque?
- O autoplay pode ser pausado e respeita redução de movimento?

Rejeitar movimento que exista apenas para aumentar sensação de sofisticação.

### UX writer

Perguntar:

- A copy descreve uma vantagem concreta?
- Os verbos indicam exatamente o que acontece?
- Existem clichês, metáforas vazias ou promessas não comprovadas?
- Limitações, preço, disponibilidade e próximos passos estão claros?

Rejeitar “reinventado”, “sem esforço”, “experiência única”, “eleve” e similares quando não houver prova objetiva.

### Especialista em acessibilidade

Perguntar:

- Contraste, foco e tamanho de toque são suficientes?
- A ordem semântica corresponde à ordem visual?
- Informação depende apenas de cor, ícone ou bandeira?
- A interface funciona em zoom, teclado e leitor de tela?

Rejeitar refinamento visual que reduza legibilidade ou controle.

### Especialista em conversão e confiança

Perguntar:

- O usuário entende preço, risco, disponibilidade e política antes do CTA?
- Provas são verdadeiras e verificáveis?
- Há telefone, endereço, termos, caução, seguro e cancelamento quando relevantes?
- O formulário pede apenas o necessário no momento correto?

Rejeitar urgência, reviews, números ou selos inventados.

### Frontend e performance

Perguntar:

- O layout reserva espaço para imagens e fontes?
- A animação usa transform e opacity?
- O componente adiciona dependência sem necessidade?
- Mobile é uma composição própria ou apenas desktop empilhado?
- A interface funciona sem banco, rede ou conteúdo completo?

Rejeitar decoração que aumente bundle, LCP, CLS ou custo de manutenção sem ganho de experiência.

## 4. Catálogo de sinais de IA

### Hero

- hero centralizado sobre fundo escuro genérico;
- gradiente roxo, azul ou neon;
- headline enorme com palavra em gradiente;
- eyebrow em mono e caixa alta;
- dois CTAs equivalentes;
- mockup falso desenhado com divs;
- badges de confiança dentro do hero;
- scroll cue ou contador decorativo.

Alternativa: uma promessa, uma prova concreta, uma ação e uma imagem real. Usar split, manifesto ou fotografia integral conforme o conteúdo.

### Cards

- borda, fundo branco, raio e sombra aplicados juntos em todo bloco;
- quatro cards idênticos para benefícios;
- ícone dentro de quadrado arredondado em cada card;
- títulos e textos com exatamente o mesmo comprimento;
- hover elevando todos os elementos.

Alternativa: usar faixa com divisores, lista editorial, comparação, imagem com legenda, tabela curta ou composição assimétrica. Manter card apenas quando o item é uma entidade clicável ou estado independente.

### Formas

- tudo arredondado;
- mistura sem regra de pills, cards redondos e botões quadrados;
- círculos e pontos como preenchimento;
- elementos inclinados ou rotacionados sem relação com a marca.

Alternativa: definir uma gramática. Exemplo: containers 16 px, inputs 10 px, botões 8 px, pills apenas para filtros.

### Gradientes e efeitos

- gradiente decorativo no fundo;
- gradient text;
- blur colorido;
- glow em CTA;
- glassmorphism em conteúdo comum;
- grain ou noise aplicado a toda a página sem motivo.

Alternativa: cor sólida, fotografia, contraste tipográfico e profundidade por sobreposição real. Gradiente só pode proteger legibilidade sobre imagem ou pertencer ao ativo da marca.

### Tipografia

- três ou mais famílias sem função;
- mono em labels, botões, nav e corpo;
- caixa alta excessiva;
- H1 enorme para compensar falta de composição;
- texto pequeno e cinza usado como decoração;
- quebras de linha forçadas para parecer editorial.

Alternativa: uma família principal, uma auxiliar opcional, escala curta e hierarquia por peso, largura e espaço.

### Copy

- frases que cabem em qualquer produto;
- metáfora automotiva em todos os títulos;
- promessas sem prova;
- excesso de frases curtas com ponto;
- tom artificialmente poético;
- labels como “01”, “explore”, “discover”, “crafted”.

Alternativa: linguagem operacional, local e verificável. Dizer onde, quando, quanto, como e o que acontece depois.

### Imagens

- banco de imagens sem relação com a frota real;
- todas com mesmo aspecto e crop;
- overlays escuros uniformes;
- captions decorativas;
- cards de veículos sem marca, modelo, preço ou disponibilidade reais.

Alternativa: fotos próprias, enquadramentos por categoria, detalhes do carro, loja e processo. Se não houver ativo real, identificar claramente o placeholder e não fingir autenticidade.

### Movimento

- tudo aparece com fade-up;
- parallax e tilt em conteúdo estático;
- carrossel automático sem controle;
- hover que move blocos inteiros;
- animação contínua em elementos não interativos.

Alternativa: usar movimento para mudança de slide, abertura, confirmação, loading e reorganização. Respeitar redução de movimento.

## 5. Alternativas humanas

### Assimetria sem aleatoriedade

Variar a composição porque a importância varia. Uma categoria principal pode ocupar duas colunas; uma secundária, uma coluna. Não rotacionar cards nem deslocá-los verticalmente só para quebrar o grid.

### Ritmo editorial

Alternar arquiteturas de seção: split hero, faixa de confiança, vitrine com imagem dominante, bloco narrativo e FAQ em lista. Não repetir a mesma família de layout consecutivamente.

### Materialidade honesta

Usar borda, sombra e fundo apenas quando sinalizam agrupamento ou elevação. Espaço vazio e alinhamento devem resolver a maior parte da hierarquia.

### Conteúdo real

Preferir quatro informações concretas a oito benefícios genéricos. Mostrar políticas e limitações antes de slogans.

### Imperfeições de conteúdo

Comprimentos diferentes, fotos com enquadramentos próprios, nomes reais e estados incompletos geram humanidade. Não normalizar tudo para que os cards tenham a mesma altura ou o texto o mesmo número de linhas.

## 6. Método de auditoria

### Passo 1: captura

Capturar desktop e mobile, acima da dobra e página completa. Registrar rota, locale, viewport, login e estado de dados.

### Passo 2: inventário

Contar:

- quantos containers têm borda + raio + sombra;
- quantas seções usam cards;
- quantos elementos usam pill;
- quantos gradientes e glows existem;
- quantos eyebrows e micro-labels aparecem;
- quantas arquiteturas de seção se repetem;
- quantas mensagens são genéricas ou não verificáveis.

O objetivo da contagem é encontrar concentração, não cumprir uma pontuação arbitrária.

### Passo 3: causalidade

Para cada elemento, perguntar: “o que quebra se isto for removido?”. Se nada quebrar em compreensão, tarefa, confiança ou marca, remover.

### Passo 4: recomposição

Corrigir na ordem:

1. hierarquia e fluxo;
2. geometria das seções;
3. tipografia e espaço;
4. fotografia e conteúdo;
5. cor, borda e sombra;
6. interação e movimento.

Não começar por microestilo quando a estrutura estiver errada.

### Passo 5: falsificação

Tentar provar que cada irregularidade é arbitrária. Tentar provar que cada card poderia ser apenas espaço ou divisor. Tentar provar que cada texto poderia pertencer a outro produto. Corrigir tudo que falhar.

## 7. Regras por superfície

### Site de serviço local

- priorizar local, disponibilidade, preço, contacto, políticas e prova operacional;
- usar fotografia real da operação;
- manter ação principal visível sem sufocar a marca;
- evitar estética de SaaS, dashboard e startup tecnológica.

### Ecommerce e reserva

- apresentar total, condições e risco antes da decisão;
- preservar busca e filtros ao navegar;
- diferenciar catálogo, seleção e checkout visualmente;
- tratar indisponibilidade e erro como parte da experiência.

### Landing institucional

- uma tese visual;
- uma promessa concreta;
- no máximo uma grade de cards;
- cada seção com arquitetura própria;
- prova antes de repetição de CTA.

## 8. Gate de implementação

Responder “sim” antes de concluir:

- O usuário sabe o que fazer em cinco segundos?
- O maior elemento é realmente o mais importante?
- Cada caixa delimita uma entidade, ação ou estado?
- A página continuaria reconhecível sem o logo?
- A variação visual vem da hierarquia?
- Há no máximo uma cor de destaque dominante?
- Gradientes existem apenas para legibilidade sobre imagem ou marca?
- Pills comunicam filtro, seleção, taxonomia ou estado?
- A copy contém informações específicas do negócio?
- Não existem métricas, reviews, urgência ou confiança inventados?
- Desktop e mobile têm composições deliberadas?
- Foco, contraste, teclado, toque e reduced motion estão cobertos?
- Loading, vazio, erro e dados ausentes foram considerados?
- Lint, build e fluxo principal foram verificados?

Se qualquer resposta for “não”, continuar trabalhando.

