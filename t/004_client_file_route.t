use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use weather_service;
use Test::More tests => 3;
use Plack::Test;
use HTTP::Request::Common;
use Ref::Util qw<is_coderef>;
use Data::Dumper;
use JSON::PP /decode_json/;

my $app = weather_service->to_app;

ok( is_coderef($app), 'Got the Weather Service app' );

my $test = Plack::Test->create($app);

subtest "Route '/' should return a JSON message" => sub {
    plan tests => 2;
    my $expect_home_res = { wrong_url => "Try the '/client/:name' path instead" };
    my $res = $test->request( GET '/' );
    ok( $res->is_success, '[GET /] Successful request' );
    my $decoded_content = decode_json $res->content;
    is_deeply( $decoded_content, $expect_home_res,
        "Should get 'wrong_url' message for route '/'" );
    done_testing();
};

subtest "Route '/client/:name' should return parsed JSON Weather Data" => sub {
    plan tests => 2;
    my $client_name     = 'client_a';
    my $route           = "/client/$client_name";
    my $expect_json = get_expected_json_weather_data();

    my $res = $test->request( GET $route );
    ok( $res->is_success, "[GET $route] Successful request" );

    my $decoded_content = decode_json $res->content;
    is_deeply( $decoded_content, $expect_json,
        "Should get JSON weather data for route '$route'" );
    done_testing();
};

#------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------
sub get_expected_json_weather_data {
    my $json_str = '';
    while ( my $json_test_data_line = <DATA> ) {
        # chomp($json_test_data_line);
        $json_str .= $json_test_data_line;
    }
    return decode_json $json_str;
}

__DATA__
{
    "weather_data": [
        {
            "latitude": 40.722767,
            "timezone": "America/New_York",
            "temperature": [
                6.3,
                2.6,
                6.5,
                4.8,
                4.0,
                5.1,
                10.7
            ],
            "time": [
                "2024-02-02T05:00:00Z",
                "2024-02-03T05:00:00Z",
                "2024-02-04T05:00:00Z",
                "2024-02-05T05:00:00Z",
                "2024-02-06T05:00:00Z",
                "2024-02-07T05:00:00Z",
                "2024-02-08T05:00:00Z"
            ],
            "wind_speed": [
                18.6,
                20.1,
                12.6,
                19.1,
                14.5,
                9.7,
                11.5
            ],
            "wind_direction": [
                336,
                347,
                355,
                12,
                11,
                339,
                250
            ],
            "longitude": -73.91525,
            "precipitation_chance": [
                97,
                0,
                0,
                0,
                0,
                0,
                0
            ]
        }
    ],
    "client_name": "client_a"
}