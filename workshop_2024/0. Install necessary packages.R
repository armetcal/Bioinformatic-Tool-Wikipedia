# PACKAGES REQUIRED FOR 2024 METAGENOMICS WORKSHOP
# Please run the following prior to running the scripts in the workshop.
# Installing all the following packages may take 30-60 minutes.

## NOTES:

# 1. If R tells you that some of the packages are already loaded and that restarting R is highly recommended prior to installation, feel free to restart R by pressing the button (do not close the program manually).

# 2. If R asks you to update packages, feel free to do so. Please note that updating packages may impact code that you have written in the past that used previous versions of the package (though this is usually manageable).

# 3. If R tells you that there is a version error (ex. 'version >=5 is required, but version 4 is installed'), manually uninstall the problematic package and reinstall. This may be necessary for multiple packages.


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~``

# General data wrangling and visualization
install.packages('tidyverse')

# Data wrangling of sequencing data 
install.packages('phyloseq')

# Diversity metrics
install.packages('vegan')

# Summarize model statistics into a nice table
install.packages("broom")

# Helpful microbiome analysis functions that aren't in phyloseq, including core microbiome
library(BiocManager)
BiocManager::install("microbiome")

# Venn diagram functions for core microbiome
install.packages("ggVennDiagram")

# Add statistics and extra formatting to plots
install.packages('ggpubr')

# Run ANCOM-BC differential abundance tool
if (!require("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

BiocManager::install("ANCOMBC")

