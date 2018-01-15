#!/usr/bin/perl -w
# this program uses one.q and calls sing_blast.pl in qsub
# call blast in pararllel
use FindBin qw($Bin);
use lib $Bin;
use strict;
use warnings;
use CONFIG;
use File::Copy;
use File::Basename;
use Util;

if (scalar @ARGV != 4){
	print STDERR "Error: Usage: perl call_blast_parallel.pl <faa_file> <db> <evalue> <start_time>\n";
	exit(-1);
}

my $faa_file = $ARGV[0]; # in full path
my $dir = dirname($faa_file);
my $faa_file_basename = basename($faa_file);
my $log_file = "$dir/log"; # full path

my $database = $ARGV[1]; # in full path
my $evalue = $ARGV[2];
my $t1 = $ARGV[3];

# cut faa file into pieces.
my @arr = split (">", `cat $faa_file`);
@arr = grep ($_ !~ /^[\n\s]*$/ , @arr);
my $piece=0;
for(my $i = 0; $i <= $#arr; $i++){
	my $sufix  = ($i % $CORE_NUMBER_REVIEWED) + 1;
	open(OUT, ">> $faa_file\_$sufix");
	print OUT '>'. $arr[$i];
	close OUT;
	if ($sufix >$piece){
		$piece = $sufix;
	}
}
if ($piece == 0){
	system("echo 'Nothing in .faa file. Program exit!' >>$log_file");
	exit(0);
}else{
	system("echo 'Split .faa file into $piece!' >> $log_file");
}
# call single_node_blast
chdir $dir;
system("echo 'change to $dir' >> $log_file");
my $command = " $BIN/single_blast.pl  $faa_file_basename $database $evalue $BIN/blastall";
call_cluster($piece, $piece, $command, $t1, "one.q", $log_file);

#combine all the files
#combine all the files
my $file_str = '';
for (my $i = 1; $i <= $piece; $i++){
	if (-s "$faa_file_basename\_$i\_out" && `cat $faa_file_basename\_$i\_out` !~ /^[\s\n]*$/){
		$file_str .= "$faa_file_basename\_$i\_out  " ;
	}
}
system("echo 'file_str=$file_str' >>$log_file");
system("cat $file_str > $faa_file_basename\_blast_out") if ($file_str ne '');

system("echo 'call_blast_parallel.pl program exit' >> $log_file");
exit;


		
