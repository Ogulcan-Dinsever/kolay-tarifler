const fs = require('fs');
const path = require('path');

const recipes = require('./new_turkish_recipes_50');
const candidates = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'build', 'new-turkish-recipe-image-candidates.json'), 'utf8'));
const byName = new Map(candidates.map(item => [item.name, item.candidates]));

const picks = {
  'Ankara Tava': [0, 1], 'Ayvalık Tostu': [5, 6], 'Bafra Pidesi': [0, 0], 'Bici Bici': [13, 13],
  'Boyoz': [0, 3], 'Bursa Cantık': [0, 2], 'Büryan Kebabı': [4, 10], 'Ciğer Sarma': [0, 3],
  'Denizli Kebabı': [0, 1], 'Döner Kebap': [0, 3], 'Edirne Tava Ciğeri': [0, 6], 'Elbasan Tava': [0, 4],
  'Firik Pilavı': [0, 'firik-alt'], 'Hasanpaşa Köftesi': [0, 0], 'Haşhaşlı Çörek': [1, 2],
  'Islama Köfte': [0, 0], 'İskilip Dolması': [0, 2], 'Kaburga Dolması': [1, 1],
  'Kayseri Yağlaması': [0, 1], 'Keledoş': [0, 1], 'Konya Fırın Kebabı': [0, 'konya-alt'],
  'Laz Böreği': [5, 6], 'Nevzine Tatlısı': [0, 1], 'Paçanga Böreği': [0, 1],
  'Patates Oturtma': [1, 2], 'Siron': [5, 6], 'Şambali': [6, 7], 'Tire Köftesi': [0, 1],
  'Tokat Kebabı': [0, 1], 'Yalancı Dolma': [4, 5], 'Yuvalama': [1, 4], 'Ayran Aşı Çorbası': [0, 1],
  'Besmeç': [0, 1], 'Peynir Helvası': [0, 2], 'Fırında Makarna': ['makarna-1', 'makarna-2'],
  'Kıbrıs Tatlısı': [0, 1], 'Samsun Kaz Tiridi': [0, 2], 'Sinop Mantısı': [0, 1],
  'Dalyan Köfte': [0, 2], 'İslim Kebabı': [1, 2], 'Manisa Kebabı': [0, 1],
  'Tekirdağ Köftesi': [0, 'tekirdag-alt'], 'Çöp Şiş': [3, 4], 'Mısır Ekmeği': [3, 6],
  'Belen Tava': [0, 2], 'Kerebiç': [3, 4], 'Deniz Börülcesi': [3, 4], 'Enginar Dolması': [0, 1],
  'Çökelekli Pide': [0, 2], 'Kuzu Güveç': [0, 1],
};

const manual = {
  'firik-alt': {
    provider: 'Wikimedia Commons', source: 'wikimedia', title: '20241025-USDA-FNS-UNK-0027',
    imageUrl: 'https://live.staticflickr.com/65535/54092096592_d09edbd48e_b.jpg',
    page: 'https://www.flickr.com/photos/usdagov/54092096592', license: 'Public Domain Mark',
    licenseUrl: 'https://creativecommons.org/publicdomain/mark/1.0/', artist: 'USDA',
  },
  'konya-alt': {
    provider: 'Wikimedia Commons', source: 'wikimedia', title: 'Fırın Kebabı',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/2/22/F%C4%B1r%C4%B1n_Kebab%C4%B1.jpg',
    page: 'https://commons.wikimedia.org/wiki/File:F%C4%B1r%C4%B1n_Kebab%C4%B1.jpg', license: 'CC BY-SA 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/', artist: 'Muratkkara',
  },
  'tekirdag-alt': {
    provider: 'Wikimedia Commons', source: 'wikimedia', title: 'Köfteler',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/1/1d/K%C3%B6fteler.jpg',
    page: 'https://commons.wikimedia.org/wiki/File:K%C3%B6fteler.jpg', license: 'CC BY-SA 4.0',
    licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/', artist: 'Wikimedia Commons contributor',
  },
  'makarna-1': {
    provider: 'Wikimedia Commons', source: 'wikimedia', title: 'Baked macaroni and cheese',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/c/cc/Baked_macaroni_and_cheese.jpg',
    page: 'https://commons.wikimedia.org/wiki/File:Baked_macaroni_and_cheese.jpg', license: 'CC BY 2.0',
    licenseUrl: 'https://creativecommons.org/licenses/by/2.0/', artist: 'Wikimedia Commons contributor',
  },
  'makarna-2': {
    provider: 'Wikimedia Commons', source: 'wikimedia', title: 'Baked macaroni and cheese close-up',
    imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/8/85/Baked_macaroni_and_cheese_close-up.jpg',
    page: 'https://commons.wikimedia.org/wiki/File:Baked_macaroni_and_cheese_close-up.jpg', license: 'CC BY 2.0',
    licenseUrl: 'https://creativecommons.org/licenses/by/2.0/', artist: 'Wikimedia Commons contributor',
  },
};

const manifest = recipes.map(recipe => {
  const choices = picks[recipe.name];
  if (!choices || choices.length !== 2) throw new Error(`Eksik seçim: ${recipe.name}`);
  const pool = byName.get(recipe.name) || [];
  const images = choices.map(choice => {
    const image = typeof choice === 'number' ? pool[choice] : manual[choice];
    if (!image) throw new Error(`Geçersiz seçim: ${recipe.name} / ${choice}`);
    return { ...image };
  });
  return { name: recipe.name, images };
});

const output = path.join(__dirname, '..', 'build', 'new-turkish-recipe-image-manifest.json');
fs.writeFileSync(output, JSON.stringify(manifest, null, 2) + '\n');
console.log(`Manifest: ${manifest.length} tarif / ${manifest.reduce((sum, item) => sum + item.images.length, 0)} görsel`);
console.log(output);
