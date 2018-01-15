#!/usr/bin/perl -w

# Script to create an index file for a uniprot database file.
#
# David Arndt, June 2007

use strict;

sub trim($);

################################################################
##########                 Main code                 ###########
################################################################

if(@ARGV<1)
{
  print "Usage: ./index_db.pl <database_file>\n";
  exit(0);
}
my $t1 = time();
my $db_filename = $ARGV[0];

open(DBFILE, "$db_filename");
open(OUTPUT, ">${db_filename}\.ind");

my $line;
my $id;

for (;;) {
	undef $!;
	unless (defined( $line = <DBFILE> )) {
		die $! if $!;
		last; # reached EOF
	}
	
	if ($line =~ /^>(?:sp|tr)\|(.*?)\|/) {
		$id = $1;
		print OUTPUT $id . "\t" . (tell(DBFILE) - length($line)) . "\n";
	}
}
seek(DBFILE, 0, 2);
print OUTPUT "ENDEND\t". tell(DBFILE). "\n";

close(DBFILE);
close(OUTPUT);

print "Index file ${db_filename}\.ind created.\n";
my $t2 = time();
my $dif = $t2 - $t1;
my $h = int($dif / 3600);
my $m = int(($dif - $h * 3600) / 60);
my $s = $dif - $h * 3600 - $m * 60;
print "Finish. run time: $h:$m:$s\n";
print "Program exit\n";
exit;
