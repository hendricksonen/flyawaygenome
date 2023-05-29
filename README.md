# Hybrid nuclear genome assembly

This is a description of the pipeline I've used to assemble nuclear genomes from blackflies and a collection of the commands for doing so.

## You will need:

- Oxford Nanopore Technologies long-reads
- Illumina shotgun sequencing short-reads
- [EPI2ME](https://labs.epi2me.io/installation/) 
- Access to a [Galaxy Project server](https://usegalaxy.org.au/) and an account
- Access to a HPC cluster with the following modules:
  - Minimap2
  - Trimmomatic
