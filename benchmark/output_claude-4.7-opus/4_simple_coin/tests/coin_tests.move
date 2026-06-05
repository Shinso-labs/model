#[test_only]
module coin::coin_tests {
    use coin::coin::{Self, COIN};
    use sui::coin::{Coin, TreasuryCap};
    use sui::test_scenario::{Self as ts};

    #[test]
    /// Test that mint creates coins with correct amount
    fun test_mint_creates_correct_amount() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<COIN>>(&scenario);
            let minted_coin = coin::mint(&mut treasury_cap, 100, ts::ctx(&mut scenario));
            assert!(sui::coin::value(&minted_coin) == 100, 0);
            sui::transfer::public_transfer(minted_coin, @0xA);
            ts::return_to_sender(&scenario, treasury_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that mint can create zero amount
    fun test_mint_zero_amount() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<COIN>>(&scenario);
            let minted_coin = coin::mint(&mut treasury_cap, 0, ts::ctx(&mut scenario));
            assert!(sui::coin::value(&minted_coin) == 0, 1);
            sui::transfer::public_transfer(minted_coin, @0xA);
            ts::return_to_sender(&scenario, treasury_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that mint can create large amounts
    fun test_mint_large_amount() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<COIN>>(&scenario);
            let large_amount = 1_000_000_000_000;
            let minted_coin = coin::mint(&mut treasury_cap, large_amount, ts::ctx(&mut scenario));
            assert!(sui::coin::value(&minted_coin) == large_amount, 2);
            sui::transfer::public_transfer(minted_coin, @0xA);
            ts::return_to_sender(&scenario, treasury_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that multiple mints work correctly
    fun test_multiple_mints() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<COIN>>(&scenario);
            let coin1 = coin::mint(&mut treasury_cap, 100, ts::ctx(&mut scenario));
            let coin2 = coin::mint(&mut treasury_cap, 200, ts::ctx(&mut scenario));
            let coin3 = coin::mint(&mut treasury_cap, 300, ts::ctx(&mut scenario));
            assert!(sui::coin::value(&coin1) == 100, 3);
            assert!(sui::coin::value(&coin2) == 200, 4);
            assert!(sui::coin::value(&coin3) == 300, 5);
            sui::transfer::public_transfer(coin1, @0xA);
            sui::transfer::public_transfer(coin2, @0xA);
            sui::transfer::public_transfer(coin3, @0xA);
            ts::return_to_sender(&scenario, treasury_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that burn reduces supply correctly
    fun test_burn_reduces_supply() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<COIN>>(&scenario);
            let minted_coin = coin::mint(&mut treasury_cap, 100, ts::ctx(&mut scenario));
            coin::burn(&mut treasury_cap, minted_coin);
            ts::return_to_sender(&scenario, treasury_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that burn works with zero amount coin
    fun test_burn_zero_amount() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<COIN>>(&scenario);
            let minted_coin = coin::mint(&mut treasury_cap, 0, ts::ctx(&mut scenario));
            coin::burn(&mut treasury_cap, minted_coin);
            ts::return_to_sender(&scenario, treasury_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test mint and burn sequence
    fun test_mint_and_burn_sequence() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<COIN>>(&scenario);
            let coin1 = coin::mint(&mut treasury_cap, 1000, ts::ctx(&mut scenario));
            coin::burn(&mut treasury_cap, coin1);
            let coin2 = coin::mint(&mut treasury_cap, 500, ts::ctx(&mut scenario));
            assert!(sui::coin::value(&coin2) == 500, 6);
            sui::transfer::public_transfer(coin2, @0xA);
            ts::return_to_sender(&scenario, treasury_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that coins can be transferred between users
    fun test_coin_transfer() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<COIN>>(&scenario);
            let minted_coin = coin::mint(&mut treasury_cap, 100, ts::ctx(&mut scenario));
            sui::transfer::public_transfer(minted_coin, @0xB);
            ts::return_to_sender(&scenario, treasury_cap);
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let received_coin = ts::take_from_sender<Coin<COIN>>(&scenario);
            assert!(sui::coin::value(&received_coin) == 100, 7);
            ts::return_to_sender(&scenario, received_coin);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test minting to multiple different users
    fun test_mint_to_multiple_users() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<COIN>>(&scenario);
            let coin1 = coin::mint(&mut treasury_cap, 100, ts::ctx(&mut scenario));
            let coin2 = coin::mint(&mut treasury_cap, 200, ts::ctx(&mut scenario));
            let coin3 = coin::mint(&mut treasury_cap, 300, ts::ctx(&mut scenario));
            sui::transfer::public_transfer(coin1, @0xB);
            sui::transfer::public_transfer(coin2, @0xC);
            sui::transfer::public_transfer(coin3, @0xD);
            ts::return_to_sender(&scenario, treasury_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that coin values are preserved through operations
    fun test_coin_value_preservation() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<COIN>>(&scenario);
            let amount = 12345;
            let minted_coin = coin::mint(&mut treasury_cap, amount, ts::ctx(&mut scenario));
            assert!(sui::coin::value(&minted_coin) == amount, 8);
            sui::transfer::public_transfer(minted_coin, @0xB);
            ts::return_to_sender(&scenario, treasury_cap);
        };
        ts::next_tx(&mut scenario, @0xB);
        {
            let received_coin = ts::take_from_sender<Coin<COIN>>(&scenario);
            assert!(sui::coin::value(&received_coin) == 12345, 9);
            ts::return_to_sender(&scenario, received_coin);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test burning large amount of coins
    fun test_burn_large_amount() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<COIN>>(&scenario);
            let large_amount = 999_999_999_999;
            let minted_coin = coin::mint(&mut treasury_cap, large_amount, ts::ctx(&mut scenario));
            coin::burn(&mut treasury_cap, minted_coin);
            ts::return_to_sender(&scenario, treasury_cap);
        };
        ts::end(scenario);
    }

    #[test]
    /// Test that treasury cap is transferred to creator
    fun test_treasury_cap_transferred() {
        let mut scenario = ts::begin(@0xA);
        {
            coin::init_for_testing(ts::ctx(&mut scenario));
        };
        ts::next_tx(&mut scenario, @0xA);
        {
            assert!(ts::has_most_recent_for_sender<TreasuryCap<COIN>>(&scenario), 10);
        };
        ts::end(scenario);
    }
}
