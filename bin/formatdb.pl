#!/usr/bin/perl -w
#$ -S /usr/bin/perl
#$ -cwd
#$ -r yes
#$ -j no
#$ -pe smp 1
use strict;
use warnings;
use File::Basename;

if (scalar @ARGV != 2){
	print STDERR "Error: Usage: perl formatdb.pl <db_basename> <formatdb_exec>\n";
	exit(-1);
}
my $db_basename = $ARGV[0];
my $formatdb_exec = $ARGV[1];
my $i = $ENV{SGE_TASK_ID}; # Batch-scheduler assigns this.



my $cmd = "$formatdb_exec -p T -i $db_basename$i -l formatdb_$i.log";
print "$cmd ...\n";
system($cmd);

exit;