#===============================================================================
#
#         NAME: WeatherUtils.pm
#         Exports some utility functions;
#
#===============================================================================
use strict;
use warnings;
use v5.34;
package  WeatherUtils;

use Exporter qw/import/;
use Parse_Weather_JSON;
use Parse_Weather_XML;

#-------------------------------------------------------------------------------
#                Exported Functions
#-------------------------------------------------------------------------------
our @EXPORT_OK = qw (
    parse_client_file
    parse_client_files
    insert_data_to_database 
    get_database_satement_handles
);

#-------------------------------------------------------------------------------
#                SQL Statements
#-------------------------------------------------------------------------------
my $insert_location_sql = qq{
    INSERT INTO location_coordinate ( latitude, longitude )
    VALUES (?,?);
};

my $insert_weather_sql = qq{
    INSERT OR REPLACE INTO weather_data ( 
    location_id, recorded_date, temperature,
    wind_speed, wind_direction, precipitation_chance
    ) 
    VALUES (?,?,?,?,?,?);
};

my $select_location_id_sql = qq{
    SELECT id FROM location_coordinate
    WHERE  latitude = ? AND  longitude = ?;
};

my $select_weather_sql = qq{
    SELECT *  FROM weather_data wd
    INNER JOIN location_coordinate lc
    ON wd.location_id = lc.id 
    ORDER BY wd.recorded_date DESC;
};


#-------------------------------------------------------------------------------
#  File Functions
#-------------------------------------------------------------------------------
# parse_client_file_
# Pass: {
#    {
#      client_weather_file_s => $weather_file_arrayref, 
#      wanted_fields_config => [{...},{...}],
#      file_type,   => 'json'   # json or xml for now
#    }
# Returns:
#  Array of requested parsed weather data in JSON format
#---------------------------------------------------------------
sub parse_client_files {
    my ( $client_weather_files, $wanted_fields, $file_type ) = @_;
    my @requested_weather_data;

    for my $weather_file ( @{ $client_weather_files || [] } ) {
        print "Weather file: " . $weather_file->basename . "\n";
        my $weather_data_h = parse_client_file(
            {
                file_type            => $file_type,
                weather_file         => $weather_file,
                wanted_fields_config => $wanted_fields,
            }
        );
        push @requested_weather_data, $weather_data_h;
    }
    return \@requested_weather_data;
}

#---------------------------------------------------------------
# parse_client_file
# Pass: {
#    {
#      file_type,   => 'json'   # json or xml for now
#      weather_file => $weather_file,  # Path::Tiny obj.
#      wanted_fields_config => [{...},{...}],
#    }
# Returns:
#  Requested parsed weather data in JSON format
#---------------------------------------------------------------
sub parse_client_file {
    my $param = shift;
    my ( $parser, $error_msg );

    my %parser_params = (
        wanted_fields_config          => $param->{wanted_fields_config},
        $param->{file_type} . '_data' => $param->{weather_file}->slurp,
    );

    if ( lc $param->{file_type} eq 'json' ) {
        $parser    = eval { Parse_Weather_JSON->new( \%parser_params ) };
        $error_msg = $@;
    }
    elsif ( lc $param->{file_type} eq 'xml' ) {
        $parser    = eval { Parse_Weather_XML->new( \%parser_params ) };
        $error_msg = $@;
    }
    else {
        print(
          "ERROR! Only accepting json and xml file types. Not '$param->{file_type}'\n");
    }
    print "\nError in $param->{file_type} parser: $error_msg\n" if $error_msg;
    return $parser ? $parser->parse_weather_data() : undef;
}

#TODO Validate all input data
sub insert_data_to_database {
    my $requested_weather_data = shift;
    my $dbh                    = shift;
    my $db_sth_h               = get_database_satement_handles($dbh);

  INSERT_TABLES_LOOP:
    for my $weather_data ( @{ $requested_weather_data || [] } ) {
        my ( $is_success, $location_id );
        my $longitude = $weather_data->{longitude};
        my $latitude  = $weather_data->{latitude};

        $db_sth_h->{location_select_sth}->execute( $latitude, $longitude );
        my @row = $db_sth_h->{location_select_sth}->fetchrow_array();
        $location_id = $row[0] if @row;
        if ( not $location_id ) {
            $is_success = $db_sth_h->{location_insert_sth}
              ->execute( $latitude, $longitude );
            if ( not $is_success ) {
                print
"ERROR: Failed inserting: la:<$latitude>, lo:<$longitude> to location table\n";
                next INSERT_TABLES_LOOP;
            }
            $location_id = $db_sth_h->{location_insert_sth}
              ->last_insert_id( "", "", "", "" );
        }

        print("Location ID: $location_id\n");

        my $record_ct = @{ $weather_data->{time} };

        if ( $record_ct > 0 ) {

            $dbh->{AutoCommit} = 1;
            $dbh->begin_work;   # AC is off for the duration of the transaction.

            eval {
                for ( my $i = 0 ; $i < $record_ct ; $i++ ) {
                    my $recorded_date = @{ $weather_data->{time} }[$i];

                    $is_success = $db_sth_h->{weather_insert_sth}->execute(
                        $location_id,
                        $recorded_date,
                        @{ $weather_data->{temperature} }[$i],
                        @{ $weather_data->{wind_speed} }[$i],
                        @{ $weather_data->{wind_direction} }[$i],
                        @{ $weather_data->{precipitation_chance} }[$i]
                    );

                    my $msg = "LocId:<$location_id>, date:<$recorded_date>";

                    if ($is_success) {
                        print "Inserted: $msg\n";
                    }
                    else {
                        print "ERROR! Failed inserting: $msg\n";
                    }
                }
            };
            if ($@) {
                print("ERROR! No data inserted to weather_table: $@\n");
                $db_sth_h->{weather_insert_sth}->finish;
                $dbh->rollback;
            }
            else {
                print("Data is committed to the weather_table\n");
                $dbh->commit;
            }
        }
        else{
            print("No weather records for location id: $location_id\n");
        }
    }
}

#-------------------------------------------------------------------------------
#  Database Functions
#-------------------------------------------------------------------------------

sub get_database_satement_handles {
    my $dbh = shift;
    return {
        location_select_sth => $dbh->prepare($select_location_id_sql),
        weather_select_sth  => $dbh->prepare($select_weather_sql),
        # Insert statements
        location_insert_sth => $dbh->prepare($insert_location_sql),
        weather_insert_sth  => $dbh->prepare($insert_weather_sql),
    };
}

#-------------------------------------------------------------------------------
1;

