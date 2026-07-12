/**
 * Commons'ta telifsiz görseli bulunamayan tarifler için Pollinations (Flux)
 * ile AI görsel üretir — GÖRSEL DOĞRULAMA için scratchpad'e indirir.
 *
 *   node ai_gen.js            → _ai_prompts.json'daki tüm tarifler (gNN.jpg)
 *   node ai_gen.js <idx> [seed] → tek tarifi (farklı seed'le) yeniden üret
 *
 * Doğrulama sonrası: node ai_commit.js <idx> <idx> ...
 */
const fs = require('fs');
const OUT = 'C:/Users/ogulc/AppData/Local/Temp/claude/C--Users-ogulc-Downloads-Yeni-klas-r/28f292cc-44e5-45e9-a85a-02aada20f8bf/scratchpad';
const ITEMS = JSON.parse(fs.readFileSync('_ai_prompts.json', 'utf8'));

const STYLE = ', professional food photography, natural light, appetizing, restaurant plating, no text, no watermark';

async function gen(prompt, seed, dest) {
  const url = 'https://image.pollinations.ai/prompt/' + encodeURIComponent(prompt + STYLE)
    + `?width=1024&height=768&nologo=true&model=flux&seed=${seed}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`gen ${res.status}`);
  const buf = Buffer.from(await res.arrayBuffer());
  if (buf.length < 10000) throw new Error('şüpheli küçük dosya');
  fs.writeFileSync(dest, buf);
  return buf.length;
}

(async () => {
  const only = process.argv[2] !== undefined ? parseInt(process.argv[2], 10) : null;
  const seedArg = process.argv[3] !== undefined ? parseInt(process.argv[3], 10) : null;

  for (let i = 0; i < ITEMS.length; i++) {
    if (only !== null && i !== only) continue;
    const it = ITEMS[i];
    const seed = seedArg !== null ? seedArg : 100 + i;
    const dest = `${OUT}/g${String(i).padStart(2, '0')}.jpg`;
    try {
      const size = await gen(it.prompt, seed, dest);
      console.log(String(i).padStart(2), '| g' + String(i).padStart(2, '0'), '|', it.name, '|', Math.round(size / 1024) + 'KB', '| seed', seed);
    } catch (e) {
      console.log(String(i).padStart(2), '| HATA |', it.name, '|', e.message);
    }
    if (only === null) await new Promise(r => setTimeout(r, 1500));
  }
  process.exit(0);
})();
