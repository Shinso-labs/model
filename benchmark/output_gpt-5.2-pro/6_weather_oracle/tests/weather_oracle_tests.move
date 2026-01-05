#[test_only]
module weather_oracle::weather_oracle_tests {
    use std::option;
    use sui::test_scenario;
    use sui::tx_context;
    use weather_oracle::weather_oracle::{
        test_dispose, test_setup, test_setup_with_city, add_city, city_dt, city_exists,
        city_exists_flag, city_geoname_id, city_name, city_country, city_weather_id, city_wind_gust,
        get_city, mint_snapshot, registry_description, registry_name, registry_oracle_address,
        remove_city, update_city,
    };

    #[test]
    fun test_setup_has_defaults() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (registry, cap) = test_setup(ctx);
        assert!(registry_oracle_address(&registry) == @0xA, 100);
        assert!(registry_name(&registry) == b"Weather Oracle", 101);
        assert!(registry_description(&registry) == b"Sui Move weather oracle registry", 102);
        test_dispose(registry, cap, ctx);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_add_city_stores_data() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (mut registry, cap) = test_setup(ctx);
        add_city(
            &mut registry,
            &cap,
            7,
            b"Berlin",
            b"DE",
            5231,
            true,
            1324,
            true,
        );
        let city = get_city(&registry, 7);
        assert!(city_name(&city) == b"Berlin", 200);
        assert!(city_country(&city) == b"DE", 201);
        assert!(city_exists_flag(&city), 202);
        test_dispose(registry, cap, ctx);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = weather_oracle::weather_oracle)]
    fun test_add_city_duplicate_aborts() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (mut registry, cap) = test_setup_with_city(ctx);
        add_city(
            &mut registry,
            &cap,
            1,
            b"Paris",
            b"FR",
            4888568,
            true,
            2345,
            true,
        );
        test_scenario::end(scenario);
    }

    #[test]
    fun test_remove_city_succeeds() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (mut registry, cap) = test_setup_with_city(ctx);
        remove_city(&mut registry, &cap, 1);
        assert!(!city_exists(&registry, 1), 300);
        test_dispose(registry, cap, ctx);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = weather_oracle::weather_oracle)]
    fun test_remove_city_missing_aborts() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (mut registry, cap) = test_setup(ctx);
        remove_city(&mut registry, &cap, 99);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_update_city_sets_values() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (mut registry, cap) = test_setup_with_city(ctx);
        update_city(
            &mut registry,
            &cap,
            1,
            500,
            2950,
            1013,
            55,
            10000,
            12,
            250,
            true,
            30,
            80,
            1700000000,
        );
        let city = get_city(&registry, 1);
        assert!(city_weather_id(&city) == 500, 400);
        assert!(city_wind_gust(&city) == option::some(30), 401);
        assert!(city_dt(&city) == 1700000000, 402);
        test_dispose(registry, cap, ctx);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 4, location = weather_oracle::weather_oracle)]
    fun test_update_missing_city_aborts() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (mut registry, cap) = test_setup(ctx);
        update_city(
            &mut registry,
            &cap,
            44,
            1,
            1,
            1,
            1,
            1,
            1,
            1,
            false,
            0,
            0,
            1,
        );
        test_scenario::end(scenario);
    }

    #[test]
    fun test_update_wind_gust_none() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (mut registry, cap) = test_setup_with_city(ctx);
        update_city(
            &mut registry,
            &cap,
            1,
            200,
            2800,
            1000,
            60,
            5000,
            5,
            90,
            false,
            0,
            10,
            1700000001,
        );
        let city = get_city(&registry, 1);
        assert!(option::is_none(&city_wind_gust(&city)), 500);
        test_dispose(registry, cap, ctx);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_mint_snapshot_succeeds() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (mut registry, cap) = test_setup_with_city(ctx);
        update_city(
            &mut registry,
            &cap,
            1,
            300,
            3000,
            1010,
            70,
            9000,
            8,
            45,
            false,
            0,
            50,
            1700000002,
        );
        mint_snapshot(&registry, 1, ctx);
        test_dispose(registry, cap, ctx);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = weather_oracle::weather_oracle)]
    fun test_mint_snapshot_missing_city_aborts() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (registry, cap) = test_setup(ctx);
        mint_snapshot(&registry, 99, ctx);
        test_dispose(registry, cap, ctx);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_city_exists_true_false() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (registry, cap) = test_setup(ctx);
        assert!(!city_exists(&registry, 5), 600);
        test_dispose(registry, cap, ctx);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = weather_oracle::weather_oracle)]
    fun test_borrow_city_missing_aborts() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (registry, cap) = test_setup(ctx);
        let _ = get_city(&registry, 500);
        test_dispose(registry, cap, ctx);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_get_city_returns_copy() {
        let mut scenario = test_scenario::begin(@0xA);
        let ctx = test_scenario::ctx(&mut scenario);
        let (mut registry, cap) = test_setup_with_city(ctx);
        let city = get_city(&registry, 1);
        assert!(city_geoname_id(&city) == 1, 700);
        assert!(city_name(&city) == b"Paris", 701);
        assert!(city_country(&city) == b"FR", 702);
        // Update original to ensure copy semantics
        update_city(
            &mut registry,
            &cap,
            1,
            900,
            9999,
            900,
            10,
            1,
            1,
            1,
            false,
            0,
            1,
            2,
        );
        let original = get_city(&registry, 1);
        assert!(city_weather_id(&original) == 900, 703);
        assert!(city_weather_id(&city) == 0, 704);
        test_dispose(registry, cap, ctx);
        test_scenario::end(scenario);
    }
}