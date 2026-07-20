const fs = require('fs');
const path = require('path');

const OUTPUT = path.join(__dirname, '..', 'build', 'new-turkish-recipe-image-candidates.json');
const UA = 'KolayTarifler/1.0 (new Turkish recipe sourcing; ogulcandnsvr@gmail.com)';
const ACCEPTED = /^(CC0|CC BY(?:-SA)?(?: |$)|Public domain)/i;
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const stripTags = value => (value || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();

const NAMES = [
  'Abant Kebabı','Ankara Tava','Ayvalık Tostu','Avcı Böreği','Bafra Pidesi','Banduma','Batırık','Bici Bici',
  'Bostana Salatası','Boyoz','Bursa Cantık','Büryan Kebabı','Cennet Çamuru','Cevizli Biber','Ciğer Sarma','Cızlama',
  'Çömlek Kebabı','Çullama Köfte','Damat Paçası','Denizli Kebabı','Dible','Divriği Pilavı','Döner Kebap','Dövme Çorbası',
  'Edirne Tava Ciğeri','Ekmek Aşı','Elbasan Tava','Erişte Pilavı','Firik Pilavı','Gerdan Tatlısı','Gömme',
  'Hasanpaşa Köftesi','Haşhaşlı Çörek','Helle Çorbası','Hibeş','Islama Köfte','İskilip Dolması','Kabak Borani',
  'Kaburga Dolması','Kayseri Yağlaması','Keledoş','Kenger Yemeği','Kesme Aşı','Kilis Tava','Kirde Kebabı',
  'Konya Fırın Kebabı','Kuru Patlıcan Dolması','Laz Böreği','Lebeniye Çorbası','Madımak Yemeği','Mahluta Çorbası',
  'Meyir Çorbası','Murtuğa','Nevzine Tatlısı','Öcce','Paçanga Böreği','Patates Oturtma','Patlıcan Kapama',
  'Peskütan Çorbası','Pöç Kebabı','Sini Mantısı','Siron','Sivas Köftesi','Soğan Kebabı','Sultan Kebabı','Şambali',
  'Şırdan Dolması','Şiveydiz','Tandır Çorbası','Tire Köftesi','Tokat Kebabı','Topalak Çorbası','Yaren Güveci',
  'Yalancı Dolma','Yuvalama','Zülbiye','Ayran Aşı Çorbası','Harput Köftesi','Besmeç','Paluze','Peynir Helvası',
  'Saray Helvası','Mafiş Tatlısı','Tahinli Piyaz','Kabak Sinkonta','Acem Köftesi','Kavut','Hira Tatlısı',
  'Kıbrıs Tatlısı','İçli Tava','Koca Görmez','Sütlü Çorba','Samsun Kaz Tiridi','Sinop Mantısı',
  'Abdigör Köftesi','Dalyan Köfte','İslim Kebabı','Manisa Kebabı','Tekirdağ Köftesi','Çöp Şiş',
  'Trabzon Pidesi','Küt Böreği','Tava Böreği','Mısır Ekmeği','Karalahana Çorbası','Karnabahar Kızartması',
  'Yoğurtlu Patlıcan','Antalya Piyazı','Şehzade Kebabı','Belen Tava','Patlıcan Söğürme','Kerebiç',
  'Şıllık Tatlısı','Taş Kadayıf','Midye Baklava','Börülce Salatası','Deniz Börülcesi','Enginar Dolması',
  'Pazı Sarması','Mercimekli Pilav','Tatar Böreği','Çökelekli Pide','Kuru Börülce Yemeği','Kuzu Güveç'
];

async function commons(query) {
  const url = 'https://commons.wikimedia.org/w/api.php?format=json&action=query'
    + '&generator=search&gsrnamespace=6&gsrlimit=16'
    + `&gsrsearch=${encodeURIComponent(`${query} filetype:bitmap`)}`
    + '&prop=imageinfo&iiprop=url|extmetadata|mime|size&iiurlwidth=1200';
  const response = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!response.ok) throw new Error(`Commons ${response.status}`);
  const body = await response.json();
  return Object.values(body.query?.pages || {}).flatMap(page => {
    const info = page.imageinfo?.[0];
    if (!info || !/image\/(jpeg|png)/.test(info.mime || '') || (info.width || 0) < 600) return [];
    const meta = info.extmetadata || {};
    const license = meta.LicenseShortName?.value || '';
    if (!ACCEPTED.test(license)) return [];
    return [{
      provider: 'Wikimedia Commons', source: 'wikimedia', title: page.title || '',
      description: stripTags(meta.ImageDescription?.value), imageUrl: info.url,
      previewUrl: info.thumburl || info.url, page: info.descriptionurl || '', license,
      licenseUrl: meta.LicenseUrl?.value || '', artist: stripTags(meta.Artist?.value),
      width: info.width || 0, height: info.height || 0, query,
    }];
  });
}

(async () => {
  const output = fs.existsSync(OUTPUT) ? JSON.parse(fs.readFileSync(OUTPUT, 'utf8')) : [];
  const completed = new Set(output.map(item => item.name));
  for (let index = 0; index < NAMES.length; index += 1) {
    const name = NAMES[index];
    if (completed.has(name)) continue;
    let candidates = [];
    try {
      candidates = await commons(name);
    } catch (error) {
      if (!String(error.message).includes('429')) throw error;
      await sleep(3000);
      candidates = await commons(name);
    }
    output.push({ name, candidates });
    fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
    fs.writeFileSync(OUTPUT, JSON.stringify(output, null, 2) + '\n');
    console.log(`${index + 1}/${NAMES.length} ${name}: ${candidates.length}`);
    await sleep(350);
  }
  console.log(`Rapor: ${OUTPUT}`);
})().catch(error => { console.error(error.stack || error.message); process.exit(1); });
