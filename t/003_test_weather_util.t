#===============================================================================
#   NAME: 003_test_weather_util.t
#   Test: WeatherUtils.pm
#===============================================================================
use v5.34;
use strict;
use warnings;
use Test::More;
use FindBin qw/$Bin/;
use lib qq{$Bin/../lib};
use Path::Tiny qw/path/;
use Data::Dumper;
use DateTime;
#------------------------------------------------------------------------------
my $module_name;
BEGIN {
    $module_name = 'WeatherUtils';
    use_ok($module_name);
}

my @functions             = (qw / 
    parse_client_file parse_client_files 
    insert_data_to_database get_database_satement_handles
/);

can_ok( $module_name, @functions );

 
TODO: {
    local $TODO = "Need to create unit tests for all exported functions";
    ok('parse_client_file' ,"Test 'parse_client_file'" );
    ok('parse_client_files' ,"Test 'parse_client_files" );
    ok('insert_data_to_database' ,"Test 'insert_data_to_database" );
    ok('get_database_satement_handles' ,"Test 'get_database_satement_handles'" );

};

done_testing();
#------------------------------------------------------------------------------
__END__
