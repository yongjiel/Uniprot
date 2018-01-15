#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  download_unitpro.pl
#
#        USAGE:  ./download_unitpro.pl  
#
#  DESCRIPTION:  This program will be downlad reviewed and 
#				unreviewed dbs from uniprot and filter the 
#  				eukaryote part from the unreivewed db and 
#				merge them together to make a db.
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  YOUR NAME (), 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  10/15/2012 02:50:36 PM
#     REVISION:  ---
#===============================================================================
use FindBin qw($Bin);
use lib $Bin;
use strict;
use warnings;
use CONFIG;
use Util;
use File::Copy;
use File::Path;

my $dir_needed =  $DB_DIR;
my $working_dir = $DB_DIR_TMP;
my $remote_db_dir = $REMOTE_UNIPROT_DB_DIR;

rmtree($working_dir) if (-d $working_dir);
mkdir $working_dir;
my $log_file = $working_dir. '/log';

my $date = `date`;
my $t1 = time();
unlink $log_file;
system("echo '$date \n' > $log_file");

chdir $working_dir;

download_gunzip($UNIPROT_SP_LINK, $t1, $log_file);
download_gunzip($UNIPROT_TREMBL_LINK, $t1, $log_file);

if (-s $SPROT_DATA_FILE && -s $TREMBL_DATA_FILE){
	reformat_db($SPROT_DATA_FILE, $TREMBL_DATA_FILE, $SPROT_FASTA_OUTPUT_FILE, $ALL_FASTA_OUTPUT_FILE, $log_file);
}else{
	my $msg = "Error: No file $SPROT_DATA_FILE or $TREMBL_DATA_FILE exists!";
	print STDERR "$msg\n";
	system("echo '$msg' >> $log_file");
}
get_time($t1, "reformat_db()", $log_file);

#remove .dat files
unlink $SPROT_DATA_FILE;
unlink $TREMBL_DATA_FILE;
get_time($t1, "remove .dat file", $log_file);

system("perl $BIN/index_db.pl $SPROT_FASTA_OUTPUT_FILE");
get_time($t1, "Index $SPROT_FASTA_OUTPUT_FILE", $log_file);

my $cmd = "$BIN/formatdb -p T -i $SPROT_FASTA_OUTPUT_FILE";
print "$cmd ...\n";
system("echo '$cmd' >> $log_file");
system($cmd);
unlink "formatdb.log";
get_time($t1, "formatdb $SPROT_FASTA_OUTPUT_FILE", $log_file);

# generate index file for db
system("perl $BIN/index_db.pl $ALL_FASTA_OUTPUT_FILE");
get_time($t1, "index $ALL_FASTA_OUTPUT_FILE", $log_file);

if (-s $ALL_FASTA_OUTPUT_FILE){
	my ($total_count) = `grep '>' $ALL_FASTA_OUTPUT_FILE -c` =~ /^\s*(\d+)/;
	get_time($t1, "grep $ALL_FASTA_OUTPUT_FILE", $log_file);

	split_db_big($ALL_FASTA_OUTPUT_FILE, $total_count, $CORE_NUMBER);
	get_time($t1, "Split $ALL_FASTA_OUTPUT_FILE", $log_file);

	call_format(6, $CORE_NUMBER, $ALL_FASTA_OUTPUT_FILE, $t1, $log_file);
	get_time($t1, "formatdb $ALL_FASTA_OUTPUT_FILE", $log_file);

	# transfer files into different locations
	foreach my $i (@NODE_ARR){
		print "Node $i\n";
		system("echo 'Node $i' >> $log_file");
		my $cmd = "scp -i $KEY uniprot.fasta_*.p*  botha-$i:$remote_db_dir/. ";
		system("echo '$cmd' >> $log_file");
		system($cmd) == 0 or system("echo $! >> $log_file"); 
	}
	get_time($t1, "transfer uniprot.fasta_*.p*", $log_file);


	chdir  $ROOT;
	move $dir_needed, "$dir_needed\_old" if (-d $dir_needed);
	move $working_dir, $dir_needed;
	rmtree("$dir_needed\_old") if (-d "$dir_needed\_old");
	mkdir $working_dir;
	get_time($t1, "switch to db", $log_file);

}else{
	get_time($t1, "No $ALL_FASTA_OUTPUT_FILE exist", $log_file);
}

system("echo 'Program exit' >> $log_file");
exit;

