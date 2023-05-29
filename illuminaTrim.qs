#!/bin/bash
#SBATCH --cpus-per-task 1
#SBATCH --mem-per-cpu=16384
#SBATCH --partition=day
#SBATCH --time=24:00:00


module load Trimmomatic

##unique sample id's here
ID=""

for i in $ID
do
echo "$i"
java -jar $EBROOTTRIMMOMATIC/trimmomatic-0.39.jar PE -threads 2 -phred33 -trimlog $i\.trim.log $i\_R1.fastq.gz $i\_R2.fastq.gz $i\_1P.fq.gz $i\_1U.fq.gz $i\_2P.fq.gz $i\_2U.fq.gz ILLUMINACLIP:NexteraPE-PE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:125
rm *trim.log
done
