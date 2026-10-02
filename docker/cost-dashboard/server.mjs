import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { CostExplorerClient, GetCostAndUsageCommand } from '@aws-sdk/client-cost-explorer';
import { MongoClient } from 'mongodb';

const port = Number.parseInt(process.env.COST_DASHBOARD_PORT ?? '8080', 10);
const mongoUri = process.env.COST_DASHBOARD_MONGO_URI;
const costExplorerRegion = process.env.COST_EXPLORER_REGION ?? 'us-east-1';
const bundledPricingFile = new URL('./pricing.json', import.meta.url);
const runtimePricingFile = process.env.COST_DASHBOARD_PRICING_FILE;

async function loadPricing() {
  if (runtimePricingFile) {
    try {
      return {
        catalog: JSON.parse(await readFile(runtimePricingFile, 'utf8')),
        source: 'EC2 startup synchronization',
      };
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
  return {
    catalog: JSON.parse(await readFile(bundledPricingFile, 'utf8')),
    source: 'Bundled fallback awaiting first EC2 startup synchronization',
  };
}

const loadedPricing = await loadPricing();
const pricing = loadedPricing.catalog;

if (!mongoUri) {
  throw new Error('COST_DASHBOARD_MONGO_URI is required.');
}

const mongoClient = new MongoClient(mongoUri, {
  serverSelectionTimeoutMS: 5_000,
  maxPoolSize: 4,
});
const costExplorer = new CostExplorerClient({ region: costExplorerRegion });
const actualCostCache = new Map();
const actualCostCacheTtlMs = 6 * 60 * 60 * 1_000;

function toUtcDate(value) {
  return value.toISOString().slice(0, 10);
}

function daysFromRequest(url) {
  const raw = Number.parseInt(url.searchParams.get('days') ?? '30', 10);
  return [1, 7, 30].includes(raw) ? raw : 30;
}

function period(days) {
  const now = new Date();
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - days + 1));
  const end = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));
  return { start, end, startDate: toUtcDate(start), endDate: toUtcDate(end) };
}

function tokenClass(tokenType) {
  return tokenType === 'completion' ? 'output' : 'input';
}

function unitPrice(model, tokenType) {
  const modelPrice = pricing.models[model];
  if (!modelPrice) return null;
  return tokenClass(tokenType) === 'output' ? modelPrice.outputPerMillion : modelPrice.inputPerMillion;
}

function estimateFor(tokens, model, tokenType) {
  const price = unitPrice(model, tokenType);
  return price === null ? null : (tokens / 1_000_000) * price;
}

async function tokenSummary(days) {
  const { start } = period(days);
  const database = mongoClient.db('LibreChat');
  const rows = await database.collection('transactions').aggregate([
    {
      $match: {
        createdAt: { $gte: start },
        model: { $type: 'string' },
        tokenType: { $in: ['prompt', 'completion'] },
        rawAmount: { $type: 'number' },
      },
    },
    {
      $group: {
        _id: { model: '$model', tokenType: '$tokenType' },
        tokens: { $sum: { $abs: '$rawAmount' } },
      },
    },
  ]).toArray();

  const models = new Map();
  for (const row of rows) {
    const model = row._id.model;
    const entry = models.get(model) ?? {
      model,
      provider: pricing.models[model]?.provider ?? 'Unknown',
      inputTokens: 0,
      outputTokens: 0,
      estimatedCostUsd: 0,
      priceConfigured: Boolean(pricing.models[model]),
    };
    const tokens = Math.abs(Number(row.tokens));
    if (tokenClass(row._id.tokenType) === 'output') entry.outputTokens += tokens;
    else entry.inputTokens += tokens;
    const estimate = estimateFor(tokens, model, row._id.tokenType);
    if (estimate !== null) entry.estimatedCostUsd += estimate;
    models.set(model, entry);
  }

  const result = [...models.values()].sort((left, right) => right.estimatedCostUsd - left.estimatedCostUsd || left.model.localeCompare(right.model));
  return {
    models: result,
    totalInputTokens: result.reduce((total, item) => total + item.inputTokens, 0),
    totalOutputTokens: result.reduce((total, item) => total + item.outputTokens, 0),
    estimatedCostUsd: result.reduce((total, item) => total + item.estimatedCostUsd, 0),
    unpricedModels: result.filter((item) => !item.priceConfigured).map((item) => item.model),
  };
}

