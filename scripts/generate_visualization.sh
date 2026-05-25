#!/bin/bash
# Generate Figures 6-7 (visualization, online supplement) from the paper.
# Run this script from the root of the repository:
#   bash scripts/generate_visualization.sh
#
# Prerequisites: Python 3 with matplotlib, numpy
#
# Output: .eps figures in scripts/visualization/eps/
# The final PDF versions of Figures 6-7 are already available in results/figures/.

set -e

echo "Running scripts/visualization/visualization_plot_p_r.py to generate Figures 6-7..."
cd scripts/visualization && python3 visualization_plot_p_r.py && cd ../..
echo "  Figures saved to scripts/visualization/eps/ (EPS) and scripts/visualization/png/ (PNG):"
echo "    visualization_r5.eps    visualization_r5.png  (Figure 6, online supplement)"
echo "    visualization_p5.eps    visualization_p5.png  (Figure 7, online supplement)"
echo ""
echo "The PDF versions included in results/figures/ were generated from these .eps files."
