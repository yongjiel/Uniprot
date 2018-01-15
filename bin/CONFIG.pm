#!/usr/bin/perl -w
package CONFIG;
use strict;
use warnings;

use Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw($BIN $ROOT $DB_DIR $DB_DIR_TMP $TMP_FOLDER $EVALUE $KEEP_DATES $CORE_NUMBER $CORE_NUMBER_REVIEWED 
				 $UNIPROT_SP_LINK $UNIPROT_TREMBL_LINK $SPROT_DATA_FILE $TREMBL_DATA_FILE $SPROT_FASTA_OUTPUT_FILE 
				 $ALL_FASTA_OUTPUT_FILE $KEY @NODE_ARR $REMOTE_UNIPROT_DB_DIR $REMOTE_UNIPROT_DB_MICROB_DIR) ;

use FindBin qw($Bin);
use lib $Bin;


our $ROOT = "/usr/sdd1/uniprot_self";
our $BIN = "$ROOT/bin";
our $DB_DIR = "$ROOT/db"; # for blast run
our $DB_DIR_TMP = "$ROOT/db_tmp"; # for update db usage.
our $TMP_FOLDER = "$ROOT/tmp"; # for query case.
our $EVALUE = 0.0001; # default evalue. User can input it as args when call uniprot.pl as 2nc arg.
our $KEEP_DATES = 3; # dates want to keep the case in tmp folder

our $CORE_NUMBER = 120; # used for uniprot_all.pl and download_unitpro_reformat_formatdb.pl
						# for split db and cores used for bunch call of fasta records in input file.
our $CORE_NUMBER_REVIEWED = 30; # used for uniprot_reviewed.pl for splitting faa file

our $UNIPROT_SP_LINK = "ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.dat.gz";
our $UNIPROT_TREMBL_LINK = "ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_trembl.dat.gz";

our $SPROT_DATA_FILE = "uniprot_sprot.dat";
our $TREMBL_DATA_FILE = "uniprot_trembl.dat";
our $SPROT_FASTA_OUTPUT_FILE = "uniprot_sprot.fasta";
our $ALL_FASTA_OUTPUT_FILE = "uniprot.fasta";

our $KEY = "~/.ssh/scp-key"; # use to transfer files btw nodes
our @NODE_ARR = qw(w1 w2 w3 w4 w5 w6 w7 w8 w9 w10);
our $REMOTE_UNIPROT_DB_DIR = "/usr/scratch/uniprot_db";

1;
