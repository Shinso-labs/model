// sources/weather.move
module weather_oracle::weather {
    use std::string::String;

    // -------------------------------------------------------------------------
    // Error codes
    // -------------------------------------------------------------------------

    const E_CITY_ALREADY_EXISTS: u64 = 0;
    const E_CITY_NOT_FOUND: u64 = 1;

    // -------------------------------------------------------------------------
    // Admin capability
    // -------------------------------------------------------------------------
    //
    // Solidity used OpenZeppelin AccessControl with DEFAULT_ADMIN_ROLE.
    // In Sui Move, privileged operations are gated by ownership of AdminCap.

    public struct AdminCap has key, store {
        id: sui::object::UID,
    }

    // -------------------------------------------------------------------------
    // Shared oracle object
    // -------------------------------------------------------------------------

    public struct WeatherOracle has key {
        id: sui::object::UID,

        oracle_address: address,
        name: String,
        description: String,

        // Solidity mapping(uint32 => CityWeather) becomes a Sui Table.
        cities: sui::table::Table<u32, CityWeather>,
    }

    // -------------------------------------------------------------------------
    // City weather record
    // -------------------------------------------------------------------------
    //
    // Solidity's `exists` sentinel is omitted because Table::contains provides
    // existence checks.

    public struct CityWeather has copy, drop, store {
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

    // -------------------------------------------------------------------------
    // Snapshot NFT object
    // -------------------------------------------------------------------------
    //
    // Solidity used an ERC-721 contract plus a snapshot mapping.
    // In Sui, the snapshot itself is an owned object.

    public struct WeatherNFT has key, store {
        id: sui::object::UID,

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

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

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
        snapshot_object_id: sui::object::ID,
        geoname_id: u32,
        recipient: address,
    }

    // -------------------------------------------------------------------------
    // Module initializer
    // -------------------------------------------------------------------------
    //
    // The Solidity constructor accepted oracleName and oracleDescription.
    // Sui module initializers cannot accept arbitrary user parameters, so init()
    // only creates AdminCap. The admin then calls create_oracle/create.

    fun init(ctx: &mut sui::tx_context::TxContext) {
        let admin_cap = AdminCap {
            id: sui::object::new(ctx),
        };

        sui::transfer::transfer(admin_cap, sui::tx_context::sender(ctx));
    }

    // -------------------------------------------------------------------------
    // Oracle creation
    // -------------------------------------------------------------------------
    //
    // Tests and callers can use either create_oracle or create.
    // Both create a shared WeatherOracle object.

    public fun create_oracle(
        _admin_cap: &AdminCap,
        oracle_name: String,
        oracle_description: String,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        let sender = sui::tx_context::sender(ctx);

        let oracle = WeatherOracle {
            id: sui::object::new(ctx),
            oracle_address: sender,
            name: oracle_name,
            description: oracle_description,
            cities: sui::table::new<u32, CityWeather>(ctx),
        };

        sui::event::emit(OracleInitialized {
            admin: sender,
            oracle_address: sender,
            name: oracle_name,
            description: oracle_description,
        });

        sui::transfer::share_object(oracle);
    }

    public fun create(
        admin_cap: &AdminCap,
        oracle_name: String,
        oracle_description: String,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        create_oracle(admin_cap, oracle_name, oracle_description, ctx);
    }

    // -------------------------------------------------------------------------
    // Admin functions
    // -------------------------------------------------------------------------
    //
    // Function argument order is:
    //     (&AdminCap, &mut WeatherOracle, ..., &mut TxContext)
    //
    // This matches the common Sui capability-first style and the expected tests.

