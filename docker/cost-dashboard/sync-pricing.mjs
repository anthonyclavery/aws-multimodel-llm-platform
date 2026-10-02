import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { GetProductsCommand, PricingClient } from '@aws-sdk/client-pricing';

const outputFile = process.env.COST_DASHBOARD_PRICING_OUTPUT ?? '/var/lib/cost-dashboard/pricing.json';
const bundledPricingFile = new URL('./pricing.json', import.meta.url);
const pricing = new PricingClient({ region: 'us-east-1' });
const novaModels = new Map([
  ['eu.amazon.nova-micro-v1:0', 'Nova Micro'],
  ['eu.amazon.nova-lite-v1:0', 'Nova Lite'],
  ['eu.amazon.nova-pro-v1:0', 'Nova Pro'],
]);
const claudeModels = ['Claude Opus 5', 'Claude Sonnet 5', 'Claude Haiku 4.5'];

function plainText(html) {
  return html.replace(/<script[\s\S]*?<\/script>/gi, ' ').replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ').replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&').replace(/\s+/g, ' ').trim();
}

function pricePerMillion(product) {
  for (const term of Object.values(product.terms?.OnDemand ?? {})) {
    for (const dimension of Object.values(term.priceDimensions ?? {})) {
      const price = Number(dimension.pricePerUnit?.USD);
      if (dimension.unit === '1K tokens' && Number.isFinite(price)) return price * 1_000;
    }
  }
  throw new Error('No USD token price was found in the AWS Price List response.');
}

async function novaPrice(model, inferenceType) {
  const response = await pricing.send(new GetProductsCommand({
    ServiceCode: 'AmazonBedrock',
    Filters: [
      { Type: 'TERM_MATCH', Field: 'location', Value: 'EU (Frankfurt)' },
      { Type: 'TERM_MATCH', Field: 'model', Value: model },
      { Type: 'TERM_MATCH', Field: 'feature', Value: 'On-demand Inference' },
      { Type: 'TERM_MATCH', Field: 'inferenceType', Value: inferenceType },
    ],
    MaxResults: 1,
  }));
  const raw = response.PriceList?.[0];
  if (!raw) throw new Error(`AWS Price List returned no ${inferenceType} price for ${model}.`);
  return pricePerMillion(JSON.parse(raw));
}

async function geminiPrice() {
  const response = await fetch('https://ai.google.dev/gemini-api/docs/pricing?hl=en', {
    headers: { 'user-agent': 'aws-multimodel-llm-platform-cost-catalog/1.0' },
  });
  if (!response.ok) throw new Error(`Google Gemini pricing page returned HTTP ${response.status}.`);
  const text = plainText(await response.text());
  const sectionStart = text.indexOf('Gemini 3.5 Flash');
  const section = sectionStart === -1 ? '' : text.slice(sectionStart, sectionStart + 2_500);
  const paidPrices = [...section.matchAll(/([0-9]+(?:[.,][0-9]+)?)\s*\$/g)]
    .map((match) => Number(match[1].replace(',', '.')))
    .filter(Number.isFinite);
  if (paidPrices.length < 2) throw new Error('Could not identify the paid Gemini 3.5 Flash token prices.');
  return { inputPerMillion: paidPrices[0], outputPerMillion: paidPrices[1] };
}

async function verifyClaudePublication() {
  const response = await fetch('https://aws.amazon.com/bedrock/pricing/');
  if (!response.ok) throw new Error(`AWS Bedrock pricing page returned HTTP ${response.status}.`);
  const text = plainText(await response.text());
  for (const model of claudeModels) {
    if (!text.includes(model)) throw new Error(`AWS Bedrock pricing page no longer lists ${model}.`);
  }
}

const catalog = JSON.parse(await readFile(bundledPricingFile, 'utf8'));
await verifyClaudePublication();
for (const [modelId, modelName] of novaModels) {
  catalog.models[modelId] = {
    ...catalog.models[modelId],
    inputPerMillion: await novaPrice(modelName, 'Input tokens'),
    outputPerMillion: await novaPrice(modelName, 'Output tokens'),
  };
}
catalog.models['gemini-3.5-flash'] = {
  ...catalog.models['gemini-3.5-flash'],
  ...(await geminiPrice()),
};
catalog.catalogVersion = new Date().toISOString().slice(0, 10);
catalog.generatedAt = new Date().toISOString();
catalog.sources = {
  nova: 'AWS Price List API, EU (Frankfurt), on-demand inference',
  gemini: 'Google Gemini API pricing page, paid tier',
  claude: 'AWS Bedrock pricing page publication check; configured rates remain the reviewed baseline until AWS exposes the current Claude 5 rates through the Price List API.',
};

await mkdir(dirname(outputFile), { recursive: true, mode: 0o750 });
const temporaryFile = `${outputFile}.tmp-${process.pid}`;
await writeFile(temporaryFile, `${JSON.stringify(catalog, null, 2)}\n`, { mode: 0o640 });
await rename(temporaryFile, outputFile);
console.log(`Cost pricing catalog synchronized at ${catalog.generatedAt}.`);
