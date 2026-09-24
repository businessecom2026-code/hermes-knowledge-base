// Verifica licenca, peso, manutencao e popularidade de pacotes npm nas fontes
// primarias. Edite a lista PKGS e rode:  node verificar-pacotes.mjs
//
// No Windows/MSYS copie este arquivo para $LOCALAPPDATA/Temp antes de rodar:
// ferramenta nativa (node.exe) nao resolve caminho estilo /tmp.

const PKGS = [
  'recharts',
  'chart.js',
  'react-chartjs-2',
  '@tanstack/react-table',
];

// owner/repo dos projetos cuja licenca SPDX real interessa confirmar.
// O campo `license` do npm e declarado pelo autor e mente quando a licenca
// virou proprietaria; `spdx_id` do GitHub e derivado do arquivo LICENSE.
const REPOS = [
  // 'recharts/recharts',
];

const jsonOf = async (url) => {
  const r = await fetch(url, { headers: { 'User-Agent': 'dep-check' } });
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return r.json();
};

const alerta = (licenca, publicadoEm) => {
  const sinais = [];
  // Licenca nao-SPDX = licenca propria, quase sempre com teto de faturamento
  // ou proibicao de uso em produto concorrente. Abrir o LICENSE e obrigatorio.
  if (/SEE LICENSE|NOASSERTION|UNLICENSED/i.test(licenca)) sinais.push('LICENCA PROPRIA');
  const meses = (Date.now() - Date.parse(publicadoEm)) / 2.6e9;
  if (meses > 12) sinais.push(`PARADO ${Math.round(meses)}m`);
  return sinais.length ? '  <<< ' + sinais.join(' + ') : '';
};

console.log('pkg | versao | licenca | publicado | dl/semana | min | gzip | treeshake');
for (const p of PKGS) {
  try {
    const meta = await jsonOf('https://registry.npmjs.org/' + p.replace('/', '%2f'));
    const v = meta['dist-tags'].latest;
    const lic = meta.versions[v]?.license || meta.license || '?';
    const quando = (meta.time[v] || '').slice(0, 10);
    const dl = await jsonOf('https://api.npmjs.org/downloads/point/last-week/' + p)
      .catch(() => ({ downloads: 0 }));
    // bundlephobia pode demorar ou faltar em pacote muito novo: nao aborta o laco.
    const bp = await jsonOf('https://bundlephobia.com/api/size?package=' + encodeURIComponent(p))
      .catch(() => null);
    const peso = bp
      ? `${(bp.size / 1024).toFixed(0)}KB | ${(bp.gzip / 1024).toFixed(0)}KB | ${bp.hasJSModule || bp.hasJSNext ? 'sim' : 'nao'}`
      : 'n/d | n/d | n/d';
    console.log(`${p} | ${v} | ${lic} | ${quando} | ${dl.downloads} | ${peso}${alerta(lic, quando)}`);
  } catch (e) {
    console.log(`${p} | ERRO ${e.message}`);
  }
}

for (const r of REPOS) {
  try {
    const j = await jsonOf('https://api.github.com/repos/' + r);
    console.log(`${r} | spdx:${j.license?.spdx_id || '?'} | ${j.stargazers_count}* | push:${(j.pushed_at || '').slice(0, 10)}`);
  } catch (e) {
    console.log(`${r} | ERRO ${e.message}`);
  }
}