sub download_gunzip{
	my ($link, $t1, $log_file) = @_;
	my ($db_basename) = $link =~ /.*\/(.*?)$/;
	unlink $db_basename;
	system("wget $link -O $db_basename");
	get_time($t1, "wget $db_basename", $log_file);
	my $cmd = "gunzip -f $db_basename";
	print "$cmd....\n";
	system("echo '$cmd' >> $log_file");
	system($cmd)==0 or system("echo '$!' >> $log_file");
	get_time($t1, "gunzip $db_basename", $log_file);
}

sub call_format{
	my ($num_in_each_batch, $piece, $db, $t1, $log_file)= @_;
	my $times = $piece / $num_in_each_batch;
	foreach my $i (1 .. $times){
		my @childs = ();
		foreach my $n (1 .. $num_in_each_batch){
			my $pid = fork();
			if (not defined $pid){
				print "Resource not available for fork\n";
			}elsif ( $pid == 0){
				#child
				my $w = ($i - 1) * $num_in_each_batch + $n;
				my $cmd = "$BIN/makeblastdb -dbtype prot -in $db\_$w -logfile makeblast_$w.log";
				system($cmd);
				exit;
			}else{
				# parent
				push @childs, $pid
			}
		}
		foreach my $c (@childs){
		  waitpid($c, 0);
		}
		get_time($t1, "batch $i : $num_in_each_batch jobs ", $log_file);
		#next batch
	}
	#delete formatdb log file
	unlink glob "makeblast_*.log";
}

sub split_db_big{
	my ($db, $total_count, $piece) = @_;
	my $num_in_each_file = int($total_count / $piece);
	print "Total record count = $total_count, each file should contain $num_in_each_file\n";
	open(IN, $db);
	my $suffix = 0;
	my $count = 0;
	my $out;
	while(<IN>){
		if ($_ =~/^>/){
			$count++;
			if ($count == 1 || $count > $num_in_each_file){
				close $out if (defined $out);
				$count = 1;
				$suffix += 1;
				if ($suffix > $piece){
					$suffix = $piece;
					open($out, ">> $db\_$suffix");
				}else{
					open($out, "> $db\_$suffix");
				}
			}
			print $out $_;
		}else{
			print $out $_;
		}
	}
	close $out if (defined $out);
	close IN;
}


sub reformat_db{
	my $sprot_file = shift;
	my $trembl_file = shift;
	my $db_sprot_outfile = shift;
	my $db = shift;
	my $log_file = shift;

	
	open(OUT, "> $db") or die "Cannot write $db";
	open(OUT1, "> $db_sprot_outfile") or die "Cannot write $db_sprot_outfile";

	my $count = read_make_db($sprot_file, \*OUT, \*OUT1);
	close OUT1;
	system("echo 'Finish $sprot_file, total count = $count' >> $log_file");
=pod
ID   M5BHD1_9HIV1            Unreviewed;       131 AA.
AC   M5BHD1;
DT   29-MAY-2013, integrated into UniProtKB/TrEMBL.
DT   29-MAY-2013, sequence version 1.
DT   07-JAN-2015, entry version 8.
DE   SubName: Full=Gag polyprotein, p17 region {ECO:0000313|EMBL:CCN26498.1};
DE   Flags: Fragment;
GN   Name=gag {ECO:0000313|EMBL:CCN26498.1};
OS   HIV-1 M:CRF02_MP1539.
OC   Viruses; Retro-transcribing viruses; Retroviridae; Orthoretrovirinae;
OC   Lentivirus; Primate lentivirus group.
OX   NCBI_TaxID=1243296 {ECO:0000313|EMBL:CCN26498.1};
RN   [1] {ECO:0000313|EMBL:CCN26498.1}
RP   NUCLEOTIDE SEQUENCE.
RC   STRAIN=MP1539 {ECO:0000313|EMBL:CCN26498.1};
RX   PubMed=23232100; DOI=10.1016/j.meegid.2012.11.017;
RA   Vidal N., Diop H., Montavon C., Butel C., Bosch S., Ngole E.M.,
RA   Toure-Kane C., Mboup S., Delaporte E., Peeters M.;
RT   "A novel multiregion hybridization assay reveals high frequency of
RT   dual inter-subtype infections among HIV-positive individuals in
RT   Cameroon, West Central Africa.";
RL   Infect. Genet. Evol. 14:73-82(2013).
CC   -----------------------------------------------------------------------
CC   Copyrighted by the UniProt Consortium, see http://www.uniprot.org/terms
CC   Distributed under the Creative Commons Attribution-NoDerivs License
CC   -----------------------------------------------------------------------
DR   EMBL; HF543093; CCN26498.1; -; Genomic_DNA.
DR   GO; GO:0019028; C:viral capsid; IEA:InterPro.
DR   GO; GO:0005198; F:structural molecule activity; IEA:InterPro.
DR   GO; GO:0016032; P:viral process; IEA:InterPro.
DR   Gene3D; 1.10.150.90; -; 1.
DR   Gene3D; 1.10.375.10; -; 1.
DR   InterPro; IPR000071; Lentvrl_matrix_N.
DR   InterPro; IPR012344; Matrix_HIV/RSV.
DR   InterPro; IPR008919; Retrov_capsid_N.
DR   InterPro; IPR010999; Retrovr_matrix.
DR   Pfam; PF00540; Gag_p17; 1.
DR   PRINTS; PR00234; HIV1MATRIX.
DR   SUPFAM; SSF47836; SSF47836; 1.
DR   SUPFAM; SSF47943; SSF47943; 1.
PE   4: Predicted;
FT   NON_TER       1      1       {ECO:0000313|EMBL:CCN26498.1}.
FT   NON_TER     131    131       {ECO:0000313|EMBL:CCN26498.1}.
SQ   SEQUENCE   131 AA;  14650 MW;  698428FF78A2DB42 CRC64;
     LVWASRELER FALNPSLLET AEGCQQLMEQ LQPALGTGSE ELRSLFNTLA TLWCVHRRID
     IKDTKEALDK IEELQNKSKQ KTQQAAAATG SSSQNYPIVQ NAQGQMTHQA LSPRTLNAWV
     KVIEEKGSTQ K
//
=cut
	my $count1 = read_make_db($trembl_file, \*OUT);
	system("echo 'Finish $trembl_file, total count = $count1' >> $log_file");
	my $t_c = $count + $count1;
	system("echo 'Finish $db, total_count = $t_c' >> $log_file");
	close OUT;
	if (-s $db){
		print "$db generated!!!\n";
	}
}

