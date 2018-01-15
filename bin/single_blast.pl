#!/usr/bin/perl -w
#$ -S /usr/bin/perl
#$ -cwd
#$ -r yes
#$ -j no
#$ -pe smp 1
use strict;
use warnings;
use File::Basename;

# run blast on a single node of our cluster.
if (scalar @ARGV != 4){
	print STDERR "Error: Usage: single_blast.pl <faa_file> <db_basename> <evalue> <blast_exec>\n";
	exit(-1);
}
my $faa_file_basename = $ARGV[0];
my $database = $ARGV[1];
my $evalue = $ARGV[2];
my $blast_exec = $ARGV[3];
my $id = $ENV{SGE_TASK_ID}; # Batch-scheduler assigns this.

my $command = "$blast_exec  -p blastp -d $database -m 8 -e $evalue -i $faa_file_basename\_$id -o $faa_file_basename\_$id\_out  -a 1 -F F";
system("echo '$command'");
system($command) ;
exit;
