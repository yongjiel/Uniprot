#!/usr/bin/perl -w

package Util;

use Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(get_faa_file  get_time  parse_blast_output_file  call_cluster  split_db);

use FindBin qw($Bin);
use lib $Bin;
use File::Basename;


sub split_db{
	my ($db, $piece, $t1, $log_file) = @_;
	my $count = 0;
	my ($total_count) = `grep '>' $db -c` =~ /^\s*(\d+)/;
	get_time($t1, "grep '>' uniprot.fasta -c", $log_file);
	my $num_in_each_file = int($total_count / $piece); 
	open(IN, $db);
	my $suffix = 0;
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
	get_time($t1, "Split $db", $log_file);
}

sub call_cluster{
	my ($num_in_each_batch, $piece, $cmd, $t1, $queue, $log_file) = @_;
	for (my $i = 1; $i <= $piece / $num_in_each_batch; $i++){
	  my $start = ($i - 1) * $num_in_each_batch + 1;
	  my $end = $i * $num_in_each_batch;
	  my $command = "qsub -t $start-$end  -pe \"*\" 1 -q $queue -sync yes  $cmd ";
	  open(LOG, ">> $log_file"); print LOG $command ."\n"; close LOG;
	  system("$command 2>&1 > /dev/null");
	  get_time($t1, $command, $log_file);
	}
}


sub parse_blast_output_file{
	my ($blast_output_file, $ids) = @_;
=pod
sp|Q197F8|os|Invertebrate_iridescent_virus_3|   sp|P09405|os|Mus_musculus|      26.47   136     71      2       343     457     146     273     8e-05   48.9
sp|Q6GZX1|os|Frog_virus_3|      sp|Q6GZX1|os|Frog_virus_3|      100.00  60      0       0       1       60      1       60      3e-29    126
=cut
	my %hit_hash = ();
	open(IN, $blast_output_file) or die "Cannot open $blast_output_file";
	while(<IN>){
		if ($_ =~ /^(?:sp|tr)\|(.*?)\|.*?((?:sp|tr)\|(.*?)\|.*?$)/ ){
			my $sp = $1; my $hit = $2;  my $id = $3;
			next if( $sp eq $id );
			if (!defined $hit_hash{$sp}){
				$hit_hash{$sp} = $hit;
			}else{
				$hit_hash{$sp} .= "%%$hit";
			}
		}
	}
	close IN;
	return \%hit_hash;
}

sub get_faa_file{
	my ($ids, $faa_file, $db, $log_file) = @_;
	my @ids = split(",", $ids);
	my @rc_arr = ();
	my @not_exist =();
	my @exist = ();
	open(IN, $db) or die "Cannot open $db";
	foreach my $id (@ids){
		my $rc = `grep '^$id' $db\.ind -A1 `;
		my ($start_index, $end_index) = $rc =~ /^\w+\s+(\d+)\n\w+\s+(\d+)/s;
		#print "start: $start_index, end: $end_index\n";
		if (defined $start_index and defined $end_index){
			my $len = $end_index - $start_index;
			my $str;
			seek(IN, $start_index, 0);
			read(IN, $str, $len);
			push @rc_arr, $str;
			push @exist, $id;
		}
		else{
			push @not_exist, $id;
		}
	}
	open(OUT, "> $faa_file") or die "Cannot write $faa_file"; 
	foreach (@rc_arr){
		print OUT $_;
	}
	close OUT;

	if (scalar @exist == scalar @ids){
		system("echo 'All the ids in $faa_file' >> $log_file");
	}else{
		my $miss_cases = join(",", @not_exist);
		system("echo '$miss_cases NOT exist in $db' >> $log_file");
	}
}

sub get_time{
	my ($t1, $msg, $log_file) = @_;
	my $t2 = time();
	my $dif = $t2 - $t1;
	my $h = int($dif / 3600);
	my $m = int(($dif - $h * 3600) / 60);
	my $s = $dif - $h * 3600 - $m * 60;
	#print "Finish $msg, run time: $h:$m:$s\n";
	system("echo 'Finish $msg, run time: $h:$m:$s' >> $log_file");
}

1;