sub read_make_db{
	my ($file, $out, $out1) = @_;
	my $count = 0;
	my $t_count = 0;
	my $flag1 = 0; my $flag2 = 0; my $flag3 = 0; my $flag4 = 0;
	my $id = ''; my $sp = ''; my $name = ''; my $seq = ''; 
	my $eu_flag = 0;
	open(IN, $file) or die "No $file exist";
	while(<IN>){
		chomp $_;
		if ($_ =~ /^AC   (\S+?);/){
			$flag1 = 0; $flag2 = 0; $flag3 = 0; $flag4 = 0; 
			$seq = ''; $id = ''; $sp = ''; $name = '';
			$eu_flag = 0;
			$t_count++;
			$id = $1; 
			$flag1 = 1;
			next;
		}
		if ($_ =~ /^OS   (.*)/ && $flag2 == 0){
			$sp = $1; 
			$sp =~ s/\(.*?\)//g; $sp =~ s/\s*$//; $sp =~ s/\s/\_/g;
			$sp =~ s/[\.\_\s]*$//;
			$flag2 = 1;
			next;
		}
		if ($_ =~ /^DE   (?:SubName|RecName): Full=(.*)/ && $flag3 ==0 ){
			$name = $1; $name =~ s/\{.*?$//; $name =~ s/\s*$//;
			$name =~ s/\s/\_/g;
			$flag3 = 1;
			next;
		}
		if ($_ =~ /^OC   Eukaryota/ && $file =~ /_trembl/){ # filter in trembl only
			$flag1 = 0; $flag2 = 0; $flag3 = 0;
			$eu_flag = 1;
			next;
		}
		if ($_ =~ /^SQ   SEQUENCE/ && $flag1 == 1 && $flag2 == 1 && $flag3 == 1){
			$flag4 = 1;
			next;
		}
		if ($_ !~ /^\/\// && $flag1 == 1 && $flag2 == 1 && $flag3 == 1 && $flag4 == 1){
			$seq .= $_;
			next;
		}
		if ($_ =~ /^\/\// && $flag1 == 1 && $flag2 == 1 && $flag3 == 1 && $flag4 == 1){
			$count++;
			my $mark = ($file =~ /_trembl/)? "tr" : "sp";
			print $out ">$mark\|$id\|os\|$sp\| $name\n";
			print $out1 ">$mark\|$id\|os\|$sp\| $name\n" if (defined $out1);
			$seq =~ s/[\s\n]//g;
			print $out $seq."\n";
			print $out1 $seq."\n" if (defined $out1);
		}elsif ($_ =~ /^\/\//){
			print "AC $id no write. flag1=$flag1; flag2=$flag2; flag3=$flag3; flag4=$flag4.\n";
			print "             sp=$sp, name=$name, eu_flag=$eu_flag\n";
		}
		
	}
	close IN;
	return $count;
}

