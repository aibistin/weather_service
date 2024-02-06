/*
 Create two tables to save the weather data 
 Note: All units will be in metric.
*/
DROP TABLE IF EXISTS weather_data;
DROP TABLE IF EXISTS location_coordinate;

CREATE TABLE IF NOT EXISTS location_coordinate (
    id INTEGER PRIMARY KEY autoincrement,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    UNIQUE (latitude, longitude)
);

CREATE TABLE IF NOT EXISTS weather_data (
    location_id INTEGER NOT NULL,
    recorded_date VARCHAR(40) NOT NULL,
    temperature REAL NOT NULL,
    wind_speed REAL NOT NULL,
    wind_direction VARCHAR(20) NOT NULL,
    precipitation_chance REAL NOT NULL,
    FOREIGN KEY (location_id) REFERENCES location_coordinate (id)
);
CREATE UNIQUE INDEX weather_data_loc_idx ON weather_data(location_id, recorded_date);