# 🌌 Creating Astrometry.net Index Files from GAIA Data  

This tutorial explains step by step how to generate custom index files for the astrometry.net solver using GAIA catalog data.

---

## 🔹 1. Querying and Downloading GAIA Data (TAP / ADQL)

Use the following ADQL query to retrieve 10,000 sources from a 1-degree radius sky region centered at RA = 220.2420, Dec = +14.6736.

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

### 📥 Output download:

- Format: `FITS`
- Example file: `input_cat/1750766772370O-result.fits`

---

## 🔹 2. Splitting the Catalog into HEALPix Tiles (`hpsplit`)

The star catalog must be split into HEALPix tiles to generate astrometry.net index files. Use the `hpsplit` tool:

```bash
mkdir -p gaia_hp

hpsplit \
  -o gaia_hp/gaia-hp%02i.fits \
  -n 2 -m 1 \
  input_cat/1750766772370O-result.fits
```

### Parameter Explanation:

| Parameter | Description |
|-----------|-------------|
| `-o`      | Output filename pattern (including HEALPix ID) |
| `-n 2`    | NSIDE = 2 → divides the sky into 48 HEALPix tiles |
| `-m 1`    | Use HEALPix level 1 |
| `%02i`    | Two-digit HEALPix ID, e.g. `gaia-hp08.fits` |

> After this step, the folder `gaia_hp/` will contain files like `gaia-hp00.fits`, `gaia-hp01.fits`, etc. (you may get only one file depending on the region covered).

---

## 🔹 3. Building Index Files (`build-astrometry-index`)

Now we generate astrometry index files at different quad scales using each HEALPix tile.

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

### Parameter Explanation:

| Parameter           | Description |
|---------------------|-------------|
| `-i`                | Input FITS catalog |
| `-s 2`              | HEALPix NSIDE = 2 |
| `-H 8`              | HEALPix tile ID (here '08' is used as an example — replace with the tile you are working on) |
| `-P`                | Quad scale index |
| `-E`                | Scan catalog for HEALPix occupancy |
| `-S phot_g_mean_mag` | Sort stars by brightness (G-band magnitude) |
| `-o`                | Output index filename |
| `-I`                | Unique index ID (must be unique across all files) |

### `-P` Scale Guide:

| `-P` Value | Approx. Field of View | Recommended For          |
|------------|------------------------|---------------------------|
| `0`        | ~6 arcmin              | Small CCDs                |
| `2`        | ~12 arcmin             | Medium field images       |
| `4`        | ~24 arcmin             | Wide-field CCDs           |
| `6`        | ~1 degree              | Survey instruments        |

---

## 🔹 4. Testing with `solve-field`

Once your index files are built, test them with astrometry.net:

```bash
solve-field \
  --index-xyls output_index/index-55000-08.fits \
  --ra 220.2420 --dec 14.6736 --radius 0.5 \
  /path/to/image.fits
```

> Alternatively, you may use `.xyls` or `.axy` input files.

---

## ✅ Summary Workflow

1. 📡 Query GAIA data from TAP service using ADQL  
2. 🧩 Split the catalog into HEALPix tiles with `hpsplit`  
3. ⚙️ Generate index files using `build-astrometry-index`  
4. 🔭 Use `solve-field` to test solution with your own data

---

## 📌 Notes

- For broader coverage, consider NSIDE = 1 or NSIDE = 4.  
- You can use your own source extractor (e.g. `sextractor`) with:  
  `solve-field --use-sextractor`  
- If quad generation fails, try tuning `-B`, `-n`, or `-f` parameters.
