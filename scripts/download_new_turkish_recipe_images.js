const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const manifestPath = path.join(__dirname, '..', 'build', 'new-turkish-recipe-image-manifest.json');
const outputDir = path.join(__dirname, '..', 'build', 'new-turkish-recipe-images');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const slug = value => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/ı/g, 'i').replace(/[^a-zA-Z0-9]+/g, '-').replace(/^-|-$/g, '').toLowerCase();
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

(async () => {
  fs.mkdirSync(outputDir, { recursive: true });
  let count = 0;
  for (const recipe of manifest) {
    for (let index = 0; index < recipe.images.length; index += 1) {
      const image = recipe.images[index];
      const target = path.join(outputDir, `${String(count + 1).padStart(3, '0')}-${slug(recipe.name)}-${index + 1}.jpg`);
      if (fs.existsSync(target) && fs.statSync(target).size >= 20000) {
        const existing = fs.readFileSync(target);
        image.localPath = path.relative(path.join(__dirname, '..'), target).replace(/\\/g, '/');
        image.bytes = existing.length;
        image.sha256 = crypto.createHash('sha256').update(existing).digest('hex');
        count += 1;
        console.log(`${count}/100 ${recipe.name} #${index + 1} (mevcut)`);
        continue;
      }
      let buffer;
      for (let attempt = 1; attempt <= 5; attempt += 1) {
        const response = await fetch(image.imageUrl, { headers: { 'User-Agent': 'KolayTarifler/1.0 (recipe image QA; ogulcandnsvr@gmail.com)' } });
        if (response.ok) {
          buffer = Buffer.from(await response.arrayBuffer());
          break;
        }
        if (attempt === 5) throw new Error(`${recipe.name} ${index + 1}: HTTP ${response.status} ${image.imageUrl}`);
        await sleep(response.status === 429 ? attempt * 5000 : attempt * 1500);
      }
      if (buffer.length < 20000) throw new Error(`${recipe.name} ${index + 1}: dosya çok küçük (${buffer.length})`);
      const isJpeg = buffer[0] === 0xff && buffer[1] === 0xd8;
      const isPng = buffer.subarray(1, 4).toString() === 'PNG';
      if (!isJpeg && !isPng) throw new Error(`${recipe.name} ${index + 1}: bitmap değil`);
      fs.writeFileSync(target, buffer);
      image.localPath = path.relative(path.join(__dirname, '..'), target).replace(/\\/g, '/');
      image.bytes = buffer.length;
      image.sha256 = crypto.createHash('sha256').update(buffer).digest('hex');
      count += 1;
      console.log(`${count}/100 ${recipe.name} #${index + 1} (${Math.round(buffer.length / 1024)} KB)`);
      await sleep(700);
    }
  }
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
  console.log(`Tamamlandı: ${count} görsel`);
})().catch(error => { console.error(error.stack || error.message); process.exit(1); });
