#!/bin/bash
# Generate Table 1 and the instance-wise large-scale results table from the paper.
# Run this script from the root of the repository:
#   bash scripts/generate_tables.sh

set -e

OUTPUT="scripts/table/Table1.tex"
OUTPUT2="scripts/table/table_Qi.tex"

echo "Step 1: Processing Biesinger results..."
awk -v format=tex -f scripts/table/Biesinger.awk results/Biesinger/*.out > results/Biesinger_summary.out

echo "Step 2: Merging EA results from Biesinger et al. (2016)..."
python3 scripts/table/merge_Biesinger.py

echo "Step 3: Generating instance-wise large-scale results table (Qi instances)..."
awk -v format=tex -v mode=table -f scripts/plot/Qi.awk results/Qi/*.out > "$OUTPUT2"
echo "  Note: a pre-generated CSV version of this table is available at results/table_Qi.csv"

echo "Done. Table 1 LaTeX source written to: $OUTPUT"
echo "      Large-scale instance-wise table written to: $OUTPUT2"

