module simple_coin::simple_coin {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// TreasuryCap capability for minting COIN tokens
    /// Equivalent to TREASURY_ROLE in Solidity
    public struct TreasuryCap has key, store {
        id: UID,
    }

    /// Initialize the coin module and create TreasuryCap
    /// Equivalent to the Solidity constructor
    fun init(ctx: &mut TxContext) {
        let treasury_cap = TreasuryCap {
            id: object::new(ctx),
        };

        // Create the coin type with 2 decimals (like Solidity override)
        let coin_metadata = coin::create_currency(
            treasury_cap,
            b"First Coin",  // name
            b"COIN",        // symbol
            2,              // decimals
            ctx
        );

        // Transfer TreasuryCap to the package publisher (like granting TREASURY_ROLE)
        transfer::public_transfer(coin_metadata, tx_context::sender(ctx));
    }

    /// Mint new COIN tokens to recipient
    /// Equivalent to mint() function in Solidity
    /// Requires TreasuryCap capability (like onlyRole(TREASURY_ROLE))
    public entry fun mint(
        treasury_cap: &mut TreasuryCap,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }

    /// Mint and transfer COIN tokens (syntactic sugar)
    /// Equivalent to mintAndTransfer() function in Solidity
    public entry fun mint_and_transfer(
        treasury_cap: &mut TreasuryCap,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(coin, recipient);
    }

    /// Burn COIN tokens
    /// In Move, anyone can burn their own coins (like ERC20Burnable)
    /// No TreasuryCap required for burning (different from some Move implementations)
    public entry fun burn(coin: Coin<COIN>, ctx: &mut TxContext) {
        let Coin { value, .. } = coin;
        coin::burn(coin, ctx);
    }

    /// Burn from a specific coin object (alternative burn pattern)
    public entry fun burn_coin(coin: Coin<COIN>, ctx: &mut TxContext) {
        coin::burn(coin, ctx);
    }
}