package weather_service;
use Dancer2;
use Data::Dumper;
use DateTime;
use Path::Tiny qw/path/;
# Local Modules 
use Parse_Weather_JSON;
use Parse_Weather_XML;

# All responses will be in JSON format
set serializer => 'JSON';

our $VERSION = '0.1';
my %converter_function;
my $base_client_dir  = config->{client_files}{directory};
my $base_archive_dir = config->{client_files}{archive};

get '/' => sub {
    debug "Inside base '/' directory";
    return {
        wrong_url => "Try the '/client/:name' path instead",
    }
};


get '/client/:name' => sub {

    my $client_name = route_parameters->get('name');
    my $client_dir = path( $base_client_dir . "/$client_name" );
    debug "Client dir: " . $client_dir->stringify;

    if ( ( not $client_dir->exists ) or ( not $client_dir->is_dir ) ) {
        warning "No client directory for $client_name";
        send_error {
            error   => '404',
            path    => request->path,
            message => "No file directory for client $client_name"
        };
        pass;
    }
    my $file_type = config->{client_weather_fields}{$client_name}{file}{type};

    my @client_weather_files = $client_dir->children(qr/\.$file_type\z/);
    debug "Client Files: " . $_->stringify for @client_weather_files;
    if ( not @client_weather_files ) {
        warning "Client $client_name has no $file_type weather files now";
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

    my @requested_weather_data;

    for my $weather_file (@client_weather_files) {
        info "Weather file: " . $weather_file->basename;
        my $weather_data_h = parse_client_file(
            {
                file_type           => $file_type,
                weather_file         => $weather_file,
                wanted_fields_config => $wanted_fields,
            }
        );
        push  @requested_weather_data ,$weather_data_h;
        #TODO Move eache parsed file to the archive
    }
    return {
        client_name  => $client_name,
        weather_data => \@requested_weather_data
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
    info "Data before serialize: " . Dumper($content) . "\n";
};

#---------------------------------------------------------------
#  Helper Functions
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
    my ($parser,$error_msg);

    my %parser_params = (
        wanted_fields_config          => $param->{wanted_fields_config},
        $param->{file_type} . '_data' => $param->{weather_file}->slurp,
    );

    if ( lc $param->{file_type} eq 'json' ) {
        $parser = eval{Parse_Weather_JSON->new( \%parser_params )};
        $error_msg = $@;
    }
    elsif ( lc $param->{file_type} eq 'xml' ) {
        $parser = eval{Parse_Weather_XML->new( \%parser_params )};
        $error_msg = $@;
    }
    else {
        error
          "Only accepting json and xml file types. Not '$param->{file_type}'";
    }
    error "Error in $param->{file_type} parser: $error_msg" if $error_msg;
    return $parser ? $parser->parse_weather_data() : undef;
}

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
