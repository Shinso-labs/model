#[test_only]
module tipjar::tip_jar_tests {
    use tipjar::tip_jar::{Self, TipJar};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::test_scenario::{Self as ts, Scenario};

    // Helper function to create a coin with specific value
    fun mint_sui(scenario: &mut Scenario, amount: u64, recipient: address) {
        ts::next_tx(scenario, @0x0);
        {
            let coin = coin::mint_for_testing<SUI>(amount, ts::ctx(scenario));
            sui::transfer::public_transfer(coin, recipient);
        };
    }

    #[test]
    /// Test that init creates and shares a TipJar
    fun test_init_creates_tip_jar() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            assert!(ts::has_most_recent_shared<TipJar>(), 0);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that initial tip count is zero
    fun test_initial_tip_count_is_zero() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let tip_jar = ts::take_shared<TipJar>(&scenario);
            assert!(tip_jar::get_tip_count(&tip_jar) == 0, 1);
            ts::return_shared(tip_jar);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that initial total tips is zero
    fun test_initial_total_tips_is_zero() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let tip_jar = ts::take_shared<TipJar>(&scenario);
            assert!(tip_jar::get_total_tips(&tip_jar) == 0, 2);
            ts::return_shared(tip_jar);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that owner is set correctly
    fun test_owner_is_set_correctly() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let tip_jar = ts::take_shared<TipJar>(&scenario);
            assert!(tip_jar::get_owner(&tip_jar) == @0xA, 3);
            ts::return_shared(tip_jar);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test sending a single tip updates state correctly
    fun test_send_single_tip() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        mint_sui(&mut scenario, 100, @0xB);
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut tip_jar = ts::take_shared<TipJar>(&scenario);
            let payment = ts::take_from_sender<Coin<SUI>>(&scenario);
            tip_jar::send_tip(&mut tip_jar, payment, ts::ctx(&mut scenario));
            assert!(tip_jar::get_total_tips(&tip_jar) == 100, 4);
            assert!(tip_jar::get_tip_count(&tip_jar) == 1, 5);
            ts::return_shared(tip_jar);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test sending multiple tips accumulates correctly
    fun test_send_multiple_tips() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        // First tip
        mint_sui(&mut scenario, 100, @0xB);
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut tip_jar = ts::take_shared<TipJar>(&scenario);
            let payment = ts::take_from_sender<Coin<SUI>>(&scenario);
            tip_jar::send_tip(&mut tip_jar, payment, ts::ctx(&mut scenario));
            ts::return_shared(tip_jar);
        };
        // Second tip
        mint_sui(&mut scenario, 50, @0xC);
        ts::next_tx(&mut scenario, @0xC);
        {
            let mut tip_jar = ts::take_shared<TipJar>(&scenario);
            let payment = ts::take_from_sender<Coin<SUI>>(&scenario);
            tip_jar::send_tip(&mut tip_jar, payment, ts::ctx(&mut scenario));
            assert!(tip_jar::get_total_tips(&tip_jar) == 150, 6);
            assert!(tip_jar::get_tip_count(&tip_jar) == 2, 7);
            ts::return_shared(tip_jar);
        };
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = tipjar::tip_jar::InvalidTipAmount)]
    /// Test that sending zero amount tip fails
    fun test_zero_tip_fails() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        mint_sui(&mut scenario, 0, @0xB);
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut tip_jar = ts::take_shared<TipJar>(&scenario);
            let payment = ts::take_from_sender<Coin<SUI>>(&scenario);
            tip_jar::send_tip(&mut tip_jar, payment, ts::ctx(&mut scenario));
            ts::return_shared(tip_jar);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that tips are transferred to owner
    fun test_tips_transferred_to_owner() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        mint_sui(&mut scenario, 100, @0xB);
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut tip_jar = ts::take_shared<TipJar>(&scenario);
            let payment = ts::take_from_sender<Coin<SUI>>(&scenario);
            tip_jar::send_tip(&mut tip_jar, payment, ts::ctx(&mut scenario));
            ts::return_shared(tip_jar);
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            // Owner should have received the coin
            assert!(ts::has_most_recent_for_sender<Coin<SUI>>(&scenario), 8);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test is_owner function returns true for owner
    fun test_is_owner_returns_true() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let tip_jar = ts::take_shared<TipJar>(&scenario);
            assert!(tip_jar::is_owner(&tip_jar, @0xA), 9);
            ts::return_shared(tip_jar);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test is_owner function returns false for non-owner
    fun test_is_owner_returns_false() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let tip_jar = ts::take_shared<TipJar>(&scenario);
            assert!(!tip_jar::is_owner(&tip_jar, @0xB), 10);
            ts::return_shared(tip_jar);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test tip count increments correctly with multiple tips
    fun test_tip_count_increments() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        // Send 3 tips
        mint_sui(&mut scenario, 10, @0xB);
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut tip_jar = ts::take_shared<TipJar>(&scenario);
            let payment = ts::take_from_sender<Coin<SUI>>(&scenario);
            tip_jar::send_tip(&mut tip_jar, payment, ts::ctx(&mut scenario));
            ts::return_shared(tip_jar);
        };
        mint_sui(&mut scenario, 20, @0xB);
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut tip_jar = ts::take_shared<TipJar>(&scenario);
            let payment = ts::take_from_sender<Coin<SUI>>(&scenario);
            tip_jar::send_tip(&mut tip_jar, payment, ts::ctx(&mut scenario));
            ts::return_shared(tip_jar);
        };
        mint_sui(&mut scenario, 30, @0xB);
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut tip_jar = ts::take_shared<TipJar>(&scenario);
            let payment = ts::take_from_sender<Coin<SUI>>(&scenario);
            tip_jar::send_tip(&mut tip_jar, payment, ts::ctx(&mut scenario));
            assert!(tip_jar::get_tip_count(&tip_jar) == 3, 11);
            assert!(tip_jar::get_total_tips(&tip_jar) == 60, 12);
            ts::return_shared(tip_jar);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test large tip amount
    fun test_large_tip_amount() {
        let mut scenario = ts::begin(@0xA);
        {
            tip_jar::init_for_testing(ts::ctx(&mut scenario));
        };
        let large_amount = 1_000_000_000; // 1 billion
        mint_sui(&mut scenario, large_amount, @0xB);
        ts::next_tx(&mut scenario, @0xB);
        {
            let mut tip_jar = ts::take_shared<TipJar>(&scenario);
            let payment = ts::take_from_sender<Coin<SUI>>(&scenario);
            tip_jar::send_tip(&mut tip_jar, payment, ts::ctx(&mut scenario));
            assert!(tip_jar::get_total_tips(&tip_jar) == large_amount, 13);
            ts::return_shared(tip_jar);
        };
        ts::end(scenario);
    }
}
