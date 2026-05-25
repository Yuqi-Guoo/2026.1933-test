#!/bin/bash
# Generate Figures 1-4 (performance profiles) from the paper.
# Run this script from the root of the repository:
#   bash scripts/generate_plots.sh
#
# Prerequisites: awk, Python 3 with matplotlib (for scripts/plot/plot.ipynb)
#
# Output: .stat files in scripts/plot/, and .eps figures in scripts/plot/eps/
# The final PDF versions of Figures 1-4 are already available in results/figures/.

set -e

echo "Step 1: Generating .stat files for performance profiles..."
bash scripts/plot/plot_mnpr.sh

echo ""
echo "Step 2: Running scripts/plot/plot.ipynb to generate .eps and .png figures..."
cd scripts/plot && python3 -m nbconvert --to notebook --execute plot.ipynb --output plot_executed.ipynb && rm -f plot_executed.ipynb && cd ../..
echo "  Figures saved to scripts/plot/eps/ (EPS) and scripts/plot/png/ (PNG):"
echo "    time_m_{500,800,1000}.eps  time_m_{500,800,1000}.png (Figure 1, grouped by m)"
echo "    time_n_{500,800,1000}.eps  time_n_{500,800,1000}.png (Figure 2, grouped by n)"
echo "    time_p_{2,5,10,50}.eps     time_p_{2,5,10,50}.png    (Figure 3, grouped by p)"
echo "    time_r_{2,5,10,50}.eps     time_r_{2,5,10,50}.png    (Figure 4, grouped by r)"
echo ""
echo "The PDF versions included in results/figures/ were generated from these .eps files."
