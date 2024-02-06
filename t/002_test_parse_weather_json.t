#===============================================================================
#
#   NAME: 002_test_parse_weather_json.t
#
#   Tests Module: Parse_Weather_JSON.pm
#        
#   Given: A sample weather report in JSON format
#   Should return a Perl Hash with values for the below fields.
#         longitude 
#         latitude 
#         temperature
#         precipitation_chance 
#         wind_speed 
#         wind_direction 
#         time
#         timezone   # Not a required field, but is needed convert the date/time
#                    # to UTC time.
#
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
    $module_name = 'Parse_Weather_JSON';
    use_ok($module_name);
}

my @methods             = (qw /parse_weather_data/);
my @expect_weather_keys = sort qw/
  longitude latitude timezone temperature
  precipitation_chance wind_speed wind_direction time
  /;
my $json_file            = path("$Bin/infiles/open_meteo_maspeth_daily.json");


subtest 'Should have a good input JSON file.' => sub {
    plan tests => 2;
    isa_ok( $json_file, 'Path::Tiny' );
    cmp_ok( scalar ( $json_file->lines() ),
        '>=', 1, "The input file should have at least one line of data" ) || BAIL_OUT("Bad JSON file");
};

my $json_parser;
subtest 'Should have a good JSON parsing module.' => sub {
    plan tests => 2;

    can_ok( $module_name, @methods );
    $json_parser = Parse_Weather_JSON->new(
        {
            wanted_fields_config => get_wanted_field_configs(),
            json_data             => $json_file->slurp,
        }
    );
    isa_ok( $json_parser, $module_name );
};

subtest 'Should parse the correct values from the JSON file.' => sub {
    plan tests => 2;
    my $weather_forecast = $json_parser->parse_weather_data();
    isa_ok( $weather_forecast, 'HASH',
        "parse_weather_data should return a Hash" );

    my @got_weather_keys = sort keys %{$weather_forecast};

    is_deeply( \@got_weather_keys, \@expect_weather_keys,
        "Should get weather fields: @{[ join ', ', @expect_weather_keys]}" );
};

done_testing();

#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------
sub get_wanted_field_configs {
    return [
        {
            longitude => 'longitude',
            latitude  => 'latitude',
            timezone  => 'timezone',
        },
        {
            daily => {
                time               => 'time',
                times_convert_func => sub {
                    my ( $times_in, $time_zone ) = @_;
                    my @utc_times;
                    $times_in = [$times_in]
                      unless ( ref $times_in );

                    for my $yyyy_mm_dd ( @{$times_in} ) {
                        my ( $year, $month, $day ) =
                          split( /\s*-\s*/, $yyyy_mm_dd );
                        my $dt = DateTime->new(
                            year      => $year,
                            month     => $month,
                            day       => $day,
                            time_zone => $time_zone
                        )->set_time_zone('UTC');
                        push( @utc_times, $dt->rfc3339 );
                    }
                    return \@utc_times;
                },
                temperature_2m_max            => 'temperature',
                precipitation_probability_max => 'precipitation_chance',
                wind_speed_10m_max            => 'wind_speed',
                wind_direction_10m_dominant   => 'wind_direction',
            },
        }
    ];
}

#------------------------------------------------------------------------------
__END__
