module coin::coin {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// The `COIN` struct serves as the unique type identifier for our fungible token.
    /// It has the `drop` ability, meaning it can be freely created and destroyed,
    /// but it's primarily used as a phantom type parameter for `sui::coin::Coin<COIN>`.
    struct COIN has drop {}

    /// `init` is called once when the module is published.
    /// It creates the `COIN` currency and transfers the `TreasuryCap` to the deployer.
    /// This mirrors the Solidity constructor's role granting (`_grantRole(TREASURY_ROLE, msg.sender)`).
    fun init(ctx: &mut TxContext) {
        // Create the currency with name "First Coin", symbol "COIN", and 2 decimals.
        // The TreasuryCap is returned, which grants the ability to mint and burn.
        let treasury_cap = coin::create_currency(COIN {}, 2, b"First Coin", b"COIN", ctx);

        // Transfer the TreasuryCap to the module deployer.
        // This makes the deployer the "admin" or "minter" for this coin.
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    /// Mints `amount` of `COIN` tokens and transfers them to `recipient`.
    /// This function requires a mutable reference to `TreasuryCap<COIN>`,
    /// enforcing the access control similar to Solidity's `onlyRole(TREASURY_ROLE)`.
    public entry fun mint(
        treasury_cap: &mut TreasuryCap<COIN>,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Mint new coins using the treasury capability.
        let new_coin = coin::mint(treasury_cap, amount, ctx);
        // Transfer the newly minted coin to the specified recipient.
        transfer::public_transfer(new_coin, recipient);
    }

    /// Mints `amount` of `COIN` tokens and directly transfers them to `recipient`.
    /// This is a convenience function, mirroring Solidity's `mintAndTransfer`.
    /// It also requires the `TreasuryCap` for access control.
    public entry fun mint_and_transfer(
        treasury_cap: &mut TreasuryCap<COIN>,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Use the sui::coin's direct mint_and_transfer function.
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx);
    }

    /// Burns a `Coin<COIN>` object provided by the caller.
    /// In Move, any holder of a `Coin` object can burn it,
    /// which aligns with Solidity's `ERC20Burnable` where `burn` is a public function
    /// that burns the caller's own tokens. The `Coin<COIN>` object itself represents
    /// the tokens to be burned.
    public entry fun burn(coin: Coin<COIN>) {
        // Destroy the coin object, effectively burning the tokens.
        coin::burn(coin);
    }

    /// Helper function to get the balance of a specific address.
    /// This is not an entry function as it only reads state.
    public fun balance_of(owner: address): u64 {
        coin::balance(owner, COIN {})
    }

    // Note on `burnFrom`:
    // The Solidity `burnFrom` function relies on an allowance mechanism (ERC20 `approve` and `transferFrom`).
    // In Sui Move's `sui::coin` module, there isn't a direct equivalent for this allowance pattern.
    // To achieve a similar effect, the owner of the tokens would typically need to explicitly
    // transfer the `Coin<COIN>` object to the address that is intended to burn them,
    // or a more complex shared object/capability pattern would be required to manage allowances,
    // which goes beyond the scope of a direct `sui::coin` wrapper.
    // Therefore, a direct `burnFrom` entry function is not provided here.
}