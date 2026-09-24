/**
 * Esqueleto de limpeza aprovada: ensaio por omissão, grava só com --executar.
 *
 * Copiar, preencher as constantes e correr DUAS vezes:
 *   1) sem argumentos  -> ensaio, desfaz tudo no fim, imprime o que faria
 *   2) com --executar   -> grava, se os números do ensaio foram conferidos
 *
 * O comentário de cabeçalho deve dizer o que foi aprovado e o que é PROIBIDO
 * tocar, para quem abrir o ficheiro depois perceber sem procurar a conversa.
 */
const { PrismaClient } = require('@prisma/client');

const EXECUTAR = process.argv.includes('--executar');

// [id, nome-esperado] — o nome é conferido contra a base antes de apagar
const ALVOS = [
  // ['uuid', 'Nome Exacto Como Aprovado'],
];
const IDS = ALVOS.map(([id]) => id);

// ID que NUNCA pode ser tocado; a guarda relê-o dentro da transacção
const PROIBIDO = '';

class Abortar extends Error {}

(async () => {
  const prisma = new PrismaClient({ datasources: { db: { url: process.env.DATABASE_URL } } });
  const log = { modo: EXECUTAR ? 'EXECUTAR' : 'ENSAIO', antes: {}, apagado: {}, depois: {}, erro: null };

  try {
    if (IDS.includes(PROIBIDO)) throw new Error('GUARDA: protegido entrou na lista de alvos — abortado');

    // contagens que provam o antes/depois, incluindo tabelas que NÃO devem mexer
    const contar = async () => ({
      alvo: (await prisma.$queryRawUnsafe('SELECT COUNT(*)::int n FROM "<tabela_alvo>"'))[0].n,
      naoMexer: (await prisma.$queryRawUnsafe('SELECT COUNT(*)::int n FROM "users"'))[0].n,
      protegido: (await prisma.$queryRawUnsafe(
        'SELECT COUNT(*)::int n FROM "<tabela_alvo>" WHERE id = $1', PROIBIDO))[0].n,
      filhasProtegido: (await prisma.$queryRawUnsafe(
        'SELECT COUNT(*)::int n FROM "<tabela_filha>" WHERE "<coluna>" = $1', PROIBIDO))[0].n,
    });
    log.antes = await contar();

    // cada ID tem de ser quem foi aprovado; ID trocado apaga o vizinho em silêncio
    const fichas = await prisma.$queryRawUnsafe(
      'SELECT id, name FROM "<tabela_alvo>" WHERE id = ANY($1::text[])', IDS);
    log.confirmacaoDeIdentidade = fichas.map((f) => ({ id: f.id.slice(0, 8), nome: f.name }));
    for (const [id, esperado] of ALVOS) {
      const achado = fichas.find((f) => f.id === id);
      if (!achado) { log.confirmacaoDeIdentidade.push(`AUSENTE: ${esperado}`); continue; }
      if (achado.name !== esperado) {
        throw new Error(`GUARDA: ${id} devia ser "${esperado}" mas é "${achado.name}"`);
      }
    }

    await prisma.$transaction(async (tx) => {
      const del = async (rotulo, sql, ...p) => {
        const n = await tx.$executeRawUnsafe(sql, ...p);
        if (n > 0) log.apagado[rotulo] = n;
      };

      // 1) primeiro as chaves SET NULL / RESTRICT — não caem por cascade
      // await del('<filha>', 'DELETE FROM "<filha>" WHERE "<coluna>" = ANY($1::text[])', IDS);

      // 2) depois o pai; as chaves CASCADE caem com ele
      // await del('<tabela_alvo>', 'DELETE FROM "<tabela_alvo>" WHERE id = ANY($1::text[])', IDS);

      // 3) guarda: o protegido tem de estar intacto, com as filhas todas
      const vivo = await tx.$queryRawUnsafe(
        'SELECT COUNT(*)::int n FROM "<tabela_alvo>" WHERE id = $1', PROIBIDO);
      const filhas = await tx.$queryRawUnsafe(
        'SELECT COUNT(*)::int n FROM "<tabela_filha>" WHERE "<coluna>" = $1', PROIBIDO);
      if (vivo[0].n !== 1 || filhas[0].n !== log.antes.filhasProtegido) {
        throw new Error(`GUARDA: protegido afectado (existe=${vivo[0].n}, filhas=${filhas[0].n}) — desfazendo`);
      }

      if (!EXECUTAR) throw new Abortar('ensaio');
    });

    log.depois = await contar();
  } catch (e) {
    if (e instanceof Abortar) log.depois = { nota: 'ensaio desfeito — nada gravado' };
    else log.erro = String(e.message).slice(0, 240);
  } finally {
    await prisma.$disconnect().catch(() => {});
  }
  console.log(JSON.stringify(log, null, 1));
})();
