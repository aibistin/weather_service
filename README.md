# Weather Service

## Parses Weather Files

- Daily weather files can be from the [Meteo](https://open-meteo.com/en/docs) or any other weather API.
- File are copied to their specific client directory
  - Eg. 'client_a' will place thier, JSON or XML files  in 'client_files/infiles/client_a/'
- Call this service giving it the client name('client_a')
  - This service will parse the client file and retun results for the required fields
    - Latitude 
    - Longitude
    - UTC Time
    - Temperature
    - Wind Speed
    - Wind Direction
    - Precipitation Chance
- A configuration needs to be added for each client and file type
  - The `dev` config file is: 'environments/development.yml'



### Clone this repo to your test machine

#### CPAN nodules you may need to install or use the 'carton' package manager

```bash
cpanm DateTime
cpanm Class::Accessor
cpanm JSON
cpanm XML::Twig
cpanm Test::More
# Installing Task::Dancer2 installs a lot of unnecessary modules and takes a while. 
# It may not be necessary if you use `carton install`
cpanm Task::Dancer2
```

#### You could also run `carton install` in the project directory.

[Carton Docs](https://metacpan.org/pod/Carton#TUTORIAL)


#### Run Some Unit Tests and Route Tests

Run Tests from the Project Directory

```bash
prove -v t/
```

Run Tests Individually

```bash
prove -v  t/00_test_parse_weather_xml.t
prove -v  t/00_test_parse_weather_json.t
prove -v  003_base.t  
prove -v  004_client_file_route.t 
```

Run the weather_service application from the project directory

```bash
# Runs in localhost
plackup -p 5000 bin/app.psgi
# CTL-c will shut it down
```

Use `curl` to test the parsing app

**Note**: Two clients have been setup for testing. 'client_a' and 'client_b'

```bash
curl --request GET --url http://0.0.0.0:5000/client/client_a
curl --request GET --url http://0.0.0.0:5000/client/client_b
```

[Or in the browser](http://0.0.0.0:5000/client/client_a)

#### TODO

1. Add more testing
2. Add input validation
3. Store parsed data to SQLite
4. Call Weather API's directly
5. Process hourly weather.

