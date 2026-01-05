module first_coin::first_coin {
    use sui::coin::{Self, Coin, CoinMetadata, TreasuryCap};
    use sui::object::{Self, UID};
    use sui::option;
    use sui::string::{Self, String};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// Coin type marker; analogous to the ERC-20 token contract.
    public struct COIN has drop {}

    /// Admin capability: replaces AccessControl DEFAULT_ADMIN_ROLE.
    /// Holder can operate on the TreasuryCap (i.e., minting rights).
    public struct AdminCap has key, store {
        id: UID,
    }

    /// Publish-time initializer: creates the coin type with 2 decimals,
    /// shares metadata, and gives the publisher both AdminCap and TreasuryCap.
    fun init(ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<COIN>(
            string::utf8(b"First Coin"),          // name
            string::utf8(b"COIN"),                // symbol
            string::utf8(b"First Coin (COIN)"),   // description
            option::none(),                       // icon URL
            2,                                    // decimals (matches Solidity override)
            ctx
        );

        // Share metadata so wallets/UIs can read coin info.
        transfer::share_object(metadata);

        // Give deployer the admin capability and treasury cap (minter authority).
        let admin = AdminCap { id: object::new(ctx) };
        transfer::public_transfer(admin, tx_context::sender(ctx));
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    /// Mint `amount` to `recipient`. Requires AdminCap + TreasuryCap (mirrors TREASURY_ROLE).
    public entry fun mint(
        _admin: &AdminCap,
        treasury_cap: &mut TreasuryCap<COIN>,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx);
    }

    /// Mint to self (publisher) and then transfer — syntactic sugar akin to `mintAndTransfer`.
    public entry fun mint_and_transfer(
        _admin: &AdminCap,
        treasury_cap: &mut TreasuryCap<COIN>,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx);
    }

    /// Burn an entire Coin object (holder-initiated burn, like ERC20Burnable burn()).
    public entry fun burn(coin_in: Coin<COIN>) {
        coin::burn(coin_in);
    }

    /// Burn a specific `amount` from a Coin object the caller owns (like burnFrom via allowance in spirit).
    public entry fun burn_amount(coin_in: &mut Coin<COIN>, amount: u64, ctx: &mut TxContext) {
        let to_burn = coin::split(coin_in, amount, ctx);
        coin::burn(to_burn);
    }

    /// Optional: transfer AdminCap to a new admin (similar to changing DEFAULT_ADMIN_ROLE holder).
    public entry fun transfer_admin_cap(admin: AdminCap, recipient: address) {
        transfer::public_transfer(admin, recipient);
    }

    /// Optional: transfer TreasuryCap to a new minter.
    public entry fun transfer_treasury_cap(treasury_cap: TreasuryCap<COIN>, recipient: address) {
        transfer::public_transfer(treasury_cap, recipient);
    }
}