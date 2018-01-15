#!/usr/bin/perl -w

# this program is the main driver of the package.
# it will create .faa file in tmp's case folder.
# anc check out what ids missing in the output. 
# It will call the call_blast_parallel.pl to initiate 
# blast in cluster to get the result.
use FindBin qw($Bin);
use lib $Bin;
use strict;
use warnings;
use CONFIG;
use Util;
use File::Copy;

if (scalar @ARGV != 1 && scalar @ARGV != 2) {
	print STDERR "Args error. Usage: perl uniprot.pl  <uniprot_ids> [<evalue>]\n".
				"<uniprot_ids> is a string of ids separated with commpas. no comma if single id. there must be no empty space in the string\n";
	exit(-1);
}

my $ids = $ARGV[0];
my $evalue = (defined $ARGV[1])? $ARGV[1] : $EVALUE;

my @ids = split(/\s*,\s*/, $ids);
my $db = "$DB_DIR/$SPROT_FASTA_OUTPUT_FILE";
my $case = time();
my $case_dir = "$TMP_FOLDER/$case";
mkdir $case_dir;
if (!-d $case_dir){
	print STDERR "No $case_dir generated!\n";
	exit(-1);
}
print "Job ID: $case\n";
my $case_filename = "$case_dir/$case.faa";  # full path
my $log_file = "$case_dir/log";
my $t1 = time();
system("echo 'ids=$ids, evalue=$evalue' >> $log_file");
get_faa_file($ids, $case_filename, $db, $log_file);
if (-s $case_filename){
	get_time($t1, "$case_filename generated", $log_file);
}else{
	get_time($t1, "$case_filename NOT generated", $log_file);
	print "$case_filename NOT generated!\n";
	exit;
}

my %hash_exist = ();
open(IN, $case_filename) or die "Cannot read $case_filename";
while(<IN>){
	if ($_ =~ /^>(sp|tr)\|(.*?)\|os\|(.*?)\|/s){
		$hash_exist{$2} = "$3\|$1";
	}
}
close IN;

# call call_blast_parallel.pl for BLAST
my $command = "perl $BIN/call_blast_parallel.pl $case_filename $db $evalue $t1";
system("echo '$command' >> $log_file");
system($command);
my $blast_output_file = "$case_filename\_blast_out";
if (-s $blast_output_file){
	my $hit_hash = parse_blast_output_file($blast_output_file, \@ids);
	print_out($hit_hash, \@ids, \%hash_exist);
}else{
	system("echo 'No BLAST output file $blast_output_file generated!' >> $log_file");
}
get_time($t1, "BLAST done", $log_file);
system("chmod 777 -R $case_dir");
system("echo 'call cleanup program' >> $log_file");
system("perl $BIN/cleanup.pl $TMP_FOLDER  2>&1 >> $log_file");

my $t_diff = time() - $t1;
system("echo 'Totally take time $t_diff seconds.' >> $log_file");
exit;


sub print_out{
	my $hit_hash = shift;
	my $ids = shift;
	my $hash_exist = shift;
	foreach my $id (@$ids){
		my $species = (defined $$hash_exist{$id})?  $$hash_exist{$id} : '';
		print  "***************************************************\n";
		print  "#Query: $id, Species: $species\n";
		if ( ! grep(/^$id$/, keys %$hash_exist) ){
			print  "***************************************************\n";
			print "No record $id in Uniprot db\n";
			print "\n\n";
		}else{
			print  "#Uniprot_ID\tSpecies\tEvalue\n";
			print  "***************************************************\n";
			if (defined $$hit_hash{$id}){
				my @tmp = split("%%", $$hit_hash{$id});
				foreach my $hit (@tmp){
					#sp|P09405|os|Mus_musculus|      26.47   136     71      2       343     457     146     273     8e-05   48.9
					if ($hit =~ /^sp\|(.*?)\|os\|(.*?)\|.*?\s+(\S+)\s+\S+$/){
						my $hit_id = $1; my $os = $2; my $evalue = $3;
						print "$hit_id\t$os\t$evalue\n";
					}
				}
			}else{
				print "No hit from blasting against Uniprot db\n";
			}
			print "\n\n";
		}
	}
}

