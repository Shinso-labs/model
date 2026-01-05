module coin::coin {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::object::{Self, UID};
    use sui::option;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// Phantom type for the coin.
    public struct COIN has drop, store, copy {}

    /// DEFAULT_ADMIN_ROLE analog; unique capability held by the deployer.
    public struct AdminCap has key {
        id: UID,
    }

    /// Shared controller that safely holds the TreasuryCap.
    /// - Minting still requires AdminCap.
    /// - Burning is open to anyone (matches ERC20Burnable semantics) but uses the stored TreasuryCap to keep supply correct.
    public struct CoinControl has key {
        id: UID,
        treasury_cap: TreasuryCap<COIN>,
    }

    const DECIMALS: u8 = 2;

    /// Initializes the coin:
    /// - Creates currency with 2 decimals.
    /// - Gives metadata and AdminCap to publisher.
    /// - Shares CoinControl so holders can burn via stored TreasuryCap without mint authority.
    public entry fun init(ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<COIN>(
            b"First Coin",                 // name
            b"COIN",                       // symbol
            b"First Coin (ERC20-style)",   // description
            option::none(),                // icon URL (none)
            DECIMALS,                      // decimals = 2
            ctx
        );

        let admin = AdminCap { id: object::new(ctx) };
        let control = CoinControl { id: object::new(ctx), treasury_cap };

        transfer::share_object(control);
        transfer::public_transfer(metadata, tx_context::sender(ctx));
        transfer::public_transfer(admin, tx_context::sender(ctx));
    }

    /// Mint `amount` to `recipient`; only AdminCap holder can mint.
    public entry fun mint(admin_cap: &AdminCap, control: &mut CoinControl, recipient: address, amount: u64, ctx: &mut TxContext) {
        assert!(amount > 0, 0);
        let minted = coin::mint(&mut control.treasury_cap, amount, ctx);
        transfer::public_transfer(minted, recipient);
    }

    /// Alias for mint (mirrors Solidity mintAndTransfer).
    public entry fun mint_and_transfer(admin_cap: &AdminCap, control: &mut CoinControl, recipient: address, amount: u64, ctx: &mut TxContext) {
        mint(admin_cap, control, recipient, amount, ctx);
    }

    /// Allow any holder to burn their own COIN; supply is reduced via the stored TreasuryCap.
    public entry fun burn(control: &mut CoinControl, coin: Coin<COIN>) {
        coin::burn(&mut control.treasury_cap, coin);
    }

    /// Returns the configured decimals (2).
    public fun decimals(): u8 {
        DECIMALS
    }
}