# 🌌 Astrometry.net için GAIA Verisinden Index Dosyası Üretimi  

Bu rehberde, GAIA katalog verilerini kullanarak astrometry.net çözümleyici için özelleştirilmiş index dosyalarının nasıl üretileceği adım adım açıklanmaktadır.

---

## 🔹 1. GAIA Verisini Sorgulama ve İndirme (TAP / ADQL)

Aşağıdaki ADQL sorgusu, belirli bir gökyüzü bölgesinde yer alan 10.000 kaynağı çeker. Örneğin RA = 220.2420, Dec = +14.6736 merkezli, 1 derece yarıçaplı bir bölge:

```sql
SELECT TOP 10000 
    gaia_source.ra,
    gaia_source.ra_error,
    gaia_source.dec,
    gaia_source.dec_error,
    gaia_source.pmra,
    gaia_source.pmra_error,
    gaia_source.pmdec,
    gaia_source.pmdec_error,
    gaia_source.phot_g_mean_mag,
    DISTANCE(
        POINT('ICRS', gaiadr3.gaia_source.ra, gaiadr3.gaia_source.dec),
        POINT('ICRS', 220.24166666666667, 14.67361111111111)
    ) AS target_separation_deg
FROM gaiadr3.gaia_source
WHERE CONTAINS(
    POINT('ICRS', gaiadr3.gaia_source.ra, gaiadr3.gaia_source.dec),
    CIRCLE('ICRS', 220.24166666666667, 14.67361111111111, 1)
) = 1
ORDER BY target_separation_deg
```

### 📥 Çıktıyı indirme:

- Format: `FITS`
- Örnek dosya adı: `output_cat/1750766772370O-result.fits`

---

## 🔹 2. HEALPix Bölütleme (`hpsplit` ile)

Astrometry.net için index üretiminde kullanılacak yıldız tablosunu, HEALPix yapısına bölmek gerekir. Bu işlem için `hpsplit` aracı kullanılır:

```bash
mkdir -p gaia_hp

hpsplit \
  -o gaia_hp/gaia-hp%02i.fits \
  -n 2 -m 1 \
  output_cat/1750766772370O-result.fits
```

### Parametre Açıklamaları:

| Parametre | Anlamı |
|-----------|--------|
| `-o`      | Çıktı dosya adı şablonu (HEALPix numarasıyla) |
| `-n 2`    | NSIDE = 2 → toplam 48 HEALPix hücresi |
| `-m 1`    | HEALPix seviye 1 alt hücrelere bölme işlemi |
| `%02i`    | İki basamaklı healpix ID → örn. `gaia-hp08.fits` |

> Bu işlem sonucunda `gaia_hp/` klasöründe `gaia-hp00.fits`, `gaia-hp01.fits`, ... gibi dosyalar oluşur. Örneğimizde yalnızca `gaia-hp08.fits` oluşmuş olabilir.

---

## 🔹 3. Index Dosyalarını Üretme (`build-astrometry-index`)

Artık her bir HEALPix dosyasından farklı çözünürlüklerde astrometry index dosyaları oluşturabiliriz.

```bash
mkdir -p output_index

for scale in 0 2 4 6; do
    SS=$(printf "%02i" $scale)
    build-astrometry-index \
      -i gaia_hp/gaia-hp08.fits \
      -s 2 \
      -H 8 \
      -P $scale \
      -E \
      -S phot_g_mean_mag \
      -o output_index/index-550${SS}-08.fits \
      -I 550${SS}08
done
```

### Parametre Açıklamaları:

| Parametre                     | Anlamı |
|-------------------------------|--------|
| `-i`                          | Giriş FITS dosyası |
| `-s 2`                        | HEALPix NSIDE = 2 |
| `-H 8`                        | HEALPix ID = 08 |
| `-P 0/2/4/6`                  | Quad çözünürlük ölçeği |
| `-E`                          | Giriş kataloğundaki dolu HEALPix’leri tarar |
| `-S phot_g_mean_mag`         | Parlaklığa göre sıralama (küçük G mag önce) |
| `-o`                          | Çıktı index dosyası adı |
| `-I`                          | Index ID (benzersiz olmalı) |

### `-P` Ölçek Tablosu:

| `-P` Değeri | Tahmini Görüntü Çapı | Uygun Görüntü Türü       |
|-------------|----------------------|---------------------------|
| `0`         | ~6 arcmin            | Küçük CCD'ler             |
| `2`         | ~12 arcmin           | Orta alan                 |
| `4`         | ~24 arcmin           | Geniş alan CCD'ler        |
| `6`         | ~1 derece            | Survey teleskopları       |

---

## 🔹 4. Çözümlemeyi Test Etme (`solve-field`)

Üretilen index dosyalarını kullanarak çözümleme yapabilirsiniz:

```bash
solve-field \
  --index-xyls output_index/index-55000-08.fits \
  --ra 220.2420 --dec 14.6736 --radius 0.5 \
  /path/to/image.fits
```

> Alternatif olarak çözümlemeyi `.xyls` veya `.axy` dosyası ile de başlatabilirsiniz.

---

## ✅ Özet Akış

1. 📡 GAIA TAP servisi ile hedef bölgeden yıldızlar sorgulanır (ADQL)
2. 🧩 `hpsplit` ile katalog HEALPix yapısına bölünür
3. ⚙️ `build-astrometry-index` ile quad tabanlı index dosyaları oluşturulur
4. 🔭 `solve-field` komutu ile çözümleme gerçekleştirilir

---

## 📌 Ek Notlar

- Daha geniş gökyüzü alanları için `NSIDE=1`, `NSIDE=4` gibi değerler denenebilir.
- `SExtractor` ile özel kaynak çıkarımı yapılabilir: `solve-field --use-sextractor`
- Quad üretim başarısı düşükse, `-B`, `-n`, `-f` gibi parametrelerle deney yapılabilir.