function modelNameFromUsageType(usageType) {
  const value = usageType.toLowerCase();
  if (value.includes('claude') && value.includes('opus')) return 'Claude Opus';
  if (value.includes('claude') && value.includes('sonnet')) return 'Claude Sonnet';
  if (value.includes('claude') && value.includes('haiku')) return 'Claude Haiku';
  if (value.includes('nova') && value.includes('pro')) return 'Amazon Nova Pro';
  if (value.includes('nova') && value.includes('lite')) return 'Amazon Nova Lite';
  if (value.includes('nova') && value.includes('micro')) return 'Amazon Nova Micro';
  return usageType;
}

async function actualBedrockCost(days) {
  const cacheKey = String(days);
  const cached = actualCostCache.get(cacheKey);
  if (cached && Date.now() - cached.createdAt < actualCostCacheTtlMs) return cached.value;

  const { startDate, endDate } = period(days);
  try {
    const response = await costExplorer.send(new GetCostAndUsageCommand({
      TimePeriod: { Start: startDate, End: endDate },
      Granularity: 'DAILY',
      Metrics: ['UnblendedCost'],
      Filter: { Dimensions: { Key: 'SERVICE', Values: ['Amazon Bedrock'] } },
      GroupBy: [{ Type: 'DIMENSION', Key: 'USAGE_TYPE' }],
    }));

    const byUsageType = new Map();
    for (const day of response.ResultsByTime ?? []) {
      for (const group of day.Groups ?? []) {
        const usageType = group.Keys?.[0] ?? 'Unknown';
        const amount = Number(group.Metrics?.UnblendedCost?.Amount ?? 0);
        byUsageType.set(usageType, (byUsageType.get(usageType) ?? 0) + amount);
      }
    }
    const groups = [...byUsageType.entries()]
      .map(([usageType, costUsd]) => ({ usageType, model: modelNameFromUsageType(usageType), costUsd }))
      .sort((left, right) => right.costUsd - left.costUsd);
    const value = {
      available: true,
      asOf: new Date().toISOString(),
      scope: 'AWS account, Amazon Bedrock service',
      costUsd: groups.reduce((total, item) => total + item.costUsd, 0),
      groups,
    };
    actualCostCache.set(cacheKey, { createdAt: Date.now(), value });
    return value;
  } catch (error) {
    return {
      available: false,
      reason: 'AWS Cost Explorer is temporarily unavailable or not authorized.',
    };
  }
}

async function summary(days) {
  const [tokens, bedrockActual] = await Promise.all([tokenSummary(days), actualBedrockCost(days)]);
  return {
    generatedAt: new Date().toISOString(),
    days,
    currency: pricing.currency,
    catalogVersion: pricing.catalogVersion,
    catalogGeneratedAt: pricing.generatedAt ?? null,
    catalogSource: loadedPricing.source,
    tokenUsage: tokens,
    bedrockActual,
  };
}

