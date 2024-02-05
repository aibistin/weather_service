
=pod

Name: Parse_Weather_JSON.pm  To parse JSON weather data given a specific configuration.


Usage: 
    $json_parser = Parse_Weather_JSON->new(
        {
            wanted_fields_config => get_wanted_field_configs(),
            json_data             => $json_data,
        }
    );

    my $weather_forecast_h = $json_parser->parse_weather_data();

Returns:
{
          'longitude' => '-73.91525',
          'latitude' => '40.722767'
          'timezone' => 'America/New_York',
          'temperature' => [
                             '6.3',
                             ...,
                           ],
          'precipitation_chance' => [
                                      '97',
                                      ...,
                                    ],
          'wind_speed' => [
                            '18.6',
                             ...,
                          ],
          'wind_direction' => [
                                '336',
                                '...',
                              ],
          'time' => [
                      '2024-02-02T05:00:00Z',
                             ...,
                    ],
        };

=cut

package Parse_Weather_JSON;
use strict;
use warnings;
use Class::Accessor "antlers";
use JSON qw/ from_json /;
use Carp qw/carp confess/;

has wanted_fields_config => (
    is  => "ro",
    isa => sub {
        confess
"Parse_Weather_JSON attribute 'wanted_fields_config' must be an Array Reference!"
          unless ( ref $_[0] eq 'ARRAY' );
    }
);

has json_data => (
    is  => "ro",
    isa => "Str",
);

sub parse_weather_data {
    my $self      = shift;
    if ( not $self->json_data or ( not length $self->json_data > 50 ) ) {
        confess "Method 'parse_weather_data' got no JSON data to parse!";
    }
    my $json_data = eval { from_json $self->json_data};
    confess "Faied parsing JSON: $@" if $@;
    # carp "JSON Data: " . $json_data;
    
    my %weather_forecast;
    for my $wanted_field_h ( @{ $self->wanted_fields_config } ) {
        my $got_data =
          _get_wanted_data( $json_data, $wanted_field_h, \%weather_forecast );
        while ( my ( $field_name, $field_value ) = each %{$got_data} ) {
            $weather_forecast{$field_name} = $field_value
              unless defined $weather_forecast{$field_name};
        }
    }
    return \%weather_forecast;
}

sub _get_wanted_data {
    my ( $json_data, $wanted_field_h, $weather_forecast_h ) = @_;
    my $required_timezone = 'UTC';

    while ( my ( $wanted_field_name, $normalised_field_name ) =
        each %{$wanted_field_h} )
    {
        if (    ( ref $normalised_field_name eq 'HASH' )
            and ( keys %{$normalised_field_name} ) )
        {
            _get_wanted_data( $json_data->{$wanted_field_name},
                $normalised_field_name, $weather_forecast_h );
        }
        elsif ( not ref $normalised_field_name  ) {    # Scalar Value
            my $json_field_value = $json_data->{$wanted_field_name};
            if ( $normalised_field_name eq 'time' ) {
                my $time_zone = $weather_forecast_h->{timezone};
                $json_field_value = $wanted_field_h->{times_convert_func}
                  ->( $json_field_value, $time_zone );
            }
            $weather_forecast_h->{$normalised_field_name} = $json_field_value;
        }
    }
    return $weather_forecast_h;
}

1;
