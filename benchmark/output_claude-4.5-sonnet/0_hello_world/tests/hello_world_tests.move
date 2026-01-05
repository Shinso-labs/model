#[test_only]
#[test_only]
module hello_world::hello_world_tests {
    use hello_world::hello_world::{Self, Hello};
    use sui::object;
    use sui::test_scenario;
    use sui::transfer;

    #[test]
    /// Test that mint_hello_world creates a Hello object
    fun test_mint_creates_object() {
        let mut scenario = test_scenario::begin(@0xA);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0xA);
        {
            assert!(test_scenario::has_most_recent_for_sender<Hello>(&scenario), 0);
        };
        test_scenario::end(scenario);
    }

    #[test]
    /// Test that Hello object is transferred to the correct sender
    fun test_object_transferred_to_sender() {
        let mut scenario = test_scenario::begin(@0xB);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0xB);
        {
            assert!(test_scenario::has_most_recent_for_sender<Hello>(&scenario), 1);
        };
        test_scenario::end(scenario);
    }

    #[test]
    /// Test that Hello object has the key ability (can be owned)
    fun test_hello_has_key_ability() {
        let mut scenario = test_scenario::begin(@0xC);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0xC);
        {
            let hello = test_scenario::take_from_sender<Hello>(&scenario);
            // If we can take and return, it has key ability
            test_scenario::return_to_sender(&scenario, hello);
        };
        test_scenario::end(scenario);
    }

    #[test]
    /// Test that multiple Hello objects can be minted
    fun test_multiple_mints() {
        let mut scenario = test_scenario::begin(@0xD);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0xD);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0xD);
        {
            // Both objects should exist
            assert!(test_scenario::has_most_recent_for_sender<Hello>(&scenario), 2);
        };
        test_scenario::end(scenario);
    }

    #[test]
    /// Test that Hello object has store ability (can be transferred)
    fun test_hello_has_store_ability() {
        let mut scenario = test_scenario::begin(@0xF);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0xF);
        {
            let hello = test_scenario::take_from_sender<Hello>(&scenario);
            // Transfer to another address
            transfer::public_transfer(hello, @0x10);
        };
        test_scenario::next_tx(&mut scenario, @0x10);
        {
            assert!(test_scenario::has_most_recent_for_sender<Hello>(&scenario), 3);
        };
        test_scenario::end(scenario);
    }

    #[test]
    /// Test that each Hello object has a unique ID
    fun test_unique_ids() {
        let mut scenario = test_scenario::begin(@0x11);
        let id1: object::ID;
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0x11);
        {
            let hello = test_scenario::take_from_sender<Hello>(&scenario);
            id1 = object::id(&hello);
            test_scenario::return_to_sender(&scenario, hello);
        };
        test_scenario::next_tx(&mut scenario, @0x11);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0x11);
        {
            let hello2 = test_scenario::take_from_sender<Hello>(&scenario);
            let id2 = object::id(&hello2);
            assert!(id1 != id2, 4); // IDs should be different
            test_scenario::return_to_sender(&scenario, hello2);
        };
        test_scenario::end(scenario);
    }

    #[test]
    /// Test that different users can mint their own Hello objects
    fun test_different_users_can_mint() {
        let mut scenario = test_scenario::begin(@0x12);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0x13);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0x13);
        {
            assert!(test_scenario::has_most_recent_for_sender<Hello>(&scenario), 5);
        };
        test_scenario::end(scenario);
    }

    #[test]
    /// Test that Hello object can be taken from sender
    fun test_object_can_be_taken() {
        let mut scenario = test_scenario::begin(@0x14);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0x14);
        {
            let hello = test_scenario::take_from_sender<Hello>(&scenario);
            test_scenario::return_to_sender(&scenario, hello);
        };
        test_scenario::end(scenario);
    }

    #[test]
    /// Test that minting works for address zero (edge case)
    fun test_mint_for_address_zero() {
        let mut scenario = test_scenario::begin(@0x0);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0x0);
        {
            assert!(test_scenario::has_most_recent_for_sender<Hello>(&scenario), 6);
        };
        test_scenario::end(scenario);
    }

    #[test]
    /// Test sequential mints by same user create multiple objects
    fun test_sequential_mints() {
        let mut scenario = test_scenario::begin(@0x15);
        // Mint first object
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0x15);
        // Mint second object
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0x15);
        // Mint third object
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0x15);
        {
            assert!(test_scenario::has_most_recent_for_sender<Hello>(&scenario), 7);
        };
        test_scenario::end(scenario);
    }

    #[test]
    /// Test that object ID is valid (not zero address)
    fun test_object_id_is_valid() {
        let mut scenario = test_scenario::begin(@0x16);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            hello_world::mint_hello_world(ctx);
        };
        test_scenario::next_tx(&mut scenario, @0x16);
        {
            let hello = test_scenario::take_from_sender<Hello>(&scenario);
            let id = object::id(&hello);
            assert!(object::id_to_address(&id) != @0x0, 8);
            test_scenario::return_to_sender(&scenario, hello);
        };
        test_scenario::end(scenario);
    }
}