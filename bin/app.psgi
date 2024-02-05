#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";


# use this block if you don't need middleware, and only have a single target Dancer app to run here
use weather_service;

weather_service->to_app;

=begin comment
# use this block if you want to include middleware such as Plack::Middleware::Deflater

use weather_service;
use Plack::Builder;

builder {
    enable 'Deflater';
    weather_service->to_app;
}

=end comment

=cut

=begin comment
# use this block if you want to mount several applications on different path

use weather_service;
use weather_service_admin;

use Plack::Builder;

builder {
    mount '/'      => weather_service->to_app;
    mount '/admin'      => weather_service_admin->to_app;
}

=end comment

=cut

