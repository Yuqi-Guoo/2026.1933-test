# Biesinger Instances

This folder contains the instance `111_n100_std` from Biesinger et al. (2016), downloaded from https://www.ac.tuwien.ac.at/research/problem-instances.

In these instances, customer locations and potential facility locations are identical, randomly chosen on a [0,100]×[0,100] Euclidean plane. The attractiveness parameter is set to v_ij = 1/(d_ij+1), where d_ij is the Euclidean distance between customer i and facility j. Customer demands are chosen uniformly at random from {1,...,10}.

The instance used in the paper has m = n = 100, tested with p ∈ {2,...,10} and r ∈ {2,...,5} (36 combinations).

## File Format

```
<instance name>
<n> points: facilities and clients

Coordinates of points in Euclidean plane and weight
    x       y       w

<index>   <x>   <y>   <w>
...
```

- `n`: number of points (= number of customers = number of candidate facility sites)
- `x`, `y`: coordinates in the Euclidean plane
- `w`: customer demand (weight)

## Reference

> **Biesinger B, Hu B, Raidl G (2016)** A hybrid genetic algorithm with solution archive for the discrete (r|p)-centroid problem. J. Heuristics 22(3):391–431.
