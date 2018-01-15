# Uniprot

This package will blast on uniprot db for homo from other organisms. 
Usage: perl uniprot.pl <uniprot_ids>  [<evalue>]
Note: for multiple uniprot ids, need comma for separation. No empty space btw them.
      evalue default is 0.0001 if not use.
1. change the path of $ROOT in bin/config.pm to locate this package.
2. formatdb and blastall must be in ~/bin.
3. ~/bin must be in $PATH. check ~/.bashrc or ~/.bash_profile.
4. crontab -e
    0   0   1,15   *   *   perl /home/prion/uniprot_self/bin/download_unitpro_reformat_formatdb.pl
