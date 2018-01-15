#!/usr/bin/perl -w
# this program uses one.q and calls bunch_blast.pl in qsub
# call blast in pararllel
use FindBin qw($Bin);
use lib $Bin;
use strict;
use warnings;
use CONFIG;
use Util;
use File::Copy;
use File::Basename;

if (scalar @ARGV != 4){
	print STDERR "Error: Usage: perl bunch_blast_parallel.pl <faa_file> <db> <evalue> <start_time>\n";
	exit(-1);
}

my $faa_file = $ARGV[0]; # in full path
my $database = $ARGV[1]; # in full path
my $evalue = $ARGV[2];
my $t1 = $ARGV[3];

my $dir = dirname($faa_file);
my $faa_file_basename = basename($faa_file);
my $log_file = "$dir/log"; # full path

# call single_node_blast
chdir $dir;
system("echo 'change to $dir' >> $log_file");

# for cluster parallel
my $num_in_each_batch  = $CORE_NUMBER;
my $cmd = "$BIN/bunch_blast.pl  $faa_file_basename $database $evalue $BIN/blastp";
call_cluster($num_in_each_batch, $CORE_NUMBER, $cmd, $t1, "all.q", $log_file); # in Util.pm

#combine all the files
my $file_str = '';
for (my $i = 1; $i <= $CORE_NUMBER; $i++){
	if (-s "$faa_file_basename\_$i\_out" && `cat $faa_file_basename\_$i\_out` !~ /^[\s\n]*$/){
		$file_str .= "$faa_file_basename\_$i\_out  " ;
	}
}
system("echo 'file_str=$file_str' >>$log_file");
system("cat $file_str > $faa_file_basename\_blast_out") if ($file_str ne '');
system("echo 'bunch_blast_parallel.pl program exit' >> $log_file");
exit;
