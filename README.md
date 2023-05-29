# Hybrid Nuclear Genome Assembly

This is a description of the pipeline I've used to assemble nuclear genomes from blackflies and a collection of the commands for doing so.

## Overview of pipeline

![image](https://github.com/hendricksonen/flyawayhome/assets/113100255/3bed643a-8ed0-4ea4-b3b6-25042d1c9852)


## You will need:

- Oxford Nanopore Technologies long-read data (GridION/MinION)
- Illumina shotgun sequencing short-read data
- [EPI2ME](https://labs.epi2me.io/installation/) 
- Access to a [Galaxy Project server](https://usegalaxy.org.au/) and an account
- Access to a HPC cluster with the following modules:
  - Minimap2
  - Trimmomatic

### Trimming ONT long reads
Because ONT reads are separated into multiple files, the first step is concatenating all fastq_pass reads into one file.

      cat ~/fastq_pass/*fastq.gz > catSeq.fastq.gz 
      
Upload concatenated reads to Galaxy Server.

Run Porechop using default parameters and concatenated read file as input.
