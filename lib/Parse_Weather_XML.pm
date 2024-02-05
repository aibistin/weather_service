
=pod

Name: Parse_Weather_XML.pm  To parse XML weather data given a specific configuration.

Usage: 
    $xml_parser = Parse_Weather_XML->new(
        {
            wanted_fields_config => get_wanted_field_configs(),
            xml_data             => $xml_data,
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

package Parse_Weather_XML;
use strict;
use warnings;
use Class::Accessor "antlers"; # Allows declaring Class attributes using 'has'
use XML::Twig;
use Carp qw/carp confess/;

has wanted_fields_config => (
    is  => "ro",
    isa => sub {
        confess "'wanted_fields_config' must be an Array Reference!"
          unless ( ref $_[0] eq 'ARRAY' );
    }
);

has xml_data => (
    is  => "rw",
    isa => "Str",
);

sub parse_weather_data {
    my $self         = shift;
    my $twig = eval {new XML::Twig()->parse( $self->xml_data )};
    confess "Faied parsing XML: $@" if $@;

    my %weather_forecast;
    my $next_section;

    for my $wanted_field_h ( @{ $self->wanted_fields_config } ) {
        if ( not defined $next_section ) {
            $next_section = $twig->root;
        }
        elsif ( !ref $wanted_field_h ) {
            $next_section = $next_section->first_child('daily');
        }
        my $got_data = _get_section_data( $next_section, $wanted_field_h,
            \%weather_forecast );

        while ( my ( $field_name, $field_value ) = each %{$got_data} ) {
            $weather_forecast{$field_name} = $field_value
              unless defined $weather_forecast{$field_name};
        }
    }

    return \%weather_forecast;
}

sub _get_section_data {
    my ( $section, $wanted_field_h, $weather_forecast_h ) = @_;

    # print "Section Name: " . $section->name . "\n";
    while ( my ( $wanted_field_name, $normalised_field_name ) =
        each %{$wanted_field_h} )
    {
        if (    ( ref $normalised_field_name eq 'HASH' )
            and ( keys %{$normalised_field_name} ) )
        {
            _get_section_data( $section->first_child($wanted_field_name),
                $normalised_field_name, $weather_forecast_h );
        }
        elsif ( !ref $normalised_field_name ) {

            # print "Normalized name: $normalised_field_name\n";
            my $xml_field_value =
              [ ( $section->children_trimmed_text($wanted_field_name) ) ];

            if ( $normalised_field_name eq 'time' ) {
                my $time_zone = $weather_forecast_h->{timezone};

                #TODO Proide better error handling
                warn("No Time Zone provided!") unless $time_zone;
                $xml_field_value = $wanted_field_h->{times_convert_func}
                  ->( $xml_field_value, $time_zone // 'UTC' );
            }

            # Single value lists to be converted to scalars.
            if (    ( ref $xml_field_value eq 'ARRAY' )
                and ( scalar @{$xml_field_value} <= 1 ) )
            {
                $xml_field_value = shift @{$xml_field_value};
            }
            $weather_forecast_h->{$normalised_field_name} = $xml_field_value;
        }
    }
    return $weather_forecast_h;
}
1;
