# Raspagem do Google Maps — receita

## Navegação

```python
import urllib.parse, time
goto_url("https://www.google.com/maps/search/" + urllib.parse.quote(query) + "/")
wait_for_load(); time.sleep(5)
```

Primeira navegação da sessão usa `new_tab(url)`; as seguintes, `goto_url`.

## Scroll do feed

O feed é virtualizado: sem scroll você pega ~7 cards. Loop de 7 iterações rende ~35-40 por query (limite prático do Maps).

```python
for i in range(7):
    js("(() => { const f=document.querySelector('div[role=\"feed\"]'); if(f){f.scrollTop=f.scrollHeight;} return 0; })()")
    time.sleep(1.8)
```

## Extração

```python
rows = json.loads(js("""(() => {
  const out=[];
  document.querySelectorAll('div[role="feed"] > div').forEach(d=>{
    const a=d.querySelector('a.hfpxzc'); if(!a) return;
    out.push({name:a.getAttribute('aria-label'), href:a.href,
              txt:d.innerText.split('\\n').filter(x=>x.trim())});
  });
  return JSON.stringify(out);
})()"""))
```

- `a.hfpxzc` é o link do card; `aria-label` traz o nome limpo.
- `innerText` do card carrega nota, nº de avaliações, categoria, endereço e telefone em linhas separadas.

## Parse do innerText

```python
fone = re.search(r'\((\d{2})\)\s?(\d{4,5})-(\d{4})', t)
nota = re.search(r'(\d,\d)\((\d[\d\.]*)\)', t)   # "4,3(648)"
sem_aval = 'Nenhuma avaliação' in t
```

O nº de avaliações vem com ponto de milhar (`1.603`) — `.replace('.','')` antes do int.

## O feed NÃO expõe o site

O card da lista não traz link do site (só a ficha aberta traz). Não gaste tempo procurando `a[data-value="Website"]` no feed — retorna `null`. Valide presença digital por busca web separada.

## Regex de descarte de diretórios

Resultado de busca por nome de PME é dominado por agregador. Descarte antes de concluir que existe site próprio:

```python
DIR = (r'instagram|facebook|google|maps|linkedin|econodata|cnpj|guiamais|apontador|'
       r'solutudo|telelistas|ondeir|yelp|foursquare|casadosdados|empresascnpj|'
       r'reclameaqui|youtube|tiktok|olx|mercadolivre|informecadastral|consultasocio|'
       r'b2brazil|wa\.me|whatsapp|escavador|jusbrasil|listaempresas|tudoempresas|'
       r'rentechdigital|poidata|cylex|serasa|consultas\.plus|locaisdobrasil|guia\.app')
```

Esta lista cresce; estenda-a em vez de criar outra.

## Checagem do site sobrevivente

```python
req = urllib.request.Request(u, headers={'User-Agent':'Mozilla/5.0'})
resp = urllib.request.urlopen(req, timeout=12, context=ctx)
```

Sem o `User-Agent` de navegador, muito host devolve 403. `406 Not Acceptable` = WAF, não site quebrado.

Sinal de template genérico: domínio contém `ueniweb.com` ou similar de construtor gratuito.
