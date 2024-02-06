package weather_service;
use Dancer2;
use Data::Dumper;
use DateTime;
use Path::Tiny qw/path/;
use Dancer2::Plugin::Database;

# Local Modules
use Parse_Weather_JSON;
use Parse_Weather_XML;
use WeatherUtils qw/
    parse_client_file
    parse_client_files
    insert_data_to_database 
    get_database_satement_handles
/;

# All responses will be in JSON format
set serializer => 'JSON';

our $VERSION = '0.1';
my %converter_function;
my $base_client_dir  = config->{client_files}{directory};
my $base_archive_dir = config->{client_files}{archive};
my $sql              = 'select id, title, text from entries order by id desc';

# my $sth = database->prepare($sql);
# $sth->execute;

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

get '/' => sub {
    debug "Inside base '/' directory";
    return { wrong_url => "Try the '/client/:name' path instead", };
};

get '/client/:name' => sub {

    my $client_name = route_parameters->get('name');
    my $client_dir  = path( $base_client_dir . "/$client_name" );
    debug "Client dir: " . $client_dir->stringify;

    if ( ( not $client_dir->exists ) or ( not $client_dir->is_dir ) ) {
        warning "No client directory for $client_name";
        send_error {
            error   => '404',
            path    => request->path,
            message => "No file directory for client $client_name"
        };
    }
    my $file_type = config->{client_weather_fields}{$client_name}{file}{type};

    my @client_weather_files = $client_dir->children(qr/\.$file_type\z/);

    debug "Client Files: " . $_->stringify for @client_weather_files;

    if ( not @client_weather_files ) {
        warning "Client $client_name has no $file_type weather files";
        return {
            client  => $client_name,
            message => "Has no $file_type weather files",
        };
    }

    my $times_convert_function_name =
      config->{client_weather_fields}{$client_name}{file}{times_convert_func};

    debug "Client file type: $file_type";
    my $wanted_fields =
      config->{client_weather_fields}{$client_name}{wanted_fields};

    #TODO Improve how this is accessed
    @$wanted_fields[1]->{daily}{times_convert_func} =
      $converter_function{$times_convert_function_name};
    debug "Wanted Fields: " . Dumper($wanted_fields) . "\n";

    #TODO Validate all input data
    my $requested_weather_data = eval {
        parse_client_files( \@client_weather_files, $wanted_fields,
            $file_type );
    };

    if ($@) {
        error "Error parsing client files: $@";
    }
    else {
        eval { insert_data_to_database($requested_weather_data, database()) };
        error "Error inserting weather data to database: $@" if $@;
    }

    return {
        client_name  => $client_name,
        weather_data => $requested_weather_data
    };
};

# Default route
any qr{.*} => sub {
    status 'not_found';

    send_error {
        error   => '404',
        reason  => "Wrong URL",
        message => "No client"
    };

};

hook before_serializer => sub {
    my $content = shift;
    debug "Data before serialize: " . Dumper($content) . "\n";
};

hook database_error => sub {
    my $error = shift;
    die $error;
};

#---------------------------------------------------------------
#  Helper Functions
#---------------------------------------------------------------

# Converts the date to UTC Date Time
%converter_function = (
    yyyy_mm_dd_convert_func => sub {
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
);
#
1;
