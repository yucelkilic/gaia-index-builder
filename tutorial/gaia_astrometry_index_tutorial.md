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
### 🔹 4. Testing with `solve-field`

Once your index files are built, you can test them using [astrometry.net](http://astrometry.net)'s `solve-field` tool.

To make the index files accessible system-wide, copy them into Astrometry.net’s default index directory. This allows `solve-field` to find them automatically during image solving.

#### ✅ Step-by-step:

1. Copy all index files into the system directory:
   ```bash
   sudo cp output_index/index-*.fits /usr/share/astrometry
   ```

   > ⚠️ Note: The directory path may vary depending on your system. Common alternatives include:
   >
   > - `/usr/local/astrometry/data/`
   > - `/usr/share/astrometry/`
   > - `~/.astrometry/data/`

2. Run `solve-field` with your target image:
   ```bash
   solve-field \
     --ra 220.2420 --dec 14.6736 --radius 0.5 \
     /path/to/image.fits
   ```

#### 💡 Notes:

- You do not need to specify `--index` manually.
- `solve-field` will automatically search in the index directory.
- Ensure your index files cover the sky region near the image's RA/Dec.

---

## ✅ Summary Workflow

1. 📡 Query GAIA data from TAP service using ADQL  
2. 🧩 Split the catalog into HEALPix tiles with `hpsplit`  
3. ⚙️ Generate index files using `build-astrometry-index`  
4. 🔭 Use `solve-field` to test solution with your own data

---

### 📌 Notes

- For broader sky coverage, consider using `NSIDE = 1` (coarse) or `NSIDE = 4` (finer) depending on your catalog density.

- You can use your own source extractor (e.g. [SExtractor](https://www.astromatic.net/software/sextractor/)) when solving images:
  ```bash
  solve-field --use-sextractor /path/to/image.fits
  ```

- If quad generation fails or results in too few matches, consider tuning the following parameters in `build-astrometry-index`:

#### 🔧 `-B <val>` — Bright limit cutoff (magnitude filter)

- Excludes stars **brighter** than the given value (e.g., saturated sources).
- Useful when sorting by magnitude (e.g. `phot_g_mean_mag`).

```bash
-B 10
```
> Only stars with G > 10 mag will be used.

---

#### 🔧 `-n <sweeps>` — Stars per HEALPix grid cell

- Controls **how many stars are retained** in each small HEALPix partition.
- Higher = denser index = more quads but slower build.
- Lower = faster but may miss some quads.

```bash
-n 20
```
> Retains 20 stars per fine HEALPix cell.

---

#### 🔧 `-f` — Sort in descending order

- Changes the sort order of the input catalog based on the selected column (`-S`).
- Useful for magnitude: makes **brighter stars appear first**.

```bash
-S phot_g_mean_mag -f
```
> Sorts the catalog by G mag in descending order (brightest first).

---

> 💡 **Tip:** When using `-B` with `-f`, ensure your logic aligns (e.g. `-B 16 -f` = only stars brighter than G=16).
