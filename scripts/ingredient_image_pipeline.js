/**
 * Ingredient repair pipeline.
 *
 * Sources are intentionally restricted to freely reusable photographs.
 * CC BY/CC BY-SA candidates preserve their attribution metadata.
 * Commands:
 *   node ingredient_image_pipeline.js find [offset] [count]
 *   node ingredient_image_pipeline.js select <ingredientId> <candidateIndex>
 *   node ingredient_image_pipeline.js retry-downloads
 *   node ingredient_image_pipeline.js mark-ai <ingredientId> <localPath> <prompt>
 *   node ingredient_image_pipeline.js commit-images [--commit]
 *   node ingredient_image_pipeline.js dedupe [--commit]
 *   node ingredient_image_pipeline.js verify
 */
const admin = require('firebase-admin');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./serviceAccountKey.json');
const config = require('./ingredient_repair_config.json');
const state = require('./ingredient_state_before.json');

const CANDIDATE_PATH = path.join(__dirname, 'ingredient_image_candidates.json');
const WORK_DIR = path.join(__dirname, 'ingredient_image_work');
const BACKUP_DIR = path.join(__dirname, 'ingredient_repair_backups');
const USER_AGENT = 'kolay-tarifler-ingredient-repair/1.0 (free-license image sourcing)';
const BUCKET = `${serviceAccount.project_id}.firebasestorage.app`;

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: BUCKET,
});

const db = admin.firestore();
const bucket = admin.storage().bucket();
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function fetchWithRetry(url, options, label) {
  for (let attempt = 1; attempt <= 4; attempt++) {
    let response;
    try {
      response = await fetch(url, {...options, signal: AbortSignal.timeout(20000)});
    } catch (error) {
      if (attempt === 4) throw error;
      const waitMs = attempt * 2000;
      console.log(`${label} request failed; retrying in ${waitMs}ms`);
      await sleep(waitMs);
      continue;
    }
    if (response.ok || ![429, 500, 502, 503, 504].includes(response.status)) return response;
    if (attempt === 4) return response;
    const retryAfter = Number.parseInt(response.headers.get('retry-after') || '0', 10);
    const waitMs = retryAfter > 0 ? Math.min(retryAfter * 1000, 15000) : attempt * 2500;
    console.log(`${label} ${response.status}; retrying in ${waitMs}ms`);
    await sleep(waitMs);
  }
  throw new Error(`${label} retry loop failed`);
}

function readCandidateState() {
  if (!fs.existsSync(CANDIDATE_PATH)) return {updatedAt: null, items: {}};
  return JSON.parse(fs.readFileSync(CANDIDATE_PATH, 'utf8'));
}

function writeCandidateState(candidateState) {
  candidateState.updatedAt = new Date().toISOString();
  fs.writeFileSync(CANDIDATE_PATH, `${JSON.stringify(candidateState, null, 2)}\n`);
}