const html = `<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Suivi des coûts</title><style>
body{font:16px system-ui,sans-serif;background:#111827;color:#e5e7eb;margin:0}main{max-width:1100px;margin:auto;padding:32px 20px}h1{margin:0 0 6px}.muted{color:#9ca3af}.choices button{margin:18px 8px 22px 0;padding:8px 14px;border:1px solid #4b5563;border-radius:7px;background:#1f2937;color:#fff;cursor:pointer}.choices button.active{background:#2563eb;border-color:#2563eb}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:16px}.card{background:#1f2937;border-radius:10px;padding:18px}.number{font-size:1.7rem;font-weight:700;margin:7px 0}.warning{color:#fbbf24}table{width:100%;border-collapse:collapse;margin-top:22px;background:#1f2937;border-radius:10px;overflow:hidden}th,td{text-align:left;padding:12px;border-bottom:1px solid #374151}th{color:#9ca3af;font-weight:600}@media(max-width:700px){table{font-size:.82rem}th,td{padding:8px}}
</style></head><body><main><h1>Suivi des coûts</h1><p class="muted">Tokens LibreChat et coût AWS Bedrock consolidé. Le coût Gemini est une estimation tarifaire, pas une facture Google.</p><div class="choices"><button data-days="1">24 h</button><button data-days="7">7 jours</button><button class="active" data-days="30">30 jours</button></div><div id="content">Chargement…</div><p class="muted">Les estimations sont calculées avec le catalogue tarifaire ${pricing.catalogVersion}. Les données Cost Explorer peuvent arriver avec un délai.</p></main><script>
const money=v=>new Intl.NumberFormat('fr-FR',{style:'currency',currency:'USD'}).format(v);const number=v=>new Intl.NumberFormat('fr-FR').format(v);const escapeHtml=v=>String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));let days=30;
async function load(){const r=await fetch('/api/summary?days='+days);if(!r.ok)throw new Error();const d=await r.json();const a=d.bedrockActual;const catalogTime=d.catalogGeneratedAt?new Date(d.catalogGeneratedAt).toLocaleString('fr-FR'):'en attente du premier démarrage EC2';document.querySelector('#content').innerHTML='<div class="cards"><section class="card"><div class="muted">Estimation immédiate, LibreChat</div><div class="number">'+money(d.tokenUsage.estimatedCostUsd)+'</div><div>'+number(d.tokenUsage.totalInputTokens)+' tokens entrants · '+number(d.tokenUsage.totalOutputTokens)+' sortants</div></section><section class="card"><div class="muted">AWS Bedrock consolidé, compte AWS</div><div class="number">'+(a.available?money(a.costUsd):'Indisponible')+'</div><div>'+(a.available?'Facturation AWS, délai possible':'Vérifier l’autorisation Cost Explorer')+'</div></section></div><p class="muted">Catalogue : '+escapeHtml(d.catalogSource)+' · mis à jour '+escapeHtml(catalogTime)+'</p><table><thead><tr><th>Modèle</th><th>Fournisseur</th><th>Entrée</th><th>Sortie</th><th>Estimation</th></tr></thead><tbody>'+d.tokenUsage.models.map(m=>'<tr><td>'+escapeHtml(m.model)+'</td><td>'+escapeHtml(m.provider)+'</td><td>'+number(m.inputTokens)+'</td><td>'+number(m.outputTokens)+'</td><td>'+ (m.priceConfigured?money(m.estimatedCostUsd):'<span class="warning">Tarif à renseigner</span>')+'</td></tr>').join('')+'</tbody></table>'+(a.available&&a.groups.length?'<h2>Amazon Bedrock par type facturé</h2><table><thead><tr><th>Libellé AWS</th><th>Coût consolidé</th></tr></thead><tbody>'+a.groups.map(g=>'<tr><td>'+escapeHtml(g.model)+'</td><td>'+money(g.costUsd)+'</td></tr>').join('')+'</tbody></table>':'');}
document.querySelectorAll('button').forEach(b=>b.onclick=()=>{days=Number(b.dataset.days);document.querySelectorAll('button').forEach(x=>x.classList.toggle('active',x===b));load().catch(()=>document.querySelector('#content').textContent='Impossible de charger les données.');});load().catch(()=>document.querySelector('#content').textContent='Impossible de charger les données.');
</script></body></html>`;

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://${request.headers.host ?? 'localhost'}`);
  if (request.method === 'GET' && url.pathname === '/health') {
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end('{"status":"ok"}');
    return;
  }
  if (request.method === 'GET' && url.pathname === '/api/summary') {
    try {
      const body = JSON.stringify(await summary(daysFromRequest(url)));
      response.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store' });
      response.end(body);
    } catch (error) {
      console.error('Unable to load dashboard summary.', error);
      response.writeHead(503, { 'content-type': 'application/json' });
      response.end('{"error":"Dashboard data is temporarily unavailable."}');
    }
    return;
  }
  if (request.method === 'GET' && url.pathname === '/') {
    response.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
    response.end(html);
    return;
  }
  response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
  response.end('Not found');
});

await mongoClient.connect();
server.listen(port, '0.0.0.0', () => console.log(`Cost dashboard listening on ${port}.`));

process.on('SIGTERM', async () => {
  server.close();
  await mongoClient.close();
  process.exit(0);
});
