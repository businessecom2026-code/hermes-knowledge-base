# Dependências e órfãos no Postgres

## Quem aponta para a tabela alvo, e com que regra

A lista tem de sair do catálogo, não da cabeça — a tabela que falta na lista escrita à mão é a que fica órfã.

```sql
SELECT tc.table_name  AS tabela,
       kcu.column_name AS coluna,
       rc.delete_rule  AS ao_apagar
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
  ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND ccu.table_name = '<tabela_alvo>'
ORDER BY tc.table_name;
```

Ler a coluna `ao_apagar`:

| Regra | O que acontece ao apagar o pai | O que tens de fazer |
|---|---|---|
| `CASCADE` | a filha desaparece sozinha | nada |
| `SET NULL` | **a filha fica, com o vínculo em branco** | `DELETE` explícito na filha, ANTES do pai |
| `RESTRICT` / `NO ACTION` | o `DELETE` do pai falha | limpar a filha primeiro, ou o delete rebenta |

Uma base madura tem dezenas de chaves para a mesma tabela e quase todas em `CASCADE`. São as duas ou três excepções que causam o estrago, por isso filtra e mostra-as:

```js
const semCascade = fks.filter((f) => f.ao_apagar !== 'CASCADE');
```

## Contar o que está amarrado a cada candidato

Iterar as chaves descobertas acima e contar por candidato. O total serve para classificar teste-vs-real, e o detalhe por tabela mostra *que tipo* de actividade existe (uma ficha vazia vale zero; nove mensagens valem cliente real).

```js
for (const fk of fks) {
  const r = await prisma.$queryRawUnsafe(
    `SELECT COUNT(*)::int AS n FROM "${fk.tabela}" WHERE "${fk.coluna}" = $1`, id);
  if (r[0].n > 0) detalhe[`${fk.tabela}.${fk.coluna}`] = r[0].n;
}
```

Puxa também a ficha do próprio registo (`name`, `isActive`, `createdAt`): a data de criação separa o que nasceu durante os testes do que já lá estava, e o nome deixa o utilizador reconhecer o registo sem decifrar um UUID.

## Coorte: classificar por comparação, não por palpite

Contar as filhas só dos candidatos diz pouco — "1 filha" pode ser pouco ou ser o normal daquela tabela. Corre a mesma contagem sobre **todas** as linhas e ordena por total ascendente: os grupos separam-se sozinhos, e cada classificação passa a ter linha de base.

```js
const linhas = await prisma.$queryRawUnsafe(
  `SELECT id, name, "isActive", "createdAt", "updatedAt" FROM "<tabela_alvo>" ORDER BY "createdAt"`);
for (const c of linhas) {
  const onde = []; let total = 0;
  for (const fk of fks) {
    const r = await prisma.$queryRawUnsafe(
      `SELECT COUNT(*)::int AS n FROM "${fk.tabela}" WHERE "${fk.coluna}" = $1`, c.id);
    if (r[0].n > 0) { onde.push(`${fk.tabela}:${r[0].n}`); total += r[0].n; }
  }
  const vidaSeg = Math.round((new Date(c.updatedAt) - new Date(c.createdAt)) / 1000);
  out.push({ nome: c.name, total, onde: onde.join(', ') || '(nada)',
             editadoApos: vidaSeg < 600 ? `${vidaSeg}s` : `${Math.round(vidaSeg / 3600)}h` });
}
out.sort((a, b) => a.total - b.total);
```

Imprime como tabela Markdown: é directamente colável na pergunta de aprovação, e o utilizador vê o padrão sem ler código.

### Três discriminadores mais fortes que o nome

| Sinal | Teste | Real |
|---|---|---|
| `updatedAt - createdAt` | segundos — criado e abandonado | horas ou dias de uso |
| **que** tabelas filhas | artefacto de um passo de formulário | convite de acesso, mensagens, tickets |
| data de criação | agrupada no dia da sessão de testes | espalhada ao longo de semanas |

O segundo é o mais discriminante e o mais fácil de ignorar: contagens iguais podem significar coisas opostas. Uma linha em `finance_contacts` é sub-produto de um passo de criação; uma linha em `onboarding_invites` significa que alguém foi convidado ao portal. Compara *quais* tabelas, não só quantas linhas.

Quando os três sinais apontam para o mesmo lado, diz na resposta que a decisão veio do padrão e não do nome — um prefixo sugestivo (`VERIF`, `CLIENTE PF`) é coincidência até os números concordarem, e nome de teste sem marca nenhuma escapa a qualquer `ILIKE`.

## Procurar órfãos depois de apagar

Uma por cada chave `SET NULL`. Tem de dar `0`; qualquer outro número é lixo deixado atrás.

```sql
SELECT COUNT(*)::int AS n
FROM "<tabela_filha>" f
WHERE f."<coluna>" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "<tabela_alvo>" p WHERE p.id = f."<coluna>");
```

## Confirmar que não sobrou candidato nem padrão

```sql
-- nenhum dos IDs aprovados sobreviveu
SELECT COUNT(*)::int AS n FROM "<tabela_alvo>" WHERE id = ANY($1::text[]);

-- nenhum nome de teste ficou para trás (rede mais larga que a lista aprovada)
SELECT name FROM "<tabela_alvo>"
WHERE name ILIKE '%teste%' OR name ILIKE '%test%' OR name ILIKE '%<nome-do-dono>%'
ORDER BY name;
```

A segunda consulta pode devolver linhas legítimas que ficaram de fora por decisão do utilizador — lista-as na resposta em vez de as apagar por iniciativa própria.

## Mostrar o destino da base sem expor a senha

```js
const u = new URL(process.env.DATABASE_URL);
console.log(u.hostname, 'db=' + u.pathname.slice(1), 'user=' + u.username.slice(0, 4) + '***');
```

Hostname terminado em `.railway.internal` (ou equivalente de rede privada) **não resolve de fora** — o script tem de correr dentro do container.
