#!/bin/bash
# Generate Table 1 from the paper.
# Run this script from the root of the repository:
#   bash scripts/generate_tables.sh

set -e

OUTPUT="scripts/table/Table1.tex"

echo "Step 1: Processing Biesinger results..."
awk -v format=tex -f scripts/table/Biesinger.awk results/Biesinger/*.out > results/Biesinger_summary.out

echo "Step 2: Merging EA results from Biesinger et al. (2016)..."
python3 scripts/table/merge_Biesinger.py

echo "Done. Table 1 LaTeX source written to: $OUTPUT"
