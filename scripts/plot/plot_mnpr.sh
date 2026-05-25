#!/bin/bash
# Generate .stat files for performance profiles from results/Qi/.
# Run from the root of the repository:
#   bash scripts/plot/plot_mnpr.sh

set -e

resultsdir=Qi
column=time

mkdir -p results/${resultsdir}-test
mkdir -p scripts/plot/stat

for m in 500 800 1000; do
    ls results/$resultsdir/instance_${m}_*.out >results/$resultsdir-test/m_${m}.test
    awk -v format=plain -v mode=plot -f scripts/plot/Qi.awk $(cat results/$resultsdir-test/m_${m}.test) >scripts/plot/stat/${column}_m_${m}.stat
done

for n in 500 800 1000; do
    ls results/$resultsdir/instance_*_${n}-*.out >results/$resultsdir-test/n_${n}.test
    awk -v format=plain -v mode=plot -f scripts/plot/Qi.awk $(cat results/$resultsdir-test/n_${n}.test) >scripts/plot/stat/${column}_n_${n}.stat
done

for p in 2 5 10 50; do
    ls results/$resultsdir/instance*-${p}-*.out >results/$resultsdir-test/p_${p}.test
    awk -v format=plain -v mode=plot -f scripts/plot/Qi.awk $(cat results/$resultsdir-test/p_${p}.test) >scripts/plot/stat/${column}_p_${p}.stat
done

for r in 2 5 10 50; do
    ls results/$resultsdir/instance*-${r}.out >results/$resultsdir-test/r_${r}.test
    awk -v format=plain -v mode=plot -f scripts/plot/Qi.awk $(cat results/$resultsdir-test/r_${r}.test) >scripts/plot/stat/${column}_r_${r}.stat
done
