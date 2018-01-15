#/usr/bin/perl 

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
	print STDERR "Error: Usage: bunch_blast.pl <faa_file> <db_basename> <evalue> <blast_exec>\n";
	exit(-1);
}
my $faa_file_basename = $ARGV[0]; # basename only
my $database = $ARGV[1]; # in full path
my $evalue = $ARGV[2];
my $blast_exec = $ARGV[3]; # in full path
my $id = $ENV{SGE_TASK_ID}; # Batch-scheduler assigns this.
my $t1 = time();

print `hostname`;

# for blastall
#my $command = "$blast_exec  -p blastp -d $used_db\_$id -m 8 -e $evalue -i $faa_file_basename -o $faa_file_basename\_$id\_out  -a 1 -F F";

# for blastp
my $command = "$blast_exec -task blastp-fast -db $database\_$id -query $faa_file_basename -out $faa_file_basename\_$id\_out -evalue $evalue -outfmt 6";
print $command. "\n";
system($command) ;
get_time($t1, $command);

=pod
unlink glob $db."*";
get_time($t1, "unlink $db*");
=cut
exit;

sub get_time{
	my ($t1, $msg) = @_;
	my $t2 = time();
	my $dif = $t2 - $t1;
	my $h = int($dif / 3600);
	my $m = int(($dif - $h * 3600) / 60);
	my $s = $dif - $h * 3600 - $m * 60;
	print "Finish $msg, run time: $h:$m:$s\n";
}

