#!/bin/bash
# build-index.sh
# Author: Yücel KILIÇ
# Description: Generate astrometry.net index files from GAIA HEALPix patches.

# ---------------- Default Values -----------------
INPUT_DIR="gaia_hp"
OUTPUT_DIR="output_index"
HP_ID=08
NSIDE=2
SERIES=550
SCALES=(0 2 4 6)
SORT_COLUMN="phot_g_mean_mag"
# --------------------------------------------------

usage() {
    echo "Usage: $0 [-i input_dir] [-o output_dir] [-h healpix_id] [-s nside] [-p series] [-l scale_list]"
    echo ""
    echo "Options:"
    echo "  -i DIR       Input directory containing gaia-hpXX.fits (default: gaia_hp)"
    echo "  -o DIR       Output directory for index files (default: output_index)"
    echo "  -h ID        HEALPix ID (e.g. 08)"
    echo "  -s NSIDE     HEALPix NSIDE value (default: 2)"
    echo "  -p SERIES    Index series number (default: 550)"
    echo "  -l LIST      List of -P scale values separated by commas (e.g. 0,2,4,6)"
    echo "  -?           Show this help message"
    exit 1
}

# ---------- Parse command-line arguments ----------
while getopts "i:o:h:s:p:l:?" opt; do
    case $opt in
        i) INPUT_DIR="$OPTARG";;
        o) OUTPUT_DIR="$OPTARG";;
        h) HP_ID="$OPTARG";;
        s) NSIDE="$OPTARG";;
        p) SERIES="$OPTARG";;
        l) IFS=',' read -r -a SCALES <<< "$OPTARG";;
        ?) usage;;
        *) usage;;
    esac
done

# ----------- Script Start ----------------
mkdir -p "$OUTPUT_DIR"
HP_PADDED=$(printf "%02d" $HP_ID)

echo "🔧 Building indexes from $INPUT_DIR/gaia-hp${HP_PADDED}.fits"
echo "📦 Output folder: $OUTPUT_DIR"
echo "🧮 NSIDE: $NSIDE | HEALPix ID: $HP_ID | Series: $SERIES"
echo "📐 Scales: ${SCALES[*]}"
echo ""

for SCALE in "${SCALES[@]}"; do
    SCALE_PADDED=$(printf "%02d" $SCALE)
    echo "➡️  Generating index for HP=$HP_ID, Scale=-P $SCALE..."

    build-astrometry-index \
      -i "${INPUT_DIR}/gaia-hp${HP_PADDED}.fits" \
      -s "$NSIDE" \
      -H "$HP_ID" \
      -P "$SCALE" \
      -E \
      -S "$SORT_COLUMN" \
      -o "${OUTPUT_DIR}/index-${SERIES}${SCALE_PADDED}-${HP_PADDED}.fits" \
      -I "${SERIES}${SCALE_PADDED}${HP_PADDED}"

    if [ $? -eq 0 ]; then
        echo "✅ index-${SERIES}${SCALE_PADDED}-${HP_PADDED}.fits created."
    else
        echo "❌ Failed for Scale=$SCALE"
    fi
done

echo "🎉 All done!"