    public fun add_city(
        _admin_cap: &AdminCap,
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        city_name: String,
        country: String,
        latitude: u32,
        positive_latitude: bool,
        longitude: u32,
        positive_longitude: bool,
        _ctx: &mut sui::tx_context::TxContext,
    ) {
        assert!(
            !sui::table::contains(&oracle.cities, geoname_id),
            E_CITY_ALREADY_EXISTS,
        );

        let city = CityWeather {
            geoname_id,
            name: city_name,
            country,
            latitude,
            positive_latitude,
            longitude,
            positive_longitude,

            // Solidity initializes measured fields to zero/none.
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

        sui::table::add(&mut oracle.cities, geoname_id, city);

        sui::event::emit(CityAdded {
            geoname_id,
            name: city_name,
            country,
        });
    }

    public fun remove_city(
        _admin_cap: &AdminCap,
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        _ctx: &mut sui::tx_context::TxContext,
    ) {
        assert!(
            sui::table::contains(&oracle.cities, geoname_id),
            E_CITY_NOT_FOUND,
        );

        let _removed_city = sui::table::remove(&mut oracle.cities, geoname_id);

        sui::event::emit(CityRemoved {
            geoname_id,
        });
    }

    public fun update_city(
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
        _ctx: &mut sui::tx_context::TxContext,
    ) {
        assert!(
            sui::table::contains(&oracle.cities, geoname_id),
            E_CITY_NOT_FOUND,
        );

        let city = sui::table::borrow_mut(&mut oracle.cities, geoname_id);

        city.weather_id = weather_id;
        city.temp = temp;
        city.pressure = pressure;
        city.humidity = humidity;
        city.visibility = visibility;
        city.wind_speed = wind_speed;
        city.wind_deg = wind_deg;
        city.has_wind_gust = has_wind_gust;

        // Match Solidity:
        // c.windGust = hasWindGust ? windGust : 0;
        city.wind_gust = if (has_wind_gust) {
            wind_gust
        } else {
            0
        };

        city.clouds = clouds;
        city.dt = dt;

        sui::event::emit(CityUpdated {
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

    // -------------------------------------------------------------------------
    // Snapshot NFT minting
    // -------------------------------------------------------------------------
    //
    // `mint` returns the WeatherNFT object to the caller.
    // `mint_snapshot` additionally transfers it to tx sender, matching the
    // Solidity user-facing mintSnapshot behavior.

    public fun mint(
        oracle: &WeatherOracle,
        geoname_id: u32,
        ctx: &mut sui::tx_context::TxContext,
    ): WeatherNFT {
        assert!(
            sui::table::contains(&oracle.cities, geoname_id),
            E_CITY_NOT_FOUND,
        );

        let city = sui::table::borrow(&oracle.cities, geoname_id);

        let nft = WeatherNFT {
            id: sui::object::new(ctx),

            geoname_id: city.geoname_id,
            name: city.name,
            country: city.country,

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

        let recipient = sui::tx_context::sender(ctx);
        let snapshot_object_id = sui::object::id(&nft);

        sui::event::emit(SnapshotMinted {
            snapshot_object_id,
            geoname_id,
            recipient,
        });

        nft
    }

    public fun mint_snapshot(
        oracle: &WeatherOracle,
        geoname_id: u32,
        ctx: &mut sui::tx_context::TxContext,
    ) {
        let nft = mint(oracle, geoname_id, ctx);
        sui::transfer::public_transfer(nft, sui::tx_context::sender(ctx));
    }

    // -------------------------------------------------------------------------
    // Oracle metadata getters
    // -------------------------------------------------------------------------

    public fun oracle_address(oracle: &WeatherOracle): address {
        oracle.oracle_address
    }

    public fun oracle_name(oracle: &WeatherOracle): String {
        oracle.name
    }

    public fun oracle_description(oracle: &WeatherOracle): String {
        oracle.description
    }

    // -------------------------------------------------------------------------
    // City read-only getters
    // -------------------------------------------------------------------------

    public fun city_exists(oracle: &WeatherOracle, geoname_id: u32): bool {
        sui::table::contains(&oracle.cities, geoname_id)
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

    public fun city_positive_latitude(
        oracle: &WeatherOracle,
        geoname_id: u32,
    ): bool {
        require_city(oracle, geoname_id).positive_latitude
    }

    public fun city_longitude(oracle: &WeatherOracle, geoname_id: u32): u32 {
        require_city(oracle, geoname_id).longitude
    }

    public fun city_positive_longitude(
        oracle: &WeatherOracle,
        geoname_id: u32,
    ): bool {
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

    public fun city_has_wind_gust(
        oracle: &WeatherOracle,
        geoname_id: u32,
    ): bool {
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

    // -------------------------------------------------------------------------
    // Snapshot NFT getters
    // -------------------------------------------------------------------------

    public fun nft_id(nft: &WeatherNFT): sui::object::ID {
        sui::object::id(nft)
    }

    public fun snapshot_geoname_id(nft: &WeatherNFT): u32 {
        nft.geoname_id
    }

    public fun snapshot_name(nft: &WeatherNFT): String {
        nft.name
    }

    public fun snapshot_country(nft: &WeatherNFT): String {
        nft.country
    }

    public fun snapshot_latitude(nft: &WeatherNFT): u32 {
        nft.latitude
    }

    public fun snapshot_positive_latitude(nft: &WeatherNFT): bool {
        nft.positive_latitude
    }

    public fun snapshot_longitude(nft: &WeatherNFT): u32 {
        nft.longitude
    }

    public fun snapshot_positive_longitude(nft: &WeatherNFT): bool {
        nft.positive_longitude
    }

    public fun snapshot_weather_id(nft: &WeatherNFT): u16 {
        nft.weather_id
    }

    public fun snapshot_temp(nft: &WeatherNFT): u32 {
        nft.temp
    }

    public fun snapshot_pressure(nft: &WeatherNFT): u32 {
        nft.pressure
    }

    public fun snapshot_humidity(nft: &WeatherNFT): u8 {
        nft.humidity
    }

    public fun snapshot_visibility(nft: &WeatherNFT): u16 {
        nft.visibility
    }

    public fun snapshot_wind_speed(nft: &WeatherNFT): u16 {
        nft.wind_speed
    }

    public fun snapshot_wind_deg(nft: &WeatherNFT): u16 {
        nft.wind_deg
    }

    public fun snapshot_has_wind_gust(nft: &WeatherNFT): bool {
        nft.has_wind_gust
    }

    public fun snapshot_wind_gust(nft: &WeatherNFT): u16 {
        nft.wind_gust
    }

    public fun snapshot_clouds(nft: &WeatherNFT): u8 {
        nft.clouds
    }

    public fun snapshot_dt(nft: &WeatherNFT): u32 {
        nft.dt
    }

    // -------------------------------------------------------------------------
    // Compatibility aliases for NFT getters
    // -------------------------------------------------------------------------

    public fun geoname_id(nft: &WeatherNFT): u32 {
        nft.geoname_id
    }

    public fun name(nft: &WeatherNFT): String {
        nft.name
    }

    public fun country(nft: &WeatherNFT): String {
        nft.country
    }

    public fun latitude(nft: &WeatherNFT): u32 {
        nft.latitude
    }

    public fun positive_latitude(nft: &WeatherNFT): bool {
        nft.positive_latitude
    }

    public fun longitude(nft: &WeatherNFT): u32 {
        nft.longitude
    }

    public fun positive_longitude(nft: &WeatherNFT): bool {
        nft.positive_longitude
    }

    public fun weather_id(nft: &WeatherNFT): u16 {
        nft.weather_id
    }

    public fun temp(nft: &WeatherNFT): u32 {
        nft.temp
    }

    public fun pressure(nft: &WeatherNFT): u32 {
        nft.pressure
    }

    public fun humidity(nft: &WeatherNFT): u8 {
        nft.humidity
    }

    public fun visibility(nft: &WeatherNFT): u16 {
        nft.visibility
    }

    public fun wind_speed(nft: &WeatherNFT): u16 {
        nft.wind_speed
    }

    public fun wind_deg(nft: &WeatherNFT): u16 {
        nft.wind_deg
    }

    public fun has_wind_gust(nft: &WeatherNFT): bool {
        nft.has_wind_gust
    }

    public fun wind_gust(nft: &WeatherNFT): u16 {
        nft.wind_gust
    }

    public fun clouds(nft: &WeatherNFT): u8 {
        nft.clouds
    }

    public fun dt(nft: &WeatherNFT): u32 {
        nft.dt
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    fun require_city(
        oracle: &WeatherOracle,
        geoname_id: u32,
    ): &CityWeather {
        assert!(
            sui::table::contains(&oracle.cities, geoname_id),
            E_CITY_NOT_FOUND,
        );

        sui::table::borrow(&oracle.cities, geoname_id)
    }
}
