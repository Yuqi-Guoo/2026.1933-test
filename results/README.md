# Results

This directory contains the computational results reported in the paper.

## Structure

| Folder | Description |
| :--- | :--- |
| `Biesinger/` | Results on the small-scale Biesinger instances (Section 7.1, Table 1) |
| `Qi/` | Results on the Qi instances (Section 7.2, Figures 1–4) |
| `visualization/` | Results for the visualization figures (online supplement, Figures 6–7) |
| `figures/` | Figures included in the paper (Section 7.2 and online supplement) |

## Algorithm Name Mapping

The filenames use internal algorithm names that differ from the paper notation. The correspondence is:

| Filename | Paper Notation | Description |
| :--- | :--- | :--- |
| `OldSubmodular` | B&C+SF | B&C algorithm based on the classic submodular formulation (SF) |
| `NewSubmodular` | B&C+GSF | B&C algorithm based on the generalized submodular formulation (GSF) |
| `ZLP` | B&C+EF | B&C algorithm based on the extended formulation (EF) |

## Output File Naming Convention

Files in `Biesinger/` and `Qi/` follow:

```
<instance>-<algorithm>-<m>-<n>-<p>-<r>.out
```

Files in `visualization/` include an additional `beta` parameter:

```
<instance>-<algorithm>-<m>-<n>-<p>-<r>-<beta>.out
```

- `instance`: name of the data instance (without file extension)
- `algorithm`: internal algorithm name (see mapping above)
- `m`: number of demand points
- `n`: number of candidate facility sites
- `p`: number of facilities opened by the leader
- `r`: number of facilities opened by the follower
- `beta`: the sensitivity of the customer to the distance: $u_{ij} = \exp(-beta \cdot d_{ij})$ under PBL rule, where $d_{ij}$ is the distance between customer $i$ and facility $j$ 

For example, `111_n100_std-NewSubmodular-100-100-2-2.out` in `Biesinger/` is the result of running B&C+GSF on the Biesinger instance with m=100, n=100, p=2, r=2.

Similarly, `instance_500_800-ZLP-500-800-2-5.out` in `Qi/` is the result of running B&C+EF on the Qi instance with m=500, n=800, p=2, r=5.

And `111_n100_std-ZLP-100-100-2-2-0.1.out` in `visualization/` is the result of running B&C+EF on the Biesinger instance with m=100, n=100, p=2, r=2, beta=0.1.
