# Scripts

This directory contains scripts for processing computational results and generating the tables and figures in the paper.

## Structure

- `table/` — scripts for generating Table 1 and the large-scale instance-wise results table
- `plot/` — scripts and data for generating Figures 1–4 (performance profiles on Qi instances)
- `visualization/` — scripts for generating Figures 6–7 (facility location visualization, online supplement)

## Generating **Table 1 and large-scale instance-wise results** (`Biesinger` and `Qi` instances):

Run the following command from the root of the repository:

```bash
bash scripts/generate_tables.sh
```

This runs three steps:
1. Processes `results/Biesinger/*.out` via `scripts/table/Biesinger.awk` and writes `results/Biesinger_summary.out`
2. Merges EA results from Biesinger et al. (2016) via `scripts/table/merge_Biesinger.py` and writes `scripts/table/Table1.tex`
3. Processes `results/Qi/*.out` via `scripts/plot/Qi.awk` and writes `scripts/table/table_Qi.tex` (a pre-generated CSV version is available at `results/table_Qi.csv`)

## Generating Figures 1–4 (performance profiles)

Run the following command from the root of the repository:

```bash
bash scripts/generate_plots.sh
```

Figures are saved as `.eps` files in `scripts/plot/eps/` and as `.png` files in `scripts/plot/png/`. The PDF versions are already available in `results/figures/`.

## Generating Figures 6–7 (visualization, online supplement)

Run the following command from the root of the repository:

```bash
bash scripts/generate_visualization.sh
```

Figures are saved as `.eps` files in `scripts/visualization/eps/` and as `.png` files in `scripts/visualization/png/`. The PDF versions are already available in `results/figures/visualization_p5.pdf` and `results/figures/visualization_r5.pdf`.
