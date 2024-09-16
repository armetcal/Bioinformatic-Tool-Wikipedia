library(phyloseq)
otu = readRDS('C:/Users/armetcal/OneDrive - UBC/Grad School/Data/HUMAN COHORT/Metcalfe-Roach_PD_Micro_2024/Reference Files/taxonomy_phyloseq.rds') %>% tax_glom('Family') %>% subset_samples(Status=='Ctrl') %>% .@otu_table %>% as.data.frame

rownames(otu) = sapply(rownames(otu), function(x) x %>% str_split('-g__') %>% .[[1]] %>% .[1])

rownames(otu) = sapply(rownames(otu), function(x) x %>% str_split('-f__') %>% .[[1]] %>% .[2])

s = sample(x = c(1:ncol(otu)),size=100)
otu = otu[,s]
colnames(otu) = paste('Sample_',c(1:ncol(otu)),sep='')

write.csv(otu,'Networks/sample_otus_family.csv',row.names = T)
