[![INFORMS Journal on Computing Logo](https://INFORMSJoC.github.io/logos/INFORMS_Journal_on_Computing_Header.jpg)](https://pubsonline.informs.org/journal/ijoc)

# An Efficient Branch-and-Cut Approach for the Sequential Competitive Facility Location Problem under Partially Binary Rule

This archive is distributed in association with the [INFORMS Journal on Computing](https://pubsonline.informs.org/journal/ijoc) under the [MIT License](LICENSE).

The software and data in this repository are a snapshot of the software and data that were used in the research reported on in the paper [An Efficient Branch-and-Cut Approach for the Sequential Competitive Facility Location Problem under Partially Binary Rule](https://doi.org/10.1287/ijoc.2026.1933) by Yu-Qi Guo, Yan-Ru Wang, Wei-Kun Chen, and Yu-Hong Dai.

## Cite

To cite the contents of this repository, please cite both the paper and this repo, using their respective DOIs.

https://doi.org/10.1287/ijoc.2026.1933

https://doi.org/10.1287/ijoc.2026.1933.cd

Below is the BibTex for citing this snapshot of the repository.

```
@misc{GuoWangChenDai2026,
  author =        {Yu-Qi Guo, Yan-Ru Wang, Wei-Kun Chen, and Yu-Hong Dai},
  publisher =     {INFORMS Journal on Computing},
  title =         {An Efficient Branch-and-Cut Approach for the Sequential Competitive Facility Location Problem under Partially Binary Rule},
  year =          {2026},
  doi =           {10.1287/ijoc.2026.1933.cd},
  url =           {https://github.com/INFORMSJoC/2026.1933},
  note =          {Available for download at https://github.com/INFORMSJoC/2026.1933},
}
```

## Description

This repository provides data for the problem and source code for the proposed approaches. The main folders are [src](src), [data](data), [results](results), and [scripts](scripts).

- [src](src): this folder contains the source code for the proposed approaches.
- [data](data): this folder contains the data used in the paper.
- [results](results):  this folder contains all logfiles and figures produced by the computational experiments.
- [scripts](scripts): this folder contains shell, AWK, and Python scripts used to generate the tables and figures in the paper.

## Installation and Setup

To run this code and reproduce the results presented in the paper, you must install:

- [Julia 1.10.3](https://julialang.org) with the packages listed in [src/startup.jl](src/startup.jl)
- [CPLEX 20.1.0](https://www.ibm.com/support/pages/downloading-ibm-ilog-cplex-optimization-studio-2010)
- [Python 3](https://www.python.org) with `pandas` (for `scripts/generate_tables.sh`), and `matplotlib`, `numpy`, `jupyter`, `nbconvert` (for `scripts/generate_plots.sh` and `scripts/generate_visualization.sh`)

## Usage

Example usage:

```bash
julia src/scflp.jl fn=data/Biesinger/111_n100_std p=2 r=3 data=Biesinger mode=NewSubmodular is_visualization=0 beta=0.1 solver=cplex timelimit=7200 gap=0.0 

```

Command-line argument descriptions:

- `src/scflp.jl`: main Julia file
- `fn`: path to the instance data file
- `p`: number of leader facilities to open
- `r`: number of follower facilities to open
- `data`: dataset format; options: `Qi`, `Biesinger`
- `mode`: formulation mode in B&C algorithm; options: `OldSubmodular` (`B&C+SF`), `NewSubmodular` (`B&C+GSF`), `ZLP` (`B&C+EF`)
- `is_visualization`: whether to print visualization information under partially binary logit (PBL) rule (default: `0`)
- `beta`: the sensitivity of the customer to the distance: $u_{ij} = exp(-beta * d_{ij})$ under PBL rule (default: `0.1`)
- `solver`: solver to use (default: `cplex`)
- `timelimit`: time limit in seconds (default: `7200`)
- `gap`: MIP optimality gap tolerance (default: `0.0`)

## Replicating

To reproduce the computational results presented in the paper, run the following scripts from the root of the repository.

**Table 1** (small-scale `Biesinger` instances):

```bash
bash scripts/generate_tables.sh
```

This processes the `.out` files in `results/Biesinger/` and writes the final `LaTeX` table to `scripts/table/Table1.tex`.

**Figures 1–4** (performance profiles on `Qi` instances):

```bash
bash scripts/generate_plots.sh
```

Figures are saved as `.eps` files in `scripts/plot/eps/` and as `.png` files in `scripts/plot/png/`.

**Figures 6–7** (visualization, online supplement):

```bash
bash scripts/generate_visualization.sh
```

Figures are saved as `.eps` files in `scripts/visualization/eps/` and as `.png` files in `scripts/visualization/png/`.

## Support

For questions about the paper or the code, submit an [issue](https://github.com/INFORMSJoC/2026.1933/issues/new) in this repository or contact the corresponding author.
