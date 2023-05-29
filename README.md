# Hybrid Nuclear Genome Assembly

This is a description of the pipeline I've used to assemble nuclear genomes from blackflies and a collection of the commands for doing so.


## Overview of pipeline


![image](https://github.com/hendricksonen/flyawayhome/assets/113100255/3bed643a-8ed0-4ea4-b3b6-25042d1c9852)


## You will need:


- Oxford Nanopore Technologies long-read data (GridION/MinION)
- Illumina shotgun sequencing short-read data
- [EPI2ME](https://labs.epi2me.io/installation/) 
- Access to a [Galaxy Project server](https://usegalaxy.org.au/) and an account. Will use these tools:
  - Porechop
  - seqtk
  - Flye
  - Racon
  - BUSCO
  - QUAST
  - Bowtie2
- Access to a HPC cluster with the following modules:
  - minimap2
  - Trimmomatic


##Pipeline Steps


### Trimming ONT long reads


Because ONT reads are separated into multiple files, the first step is concatenating all fastq_pass reads into one file.

      cat ~/fastq_pass/*fastq.gz > catReads.fq.gz 
      
Upload concatenated reads to Galaxy Server.

Run Porechop using default parameters (porechopONT) and concatenated read file as input. Save output as reads.trimmed.fq

Download Porechop output.


### Filtering out human and microbial contamination


For this, you will use EPI2ME, the ONT analysis software. This does require an ONT account.

In EPI2ME, start an analysis and select the reads.trimmed.fq file as input.

Choose 'FASTQ WIMP' as the analysis.

Change minimum length filter to 500. 

Accept & Start.

**Human and microbial reads will be "Classified" and all others will be "Unclassified"**

When completed, select 'View Report' and download CSV report.

From the CSV, 

     grep "Unclassified"  wimp.output | awk '{print $2}' > wimpReadIDs.txt
     
Upload wimpReadIDs.txt into Galaxy.

Use the tool seqtk to sort only unclassified reads uisng wimpReadIDs.txt as list of seqIDs and reads.trimmed.fq as query reads. 

Gzip the output if not zipped already (use tool 'compress') and name the output reads.trimmed.wimp.fq.gz and download.


### Filtering out other potential contaminant reads


For this step, you will filter out potential contaminant reads from other eukaryotes and organelle DNA. 

For blood-feeding orgnaisms like Simulium spp., filtering out reads from potential food sources is important. A study from [Lamberton et al. (2016)](https://parasitesandvectors.biomedcentral.com/articles/10.1186/s13071-016-1703-2) assessed the species on which blackflies were feeding by identifying the organism from which the fly had taken a blood meal. Using these results and information about the animals in the surrounding areas of Ethiopia, compile a folder of reference sequences that contain the following genomes: 

*note, this is most easily done directly from the cluster*

  - GCF_002263795.2 (cow)
  - GCF_000003025.6 (pig)
  - GCF_001704415.2 (goat)
  - GCA_000298735.2 (sheep)
  - GCA_000002315.5 (chicken)
  - GCF_000002285.5 (dog)
  - GCF_018350175.1 (cat)
  - nOv_mtOv_wOv (O. volvulus nuclear, mito, and wolbachia v4)
  - Sim_Eth_JIM_mt (Simulium mt)

Then concatenate the genomes into one fasta file.

     cat *.fna > catRefSeqs.fna
     gzip catRefSeqs.fna
     
Then, upload reads.trimmed.wimp.fq.gz (the output from the last section) to the cluster.

Using minimap2, map the ONT reads to the references (removeContamReads.qs)

     minimap2 -ax map-ont catRefSeqs.fna.gz reads.trimmed.wimp.fq.gz > reads.trimmed.wimp.farm.Ov.alignment.sam

Then select only the unmapped read id's 

     awk '$2 == 4 {print($0)}' reads.trimmed.wimp.farm.Ov.alignment.sam | awk '{print $1}' > farm.Ov.readids.txt 
  
Upload farm.Ov.readids.txt onto the Galaxy server. 

Use the tool seqtk to sort only unclassified reads uisng farm.Ov.readids.txt as list of seqIDs and reads.trimmed.wimp.fq as query reads. Name the output reads.trimmed.wimp.farm.Ov.fq


### Assemble genome


On the Galaxy server, generate a preliminary assembly with Flye using the parameters

     --nano-raw --iterations 2 --scaffold 

Set --min-overlap to equal the mean fragment lengh of your reads. 

Execute assembly.

*note, these are just guidelines. You may need to adjust assembly parameters and compare assembly QC to determine the best parameters to set for your data.*


### Assembly QC 


On the Galaxy server, assess the quality of your assembly.

Run BUSCO using Metaeuk with the parameters.

     --mode 'geno' --e-value 0.001 --limit 3 --lineage-dataset 'diptera_odb10'
     
Run QUAST to generate assembly statistics with default parameters.

     --est-ref-size 250000000 --min-identity 95.0 --min-contig 500 --min-alignment 65 --ambiguity-usage 'one' --ambiguity-score 0.99 --local-mis-size 200   --contig-thresholds '0,1000' --extensive-mis-size 1000 --scaffold-gap-max-size 1000 --unaligned-part-size 500 --x-for-Nx 90
 
 
### Polish with Long Reads

Polishing with long reads increases the contiguity of the assembly. The steps for polishing using Racon are 

1. Map reads to genome contigs.
2. Use mapping and coverage to close gaps with Racon. 
3. Map reads to polished contigs.
4. Repeat step 2 for further polishing.
5. Repeat as necessary.


First, on the Galaxy server, map the ONT reads used for genome assembly to the draft genome using minimap2 with the parameters

     --ava-ont 

     

