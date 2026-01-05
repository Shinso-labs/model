module coin::coin {
    use sui::coin::{Self, Coin, TreasuryCap};

    /// One-time witness for coin creation (drop ability allows single use)
    public struct COIN has drop {}

    /// Initializes the coin with metadata and transfers treasury cap to deployer
    /// Creates currency with 2 decimals, symbol "COIN", and freezes metadata
    fun init(witness: COIN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<COIN>(
            witness, 
            2,                              // Decimals
            b"COIN",                        // Symbol
            b"First Coin",                  // Name
            b"This is my first coin",       // Description
            option::none(),                 // Icon URL (none)
            ctx
        );
        
        // Freeze metadata so it can't be modified
        transfer::public_freeze_object(metadata);
        // Transfer minting authority to deployer
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx))
    }

    /// Mints new coins and returns them
    public fun mint(
        treasury_cap: &mut TreasuryCap<COIN>, 
        amount: u64, 
        ctx: &mut TxContext
    ): Coin<COIN> {
        coin::mint(treasury_cap, amount, ctx)
    }

    /// Mints new coins and directly transfers to recipient
    entry fun mint_and_transfer(
        treasury_cap: &mut TreasuryCap<COIN>, 
        amount: u64, 
        recipient: address, 
        ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx);
    }

    /// Burns coins, removing them from circulation
    entry fun burn(treasury_cap: &mut TreasuryCap<COIN>, coin: Coin<COIN>) {
        coin::burn(treasury_cap, coin);
    }

    /// Test-only function to initialize coin in tests
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        let witness = COIN {};
        init(witness, ctx);
    }
}