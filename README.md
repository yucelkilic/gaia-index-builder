# 🌌 GAIA Index Builder for Astrometry.net

This project explains and automates how to generate astrometry.net index files from GAIA catalog data. It includes tutorials, scripts, and examples.

## 📁 Structure

- `input_cat/`  
  Raw GAIA FITS catalog(s) downloaded from the ESA GAIA Archive using ADQL queries.

- `gaia_hp/`  
  Output of `hpsplit`: GAIA catalogs split into HEALPix tiles (e.g., `gaia-hp08.fits`).

- `output_index/`  
  Final index `.fits` files created using `build-astrometry-index` for different quad scales.

- `scripts/`  
  Bash scripts to automate the HEALPix splitting and index generation process  
  *(e.g., `build-index.sh` with support for custom HPID and scales)*.

- `tutorial/`  
  Markdown-based guides:  
  → `gaia_astrometry_index_tutorial.md`

- `examples/` *(optional)*  
  FITS images or WCS solutions for testing the generated index files.

- `README.md`  
  General description of the project.

- `LICENSE` *(optional)*  
  Open-source license file (e.g., MIT or GPLv3).
## 🛠 Requirements

- astrometry.net
- hpsplit
- Gaia catalog (FITS format)

## 📖 Read the Guide

See [`tutorial/gaia_astrometry_index_tutorial_en.md`](tutorial/gaia_astrometry_index_tutorial.md)
