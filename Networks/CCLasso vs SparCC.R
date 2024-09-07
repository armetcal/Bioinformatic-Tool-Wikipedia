# CCLasso vs SparCC
# Last Updated: 6 Sept 2024

# Here are the CCLasso and SparCC functions: https://github.com/huayingfang/CCLasso
# And the paper that compares the methods: https://academic.oup.com/bioinformatics/article/31/19/3172/211784
# There is no package - we just have to download the functions and then source them so they can be used.
# download.file('https://raw.githubusercontent.com/huayingfang/CCLasso/master/R/SparCC.R',
#               'Networks/SparCC_function.R')
# download.file('https://raw.githubusercontent.com/huayingfang/CCLasso/master/R/cclasso.R',
#               'Networks/CCLasso_function.R')

library(tidyverse)
library(gtools)
library(ggpubr)
library(pheatmap)
library(gridExtra)

source("Networks/CCLasso_function.R")
source("Networks/SparCC_function.R")

# Filter OTUs:
# less than 2 reads per sample on average
# OR
# more than 60% 0s.
filter_otus = function(data, cols_are_otus = T, min_reads = 2, min_prev = 0.6){
  # data = df; cols_are_otus = T; min_reads = 2; min_prev = 0.6
  if(cols_are_otus==F){
    data = t(data) %>% as.data.frame()
  }
  data = data[,colMeans(data) >= min_reads]
  pct = (data > 0) %>% colSums()
  data = data[,pct/nrow(data) > min_prev]
  if(cols_are_otus==F){
    data = t(data) %>% as.data.frame()
  }
  return(data)
}

# Load example data
df = read.csv('Networks/sample_otus_genus.csv',row.names = 1) %>% t() %>% as.data.frame() %>% filter_otus() # PD taxonomy dataset
ctrl = read.csv('Networks/sample_log_normal_data.csv',row.names = 1) %>% filter_otus() # ctrl <- matrix(rnorm(n * p), nrow = n), multiplied to a random normal count from 1000-2000. Should contain no true correlations.

# Convert to compositional for sake of comparison
# This should not be done for compositional data
# dffrac = apply(df,1,function(x)x/sum(x)) %>% t() # Each sample sums to 1
ctrlfrac = apply(ctrl,1,function(x)x/sum(x)) %>% t() %>% as.data.frame() # Each sample sums to 1

# 2. run cclasso 
cclasso_count_df <- cclasso(x = df, counts = T) # using counts
cclasso_count_ctrl <- cclasso(x = ctrl, counts = T) # using counts
cclasso_frac_ctrl <- cclasso(x = ctrlfrac, counts = F) # using fraction

# 3. run SparCC.count and SparCC.frac
sparcc_count_df <- SparCC.count(x = df)
sparcc_count_ctrl <- SparCC.count(x = ctrl)
sparcc_frac_ctrl <- SparCC.frac(x = ctrlfrac)

# 4. get the correlation matrices

mat_cclasso_count_df = cclasso_count_df$cor_w %>% `colnames<-`(colnames(df)) %>% `rownames<-`(colnames(df))
mat_cclasso_count_ctrl = cclasso_count_ctrl$cor_w %>% `colnames<-`(colnames(ctrl)) %>% `rownames<-`(colnames(ctrl))
mat_cclasso_frac_ctrl = cclasso_frac_ctrl$cor_w %>% `colnames<-`(colnames(ctrl)) %>% `rownames<-`(colnames(ctrl))

mat_sparcc_count_df = sparcc_count_df$cor.w %>% `colnames<-`(colnames(df)) %>% `rownames<-`(colnames(df))
mat_sparcc_count_ctrl = sparcc_count_ctrl$cor.w %>% `colnames<-`(colnames(ctrl)) %>% `rownames<-`(colnames(ctrl))
mat_sparcc_frac_ctrl = sparcc_frac_ctrl$cor.w %>% `colnames<-`(colnames(ctrl)) %>% `rownames<-`(colnames(ctrl))

# 5. Print the correlation matrices

p1 = pheatmap::pheatmap(mat_cclasso_count_df, main = "CCLasso - Data - Count", legend = TRUE, show_colnames = F, show_rownames = F, treeheight_row=0, treeheight_col = 0)
p2 = pheatmap::pheatmap(mat_cclasso_count_ctrl, main = "CCLasso - Ctrl - Count", legend = TRUE, show_colnames = F, show_rownames = F, treeheight_row=0, treeheight_col = 0)
p3 = pheatmap::pheatmap(mat_cclasso_frac_ctrl, main = "CCLasso - Ctrl - Fraction", legend = TRUE, show_colnames = F, show_rownames = F, treeheight_row=0, treeheight_col = 0)

p4 = pheatmap::pheatmap(mat_sparcc_count_df, main = "SparCC - Data - Count", legend = TRUE, show_colnames = F, show_rownames = F, treeheight_row=0, treeheight_col = 0)
p5 = pheatmap::pheatmap(mat_sparcc_count_ctrl, main = "SparCC - Ctrl - Count", legend = TRUE, show_colnames = F, show_rownames = F, treeheight_row=0, treeheight_col = 0)
p6 = pheatmap::pheatmap(mat_sparcc_frac_ctrl, main = "SparCC - Ctrl - Fraction", legend = TRUE, show_colnames = F, show_rownames = F, treeheight_row=0, treeheight_col = 0)


# The CCLasso algorithm does an obviously better job in limiting spurious correlations. In the control datasets, all correlations are zero except for the diagonal, whereas a few correlations are noted in SparCC.
# In the real data, the existing clusters look somewhat better defined.
grid.arrange(grobs = list(p1[[4]], p2[[4]], p3[[4]], p4[[4]], p5[[4]], p6[[4]]), nrow=2, ncol=3)

# Let's look at the real data heatmaps so that we can see the clusters better.
p11 = pheatmap::pheatmap(mat_cclasso_count_df, 
                         main = "CCLasso", legend = TRUE, 
                         show_colnames = T,
                         treeheight_row = 0, treeheight_col = 5)
p44 = pheatmap::pheatmap(mat_sparcc_count_df, 
                         main = "SparCC", legend = TRUE, 
                         show_colnames = T,
                         treeheight_row = 0, treeheight_col = 5)

grid.arrange(grobs = list(p11[[4]], p44[[4]]), ncol=2)

# Now let's add the P values to the plot. This only is available for CCLasso.
cclasso_count_df_pval = cclasso_count_df$p_vals 
cclasso_count_df_pval[cclasso_count_df_pval<0.05] = '\U273B'
cclasso_count_df_pval[cclasso_count_df_pval!='\U273B'] = ''

p111 = pheatmap::pheatmap(mat_cclasso_count_df, 
                         main = "CCLasso", legend = TRUE, 
                         show_colnames = T, show_rownames = T,
                         treeheight_row = 0, treeheight_col = 5, 
                         display_numbers = cclasso_count_df_pval,
                         fontsize_number = 10)
p444 = pheatmap::pheatmap(mat_sparcc_count_df, 
                         main = "SparCC", legend = TRUE, 
                         show_colnames = T, show_rownames = T,
                         treeheight_row = 0, treeheight_col = 5)

grid.arrange(grobs = list(p111[[4]], p444[[4]]), ncol=2)