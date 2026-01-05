module weather_oracle::weather_oracle {
    use std::option;
    use std::vector;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::table;
    use sui::transfer;
    use sui::tx_context::TxContext;

    /// Admin capability; only holder can mutate registry.
    public struct AdminCap has key, store { id: UID }

    /// Per-city weather data (copyable for easy reads). Text stored as UTF-8 bytes.
    public struct CityWeather has copy, drop, store {
        geoname_id: u32,
        name: vector<u8>,
        country: vector<u8>,
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
        wind_gust: option::Option<u16>,
        clouds: u8,
        dt: u32,
        exists: bool,
    }

    /// Shared registry holding all city records.
    public struct Registry has key {
        id: UID,
        oracle_address: address,
        name: vector<u8>,
        description: vector<u8>,
        cities: table::Table<u32, CityWeather>,
    }

    /// Snapshot NFT (object transferred to caller).
    public struct Snapshot has key, store {
        id: UID,
        geoname_id: u32,
        name: vector<u8>,
        country: vector<u8>,
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
        wind_gust: option::Option<u16>,
        clouds: u8,
        dt: u32,
    }

    /// Events mirroring Solidity events (use vectors for copy ability).
    public struct OracleInitialized has copy, drop, store {
        admin: address,
        oracle_address: address,
        name: vector<u8>,
        description: vector<u8>,
    }

    public struct CityAdded has copy, drop, store {
        geoname_id: u32,
        name: vector<u8>,
        country: vector<u8>,
    }

    public struct CityRemoved has copy, drop, store { geoname_id: u32 }

    public struct CityUpdated has copy, drop, store {
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

    public struct SnapshotMinted has copy, drop, store {
        geoname_id: u32,
        owner: address,
    }

    /// Initializes the registry, shares it, and returns an AdminCap to the publisher.
    fun init(ctx: &mut TxContext) {
        let admin = tx_context::sender(ctx);
        let default_name = b"Weather Oracle";
        let default_description = b"Sui Move weather oracle registry";
        let registry = Registry {
            id: object::new(ctx),
            oracle_address: admin,
            name: copy default_name,
            description: copy default_description,
            cities: table::new(ctx),
        };
        transfer::share_object(registry);

        let admin_cap = AdminCap { id: object::new(ctx) };
        transfer::transfer(admin_cap, admin);

        event::emit(OracleInitialized {
            admin,
            oracle_address: admin,
            name: default_name,
            description: default_description,
        });
    }

    /// Add a new city (idempotent on fresh ids).
    public entry fun add_city(
        registry: &mut Registry,
        _cap: &AdminCap,
        geoname_id: u32,
        city_name: vector<u8>,
        country: vector<u8>,
        latitude: u32,
        positive_latitude: bool,
        longitude: u32,
        positive_longitude: bool
    ) {
        assert!(!table::contains(&registry.cities, geoname_id), 0);
        let city = CityWeather {
            geoname_id,
            name: copy city_name,
            country: copy country,
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
            wind_gust: option::none(),
            clouds: 0,
            dt: 0,
            exists: true,
        };
        table::add(&mut registry.cities, geoname_id, city);

        event::emit(CityAdded {
            geoname_id,
            name: city_name,
            country,
        });
    }

    /// Remove a city from the registry.
    public entry fun remove_city(registry: &mut Registry, _cap: &AdminCap, geoname_id: u32) {
        assert!(table::contains(&registry.cities, geoname_id), 1);
        let _ = table::remove(&mut registry.cities, geoname_id);
        event::emit(CityRemoved { geoname_id });
    }

    /// Update weather measurements for a city.
    public entry fun update_city(
        registry: &mut Registry,
        _cap: &AdminCap,
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
        dt: u32
    ) {
        let city_ref = borrow_city_mut(&mut registry.cities, geoname_id);
        city_ref.weather_id = weather_id;
        city_ref.temp = temp;
        city_ref.pressure = pressure;
        city_ref.humidity = humidity;
        city_ref.visibility = visibility;
        city_ref.wind_speed = wind_speed;
        city_ref.wind_deg = wind_deg;
        city_ref.wind_gust = if (has_wind_gust) option::some(wind_gust) else option::none();
        city_ref.clouds = clouds;
        city_ref.dt = dt;

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
            wind_gust: if (has_wind_gust) wind_gust else 0,
            clouds,
            dt,
        });
    }

    /// Mint a snapshot NFT of current city weather to the caller.
    public entry fun mint_snapshot(registry: &Registry, geoname_id: u32, ctx: &mut TxContext) {
        let city = borrow_city(&registry.cities, geoname_id);
        assert!(city.exists, 2);

        let snapshot = Snapshot {
            id: object::new(ctx),
            geoname_id: city.geoname_id,
            name: copy city.name,
            country: copy city.country,
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
            wind_gust: city.wind_gust,
            clouds: city.clouds,
            dt: city.dt,
        };
        let recipient = tx_context::sender(ctx);
        transfer::transfer(snapshot, recipient);

        event::emit(SnapshotMinted { geoname_id, owner: recipient });
    }

    /// ----- Read helpers (public, non-entry) -----

    public fun city_exists(registry: &Registry, geoname_id: u32): bool {
        table::contains(&registry.cities, geoname_id)
    }

    public fun get_city(registry: &Registry, geoname_id: u32): CityWeather {
        *borrow_city(&registry.cities, geoname_id)
    }

    /// Internal helpers.

    fun borrow_city(cities: &table::Table<u32, CityWeather>, geoname_id: u32): &CityWeather {
        assert!(table::contains(cities, geoname_id), 3);
        table::borrow(cities, geoname_id)
    }

    fun borrow_city_mut(cities: &mut table::Table<u32, CityWeather>, geoname_id: u32): &mut CityWeather {
        assert!(table::contains(cities, geoname_id), 4);
        table::borrow_mut(cities, geoname_id)
    }
}