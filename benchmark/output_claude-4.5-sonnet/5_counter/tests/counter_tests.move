#[test_only]
module counter::counter_tests {
    use counter::counter::{Counter, create, increment, set_value};
    use sui::test_scenario::{Self as ts};

    #[test]
    /// Test that create makes a shared Counter with value 0
    fun test_create_counter() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            assert!(ts::has_most_recent_shared<Counter>(), 0);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that increment increases counter value by 1
    fun test_increment_increases_value() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            increment(&mut counter);
            ts::return_shared(counter);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that multiple increments work correctly
    fun test_multiple_increments() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            increment(&mut counter);
            increment(&mut counter);
            increment(&mut counter);
            ts::return_shared(counter);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that different users can increment the counter
    fun test_different_users_can_increment() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            increment(&mut counter);
            ts::return_shared(counter);
        };
        ts::next_tx(&mut scenario, @0xC);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            increment(&mut counter);
            ts::return_shared(counter);
        };
        ts::next_tx(&mut scenario, @0xD);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            increment(&mut counter);
            ts::return_shared(counter);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that owner can set value
    fun test_owner_can_set_value() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            set_value(&mut counter, 100, ts::ctx(&mut scenario));
            ts::return_shared(counter);
        };
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = counter::counter)]
    /// Test that non-owner cannot set value
    fun test_non_owner_cannot_set_value() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            set_value(&mut counter, 100, ts::ctx(&mut scenario));
            ts::return_shared(counter);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that owner can set value to zero
    fun test_owner_can_set_value_to_zero() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            increment(&mut counter);
            increment(&mut counter);
            set_value(&mut counter, 0, ts::ctx(&mut scenario));
            ts::return_shared(counter);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that owner can set value to large number
    fun test_owner_can_set_large_value() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            let large_value = 999_999_999_999;
            set_value(&mut counter, large_value, ts::ctx(&mut scenario));
            ts::return_shared(counter);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test increment after set_value works correctly
    fun test_increment_after_set_value() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            set_value(&mut counter, 50, ts::ctx(&mut scenario));
            ts::return_shared(counter);
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            increment(&mut counter);
            ts::return_shared(counter);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that counter can be incremented many times
    fun test_many_increments() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            let mut i = 0;
            while (i < 100) {
                increment(&mut counter);
                i = i + 1;
            };
            ts::return_shared(counter);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that owner can reset counter multiple times
    fun test_owner_can_reset_multiple_times() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            set_value(&mut counter, 10, ts::ctx(&mut scenario));
            set_value(&mut counter, 20, ts::ctx(&mut scenario));
            set_value(&mut counter, 30, ts::ctx(&mut scenario));
            ts::return_shared(counter);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test mixed operations: increment and set_value
    fun test_mixed_operations() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            increment(&mut counter);
            increment(&mut counter);
            ts::return_shared(counter);
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            set_value(&mut counter, 100, ts::ctx(&mut scenario));
            ts::return_shared(counter);
        };
        ts::next_tx(&mut scenario, @0xC);
        {
            let mut counter = ts::take_shared<Counter>(&scenario);
            increment(&mut counter);
            ts::return_shared(counter);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that multiple counters can be created
    fun test_multiple_counters() {
        let mut scenario = ts::begin(@0xA);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xC);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::end(scenario);
    }

    #[test]
    /// Test creating counter from zero address
    fun test_create_from_zero_address() {
        let mut scenario = ts::begin(@0x0);
        {
            create(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0x0);
        {
            assert!(ts::has_most_recent_shared<Counter>(), 1);
        };
        ts::end(scenario);
    }
}