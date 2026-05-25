# Scripts

This directory contains scripts for processing computational results and generating the tables and figures in the paper.

## Structure

- `table/` — scripts for generating Table 1 (main computational results on Biesinger instances)
- `plot/` — scripts and data for generating Figures 1–4 (performance profiles on Qi instances)
- `visualization/` — scripts for generating Figures 6–7 (facility location visualization, online supplement)

## Generating Table 1

Run the following command from the root of the repository:

```bash
bash scripts/generate_tables.sh
```

The final output is written to `scripts/table/Table1.tex`.

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
