module coin::coin {
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::event::{Self, emit};
    use sui::transfer;

    // Role constants
    const TREASURY_ROLE: &str = "TREASURY_ROLE";

    // Event: Emitted when tokens are minted
    struct MintEvent has key {
        amount: u64,
        to: address,
    }

    // Event: Emitted when tokens are burned
    struct BurnEvent has key {
        amount: u64,
        from: address,
    }

    // Treasury capability: grants minting rights
    struct TreasuryCap has key {
        id: UID,
    }

    // Coin resource: the actual token
    struct Coin has key {
        id: UID,
        value: u64,
    }

    // Initialize the coin and treasury cap
    public entry fun init(ctx: &mut TxContext) {
        // Create the treasury cap (admin capability)
        let treasury_cap = TreasuryCap {
            id: object::new(ctx),
        };

        // Create the coin type (register with Sui)
        coin::register::<Coin>(ctx);

        // Share the treasury cap so it can be used by others
        transfer::share_object(treasury_cap);
    }

    // Mint tokens to a recipient
    public entry fun mint(treasury_cap: &mut TreasuryCap, to: address, amount: u64, ctx: &mut TxContext) {
        // Ensure amount is positive
        assert!(amount > 0, 1001);

        // Create new coin object
        let coin = Coin {
            id: object::new(ctx),
            value: amount,
        };

        // Transfer the coin to the recipient
        transfer::transfer(coin, to);

        // Emit mint event
        emit(MintEvent {
            amount,
            to,
        });
    }

    // Mint and transfer in one step
    public entry fun mint_and_transfer(treasury_cap: &mut TreasuryCap, recipient: address, amount: u64, ctx: &mut TxContext) {
        // Ensure amount is positive
        assert!(amount > 0, 1001);

        // Create new coin object
        let coin = Coin {
            id: object::new(ctx),
            value: amount,
        };

        // Transfer directly to recipient
        transfer::transfer(coin, recipient);

        // Emit mint event
        emit(MintEvent {
            amount,
            to: recipient,
        });
    }

    // Burn tokens from caller's balance
    public entry fun burn(coin: &mut Coin, amount: u64) {
        // Ensure amount is valid
        assert!(amount > 0, 1002);
        assert!(coin.value >= amount, 1003);

        // Deduct amount
        coin.value = coin.value - amount;

        // Emit burn event
        emit(BurnEvent {
            amount,
            from: tx_context::sender(),
        });
    }

    // Burn tokens from another account (via allowance)
    public entry fun burn_from(coin: &mut Coin, amount: u64) {
        // Ensure amount is valid
        assert!(amount > 0, 1002);
        assert!(coin.value >= amount, 1003);

        // Deduct amount
        coin.value = coin.value - amount;

        // Emit burn event
        emit(BurnEvent {
            amount,
            from: tx_context::sender(),
        });
    }

    // Get the current coin value
    public fun value(coin: &Coin): u64 {
        coin.value
    }

    // Get the coin's ID
    public fun id(coin: &Coin): UID {
        coin.id
    }

    // Get the decimal precision (2 decimals)
    public fun decimals(): u8 {
        2
    }
}