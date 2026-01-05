module weather_oracle::weather_oracle {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::string::String;
    use sui::vector;
    use sui::option::Option;

    /// Admin capability object for privileged operations
    /// Equivalent to OpenZeppelin's AccessControl with DEFAULT_ADMIN_ROLE
    public struct AdminCap has key, store {
        id: UID,
    }

    /// Weather oracle metadata
    public struct WeatherOracle has key {
        id: UID,
        admin_cap: AdminCap,
        name: String,
        description: String,
        cities: Table<u32, CityWeather>,
    }

    /// City weather data structure
    public struct CityWeather has key {
        id: UID,
        geoname_id: u32,
        name: String,
        country: String,
        latitude: u32,
        positive_latitude: bool,
        longitude: u32,
        positive_longitude: bool,
        weather_id: u16,
        temp: u32,
        pressure: u32,
        humidity: u8,
        visibility: u16,
        wind_speed: u16,
        wind_deg: u16,
        has_wind_gust: bool,
        wind_gust: u16,
        clouds: u8,
        dt: u32,
    }

    /// Weather snapshot NFT - equivalent to ERC721 WeatherNFT
    public struct WeatherSnapshot has key {
        id: UID,
        geoname_id: u32,
        name: String,
        country: String,
        latitude: u32,
        positive_latitude: bool,
        longitude: u32,
        positive_longitude: bool,
        weather_id: u16,
        temp: u32,
        pressure: u32,
        humidity: u8,
        visibility: u16,
        wind_speed: u16,
        wind_deg: u16,
        has_wind_gust: bool,
        wind_gust: u16,
        clouds: u8,
        dt: u32,
    }

    /// Events
    public struct OracleInitialized has copy, drop {
        admin: address,
        oracle_address: address,
        name: String,
        description: String,
    }

    public struct CityAdded has copy, drop {
        geoname_id: u32,
        name: String,
        country: String,
    }

    public struct CityRemoved has copy, drop {
        geoname_id: u32,
    }

    public struct CityUpdated has copy, drop {
        geoname_id: u32,
        weather_id: u16,
        temp: u32,
        pressure: u32,
        humidity: u8,
        visibility: u16,
        wind_speed: u16,
        wind_deg: u16,
        has_wind_gust: bool,
        wind_gust: u16,
        clouds: u8,
        dt: u32,
    }

    public struct SnapshotMinted has copy, drop {
        token_id: UID,
        geoname_id: u32,
    }

    /// Initialize the weather oracle
    public fun init(name: String, description: String, ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        let oracle = WeatherOracle {
            id: object::new(ctx),
            admin_cap,
            name,
            description,
            cities: table::new(ctx),
        };

        // Emit initialization event
        event::emit(OracleInitialized {
            admin: tx_context::sender(ctx),
            oracle_address: object::uid_to_address(&oracle.id),
            name: string::utf8(name),
            description: string::utf8(description),
        });

        // Share the oracle object so anyone can read from it
        transfer::share_object(oracle);
    }

    /// Add a new city to the oracle (admin only)
    public entry fun add_city(
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        name: String,
        country: String,
        latitude: u32,
        positive_latitude: bool,
        longitude: u32,
        positive_longitude: bool,
        _: &AdminCap,
        ctx: &mut TxContext
    ) {
        // Check if city already exists
        assert!(!table::contains(&oracle.cities, geoname_id), 1001); // 1001 = City already exists

        let city = CityWeather {
            id: object::new(ctx),
            geoname_id,
            name,
            country,
            latitude,
            positive_latitude,
            longitude,
            positive_longitude,
            weather_id: 0,
            temp: 0,
            pressure: 0,
            humidity: 0,
            visibility: 0,
            wind_speed: 0,
            wind_deg: 0,
            has_wind_gust: false,
            wind_gust: 0,
            clouds: 0,
            dt: 0,
        };

        table::add(&mut oracle.cities, geoname_id, city);

        // Emit city added event
        event::emit(CityAdded {
            geoname_id,
            name: string::utf8(name),
            country: string::utf8(country),
        });
    }

    /// Remove a city from the oracle (admin only)
    public entry fun remove_city(
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        _: &AdminCap,
        ctx: &mut TxContext
    ) {
        assert!(table::contains(&oracle.cities, geoname_id), 1002); // 1002 = City not found

        let city = table::remove(&mut oracle.cities, geoname_id);
        object::delete(city);

        // Emit city removed event
        event::emit(CityRemoved { geoname_id });
    }

    /// Update weather measurements for a city (admin only)
    public entry fun update_city(
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        weather_id: u16,
        temp: u32,
        pressure: u32,
        humidity: u8,
        visibility: u16,
        wind_speed: u16,
        wind_deg: u16,
        has_wind_gust: bool,
        wind_gust: u16,
        clouds: u8,
        dt: u32,
        _: &AdminCap,
        ctx: &mut TxContext
    ) {
        let city = table::borrow_mut(&mut oracle.cities, geoname_id);
        city.weather_id = weather_id;
        city.temp = temp;
        city.pressure = pressure;
        city.humidity = humidity;
        city.visibility = visibility;
        city.wind_speed = wind_speed;
        city.wind_deg = wind_deg;
        city.has_wind_gust = has_wind_gust;
        city.wind_gust = if (has_wind_gust) wind_gust else 0;
        city.clouds = clouds;
        city.dt = dt;

        // Emit city updated event
        event::emit(CityUpdated {
            geoname_id,
            weather_id,
            temp,
            pressure,
            humidity,
            visibility,
            wind_speed,
            wind_deg,
            has_wind_gust,
            wind_gust: city.wind_gust,
            clouds,
            dt,
        });
    }

    /// Check if a city exists
    public fun city_exists(oracle: &WeatherOracle, geoname_id: u32): bool {
        table::contains(&oracle.cities, geoname_id)
    }

    /// Get city name
    public fun city_name(oracle: &WeatherOracle, geoname_id: u32): String {
        let city = table::borrow(&oracle.cities, geoname_id);
        string::utf8(city.name)
    }

    /// Get city country
    public fun city_country(oracle: &WeatherOracle, geoname_id: u32): String {
        let city = table::borrow(&oracle.cities, geoname_id);
        string::utf8(city.country)
    }

    /// Get city latitude
    public fun city_latitude(oracle: &WeatherOracle, geoname_id: u32): u32 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.latitude
    }

    /// Get city positive latitude flag
    public fun city_positive_latitude(oracle: &WeatherOracle, geoname_id: u32): bool {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.positive_latitude
    }

    /// Get city longitude
    public fun city_longitude(oracle: &WeatherOracle, geoname_id: u32): u32 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.longitude
    }

    /// Get city positive longitude flag
    public fun city_positive_longitude(oracle: &WeatherOracle, geoname_id: u32): bool {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.positive_longitude
    }

    /// Get city weather ID
    public fun city_weather_id(oracle: &WeatherOracle, geoname_id: u32): u16 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.weather_id
    }

    /// Get city temperature
    public fun city_temp(oracle: &WeatherOracle, geoname_id: u32): u32 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.temp
    }

    /// Get city pressure
    public fun city_pressure(oracle: &WeatherOracle, geoname_id: u32): u32 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.pressure
    }

    /// Get city humidity
    public fun city_humidity(oracle: &WeatherOracle, geoname_id: u32): u8 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.humidity
    }

    /// Get city visibility
    public fun city_visibility(oracle: &WeatherOracle, geoname_id: u32): u16 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.visibility
    }

    /// Get city wind speed
    public fun city_wind_speed(oracle: &WeatherOracle, geoname_id: u32): u16 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.wind_speed
    }

    /// Get city wind degree
    public fun city_wind_deg(oracle: &WeatherOracle, geoname_id: u32): u16 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.wind_deg
    }

    /// Get city has wind gust flag
    public fun city_has_wind_gust(oracle: &WeatherOracle, geoname_id: u32): bool {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.has_wind_gust
    }

    /// Get city wind gust
    public fun city_wind_gust(oracle: &WeatherOracle, geoname_id: u32): u16 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.wind_gust
    }

    /// Get city clouds
    public fun city_clouds(oracle: &WeatherOracle, geoname_id: u32): u8 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.clouds
    }

    /// Get city timestamp
    public fun city_dt(oracle: &WeatherOracle, geoname_id: u32): u32 {
        let city = table::borrow(&oracle.cities, geoname_id);
        city.dt
    }

    /// Mint a weather snapshot NFT (equivalent to ERC721 mint)
    public fun mint_snapshot(
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        ctx: &mut TxContext
    ): WeatherSnapshot {
        let city = table::borrow(&oracle.cities, geoname_id);

        let snapshot = WeatherSnapshot {
            id: object::new(ctx),
            geoname_id: city.geoname_id,
            name: string::utf8(city.name),
            country: string::utf8(city.country),
            latitude: city.latitude,
            positive_latitude: city.positive_latitude,
            longitude: city.longitude,
            positive_longitude: city.positive_longitude,
            weather_id: city.weather_id,
            temp: city.temp,
            pressure: city.pressure,
            humidity: city.humidity,
            visibility: city.visibility,
            wind_speed: city.wind_speed,
            wind_deg: city.wind_deg,
            has_wind_gust: city.has_wind_gust,
            wind_gust: city.wind_gust,
            clouds: city.clouds,
            dt: city.dt,
        };

        // Emit snapshot minted event
        event::emit(SnapshotMinted {
            token_id: object::uid_to_address(&snapshot.id),
            geoname_id: city.geoname_id,
        });

        snapshot
    }
}