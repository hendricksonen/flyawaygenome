# Hybrid Nuclear Genome Assembly

This is a description of the pipeline I've used to assemble nuclear genomes from blackflies and a collection of the slurm scripts for doing so. This work has not yet been peer-reviewed.


## Overview of pipeline


![image](https://github.com/hendricksonen/flyawaygenome/assets/113100255/11cfc110-ab66-49fc-a514-892fe151380b)



## You will need:


- Oxford Nanopore Technologies long-read data (GridION/MinION)
- Illumina shotgun sequencing short-read data
- [EPI2ME](https://labs.epi2me.io/installation/) 
- Access to a [Galaxy Project server](https://usegalaxy.org.au/) and an account. Will use these tools:
  - Porechop
  - filtlong
  - seqtk
  - Flye
  - Racon
  - BUSCO
  - QUAST
  - BWA-MEM2
  - Compress file(s) ((this is just gzip))
- Access to a HPC cluster with the following modules:
  - minimap2
  - Trimmomatic


## Pipeline Steps


### Trimming ONT long reads


Because ONT reads are separated into multiple files, the first step is concatenating all fastq_pass reads into one file.

      cat ~/fastq_pass/*fastq.gz > catReads.fq.gz 
      
Upload concatenated reads to Galaxy Server.

Run Porechop using default parameters and catReads.fq.gz as input.

     --format 'fastq.gz' --barcode_threshold '75.0' --barcode_diff '5.0' --adapter_threshold '90.0' --check_reads '10000' --scoring_scheme '3,-6,-5,-2' --end_size '150' --min_trim_size '4' --extra_end_trim '2' --end_threshold '75.0' --middle_threshold '85.0' --extra_middle_trim_good_side '10' --extra_middle_trim_bad_side '100' --min_split_read_size '1000'

Save output as reads.porechop.fq

Run filtlong to filter out reads shorter than 500bp.

    --min_length '500' --length_weight '1.0' --mean_q_weight '1.0' --window_q_weight '1.0'  --window_size '250'

Save output as reads.trimmed.fq

Gzip reads.trimmed.fq using 'Compress file(s)' tool.

Download reads.trimmed.fq.gz


### Filtering out human and microbial contamination


For this, you will use EPI2ME, the ONT analysis software. This requires an ONT account.

In EPI2ME, start an analysis and select the reads.trimmed.fq file as input.

Choose 'FASTQ WIMP' as the analysis.

Change minimum length filter to 500. 

Accept & Start.

**Human and microbial reads will be 'Classified' and all others will be 'Unclassified'**

When completed, select 'View Report' and download CSV report.

To convert CSV to TSV 

     sed 's/,/\t/g' wimp_output.csv > wimp_output.tsv

From the TSV, 

     grep "Unclassified"  wimp_output.tsv | awk '{print $2}' > wimpReadIDs.txt
     
If multiple CSVs from multiple WIMP runs, select unlcassified and sort out duplicate read id's by

     cat *wimp_output.tsv | grep "Unclassified" | awk '{print $2}' | sort | uniq > wimpReadIDs.txt
     
Upload wimpReadIDs.txt into Galaxy.

Use the subseq function of the tool seqtk to sort only unclassified reads uisng wimpReadIDs.txt as list of seqIDs and reads.trimmed.fq as query reads. 

Gzip the output if not zipped already (use tool 'compress') and name the output reads.trimmed.wimp.fq.gz and download.


### Filtering out other potential contaminant reads


For this step, you will filter out potential contaminant reads from other eukaryotes and organelle DNA. 

For blood-feeding orgnaisms like Simulium spp., filtering out reads from potential food sources is important. A study from [Lamberton et al. (2016)](https://parasitesandvectors.biomedcentral.com/articles/10.1186/s13071-016-1703-2) assessed the species on which blackflies were feeding by identifying the organism from which the fly had taken a blood meal. Using these results and information about the animals in the surrounding areas of Ethiopia, compile a folder of reference sequences that contain the following genomes: 

*note, this is most easily done directly from the cluster, and genomes can be changed depending on sample collection site / purpose*

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

Then select only the unmapped read id's. 

     ### Because the reference genome is so large, minimap2 will split the reference genomes and index separately, meaning that reads will be mapped (or unmapped) multiple times. We want reads that never map. 
     
     ##This will pull out the read ID's of the reads that map at least once
     awk '$2 != 4 {print($1, $2)}' reads.trimmed.wimp.farm.Ov.alignment.sam | awk '{print $1}' | sort | uniq | grep -v "@PG" > unqiuemappedreads.txt
     
     ### This will pull out the read ID's of the reads that are unmapped
     awk '$2 == 4 {print($0)}' reads.trimmed.wimp.farm.Ov.alignment.sam | awk '{print $1}' | sort | uniq > uniqueunmappedatleastonce.txt
     
     ### This will remoce any reads that mapped once from the list of unmapped reads
     awk 'NR==FNR { b[$0] = 1; next } !b[$0]' unqiuemappedreads.txt uniqueunmappedatleastonce.txt > farm.Ov.uniq.unmapped.readids.txt 
  
  
If there are issues with the above when assembling later on (i.e., incorrect fastq format), do

      awk '$2 == 4 {print($1, $2)}' reads.trimmed.wimp.farm.Ov.alignment.sam | awk '{a[$1]+=$2} END {for(i in a) print i,a[i] }' | awk '$2 == 20 {print($1)}' > farm.Ov.uniq.unmapped.readids.txt
     
Upload farm.Ov.uniq.unmapped.readids.txt onto the Galaxy server. 

Use the tool seqtk to sort only unclassified reads using farm.Ov.readids.txt as list of seqIDs and reads.trimmed.wimp.fq as query reads. Name the output reads.trimmed.wimp.farm.Ov.fq


### Assemble genome


On the Galaxy server, generate a preliminary assembly with Flye using the read file reads.trimmed.wimp.farm.Ov.fq and the parameters

       --nano-raw --iterations 2 --scaffold --min-overlap mean fragment length of reads 

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

#### First Long-read Polishing Step

First, on the Galaxy server, map reads.trimmed.wimp.farm.Ov.fq to the draft genome using minimap2 with the parameters

     --map-ont

and set the output format to PAF.

Name the output 'output1.minimap2'.

On the Galaxy server, run Racon with the sequences file reads.trimmed.wimp.farm.Ov.fq, overlaps as 'output1.minimap2', and target sequences as the draft assembly.

Set the parameters

     --include-unpolished  --window-length 500 --quality-threshold 10.0 --error-threshold 0.3  --match 3 --mismatch -5 --gap -4
     
Name the output polish1.racon

#### Second Long-read Polishing Step

On the Galaxy server, map eads.trimmed.wimp.farm.Ov.fq to polish1.racon using minimap2 with the parameters

     --map-ont

and set the output format to PAF.

Name the output 'output2.minimap2'.

On the Galaxy server, run Racon with the sequences file reads.trimmed.wimp.farm.Ov.fq, overlaps as 'output2.minimap2', and target sequences as polish1.racon.

Set the parameters

     --include-unpolished  --window-length 500 --quality-threshold 10.0 --error-threshold 0.3  --match 3 --mismatch -5 --gap -4
     
Name the output polish2.racon


### Polish with Short Reads


#### Trim and format sequence files

The first step will be trimming the raw Illumina reads. This will be performed on the HPC cluster using the following slurm script

     #!/bin/bash
     #SBATCH --cpus-per-task 1
     #SBATCH --mem-per-cpu=16384
     #SBATCH --partition=day
     #SBATCH --time=24:00:00


     module load Trimmomatic

     java -jar $EBROOTTRIMMOMATIC/trimmomatic-0.39.jar PE -threads 2 -phred33 -trimlog $i\.trim.log read1.fastq.gz read2.fastq.gz 1P.fq.gz 1U.fq.gz 2P.fq.gz 2U.fq.gz ILLUMINACLIP:NexteraPE-PE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:125
     rm *trim.log
     done
    
Upload the output files 1P.fq.gz and 2P.fq.gz to the Galaxy server. 

The forward and reverse reads will need to be combined into one file. To do this, use the Galaxy tool **FASTQ interlacer**. 

Set 'Type of paired-end datasets' = 2 separate datasets and the left hand mates as 1P.fq.gz and the right hand mates as 2P.fq.gz.

Run and name the output interleaved.fq.gz

#### First Short-read Polishing Step

First, map interleaved.fq.gz to polish2.racon using BWA-MEM2 with the parameters

     'Will you select a reference genome from your history or use a built-in index?' = 'Use a genome from history and build index' 'Single or Paired-end reads' = 'Paired interleaved' -I 150 'Select analysis mode' = '1. Simple Illumina Mode' 'BAM sorting mode' = 'Sort by chromosomal coordinates'
 
 Name the output output1.bwamem2

This file will need to be converted to a SAM file format
 
On the Galaxy server, run Racon with the sequences file interleaved.fq.gz, overlaps in SAM file format as 'output1.bwamem2', and target sequences as polish2.racon.

Set the parameters

     --include-unpolished  --window-length 500 --quality-threshold 10.0 --error-threshold 0.3  --match 3 --mismatch -5 --gap -4
     
Name the output polish3.racon

#### Second Short-read Polishing Step

Map interleaved.fq.gz to polish2.racon using BWA-MEM2 with the parameters

     'Will you select a reference genome from your history or use a built-in index?' = 'Use a genome from history and build index' 'Single or Paired-end reads' = 'Paired interleaved' -I 150 'Select analysis mode' = '1. Simple Illumina Mode' 'BAM sorting mode' = 'Sort by chromosomal coordinates'
 
 Name the output output2.bwamem2
 
On the Galaxy server, run Racon with the sequences file interleaved.fq.gz, overlaps as 'output2.bwamem2', and target sequences as polish3.racon.

Set the parameters

     --include-unpolished  --window-length 500 --quality-threshold 10.0 --error-threshold 0.3  --match 3 --mismatch -5 --gap -4
     
Name the output polish4.racon

#### Third Short-read Polishing Step

Map interleaved.fq.gz to polish2.racon using BWA-MEM2 with the parameters

     'Will you select a reference genome from your history or use a built-in index?' = 'Use a genome from history and build index' 'Single or Paired-end reads' = 'Paired interleaved' -I 150 'Select analysis mode' = '1. Simple Illumina Mode' 'BAM sorting mode' = 'Sort by chromosomal coordinates'
 
 Name the output output3.bwamem2
 
On the Galaxy server, run Racon with the sequences file interleaved.fq.gz, overlaps as 'output3.bwamem2', and target sequences as polish4.racon.

Set the parameters

     --include-unpolished  --window-length 500 --quality-threshold 10.0 --error-threshold 0.3  --match 3 --mismatch -5 --gap -4
     
### ***Name the output as you wish your finalized genome to be named***

This is where you can run BUSCO again, and it's recommended to run BUSCO on every racon output genome. QUAST will also be useful for generating genome statistics again. Good luck!
