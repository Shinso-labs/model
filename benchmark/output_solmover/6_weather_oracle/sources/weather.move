module weather_oracle::weather {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::string::{Self, String};
    use sui::event;

    /// The AdminCap is a capability object that grants its holder administrative privileges
    /// over the WeatherOracle. This replaces Solidity's AccessControl.
    public struct AdminCap has key, store {
        id: UID,
    }

    /// Represents the weather data for a specific city.
    /// This struct has `store` ability, meaning it can be stored inside other objects (like a Table).
    public struct CityWeather has store {
        geoname_id: u32,
        name: String,
        country: String,
        latitude: u32,
        positive_latitude: bool, // N=true, S=false
        longitude: u32,
        positive_longitude: bool, // E=true, W=false
        weather_id: u16,          // condition code
        temp: u32,                // Kelvin
        pressure: u32,            // hPa
        humidity: u8,             // %
        visibility: u16,          // meters
        wind_speed: u16,          // m/s
        wind_deg: u16,            // degrees
        has_wind_gust: bool,      // Option<u16> emulation
        wind_gust: u16,           // m/s (valid iff has_wind_gust)
        clouds: u8,               // %
        dt: u32,                  // epoch seconds
    }

    /// The main WeatherOracle object, which is shared and holds the registry of city weather data.
    /// This replaces the main Solidity contract.
    public struct WeatherOracle has key {
        id: UID,
        name: String,
        description: String,
        cities: Table<u32, CityWeather>, // Mapping from geonameId to CityWeather
        next_snapshot_id: u64,           // Counter for unique NFT IDs
    }

    /// A WeatherSnapshot is an NFT representing a snapshot of a city's weather data at a point in time.
    /// This replaces the WeatherNFT ERC-721 contract.
    public struct WeatherSnapshot has key, store {
        id: UID,
        token_id: u64, // Unique ID for this snapshot, similar to ERC721 tokenId
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

    // ---- Events ----
    /// Emitted when the oracle is initialized.
    public struct OracleInitialized has copy, drop {
        admin: address,
        oracle_id: UID,
        name: String,
        description: String,
    }

    /// Emitted when a new city is added.
    public struct CityAdded has copy, drop {
        geoname_id: u32,
        name: String,
        country: String,
    }

    /// Emitted when a city is removed.
    public struct CityRemoved has copy, drop {
        geoname_id: u32,
    }

    /// Emitted when a city's weather data is updated.
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

    /// Emitted when a weather snapshot NFT is minted.
    public struct SnapshotMinted has copy, drop {
        token_id: u64,
        geoname_id: u32,
        recipient: address,
    }

    /// Module initializer, called once on package publish.
    /// Creates and shares the WeatherOracle object, and transfers the AdminCap to the deployer.
    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        // Create the AdminCap and transfer it to the deployer.
        // This replaces _grantRole(ADMIN_ROLE, msg.sender) in Solidity.
        transfer::transfer(AdminCap { id: object::new(ctx) }, sender);

        // Create the WeatherOracle object and share it.
        // This makes it a globally accessible object that anyone can interact with (read-only)
        // or modify via entry functions that require the AdminCap.
        let oracle = WeatherOracle {
            id: object::new(ctx),
            name: string::utf8(b"Weather Snapshot"), // Default name, can be set in constructor
            description: string::utf8(b"WXSNAP"), // Default description
            cities: table::new(ctx),
            next_snapshot_id: 0,
        };

        // Emit the OracleInitialized event.
        event::emit(OracleInitialized {
            admin: sender,
            oracle_id: object::id(&oracle),
            name: string::utf8(b"Weather Snapshot"),
            description: string::utf8(b"WXSNAP"),
        });

        transfer::share_object(oracle);
    }

    // ---------------- Admin Functions (require AdminCap) ----------------

    /// Helper function to get a mutable reference to a CityWeather, asserting its existence.
    fun require_city_mut(oracle: &mut WeatherOracle, geoname_id: u32): &mut CityWeather {
        assert!(table::contains(&oracle.cities, geoname_id), 0x101); // Error 0x101: City not found
        table::borrow_mut(&mut oracle.cities, geoname_id)
    }

    /// @notice Add a new city to the oracle (idempotent on fresh ids).
    /// Requires an AdminCap to perform this operation.
    public entry fun add_city(
        _admin_cap: &AdminCap, // AdminCap is consumed by reference, proving admin privilege
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        city_name: vector<u8>,
        country: vector<u8>,
        latitude: u32,
        positive_latitude: bool,
        longitude: u32,
        positive_longitude: bool,
        ctx: &mut TxContext,
    ) {
        assert!(!table::contains(&oracle.cities, geoname_id), 0x100); // Error 0x100: City already exists

        let new_city = CityWeather {
            geoname_id,
            name: string::utf8(city_name),
            country: string::utf8(country),
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

        table::add(&mut oracle.cities, geoname_id, new_city);

        event::emit(CityAdded {
            geoname_id,
            name: string::utf8(city_name),
            country: string::utf8(country),
        });
    }

    /// @notice Remove a city from the oracle.
    /// Requires an AdminCap to perform this operation.
    public entry fun remove_city(
        _admin_cap: &AdminCap,
        oracle: &mut WeatherOracle,
        geoname_id: u32,
    ) {
        assert!(table::contains(&oracle.cities, geoname_id), 0x101); // Error 0x101: City not found

        let CityWeather {
            geoname_id: _, name: _, country: _, latitude: _, positive_latitude: _,
            longitude: _, positive_longitude: _, weather_id: _, temp: _, pressure: _,
            humidity: _, visibility: _, wind_speed: _, wind_deg: _, has_wind_gust: _,
            wind_gust: _, clouds: _, dt: _
        } = table::remove(&mut oracle.cities, geoname_id);

        event::emit(CityRemoved { geoname_id });
    }

    /// @notice Update weather measurements for a city.
    /// Requires an AdminCap to perform this operation.
    public entry fun update_city(
        _admin_cap: &AdminCap,
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
    ) {
        let c = require_city_mut(oracle, geoname_id);

        c.weather_id = weather_id;
        c.temp = temp;
        c.pressure = pressure;
        c.humidity = humidity;
        c.visibility = visibility;
        c.wind_speed = wind_speed;
        c.wind_deg = wind_deg;
        c.has_wind_gust = has_wind_gust;
        c.wind_gust = if (has_wind_gust) { wind_gust } else { 0 };
        c.clouds = clouds;
        c.dt = dt;

        event::emit(CityUpdated {
            geoname_id, weather_id, temp, pressure, humidity,
            visibility, wind_speed, wind_deg, has_wind_gust, wind_gust: c.wind_gust, clouds, dt
        });
    }

    // ---------------- Read-only Functions ----------------

    /// Helper function to get an immutable reference to a CityWeather, asserting its existence.
    fun require_city(oracle: &WeatherOracle, geoname_id: u32): &CityWeather {
        assert!(table::contains(&oracle.cities, geoname_id), 0x101); // Error 0x101: City not found
        table::borrow(&oracle.cities, geoname_id)
    }

    public fun city_exists(oracle: &WeatherOracle, geoname_id: u32): bool {
        table::contains(&oracle.cities, geoname_id)
    }

    public fun city_name(oracle: &WeatherOracle, geoname_id: u32): String {
        require_city(oracle, geoname_id).name
    }

    public fun city_country(oracle: &WeatherOracle, geoname_id: u32): String {
        require_city(oracle, geoname_id).country
    }

    public fun city_latitude(oracle: &WeatherOracle, geoname_id: u32): u32 {
        require_city(oracle, geoname_id).latitude
    }

    public fun city_positive_latitude(oracle: &WeatherOracle, geoname_id: u32): bool {
        require_city(oracle, geoname_id).positive_latitude
    }

    public fun city_longitude(oracle: &WeatherOracle, geoname_id: u32): u32 {
        require_city(oracle, geoname_id).longitude
    }

    public fun city_positive_longitude(oracle: &WeatherOracle, geoname_id: u32): bool {
        require_city(oracle, geoname_id).positive_longitude
    }

    public fun city_weather_id(oracle: &WeatherOracle, geoname_id: u32): u16 {
        require_city(oracle, geoname_id).weather_id
    }

    public fun city_temp(oracle: &WeatherOracle, geoname_id: u32): u32 {
        require_city(oracle, geoname_id).temp
    }

    public fun city_pressure(oracle: &WeatherOracle, geoname_id: u32): u32 {
        require_city(oracle, geoname_id).pressure
    }

    public fun city_humidity(oracle: &WeatherOracle, geoname_id: u32): u8 {
        require_city(oracle, geoname_id).humidity
    }

    public fun city_visibility(oracle: &WeatherOracle, geoname_id: u32): u16 {
        require_city(oracle, geoname_id).visibility
    }

    public fun city_wind_speed(oracle: &WeatherOracle, geoname_id: u32): u16 {
        require_city(oracle, geoname_id).wind_speed
    }

    public fun city_wind_deg(oracle: &WeatherOracle, geoname_id: u32): u16 {
        require_city(oracle, geoname_id).wind_deg
    }

    public fun city_has_wind_gust(oracle: &WeatherOracle, geoname_id: u32): bool {
        require_city(oracle, geoname_id).has_wind_gust
    }

    public fun city_wind_gust(oracle: &WeatherOracle, geoname_id: u32): u16 {
        require_city(oracle, geoname_id).wind_gust
    }

    public fun city_clouds(oracle: &WeatherOracle, geoname_id: u32): u8 {
        require_city(oracle, geoname_id).clouds
    }

    public fun city_dt(oracle: &WeatherOracle, geoname_id: u32): u32 {
        require_city(oracle, geoname_id).dt
    }

    // ---------------- Snapshot NFT mint ----------------

    /// @notice Mint a WeatherSnapshot NFT of the current city weather to the caller.
    /// This replaces the mintSnapshot function in the Solidity WeatherOracle.
    public entry fun mint_snapshot(
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        ctx: &mut TxContext,
    ) {
        let c = require_city(oracle, geoname_id);
        let sender = tx_context::sender(ctx);
        let token_id = oracle.next_snapshot_id;
        oracle.next_snapshot_id = oracle.next_snapshot_id + 1;

        let snapshot = WeatherSnapshot {
            id: object::new(ctx),
            token_id,
            geoname_id: c.geoname_id,
            name: string::copy(&c.name),
            country: string::copy(&c.country),
            latitude: c.latitude,
            positive_latitude: c.positive_latitude,
            longitude: c.longitude,
            positive_longitude: c.positive_longitude,
            weather_id: c.weather_id,
            temp: c.temp,
            pressure: c.pressure,
            humidity: c.humidity,
            visibility: c.visibility,
            wind_speed: c.wind_speed,
            wind_deg: c.wind_deg,
            has_wind_gust: c.has_wind_gust,
            wind_gust: c.wind_gust,
            clouds: c.clouds,
            dt: c.dt,
        };

        event::emit(SnapshotMinted { token_id, geoname_id, recipient: sender });
        transfer::transfer(snapshot, sender);
    }

    // ---------------- Getters for WeatherSnapshot (equivalent to WeatherNFT.getSnapshot) ----------------

    /// @notice Get the geoname ID from a WeatherSnapshot.
    public fun snapshot_geoname_id(snapshot: &WeatherSnapshot): u32 {
        snapshot.geoname_id
    }

    /// @notice Get the name from a WeatherSnapshot.
    public fun snapshot_name(snapshot: &WeatherSnapshot): String {
        string::copy(&snapshot.name)
    }

    /// @notice Get the country from a WeatherSnapshot.
    public fun snapshot_country(snapshot: &WeatherSnapshot): String {
        string::copy(&snapshot.country)
    }

    // ... (other snapshot getters can be added similarly if needed)
}