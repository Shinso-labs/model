#[test_only]
module weather_oracle::weather_oracle_tests {
    use weather_oracle::weather::{Self, WeatherOracle, AdminCap, WeatherNFT};
    use std::string::{Self, String};
    use sui::test_scenario::{Self as ts};

    #[test]
    /// Test that add_city creates a city in the oracle
    fun test_add_city() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            weather::add_city(
                &admin_cap,
                &mut oracle,
                12345,
                string::utf8(b"New York"),
                string::utf8(b"USA"),
                40,
                true,
                74,
                false,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that multiple cities can be added
    fun test_add_multiple_cities() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            weather::add_city(&admin_cap, &mut oracle, 1, string::utf8(b"City1"), string::utf8(b"Country1"), 10, true, 20, true, ts::ctx(&mut scenario));
            weather::add_city(&admin_cap, &mut oracle, 2, string::utf8(b"City2"), string::utf8(b"Country2"), 30, false, 40, false, ts::ctx(&mut scenario));
            weather::add_city(&admin_cap, &mut oracle, 3, string::utf8(b"City3"), string::utf8(b"Country3"), 50, true, 60, true, ts::ctx(&mut scenario));
            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that remove_city removes a city from the oracle
    fun test_remove_city() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            weather::add_city(&admin_cap, &mut oracle, 123, string::utf8(b"Test City"), string::utf8(b"Test Country"), 10, true, 20, true, ts::ctx(&mut scenario));
            weather::remove_city(&admin_cap, &mut oracle, 123);
            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that update modifies city weather data
    fun test_update_city_weather() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            weather::add_city(&admin_cap, &mut oracle, 100, string::utf8(b"Test"), string::utf8(b"Country"), 10, true, 20, true, ts::ctx(&mut scenario));
            weather::update(
                &admin_cap,
                &mut oracle,
                100,
                800, // weather_id
                290, // temp
                1013, // pressure
                65, // humidity
                10000, // visibility
                5, // wind_speed
                180, // wind_deg
                option::none(), // wind_gust
                50, // clouds
                1234567890 // dt
            );
            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that city_weather_oracle_name returns correct name
    fun test_get_city_name() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            let city_name = string::utf8(b"Tokyo");
            weather::add_city(&admin_cap, &mut oracle, 999, city_name, string::utf8(b"Japan"), 35, true, 139, true, ts::ctx(&mut scenario));
            let retrieved_name = weather::city_weather_oracle_name(&oracle, 999);
            assert!(retrieved_name == city_name, 0);
            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that city_weather_oracle_country returns correct country
    fun test_get_city_country() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            let country = string::utf8(b"France");
            weather::add_city(&admin_cap, &mut oracle, 500, string::utf8(b"Paris"), country, 48, true, 2, true, ts::ctx(&mut scenario));
            let retrieved_country = weather::city_weather_oracle_country(&oracle, 500);
            assert!(retrieved_country == country, 1);
            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that weather data getters return correct values
    fun test_weather_data_getters() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            weather::add_city(&admin_cap, &mut oracle, 200, string::utf8(b"City"), string::utf8(b"Country"), 10, true, 20, true, ts::ctx(&mut scenario));
            weather::update(&admin_cap, &mut oracle, 200, 801, 295, 1015, 70, 9000, 10, 90, option::some(15), 75, 987654321);

            assert!(weather::city_weather_oracle_weather_id(&oracle, 200) == 801, 2);
            assert!(weather::city_weather_oracle_temp(&oracle, 200) == 295, 3);
            assert!(weather::city_weather_oracle_pressure(&oracle, 200) == 1015, 4);
            assert!(weather::city_weather_oracle_humidity(&oracle, 200) == 70, 5);
            assert!(weather::city_weather_oracle_visibility(&oracle, 200) == 9000, 6);
            assert!(weather::city_weather_oracle_wind_speed(&oracle, 200) == 10, 7);
            assert!(weather::city_weather_oracle_wind_deg(&oracle, 200) == 90, 8);
            assert!(weather::city_weather_oracle_clouds(&oracle, 200) == 75, 9);
            assert!(weather::city_weather_oracle_dt(&oracle, 200) == 987654321, 10);

            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that mint creates a WeatherNFT
    fun test_mint_weather_nft() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            weather::add_city(&admin_cap, &mut oracle, 300, string::utf8(b"NFT City"), string::utf8(b"NFT Country"), 25, true, 50, false, ts::ctx(&mut scenario));
            weather::update(&admin_cap, &mut oracle, 300, 500, 280, 1000, 60, 8000, 8, 120, option::none(), 40, 111111111);

            let nft = weather::mint(&oracle, 300, ts::ctx(&mut scenario));
            sui::transfer::public_transfer(nft, @0xA);

            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test latitude and longitude getters
    fun test_location_getters() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            weather::add_city(&admin_cap, &mut oracle, 400, string::utf8(b"Location Test"), string::utf8(b"Test"), 45, false, 90, true, ts::ctx(&mut scenario));

            assert!(weather::city_weather_oracle_latitude(&oracle, 400) == 45, 11);
            assert!(weather::city_weather_oracle_positive_latitude(&oracle, 400) == false, 12);
            assert!(weather::city_weather_oracle_longitude(&oracle, 400) == 90, 13);
            assert!(weather::city_weather_oracle_positive_longitude(&oracle, 400) == true, 14);

            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test update with optional wind_gust
    fun test_update_with_wind_gust() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            weather::add_city(&admin_cap, &mut oracle, 600, string::utf8(b"Windy City"), string::utf8(b"Country"), 10, true, 20, true, ts::ctx(&mut scenario));
            weather::update(&admin_cap, &mut oracle, 600, 900, 300, 1020, 55, 10000, 20, 270, option::some(25), 30, 222222222);

            let wind_gust = weather::city_weather_oracle_wind_gust(&oracle, 600);
            assert!(option::is_some(&wind_gust), 15);
            assert!(*option::borrow(&wind_gust) == 25, 16);

            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test adding cities with edge case values
    fun test_add_city_edge_cases() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            // Test with 0 latitude/longitude
            weather::add_city(&admin_cap, &mut oracle, 700, string::utf8(b"Equator"), string::utf8(b"Ocean"), 0, true, 0, true, ts::ctx(&mut scenario));
            // Test with large geoname_id
            weather::add_city(&admin_cap, &mut oracle, 4294967295, string::utf8(b"Max ID"), string::utf8(b"Test"), 90, true, 180, true, ts::ctx(&mut scenario));

            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test multiple updates to same city
    fun test_multiple_updates() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            weather::add_city(&admin_cap, &mut oracle, 800, string::utf8(b"Changing City"), string::utf8(b"Country"), 10, true, 20, true, ts::ctx(&mut scenario));

            // First update
            weather::update(&admin_cap, &mut oracle, 800, 100, 250, 1000, 50, 5000, 5, 90, option::none(), 20, 100);
            assert!(weather::city_weather_oracle_temp(&oracle, 800) == 250, 17);

            // Second update
            weather::update(&admin_cap, &mut oracle, 800, 200, 260, 1010, 60, 6000, 10, 180, option::some(15), 40, 200);
            assert!(weather::city_weather_oracle_temp(&oracle, 800) == 260, 18);

            // Third update
            weather::update(&admin_cap, &mut oracle, 800, 300, 270, 1020, 70, 7000, 15, 270, option::none(), 60, 300);
            assert!(weather::city_weather_oracle_temp(&oracle, 800) == 270, 19);

            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that AdminCap is required for admin operations
    fun test_admin_cap_required() {
        let mut scenario = ts::begin(@0xA);
        {
            weather::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut oracle = ts::take_shared<WeatherOracle>(&scenario);
            // This should succeed because we have admin_cap
            weather::add_city(&admin_cap, &mut oracle, 900, string::utf8(b"Admin Test"), string::utf8(b"Test"), 10, true, 20, true, ts::ctx(&mut scenario));
            ts::return_shared(oracle);
            ts::return_to_sender(&scenario, admin_cap);
        };
        ts::end(scenario);
    }
}
