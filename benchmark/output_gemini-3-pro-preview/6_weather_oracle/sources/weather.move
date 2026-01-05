module weather_oracle::weather_oracle {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::table::{Self, Table};
    use sui::string::String;

    /// Admin capability object - replaces OpenZeppelin AccessControl
    public struct AdminCap has key, store {
        id: UID,
    }

    /// WeatherOracle metadata - replaces contract storage variables
    public struct WeatherOracle has key {
        id: UID,
        oracle_address: address,
        name: String,
        description: String,
        cities: Table<u32, CityWeather>,
    }

    /// City weather data structure - replaces CityWeather struct
    public struct CityWeather has store {
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
        exists: bool,
    }

    /// Weather snapshot NFT - replaces ERC721 WeatherNFT
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

    /// Initialize the oracle - replaces constructor
    public fun init(
        oracle_name: String,
        oracle_description: String,
        ctx: &mut TxContext
    ) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        let oracle = WeatherOracle {
            id: object::new(ctx),
            oracle_address: tx_context::sender(ctx),
            name: oracle_name,
            description: oracle_description,
            cities: table::new(ctx),
        };

        // Share the oracle object for public access
        transfer::share_object(oracle);

        // Transfer admin capability to sender
        transfer::transfer(admin_cap, tx_context::sender(ctx));

        // Emit initialization event
        event::emit(OracleInitialized {
            admin: tx_context::sender(ctx),
            oracle_address: tx_context::sender(ctx),
            name: oracle_name,
            description: oracle_description,
        });
    }

    /// Add a new city to the oracle (admin only)
    public entry fun add_city(
        oracle: &mut WeatherOracle,
        admin_cap: &AdminCap,
        geoname_id: u32,
        city_name: String,
        country: String,
        latitude: u32,
        positive_latitude: bool,
        longitude: u32,
        positive_longitude: bool,
        ctx: &mut TxContext
    ) {
        // Only admin can call this function
        assert!(exists(admin_cap), 1); // AdminCap must exist

        // Check if city already exists
        assert!(!table::contains(&oracle.cities, geoname_id), 2); // City already exists

        let city = CityWeather {
            geoname_id,
            name: city_name,
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
            exists: true,
        };

        table::add(&mut oracle.cities, geoname_id, city);

        // Emit city added event
        event::emit(CityAdded {
            geoname_id,
            name: city_name,
            country,
        });
    }

    /// Remove a city from the oracle (admin only)
    public entry fun remove_city(
        oracle: &mut WeatherOracle,
        admin_cap: &AdminCap,
        geoname_id: u32,
        ctx: &mut TxContext
    ) {
        // Only admin can call this function
        assert!(exists(admin_cap), 1); // AdminCap must exist

        // Check if city exists
        assert!(table::contains(&oracle.cities, geoname_id), 3); // City not found

        table::remove(&mut oracle.cities, geoname_id);

        // Emit city removed event
        event::emit(CityRemoved {
            geoname_id,
        });
    }

    /// Update weather measurements for a city (admin only)
    public entry fun update_city(
        oracle: &mut WeatherOracle,
        admin_cap: &AdminCap,
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
        ctx: &mut TxContext
    ) {
        // Only admin can call this function
        assert!(exists(admin_cap), 1); // AdminCap must exist

        // Get mutable reference to city
        let city = table::borrow_mut(&mut oracle.cities, geoname_id);
        assert!(city.exists, 3); // City not found

        // Update weather data
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

    /// Mint a weather snapshot NFT
    public entry fun mint_snapshot(
        oracle: &WeatherOracle,
        geoname_id: u32,
        ctx: &mut TxContext
    ): WeatherSnapshot {
        // Get city data
        let city = table::borrow(&oracle.cities, geoname_id);
        assert!(city.exists, 3); // City not found

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

    /// Get city weather data (public read)
    public fun get_city(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): &CityWeather {
        let city = table::borrow(&oracle.cities, geoname_id);
        assert!(city.exists, 3); // City not found
        city
    }

    /// Check if city exists (public read)
    public fun city_exists(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): bool {
        table::contains(&oracle.cities, geoname_id)
    }

    /// Helper function to get city name
    public fun city_name(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): String {
        let city = get_city(oracle, geoname_id);
        string::utf8(city.name)
    }

    /// Helper function to get city country
    public fun city_country(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): String {
        let city = get_city(oracle, geoname_id);
        string::utf8(city.country)
    }

    /// Helper function to get city latitude
    public fun city_latitude(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u32 {
        get_city(oracle, geoname_id).latitude
    }

    /// Helper function to get city positive latitude flag
    public fun city_positive_latitude(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): bool {
        get_city(oracle, geoname_id).positive_latitude
    }

    /// Helper function to get city longitude
    public fun city_longitude(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u32 {
        get_city(oracle, geoname_id).longitude
    }

    /// Helper function to get city positive longitude flag
    public fun city_positive_longitude(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): bool {
        get_city(oracle, geoname_id).positive_longitude
    }

    /// Helper function to get city weather ID
    public fun city_weather_id(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u16 {
        get_city(oracle, geoname_id).weather_id
    }

    /// Helper function to get city temperature
    public fun city_temp(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u32 {
        get_city(oracle, geoname_id).temp
    }

    /// Helper function to get city pressure
    public fun city_pressure(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u32 {
        get_city(oracle, geoname_id).pressure
    }

    /// Helper function to get city humidity
    public fun city_humidity(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u8 {
        get_city(oracle, geoname_id).humidity
    }

    /// Helper function to get city visibility
    public fun city_visibility(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u16 {
        get_city(oracle, geoname_id).visibility
    }

    /// Helper function to get city wind speed
    public fun city_wind_speed(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u16 {
        get_city(oracle, geoname_id).wind_speed
    }

    /// Helper function to get city wind degree
    public fun city_wind_deg(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u16 {
        get_city(oracle, geoname_id).wind_deg
    }

    /// Helper function to get city wind gust flag
    public fun city_has_wind_gust(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): bool {
        get_city(oracle, geoname_id).has_wind_gust
    }

    /// Helper function to get city wind gust value
    public fun city_wind_gust(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u16 {
        get_city(oracle, geoname_id).wind_gust
    }

    /// Helper function to get city clouds
    public fun city_clouds(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u8 {
        get_city(oracle, geoname_id).clouds
    }

    /// Helper function to get city timestamp
    public fun city_dt(
        oracle: &WeatherOracle,
        geoname_id: u32
    ): u32 {
        get_city(oracle, geoname_id).dt
    }
}