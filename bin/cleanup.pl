#!/usr/bin/perl 

####################################################################
# this program will clean up more than one month old files since now
#Usage : perl cleanup.pl  <absolute_dir>
####################################################################
use FindBin qw($Bin);
use lib $Bin;
use strict;
use warnings;
use CONFIG;

my $dir = $ARGV[0];
if (! -d $dir){
	print "There is no $dir for cleanup.pl\n";
	exit(-1);
}
chdir $dir;

my $keep_dates = $KEEP_DATES;

my $date  = `date`;
my @array = split(" ", $date);
my $year = $array[$#array];
my $mon = $array[1];
my $day = $array[2];
$mon = change_mon_to_int($mon);
my $curr_mon= $mon;
my $curr_day= $day;
my $list =  `ls -l`;
@array = split("\n", $list);
my @temp;
for(my $i = 0; $i<=$#array; $i++){
	$mon = $curr_mon;
	$day = $curr_day;
	my $line = $array[$i];
	if ($line =~/total/){
		next;
	}
	@temp=split(" ", $line);
	my $mon1='';
	my $day1='';
	if($temp[5] =~/\d+\-(\d+)\-(\d+)/){
		$mon1 = $1;
		$day1 = $2;
	}elsif($temp[5] =~/\w+/ && length($temp[5]) ==3){
		$mon1 = change_mon_to_int($temp[5]);
		$day1 = $temp[6];
	}
	if ($mon1 eq '' or $day1 eq '') {
		print "format not correct, Please check!\n$line\n";
		exit;
	}	
	if ($mon < $mon1 ) {
		$mon += 12;
	}
	if ($mon > $mon1){
		$day += 30 *($mon-$mon1);
	}
	if ($day - $day1 > $keep_dates) {
		my $tmp = $temp[$#temp];
		$tmp =~ s/_.*//;
		if ($tmp =~/^1\d+/ && length($tmp)==10){
			print $line."\n";
		        print "mon '$mon', day '$day', mon '$mon1', day '$day1'  \n";
			print "Remove $temp[$#temp]\n";
			system("rm -rf  $temp[$#temp]");
		}
	}
	
}	


exit;


sub change_mon_to_int{
	my $mon= shift;
	$mon=~s/Jan/1/i; 
	$mon=~s/Feb/2/i;
	$mon=~s/Mar/3/i;
	$mon=~s/Apr/4/i;
	$mon=~s/May/5/i;
	$mon=~s/Jun/6/i;
	$mon=~s/Jul/7/i;
	$mon=~s/Aug/8/i;
	$mon=~s/Sep/9/i;
	$mon=~s/Oct/10/i;
	$mon=~s/Nov/11/i;
	$mon=~s/Dec/12/i;
	return $mon;
}
	
