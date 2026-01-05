module weather_oracle::weather {
    use sui::event;
    use sui::object::{Self as object, UID};
    use sui::table;
    use sui::transfer;
    use sui::tx_context::{Self as tx_context, TxContext};
    use std::option::{Self as option, Option};
    use std::string;
    use std::vector;

    const E_CITY_EXISTS: u64 = 1;
    const E_CITY_NOT_FOUND: u64 = 2;

    public struct AdminCap has key, store {
        id: UID,
    }

    public struct WeatherOracle has key {
        id: UID,
        oracle_address: address,
        name: string::String,
        description: string::String,
        cities: table::Table<u32, CityWeather>,
    }

    public struct CityWeather has store, drop {
        geoname_id: u32,
        name: string::String,
        country: string::String,
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

    public struct WeatherNFT has key, store {
        id: UID,
        geoname_id: u32,
        name: string::String,
        country: string::String,
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

    public struct OracleInitializedEvent has copy, drop, store {
        admin: address,
        oracle_address: address,
        name: string::String,
        description: string::String,
    }

    public struct CityAddedEvent has copy, drop, store {
        geoname_id: u32,
        name: string::String,
        country: string::String,
    }

    public struct CityRemovedEvent has copy, drop, store {
        geoname_id: u32,
    }

    public struct CityUpdatedEvent has copy, drop, store {
        geoname_id: u32,
        weather_id: u16,
        temp: u32,
        pressure: u32,
        humidity: u8,
        visibility: u16,
        wind_speed: u16,
        wind_deg: u16,
        has_wind_gust: bool,
        wind_gust: Option<u16>,
        clouds: u8,
        dt: u32,
    }

    public struct SnapshotMintedEvent has copy, drop, store {
        geoname_id: u32,
        snapshot_id: address,
        recipient: address,
    }

    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let oracle = WeatherOracle {
            id: object::new(ctx),
            oracle_address: sender,
            name: string::utf8(b"Weather Oracle"),
            description: string::utf8(b"Weather data registry"),
            cities: table::new(ctx),
        };
        let admin_cap = AdminCap { id: object::new(ctx) };

        transfer::share_object(oracle);
        transfer::public_transfer(admin_cap, sender);

        event::emit(OracleInitializedEvent {
            admin: sender,
            oracle_address: sender,
            name: string::utf8(b"Weather Oracle"),
            description: string::utf8(b"Weather data registry"),
        });
    }

    /// Helper for tests
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }

    entry fun add_city(
        admin: &AdminCap,
        oracle: &mut WeatherOracle,
        geoname_id: u32,
        city_name: string::String,
        country: string::String,
        latitude: u32,
        positive_latitude: bool,
        longitude: u32,
        positive_longitude: bool,
        _ctx: &mut TxContext
    ) {
        assert!(!table::contains(&oracle.cities, geoname_id), E_CITY_EXISTS);

        let city_name_bytes = string::into_bytes(city_name);
        let country_bytes = string::into_bytes(country);
        let name_for_event = string::utf8(copy_bytes(&city_name_bytes));
        let country_for_event = string::utf8(copy_bytes(&country_bytes));
        let city_name_store = string::utf8(city_name_bytes);
        let country_store = string::utf8(country_bytes);

        table::add(
            &mut oracle.cities,
            geoname_id,
            CityWeather {
                geoname_id,
                name: city_name_store,
                country: country_store,
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
            }
        );

        let _ = admin;
        event::emit(CityAddedEvent {
            geoname_id,
            name: name_for_event,
            country: country_for_event,
        });
    }

    entry fun remove_city(admin: &AdminCap, oracle: &mut WeatherOracle, geoname_id: u32) {
        assert!(table::contains(&oracle.cities, geoname_id), E_CITY_NOT_FOUND);
        let _ = admin;
        table::remove(&mut oracle.cities, geoname_id);
        event::emit(CityRemovedEvent { geoname_id });
    }

    entry fun update(
        admin: &AdminCap,
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
        dt: u32
    ) {
        let city = borrow_city_mut(oracle, geoname_id);
        city.weather_id = weather_id;
        city.temp = temp;
        city.pressure = pressure;
        city.humidity = humidity;
        city.visibility = visibility;
        city.wind_speed = wind_speed;
        city.wind_deg = wind_deg;
        city.wind_gust = wind_gust;
        city.clouds = clouds;
        city.dt = dt;

        let _ = admin;
        event::emit(CityUpdatedEvent {
            geoname_id,
            weather_id,
            temp,
            pressure,
            humidity,
            visibility,
            wind_speed,
            wind_deg,
            has_wind_gust: option::is_some(&city.wind_gust),
            wind_gust: city.wind_gust,
            clouds,
            dt,
        });
    }

    public fun city_exists(oracle: &WeatherOracle, geoname_id: u32): bool {
        table::contains(&oracle.cities, geoname_id)
    }

    public fun city_weather_oracle_name(oracle: &WeatherOracle, geoname_id: u32): string::String {
        string::utf8(copy_bytes(string::bytes(&borrow_city(oracle, geoname_id).name)))
    }

    public fun city_weather_oracle_country(oracle: &WeatherOracle, geoname_id: u32): string::String {
        string::utf8(copy_bytes(string::bytes(&borrow_city(oracle, geoname_id).country)))
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
        copy_option_u16(&borrow_city(oracle, geoname_id).wind_gust)
    }

    public fun city_weather_oracle_clouds(oracle: &WeatherOracle, geoname_id: u32): u8 {
        borrow_city(oracle, geoname_id).clouds
    }

    public fun city_weather_oracle_dt(oracle: &WeatherOracle, geoname_id: u32): u32 {
        borrow_city(oracle, geoname_id).dt
    }

    entry fun mint(
        oracle: &WeatherOracle,
        geoname_id: u32,
        ctx: &mut TxContext
    ): WeatherNFT {
        let city = borrow_city(oracle, geoname_id);

        let nft = WeatherNFT {
            id: object::new(ctx),
            geoname_id,
            name: string::utf8(copy_bytes(string::bytes(&city.name))),
            country: string::utf8(copy_bytes(string::bytes(&city.country))),
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
            wind_gust: copy_option_u16(&city.wind_gust),
            clouds: city.clouds,
            dt: city.dt,
        };

        let recipient = tx_context::sender(ctx);
        let snapshot_id = object::uid_to_address(&nft.id);
        transfer::public_transfer(nft, recipient);

        event::emit(SnapshotMintedEvent {
            geoname_id,
            snapshot_id,
            recipient,
        });

        let nft_out = WeatherNFT {
            id: object::new(ctx),
            geoname_id,
            name: string::utf8(copy_bytes(string::bytes(&city.name))),
            country: string::utf8(copy_bytes(string::bytes(&city.country))),
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
            wind_gust: copy_option_u16(&city.wind_gust),
            clouds: city.clouds,
            dt: city.dt,
        };
        nft_out
    }

    fun borrow_city(oracle: &WeatherOracle, geoname_id: u32): &CityWeather {
        assert!(table::contains(&oracle.cities, geoname_id), E_CITY_NOT_FOUND);
        table::borrow(&oracle.cities, geoname_id)
    }

    fun borrow_city_mut(oracle: &mut WeatherOracle, geoname_id: u32): &mut CityWeather {
        assert!(table::contains(&oracle.cities, geoname_id), E_CITY_NOT_FOUND);
        table::borrow_mut(&mut oracle.cities, geoname_id)
    }

    fun copy_bytes(src: &vector<u8>): vector<u8> {
        let mut dest = vector::empty<u8>();
        let len = vector::length(src);
        let mut i = 0;
        while (i < len) {
            let b = *vector::borrow(src, i);
            vector::push_back(&mut dest, b);
            i = i + 1;
        };
        dest
    }

    fun copy_option_u16(src: &Option<u16>): Option<u16> {
        if (option::is_some(src)) {
            option::some(*option::borrow(src))
        } else {
            option::none()
        }
    }
}