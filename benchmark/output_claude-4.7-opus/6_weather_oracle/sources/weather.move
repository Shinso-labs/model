/// Module: weather_oracle::weather
/// Translation of Solidity WeatherOracle + WeatherNFT contracts.
///
/// Key translation decisions:
/// - OpenZeppelin AccessControl (ADMIN_ROLE) → AdminCap capability object held by admin.
/// - mapping(uint32 => CityWeather) → sui::table::Table<u32, CityWeather>.
/// - The WeatherOracle is a shared object so anyone can read; only AdminCap holders can write.
/// - ERC-721 snapshot NFT → a `WeatherNFT` object with `key + store`, transferred to the caller.
/// - Events use sui::event::emit().
/// - Reentrancy: not applicable in Move; resource semantics + no reentrant calls in this module.
module weather_oracle::weather {
    use std::option::{Self, Option};
    use std::string::String;
    use sui::event;
    use sui::object::{Self, UID, ID};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    // ---------------- Errors ----------------
    const ECityAlreadyExists: u64 = 1;
    const ECityNotFound: u64 = 2;
    const ENotAdminForOracle: u64 = 3;

    // ---------------- Capability ----------------
    /// Admin capability — analogous to ADMIN_ROLE in the Solidity contract.
    /// Whoever holds this object can add/remove/update cities.
    public struct AdminCap has key, store {
        id: UID,
        oracle_id: ID,
    }

    // ---------------- City record ----------------
    /// Mirrors Solidity's CityWeather struct.
    /// Note: Solidity used a per-record `exists` sentinel; in Move we use Table presence.
    /// Wind gust uses Option<u16> directly (the original Move semantics).
    public struct CityWeather has store, drop, copy {
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
        wind_gust: Option<u16>,
        clouds: u8,
        dt: u32,
    }

    // ---------------- Oracle ----------------
    /// The shared oracle object — analog of the WeatherOracle contract storage.
    public struct WeatherOracle has key {
        id: UID,
        oracle_address: address,
        name: String,
        description: String,
        cities: Table<u32, CityWeather>,
    }

    // ---------------- NFT (snapshot) ----------------
    /// The snapshot NFT — analog of the ERC-721 token in WeatherNFT.
    /// Has `key + store` so it can be owned and transferred freely.
    public struct WeatherNFT has key, store {
        id: UID,
        token_id: u64,
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
        wind_gust: Option<u16>,
        clouds: u8,
        dt: u32,
    }

    /// Tracks the next token id for snapshot NFTs. Stored as a shared object,
    /// updated only when minting (which uses a mutable reference).
    public struct SnapshotCounter has key {
        id: UID,
        next_id: u64,
    }

