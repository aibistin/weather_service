#!/usr/bin/perl 
#------------------------------------------------------------------------------
# Run this to create SQLite database 'weather.db' in the /data directory.
#------------------------------------------------------------------------------
use strict;s
use warnings;
use Data::Dumper;
use Path::Tiny qw/path/;
use FindBin    qw($Bin);
#-------------------------------------------------------------------------------
#  Setup
#-------------------------------------------------------------------------------
my $database_name = path("$Bin/weather.db")->stringify;
my $sql_file = path("$Bin/../sql/create_weather_table.sql")->stringify;
#-------------------------------------------------------------------------------
#  Main
#-------------------------------------------------------------------------------
print("Creating database $database_name\n");
my $rc = system("sqlite3  $database_name < $sql_file") ;

print("Return code: $rc (0=OK!)\n");

exit()
