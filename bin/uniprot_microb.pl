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
use File::Basename;

if (scalar @ARGV != 1 && scalar @ARGV != 2) {
	print STDERR "Args error. Usage: perl uniprot_microb.pl  <job_id> [<evalue>]\n".
				"<uniprot_ids> is a string of ids separated with commpas. no comma if single id. there must be no empty space in the string\n";
	exit(-1);
}

my $job_id = $ARGV[0];
my $evalue = (defined $ARGV[1])? $ARGV[1] : $EVALUE;

my $db = "$DB_DIR/$ALL_FASTA_OUTPUT_FILE";
my $remote_db = "$REMOTE_UNIPROT_DB_DIR/$ALL_FASTA_OUTPUT_FILE";
my $t1 = time();
my $case_dir = "$TMP_FOLDER/$job_id";
if (!-d $case_dir){
	print STDERR "No $case_dir exist!\n";
	exit(-1);
}
my $case_filename = "$case_dir/$job_id.faa";  # full path
my $log_file = "$case_dir/log";

#print "Job ID: $job_id\n";
system("echo 'job_id=$job_id, evalue=$evalue' >> $log_file");

my $ids = convert_faa_file($case_filename); #return array
if (-s $case_filename){
	get_time($t1, "$case_filename converted", $log_file);
}else{
	get_time($t1, "$case_filename NOT converted", $log_file);
	print STDERR "$case_filename NOT converted!\n";
	exit(-1);
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
my $command = "perl $BIN/bunch_blast_parallel.pl $case_filename $remote_db $evalue $t1 ";
system("echo '$command' >> $log_file");
system($command);
get_time($t1, "BLAST", $log_file);

my $blast_output_file = "$case_filename\_blast_out";
if (-s $blast_output_file && `cat $blast_output_file` !~ /^[\s\n]*$/){
	my $hit_hash = parse_blast_output_file($blast_output_file, $ids);
	print_out($hit_hash, $ids, \%hash_exist);
}else{
	system("echo 'No BLAST output file $blast_output_file generated!' >> $log_file");
}
get_time($t1, "parse_blast_output_file", $log_file);
system("chmod 777 -R $case_dir");
system("echo 'call cleanup program' >> $log_file");
system("perl $BIN/cleanup.pl $TMP_FOLDER  2>&1 >> $log_file");

system("echo 'Program exit!' >> $log_file");
exit;



sub print_out{
	my $hit_hash = shift;
	my $ids = shift;
	my $hash_exist = shift;
	foreach my $id (@$ids){
		my $species = '';
		my $st = '';
		if (defined $$hash_exist{$id}){
			($species, $st) =  $$hash_exist{$id} =~ /(.*?)\|(.*)/;
			if ($st eq 'sp'){
				$st = "Reviewed";
			}elsif($st eq 'tr'){
				$st = "Unreviewed";
			}
		}
		print  "***************************************************\n";
		print  "#Query: $id, Species: $species, State: $st\n";
		if (! grep(/^$id$/, keys %$hash_exist) ){
			print  "***************************************************\n";
			print "No record $id in Uniprot db\n";
			print "\n\n";
		}else{
			print  "#Uniprot_ID\tSpecies\tState\tEvalue\n";
			print  "***************************************************\n";
			if (defined $$hit_hash{$id}){
				my @tmp = split("%%", $$hit_hash{$id});
				my $hit_obj_array = get_HIT_objs(\@tmp);
				foreach my $obj (@$hit_obj_array){
					my $hit_id = $obj->{_id}; my $os = $obj->{_os};
					my $state =  $obj->{_state}; my $evalue = $obj->{_evalue};
					print "$hit_id\t$os\t$state\t$evalue\n";
				}
			}else{
				print "No hit from blasting against Uniprot db\n";
			}
			print "\n\n";
		}
	}
}

sub get_HIT_objs{
	my $hit_array = shift;
	my @arr = ();
	foreach my $hit (@$hit_array){
		if ($hit =~ /^(sp|tr)\|(.*?)\|os\|(.*?)\|.*?\s+(\S+)\s+\S+$/){
			my $state = $1;
			$state = ($state eq 'sp')? "Reviewed": "Unreviewed";
			my $hit_id = $2; my $os = $3; my $evalue = $4;
			my $obj = HIT->new($hit_id, $os, $state, $evalue);
			push @arr, $obj;
		}
	}
	@arr = sort { $a->{_evalue} <=> $b->{_evalue} } @arr;
	return \@arr;
}

sub convert_faa_file{
	my $case_filename = shift;
	my $content = `cat $case_filename`;
=pod
>gi|158333234|ref|YP_001514406.1| NUDIX hydrolase [Acaryochloris marina MBIC11017]
MPYTYDYPRPGLTVDCVVFGLDEQIDLKVLLIQRQIPPFQHQWALPGGFVQMDESLEDAARRELREETGV
QGIFLEQLYTFGDLGRDPRDRIISVAYYALINLIEYPLQASTDAEDAAWYSIENLPSLAFDHAQILKQAI
RRLQGKVRYEPIGFELLPQKFTLTQIQQLYETVLGHPLDKRNFRKKLLKMDLLIPLDEQQTGVAHRAARL
YQFDQSKYELLKQQGFNFEV
=cut
	$content =~ s/>gi\|(.*?)\|ref\|.*?\|/>sp\|$1\|os\|XXX\|/g;
	open(OUT, ">$case_filename") or die "Cannot write $case_filename";
	print OUT $content;
	close OUT;
	my @ids = $content =~ />sp\|(.*?)\|/g;
	return \@ids;
}

package HIT;
sub new {
	my $class = shift;
    my $self = {
    	_id => shift,
    	_os => shift,
    	_state => shift,
    	_evalue => shift
    };
    bless $self, $class;
    return $self;
}
1;