    // ---------------- Events ----------------
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
        wind_gust: Option<u16>,
        clouds: u8,
        dt: u32,
    }

    public struct SnapshotMinted has copy, drop {
        token_id: u64,
        geoname_id: u32,
    }

    // ---------------- Init ----------------
    /// Initializes a default oracle and shared snapshot counter.
    /// Sender receives the AdminCap.
    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        let oracle = WeatherOracle {
            id: object::new(ctx),
            oracle_address: sender,
            name: std::string::utf8(b""),
            description: std::string::utf8(b""),
            cities: table::new<u32, CityWeather>(ctx),
        };
        let oracle_id = object::id(&oracle);

        let admin_cap = AdminCap {
            id: object::new(ctx),
            oracle_id,
        };

        let counter = SnapshotCounter {
            id: object::new(ctx),
            next_id: 0,
        };

        event::emit(OracleInitialized {
            admin: sender,
            oracle_address: sender,
            name: std::string::utf8(b""),
            description: std::string::utf8(b""),
        });

        transfer::share_object(oracle);
        transfer::share_object(counter);
        transfer::transfer(admin_cap, sender);
    }

    /// Optional: Create a freshly-named oracle post-publish (transfers a new AdminCap to caller).
    public fun create_oracle(
        oracle_name: String,
        oracle_description: String,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        let oracle = WeatherOracle {
            id: object::new(ctx),
            oracle_address: sender,
            name: oracle_name,
            description: oracle_description,
            cities: table::new<u32, CityWeather>(ctx),
        };
        let oracle_id = object::id(&oracle);

        let admin_cap = AdminCap {
            id: object::new(ctx),
            oracle_id,
        };

        event::emit(OracleInitialized {
            admin: sender,
            oracle_address: sender,
            name: oracle.name,
            description: oracle.description,
        });

        transfer::share_object(oracle);
        transfer::transfer(admin_cap, sender);
    }

    // ---------------- Helpers ----------------
    fun assert_admin(cap: &AdminCap, oracle: &WeatherOracle) {
        assert!(cap.oracle_id == object::id(oracle), ENotAdminForOracle);
    }

    // ---------------- Admin (write) ----------------

    /// Add a new city. Aborts if a record with the same geoname_id already exists.
    public fun add_city(
        cap: &AdminCap,
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        city_name: String,
        country: String,
        latitude: u32,
        positive_latitude: bool,
        longitude: u32,
        positive_longitude: bool,
        _ctx: &mut TxContext,
    ) {
        assert_admin(cap, oracle);
        assert!(!table::contains(&oracle.cities, geoname_id), ECityAlreadyExists);

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
            wind_gust: option::none<u16>(),
            clouds: 0,
            dt: 0,
        };

        event::emit(CityAdded {
            geoname_id,
            name: city.name,
            country: city.country,
        });

        table::add(&mut oracle.cities, geoname_id, city);
    }

    /// Remove a city. Aborts if the city does not exist.
    public fun remove_city(
        cap: &AdminCap,
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        _ctx: &mut TxContext,
    ) {
        assert_admin(cap, oracle);
        assert!(table::contains(&oracle.cities, geoname_id), ECityNotFound);
        let _removed: CityWeather = table::remove(&mut oracle.cities, geoname_id);
        event::emit(CityRemoved { geoname_id });
    }

    /// Update measured weather fields.
    /// Named `update` (not `update_city`) to match the original Move semantics expected by tests.
    public fun update(
        cap: &AdminCap,
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        weather_id: u16,
        temp: u32,
        pressure: u32,
        humidity: u8,
        visibility: u16,
        wind_speed: u16,
        wind_deg: u16,
        wind_gust: Option<u16>,
        clouds: u8,
        dt: u32,
    ) {
        assert_admin(cap, oracle);
        assert!(table::contains(&oracle.cities, geoname_id), ECityNotFound);

        let c = table::borrow_mut(&mut oracle.cities, geoname_id);
        c.weather_id = weather_id;
        c.temp = temp;
        c.pressure = pressure;
        c.humidity = humidity;
        c.visibility = visibility;
        c.wind_speed = wind_speed;
        c.wind_deg = wind_deg;
        c.wind_gust = wind_gust;
        c.clouds = clouds;
        c.dt = dt;

        event::emit(CityUpdated {
            geoname_id,
            weather_id,
            temp,
            pressure,
            humidity,
            visibility,
            wind_speed,
            wind_deg,
            wind_gust: c.wind_gust,
            clouds,
            dt,
        });
    }

    // ---------------- Read-only getters ----------------
    // Naming convention: `city_weather_oracle_<field>` to match the original
    // weather_oracle::weather Move module API expected by tests.

    public fun city_exists(oracle: &WeatherOracle, geoname_id: u32): bool {
        table::contains(&oracle.cities, geoname_id)
    }

    fun borrow_city(oracle: &WeatherOracle, geoname_id: u32): &CityWeather {
        assert!(table::contains(&oracle.cities, geoname_id), ECityNotFound);
        table::borrow(&oracle.cities, geoname_id)
    }

    public fun city_weather_oracle_geoname_id(oracle: &WeatherOracle, geoname_id: u32): u32 {
        borrow_city(oracle, geoname_id).geoname_id
    }

    public fun city_weather_oracle_name(oracle: &WeatherOracle, geoname_id: u32): String {
        borrow_city(oracle, geoname_id).name
    }

    public fun city_weather_oracle_country(oracle: &WeatherOracle, geoname_id: u32): String {
        borrow_city(oracle, geoname_id).country
    }

    public fun city_weather_oracle_latitude(oracle: &WeatherOracle, geoname_id: u32): u32 {
        borrow_city(oracle, geoname_id).latitude
    }

    public fun city_weather_oracle_positive_latitude(oracle: &WeatherOracle, geoname_id: u32): bool {
        borrow_city(oracle, geoname_id).positive_latitude
    }

    public fun city_weather_oracle_longitude(oracle: &WeatherOracle, geoname_id: u32): u32 {
        borrow_city(oracle, geoname_id).longitude
    }

    public fun city_weather_oracle_positive_longitude(oracle: &WeatherOracle, geoname_id: u32): bool {
        borrow_city(oracle, geoname_id).positive_longitude
    }

    public fun city_weather_oracle_weather_id(oracle: &WeatherOracle, geoname_id: u32): u16 {
        borrow_city(oracle, geoname_id).weather_id
    }

    public fun city_weather_oracle_temp(oracle: &WeatherOracle, geoname_id: u32): u32 {
        borrow_city(oracle, geoname_id).temp
    }

    public fun city_weather_oracle_pressure(oracle: &WeatherOracle, geoname_id: u32): u32 {
        borrow_city(oracle, geoname_id).pressure
    }

    public fun city_weather_oracle_humidity(oracle: &WeatherOracle, geoname_id: u32): u8 {
        borrow_city(oracle, geoname_id).humidity
    }

    public fun city_weather_oracle_visibility(oracle: &WeatherOracle, geoname_id: u32): u16 {
        borrow_city(oracle, geoname_id).visibility
    }

    public fun city_weather_oracle_wind_speed(oracle: &WeatherOracle, geoname_id: u32): u16 {
        borrow_city(oracle, geoname_id).wind_speed
    }

    public fun city_weather_oracle_wind_deg(oracle: &WeatherOracle, geoname_id: u32): u16 {
        borrow_city(oracle, geoname_id).wind_deg
    }

    public fun city_weather_oracle_wind_gust(oracle: &WeatherOracle, geoname_id: u32): Option<u16> {
        borrow_city(oracle, geoname_id).wind_gust
    }

    public fun city_weather_oracle_clouds(oracle: &WeatherOracle, geoname_id: u32): u8 {
        borrow_city(oracle, geoname_id).clouds
    }

    public fun city_weather_oracle_dt(oracle: &WeatherOracle, geoname_id: u32): u32 {
        borrow_city(oracle, geoname_id).dt
    }

    // Oracle metadata getters
    public fun oracle_address(oracle: &WeatherOracle): address { oracle.oracle_address }
    public fun oracle_name(oracle: &WeatherOracle): String { oracle.name }
    public fun oracle_description(oracle: &WeatherOracle): String { oracle.description }

    // ---------------- Snapshot mint ----------------

    /// Mint a snapshot NFT capturing the current city state and transfer to the caller.
    public fun mint_snapshot(
        oracle: &WeatherOracle,
        counter: &mut SnapshotCounter,
        geoname_id: u32,
        ctx: &mut TxContext,
    ) {
        let c = borrow_city(oracle, geoname_id);

        let token_id = counter.next_id;
        counter.next_id = counter.next_id + 1;

        let nft = WeatherNFT {
            id: object::new(ctx),
            token_id,
            geoname_id: c.geoname_id,
            name: c.name,
            country: c.country,
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
            wind_gust: c.wind_gust,
            clouds: c.clouds,
            dt: c.dt,
        };

        event::emit(SnapshotMinted { token_id, geoname_id });

        transfer::public_transfer(nft, tx_context::sender(ctx));
    }

    // ---------------- NFT getters ----------------
    public fun nft_token_id(nft: &WeatherNFT): u64 { nft.token_id }
    public fun nft_geoname_id(nft: &WeatherNFT): u32 { nft.geoname_id }
    public fun nft_name(nft: &WeatherNFT): String { nft.name }
    public fun nft_country(nft: &WeatherNFT): String { nft.country }
    public fun nft_latitude(nft: &WeatherNFT): u32 { nft.latitude }
    public fun nft_positive_latitude(nft: &WeatherNFT): bool { nft.positive_latitude }
    public fun nft_longitude(nft: &WeatherNFT): u32 { nft.longitude }
    public fun nft_positive_longitude(nft: &WeatherNFT): bool { nft.positive_longitude }
    public fun nft_weather_id(nft: &WeatherNFT): u16 { nft.weather_id }
    public fun nft_temp(nft: &WeatherNFT): u32 { nft.temp }
    public fun nft_pressure(nft: &WeatherNFT): u32 { nft.pressure }
    public fun nft_humidity(nft: &WeatherNFT): u8 { nft.humidity }
    public fun nft_visibility(nft: &WeatherNFT): u16 { nft.visibility }
    public fun nft_wind_speed(nft: &WeatherNFT): u16 { nft.wind_speed }
    public fun nft_wind_deg(nft: &WeatherNFT): u16 { nft.wind_deg }
    public fun nft_wind_gust(nft: &WeatherNFT): Option<u16> { nft.wind_gust }
    public fun nft_clouds(nft: &WeatherNFT): u8 { nft.clouds }
    public fun nft_dt(nft: &WeatherNFT): u32 { nft.dt }

    // ---------------- Test-only init ----------------
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