function sanitizeText(value) {
  return String(value || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
}

function fileType(buffer, responseType) {
  if (buffer[0] === 0xff && buffer[1] === 0xd8) return {extension: 'jpg', contentType: 'image/jpeg'};
  if (buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
    return {extension: 'png', contentType: 'image/png'};
  }
  if (buffer.subarray(0, 4).toString('ascii') === 'RIFF' && buffer.subarray(8, 12).toString('ascii') === 'WEBP') {
    return {extension: 'webp', contentType: 'image/webp'};
  }
  if ((responseType || '').includes('jpeg')) return {extension: 'jpg', contentType: 'image/jpeg'};
  if ((responseType || '').includes('png')) return {extension: 'png', contentType: 'image/png'};
  if ((responseType || '').includes('webp')) return {extension: 'webp', contentType: 'image/webp'};
  throw new Error(`unsupported image type: ${responseType || 'unknown'}`);
}

async function download(url, ingredientId) {
  const response = await fetch(url, {
    headers: {'User-Agent': USER_AGENT},
    signal: AbortSignal.timeout(6000),
  });
  if (!response.ok) throw new Error(`download ${response.status}`);
  const buffer = Buffer.from(await response.arrayBuffer());
  if (buffer.length < 3000) throw new Error(`image too small (${buffer.length} bytes)`);
  const type = fileType(buffer, response.headers.get('content-type'));
  fs.mkdirSync(WORK_DIR, {recursive: true});
  for (const filename of fs.readdirSync(WORK_DIR)) {
    if (filename.startsWith(`${ingredientId}.`)) fs.unlinkSync(path.join(WORK_DIR, filename));
  }
  const localPath = path.join(WORK_DIR, `${ingredientId}.${type.extension}`);
  fs.writeFileSync(localPath, buffer);
  return {
    localPath: path.relative(__dirname, localPath).replace(/\\/g, '/'),
    contentType: type.contentType,
    bytes: buffer.length,
  };
}

function titleScore(result, query, index) {
  const title = String(result.title || '').toLocaleLowerCase('en');
  const tokens = query.toLocaleLowerCase('en')
    .split(/[^a-z0-9]+/)
    .filter((token) => token.length >= 3 && !['raw', 'fresh', 'bowl', 'food', 'ingredient'].includes(token));
  let score = Math.max(0, 30 - index);
  for (const token of tokens) {
    if (title.includes(token)) score += 8;
  }
  if (result.category === 'photograph') score += 6;
  if (result.license === 'cc0') score += 2;
  if (/logo|icon|map|drawing|illustration|diagram|painting|stamp|poster|label/i.test(title)) score -= 50;
  if (/pear/.test(query) && /prickly|cactus/.test(title)) score -= 60;
  return score;
}

async function searchOpenverse(query, allowAttribution = false) {
  const acceptedLicenses = allowAttribution ? ['cc0', 'pdm', 'by', 'by-sa'] : ['cc0', 'pdm'];
  const params = new URLSearchParams({
    q: query,
    license: acceptedLicenses.join(','),
    category: 'photograph',
    page_size: '20',
    mature: 'false',
  });
  const response = await fetchWithRetry(`https://api.openverse.org/v1/images/?${params}`, {
    headers: {'User-Agent': USER_AGENT},
  }, 'Openverse');
  if (!response.ok) throw new Error(`Openverse ${response.status}`);
  const body = await response.json();
  return (body.results || [])
    .filter((result) => acceptedLicenses.includes(result.license) && result.thumbnail)
    .map((result, index) => ({
      id: result.id,
      title: sanitizeText(result.title),
      thumbnail: result.thumbnail,
      originalUrl: result.url,
      page: result.foreign_landing_url,
      creator: sanitizeText(result.creator),
      creatorUrl: result.creator_url || '',
      license: result.license,
      licenseVersion: result.license_version || '',
      licenseUrl: result.license_url || '',
      source: result.source || '',
      provider: result.provider || '',
      category: result.category || '',
      width: result.width || null,
      height: result.height || null,
      score: titleScore(result, query, index),
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 8);
}

function commonsLicense(rawLicense, allowAttribution) {
  if (/^CC0/i.test(rawLicense)) return 'cc0';
  if (/Public domain|PDM/i.test(rawLicense)) return 'pdm';
  if (!allowAttribution || /NC|ND/i.test(rawLicense)) return null;
  if (/CC BY-SA/i.test(rawLicense)) return 'by-sa';
  if (/CC BY/i.test(rawLicense)) return 'by';
  return null;
}

async function searchCommons(query, allowAttribution = false) {
  const params = new URLSearchParams({
    format: 'json',
    action: 'query',
    generator: 'search',
    gsrnamespace: '6',
    gsrlimit: '30',
    gsrsearch: `${query} filetype:bitmap`,
    prop: 'imageinfo',
    iiprop: 'url|extmetadata|mime|size',
    iiurlwidth: '500',
    origin: '*',
  });
  const response = await fetchWithRetry(`https://commons.wikimedia.org/w/api.php?${params}`, {
    headers: {'User-Agent': USER_AGENT},
  }, 'Commons');
  if (!response.ok) throw new Error(`Commons ${response.status}`);
  const body = await response.json();
  const pages = Object.values(body.query?.pages || {}).sort((a, b) => (a.index || 0) - (b.index || 0));
  return pages
    .map((page, index) => {
      const info = page.imageinfo?.[0];
      if (!info || !/^image\/(jpeg|png|webp)$/.test(info.mime || '')) return null;
      const metadata = info.extmetadata || {};
      const rawLicense = sanitizeText(metadata.LicenseShortName?.value);
      const license = commonsLicense(rawLicense, allowAttribution);
      if (!license) return null;
      const result = {
        id: `commons-${page.pageid}`,
        title: sanitizeText(page.title).replace(/^File:/, ''),
        thumbnail: info.thumburl || info.url,
        originalUrl: info.url,
        page: info.descriptionurl,
        creator: sanitizeText(metadata.Artist?.value),
        creatorUrl: '',
        license,
        licenseVersion: sanitizeText(metadata.License?.value),
        licenseUrl: sanitizeText(metadata.LicenseUrl?.value),
        source: 'wikimedia-commons',
        provider: 'wikimedia',
        category: 'photograph',
        width: info.width || null,
        height: info.height || null,
      };
      result.score = titleScore(result, query, index);
      return result;
    })
    .filter(Boolean)
    .sort((a, b) => b.score - a.score)
    .slice(0, 8);
}

async function searchFreeSources(query, sourceMode = 'both') {
  if (sourceMode === 'openverse') return searchOpenverse(query);
  if (sourceMode === 'openverse-free') return searchOpenverse(query, true);
  if (sourceMode === 'commons') return searchCommons(query);
  if (sourceMode === 'commons-free') return searchCommons(query, true);
  let commonsCandidates = [];
  let commonsError = null;
  try {
    commonsCandidates = await searchCommons(query);
  } catch (error) {
    commonsError = error;
  }
  if (commonsCandidates.length) return commonsCandidates;

  let openverseCandidates = [];
  let openverseError = null;
  try {
    openverseCandidates = await searchOpenverse(query);
  } catch (error) {
    openverseError = error;
  }
  const candidates = openverseCandidates;
  const unique = [];
  const seen = new Set();
  for (const candidate of candidates.sort((a, b) => b.score - a.score)) {
    const key = candidate.page || candidate.originalUrl || candidate.thumbnail;
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(candidate);
    if (unique.length === 10) break;
  }
  if (!unique.length && openverseError && commonsError) {
    throw new Error(`all sources failed: ${openverseError.message}; ${commonsError.message}`);
  }
  return unique;
}

function missingTargets() {
  const duplicateSources = new Set(config.duplicates.map((item) => item.sourceId));
  return state.ingredients.filter((item) =>
    !item.imageUrl.trim() && !duplicateSources.has(item.id),
  );
}

async function findCandidates() {
  const offset = Number.parseInt(process.argv[3] || '0', 10);
  const count = Number.parseInt(process.argv[4] || '999', 10);
  const sourceMode = process.argv[5] || 'both';
  if (!['both', 'openverse', 'openverse-free', 'commons', 'commons-free'].includes(sourceMode)) {
    throw new Error('source mode must be both, openverse, openverse-free, commons, or commons-free');
  }
  const allTargets = missingTargets();
  const targets = allTargets.slice(offset, offset + count);
  const candidateState = readCandidateState();

  const licenseLabel = sourceMode.endsWith('-free') ? 'CC0/PDM/CC BY/CC BY-SA' : 'CC0/PDM';
  console.log(`${sourceMode} ${licenseLabel}: ${targets.length} target (offset ${offset}/${allTargets.length})`);
  let found = 0;
  let empty = 0;
  let failed = 0;
  let cursor = 0;
  async function worker() {
    while (true) {
      const index = cursor++;
      if (index >= targets.length) return;
    const ingredient = targets[index];
    const existing = candidateState.items[ingredient.id];
    if (existing?.selected >= 0 && existing.localPath && fs.existsSync(path.join(__dirname, existing.localPath))) {
      found++;
      console.log(`${String(offset + index).padStart(3)} | CACHED | ${ingredient.name}`);
      continue;
    }
    const query = config.queries[ingredient.id];
    if (!query) {
      empty++;
      candidateState.items[ingredient.id] = {
        ingredientId: ingredient.id,
        name: ingredient.name,
        query: null,
        selected: -1,
        status: 'missing-query',
        candidates: [],
      };
      console.log(`${String(offset + index).padStart(3)} | QUERY MISSING | ${ingredient.name}`);
      continue;
    }
    try {
      const candidates = await searchFreeSources(query, sourceMode);
      const row = {
        ingredientId: ingredient.id,
        name: ingredient.name,
        query,
        selected: candidates.length ? 0 : -1,
        status: candidates.length ? 'candidate' : 'no-result',
        candidates,
      };
      if (candidates.length) {
        let selected = -1;
        let local = null;
        let lastDownloadError = null;
        for (let candidateIndex = 0; candidateIndex < Math.min(candidates.length, 3); candidateIndex++) {
          try {
            local = await download(candidates[candidateIndex].thumbnail, ingredient.id);
            selected = candidateIndex;
            break;
          } catch (error) {
            lastDownloadError = error;
          }
        }
        if (selected >= 0) {
          row.selected = selected;
          Object.assign(row, local);
          found++;
          console.log(`${String(offset + index).padStart(3)} | OK | ${ingredient.name} | ${candidates[selected].license.toUpperCase()} | ${candidates[selected].title}`);
        } else {
          row.status = 'download-error';
          row.error = lastDownloadError?.message || 'all candidate downloads failed';
          failed++;
          console.log(`${String(offset + index).padStart(3)} | DOWNLOAD ERROR | ${ingredient.name} | ${row.error}`);
        }
      } else {
        empty++;
        console.log(`${String(offset + index).padStart(3)} | NO RESULT | ${ingredient.name} | ${query}`);
      }
      candidateState.items[ingredient.id] = row;
    } catch (error) {
      failed++;
      candidateState.items[ingredient.id] = {
        ingredientId: ingredient.id,
        name: ingredient.name,
        query,
        selected: -1,
        status: 'error',
        error: error.message,
        candidates: [],
      };
      console.log(`${String(offset + index).padStart(3)} | ERROR | ${ingredient.name} | ${error.message}`);
    }
    writeCandidateState(candidateState);
      await sleep(sourceMode === 'commons-free' ? 1400 : 3200);
    }
  }
  await Promise.all([worker()]);
  writeCandidateState(candidateState);
  console.log(`\nFound: ${found} | no result/query: ${empty} | failed: ${failed}`);
}

async function selectCandidate() {
  const ingredientId = process.argv[3];
  const selected = Number.parseInt(process.argv[4], 10);
  const candidateState = readCandidateState();
  const row = candidateState.items[ingredientId];
  if (!row) throw new Error(`candidate row not found: ${ingredientId}`);
  const candidate = row.candidates[selected];
  if (!candidate) throw new Error(`candidate index not found: ${selected}`);
  const local = await download(candidate.thumbnail, ingredientId);
  row.selected = selected;
  row.status = 'candidate';
  Object.assign(row, local);
  writeCandidateState(candidateState);
  console.log(`Selected ${ingredientId} -> ${selected}: ${candidate.title}`);
}

async function retryDownloads() {
  const candidateState = readCandidateState();
  const rows = Object.values(candidateState.items)
    .filter((row) => ['download-error', 'error'].includes(row.status) && row.candidates?.length);
  console.log(`Retrying ${rows.length} candidate downloads`);
  let completed = 0;
  let failed = 0;
  for (const row of rows) {
    let local = null;
    let selected = -1;
    let lastError = null;
    for (let index = 0; index < Math.min(row.candidates.length, 5); index++) {
      try {
        local = await download(row.candidates[index].thumbnail, row.ingredientId);
        selected = index;
        break;
      } catch (error) {
        lastError = error;
        await sleep(900);
      }
    }
    if (selected >= 0) {
      row.selected = selected;
      row.status = 'candidate';
      delete row.error;
      Object.assign(row, local);
      completed++;
      console.log(`OK | ${row.name} | ${row.candidates[selected].title}`);
    } else {
      row.error = lastError?.message || 'all candidate downloads failed';
      failed++;
      console.log(`FAILED | ${row.name} | ${row.error}`);
    }
    writeCandidateState(candidateState);
    await sleep(900);
  }
  console.log(`Downloaded: ${completed} | failed: ${failed}`);
}

function markAi() {
  const ingredientId = process.argv[3];
  const suppliedPath = process.argv[4];
  const prompt = process.argv.slice(5).join(' ');
  if (!ingredientId || !suppliedPath || !prompt) {
    throw new Error('mark-ai requires ingredientId, localPath, and prompt');
  }
  const absolutePath = path.resolve(process.cwd(), suppliedPath);
  if (!fs.existsSync(absolutePath)) throw new Error(`file not found: ${absolutePath}`);
  const buffer = fs.readFileSync(absolutePath);
  const type = fileType(buffer, '');
  fs.mkdirSync(WORK_DIR, {recursive: true});
  const finalPath = path.join(WORK_DIR, `${ingredientId}.${type.extension}`);
  fs.copyFileSync(absolutePath, finalPath);
  const ingredient = state.ingredients.find((item) => item.id === ingredientId);
  const candidateState = readCandidateState();
  candidateState.items[ingredientId] = {
    ingredientId,
    name: ingredient?.name || ingredientId,
    query: null,
    selected: 0,
    status: 'ai-generated',
    localPath: path.relative(__dirname, finalPath).replace(/\\/g, '/'),
    contentType: type.contentType,
    bytes: buffer.length,
    prompt,
    candidates: [{
      id: `ai-${ingredientId}`,
      title: `${ingredient?.name || ingredientId} AI-generated ingredient photo`,
      page: 'https://openai.com/policies/terms-of-use/',
      creator: 'OpenAI image generation',
      license: 'ai-output-owned-by-user',
      licenseUrl: 'https://openai.com/policies/terms-of-use/',
      source: 'openai-imagegen',
      provider: 'openai',
    }],
  };
  writeCandidateState(candidateState);
  console.log(`AI image registered: ${ingredientId} -> ${finalPath}`);
}

function rejectCandidates() {
  const ingredientIds = process.argv.slice(3);
  if (!ingredientIds.length) throw new Error('reject requires at least one ingredientId');
  const candidateState = readCandidateState();
  for (const ingredientId of ingredientIds) {
    const row = candidateState.items[ingredientId];
    if (!row) {
      console.log(`Not found: ${ingredientId}`);
      continue;
    }
    row.selected = -1;
    row.status = 'rejected';
    row.rejectedAt = new Date().toISOString();
    console.log(`Rejected: ${ingredientId} | ${row.name}`);
  }
  writeCandidateState(candidateState);
}

async function uploadImage(ingredientId, row) {
  const localPath = path.join(__dirname, row.localPath);
  if (!fs.existsSync(localPath)) throw new Error(`local image missing: ${row.localPath}`);
  const candidate = row.candidates[row.selected];
  if (!candidate) throw new Error('selected candidate missing');
  const extension = path.extname(localPath).slice(1).toLowerCase();
  const storagePath = `ingredients/${ingredientId}.${extension}`;
  const token = crypto.randomUUID();
  const metadata = {
    contentType: row.contentType,
    metadata: {
      firebaseStorageDownloadTokens: token,
      source: candidate.source,
      license: candidate.license,
      sourcePage: candidate.page || '',
    },
  };
  await bucket.upload(localPath, {destination: storagePath, metadata, resumable: false});
  const imageUrl = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(storagePath)}?alt=media&token=${token}`;
  const imageSource = row.status === 'ai-generated'
    ? {
      source: candidate.source,
      prompt: row.prompt,
      license: candidate.license,
      terms: candidate.licenseUrl,
    }
    : {
      source: candidate.source,
      provider: candidate.provider,
      originalSource: candidate.source,
      title: candidate.title,
      creator: candidate.creator,
      creatorUrl: candidate.creatorUrl || '',
      page: candidate.page,
      license: candidate.license,
      licenseVersion: candidate.licenseVersion || '',
      licenseUrl: candidate.licenseUrl,
      query: row.query,
    };
  await db.collection('ingredients').doc(ingredientId).update({
    imageUrl,
    imageSource,
    imageUpdatedAt: admin.firestore.Timestamp.now(),
    modifiedAt: admin.firestore.Timestamp.now(),
  });
  return imageUrl;
}

async function commitImages() {
  const commit = process.argv.includes('--commit');
  const candidateState = readCandidateState();
  const rows = Object.values(candidateState.items)
    .filter((row) => row.selected >= 0 && row.localPath && ['candidate', 'ai-generated'].includes(row.status));
  const expected = missingTargets().length;
  console.log(`${commit ? 'COMMIT' : 'DRY RUN'}: ${rows.length}/${expected} images ready`);
  if (!commit) return;
  let completed = 0;
  for (const row of rows) {
    await uploadImage(row.ingredientId, row);
    row.status = 'uploaded';
    row.uploadedAt = new Date().toISOString();
    completed++;
    writeCandidateState(candidateState);
    console.log(`${String(completed).padStart(3)}/${rows.length} | ${row.name}`);
  }
}

function replaceIngredientIds(ingredients, replacementMap) {
  let changed = false;
  const updated = (Array.isArray(ingredients) ? ingredients : []).map((item) => {
    if (!item?.ingredientId || !replacementMap.has(item.ingredientId)) return item;
    changed = true;
    return {...item, ingredientId: replacementMap.get(item.ingredientId)};
  });
  return {changed, updated};
}

async function commitInChunks(operations) {
  for (let start = 0; start < operations.length; start += 400) {
    const batch = db.batch();
    for (const operation of operations.slice(start, start + 400)) operation(batch);
    await batch.commit();
  }
}

async function dedupe() {
  const commit = process.argv.includes('--commit');
  const replacementMap = new Map(config.duplicates.map((item) => [item.sourceId, item.targetId]));
  const canonicalNames = new Map(config.duplicates.map((item) => [item.targetId, item.canonicalName]));
  const [ingredientSnapshot, recipeSnapshot, pendingSnapshot] = await Promise.all([
    db.collection('ingredients').get(),
    db.collection('recipes').get(),
    db.collection('pending_recipes').get(),
  ]);
  const ingredientById = new Map(ingredientSnapshot.docs.map((document) => [document.id, document]));
  for (const item of config.duplicates) {
    if (!ingredientById.has(item.sourceId)) throw new Error(`source missing: ${item.sourceId}`);
    if (!ingredientById.has(item.targetId)) throw new Error(`target missing: ${item.targetId}`);
  }

  const changedRecipes = [];
  for (const document of recipeSnapshot.docs) {
    const data = document.data();
    const result = replaceIngredientIds(data.ingredients, replacementMap);
    if (result.changed) changedRecipes.push({document, before: data.ingredients, after: result.updated});
  }
  const changedPending = [];
  for (const document of pendingSnapshot.docs) {
    const data = document.data();
    const result = replaceIngredientIds(data.ingredients, replacementMap);
    if (result.changed) changedPending.push({document, before: data.ingredients, after: result.updated});
  }

  const duplicateLineCount = (ingredients) => {
    const ids = ingredients.map((item) => item?.ingredientId).filter(Boolean);
    return ids.length - new Set(ids).size;
  };
  const collisionRecipes = [...changedRecipes, ...changedPending].filter(({before, after}) =>
    duplicateLineCount(after) > duplicateLineCount(before),
  );
  if (collisionRecipes.length) {
    const details = collisionRecipes.map(({document}) => document.ref.path).join(', ');
    console.log(`Note: ${collisionRecipes.length} recipes use the same canonical ingredient more than once for separate steps: ${details}`);
  }

  console.log(`${commit ? 'COMMIT' : 'DRY RUN'}: ${config.duplicates.length} ingredient documents`);
  console.log(`Recipes to relink: ${changedRecipes.length} | pending recipes: ${changedPending.length}`);
  for (const item of config.duplicates) {
    console.log(`${item.sourceId} -> ${item.targetId} | ${item.canonicalName}`);
  }
  if (!commit) return;

  fs.mkdirSync(BACKUP_DIR, {recursive: true});
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = path.join(BACKUP_DIR, `ingredient-repair-${timestamp}.json`);
  fs.writeFileSync(backupPath, `${JSON.stringify({
    createdAt: new Date().toISOString(),
    duplicates: config.duplicates,
    ingredients: config.duplicates.flatMap((item) => [
      {id: item.sourceId, data: ingredientById.get(item.sourceId).data()},
      {id: item.targetId, data: ingredientById.get(item.targetId).data()},
    ]),
    recipes: changedRecipes.map(({document, before}) => ({id: document.id, ingredients: before})),
    pendingRecipes: changedPending.map(({document, before}) => ({id: document.id, ingredients: before})),
  }, null, 2)}\n`);

  const operations = [];
  for (const {document, after} of changedRecipes) {
    operations.push((batch) => batch.update(document.ref, {
      ingredients: after,
      modifiedAt: admin.firestore.Timestamp.now(),
    }));
  }
  for (const {document, after} of changedPending) {
    operations.push((batch) => batch.update(document.ref, {
      ingredients: after,
      modifiedAt: admin.firestore.Timestamp.now(),
    }));
  }
  for (const [targetId, canonicalName] of canonicalNames) {
    operations.push((batch) => batch.update(db.collection('ingredients').doc(targetId), {
      name: canonicalName,
      modifiedAt: admin.firestore.Timestamp.now(),
    }));
  }
  for (const item of config.duplicates) {
    operations.push((batch) => batch.delete(db.collection('ingredients').doc(item.sourceId)));
  }
  await commitInChunks(operations);
  console.log(`Backup: ${backupPath}`);
}

async function verify() {
  const [ingredientSnapshot, recipeSnapshot, pendingSnapshot] = await Promise.all([
    db.collection('ingredients').get(),
    db.collection('recipes').get(),
    db.collection('pending_recipes').get(),
  ]);
  const duplicateSourceIds = new Set(config.duplicates.map((item) => item.sourceId));
  const ingredientIds = new Set(ingredientSnapshot.docs.map((document) => document.id));
  const missingImages = ingredientSnapshot.docs
    .filter((document) => !String(document.data().imageUrl || '').trim())
    .map((document) => `${document.id}:${document.data().name}`);
  const survivingSources = [...duplicateSourceIds].filter((id) => ingredientIds.has(id));
  const brokenRefs = [];
  for (const collection of [recipeSnapshot, pendingSnapshot]) {
    for (const document of collection.docs) {
      for (const item of document.data().ingredients || []) {
        if (!ingredientIds.has(item.ingredientId)) brokenRefs.push(`${document.ref.path}:${item.ingredientId}`);
      }
    }
  }
  console.log(JSON.stringify({
    ingredients: ingredientSnapshot.size,
    recipes: recipeSnapshot.size,
    pendingRecipes: pendingSnapshot.size,
    missingImageCount: missingImages.length,
    missingImages,
    survivingDuplicateSources: survivingSources,
    brokenReferenceCount: brokenRefs.length,
    brokenReferences: brokenRefs.slice(0, 50),
  }, null, 2));
  if (missingImages.length || survivingSources.length || brokenRefs.length) process.exitCode = 2;
}

async function main() {
  const command = process.argv[2];
  if (command === 'debug-search') {
    const query = process.argv.slice(3).join(' ');
    console.log(JSON.stringify({
      openverse: await searchOpenverse(query),
      commons: await searchCommons(query),
    }, null, 2));
    return;
  }
  if (command === 'find') return findCandidates();
  if (command === 'select') return selectCandidate();
  if (command === 'retry-downloads') return retryDownloads();
  if (command === 'reject') return rejectCandidates();
  if (command === 'mark-ai') return markAi();
  if (command === 'commit-images') return commitImages();
  if (command === 'dedupe') return dedupe();
  if (command === 'verify') return verify();
  throw new Error('command must be debug-search, find, select, retry-downloads, reject, mark-ai, commit-images, dedupe, or verify');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
