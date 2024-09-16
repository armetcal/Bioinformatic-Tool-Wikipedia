# Network Analysis Tools

The information provided below is derived from **Liu et. al (2021)** unless
otherwise noted (DOI: 10.1093/bib/bbaa005).

Network analysis tools are designed to identify pairwise relationships between
features. There are two common quantitative approaches:

| Approach                 | Common Algorithms               | Use                                                                                                                                                                      |
|--------------------------|---------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| (Dis) similarity indices | Br ay-Curtis, Kullba ck-Leibler | Differences in two taxa over multiple samples. Anything that significantly interacts is used as a link to build the network.                                             |
| C orrelation matrices    | Pearson, Spearman               | Positive correlations can imply cross-feeding or co-aggregation between microbial taxa, while negative correlations can imply mutual exclusion or niche differentiation. |

## Limitations

Network tools that identify paired associations are broadly susceptible to the
following limitations:

-   **Compositional bias** (ex. microbiome): with relative abundance, as one
    taxon goes up, all others are perceived to go down even if no changes occur.

-   **Direct vs. indirect associations** cannot be discerned. For example, two
    taxa that independently rely on a third taxon will appear to be connected.

-   **Data sparsity**: unclear whether zeros indicate total absence or
    abundances under the detection limit. Especially relevant when read counts
    are low. This is particularly relevant with metrics such as Bray-Curtis
    which rely on presence/absence.

## Included Tools:

The tools included in this sub-repo are based on those covered in Liu et. al's
2021 review paper: 10.1093/bib/bbaa005. I strongly recommend reading this paper
for a full understanding of how to properly apply network analyses.

SpiecEasi is also included due to its use in my paper, Metcalfe-Roach et. al
(2024).

+--------------+--------------+--------------+--------------+--------------+
| Tool         | Type         | General      | R esistant   | Other Con    |
|              |              | Approach     | to Comp      | siderations  |
|              |              |              | Bias?        |              |
+==============+==============+==============+==============+==============+
| CCLasso      | Co rrelation | L1-norm      | YY           |              |
|              |              | shrinkage,   |              |              |
|              |              | loss         |              |              |
|              |              | function for |              |              |
|              |              | data noise   |              |              |
|              |              | (better for  |              |              |
|              |              | comp bias),  |              |              |
|              |              | otherwise    |              |              |
|              |              | similar to   |              |              |
|              |              | SparCC       |              |              |
+--------------+--------------+--------------+--------------+--------------+
| SparCC       | Co rrelation | Iterative    | Y            | High co      |
|              |              | app          |              | mputational  |
|              |              | roximation,  |              | load (slow)  |
|              |              | l og-        |              |              |
|              |              | transformed  |              |              |
|              |              | co           |              |              |
|              |              | mpositional  |              |              |
|              |              | data         |              |              |
+--------------+--------------+--------------+--------------+--------------+
| REBACCA      | Co rrelation | L1-norm      | Y            |              |
|              |              | shrinkage    |              |              |
+--------------+--------------+--------------+--------------+--------------+
| SpiecEasi    | Co rrelation |              |              |              |
+--------------+--------------+--------------+--------------+--------------+
| Partial      | Co rrelation |              |              | Can better   |
| Correlation  |              |              |              | identify     |
| Approach     |              |              |              | direct re    |
|              |              |              |              | lationships  |
|              |              |              |              |              |
|              |              |              |              | Fails when n |
|              |              |              |              | \<\< number  |
|              |              |              |              | of taxa      |
+--------------+--------------+--------------+--------------+--------------+
| Ensemble     | (Dis)s       | Combined     |              | Designed to  |
| Approach     | imilarity    | score from 4 |              | address      |
|              |              | metrics: B   |              | sparsity     |
|              |              | ray-Curtis,  |              | problems     |
|              |              | Kul lba      |              |              |
|              |              | ck-Leibler,  |              |              |
|              |              | Pearson,     |              |              |
|              |              | Spearman     |              |              |
+--------------+--------------+--------------+--------------+--------------+
