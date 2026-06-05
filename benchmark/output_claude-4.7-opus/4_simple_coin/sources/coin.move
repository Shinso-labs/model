// sources/coin.move
/// First Coin (COIN) - Sui Move implementation
///
/// Translation notes:
/// - In Solidity, `TREASURY_ROLE` (a bytes32 role) acts as a minter capability.
///   In Sui Move, the `TreasuryCap<COIN>` object IS the capability — whoever
///   owns the object can mint/burn. This is the idiomatic Sui pattern and
///   provides stronger guarantees than role-based access control because
///   the capability is a first-class object that cannot be forged.
///
/// - In Solidity, the deployer is granted both DEFAULT_ADMIN_ROLE and
///   TREASURY_ROLE in the constructor. In Sui, the `init` function transfers
///   the `TreasuryCap` to the publisher (sender), which is the equivalent.
///
/// - Burning: ERC20Burnable allows any holder to burn their own tokens. In
///   Sui's `coin` module, burning requires the `TreasuryCap`. We follow the
///   Sui-native pattern where `burn` is gated by the cap, matching the Move
///   semantics referenced in the original Solidity comments.
module coin::coin {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::url;

    /// One-Time Witness for the COIN currency.
    /// Must match the module name in uppercase.
    public struct COIN has drop {}

    /// Module initializer — runs exactly once at publish time.
    /// Equivalent to the Solidity `constructor`:
    ///   - creates the currency (analogous to deploying the ERC-20)
    ///   - transfers the `TreasuryCap` (== TREASURY_ROLE) to the deployer
    ///   - freezes the `CoinMetadata` so it becomes immutable on-chain
    fun init(witness: COIN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<COIN>(
            witness,
            2, // decimals — matches Solidity `decimals() returns 2`
            b"COIN", // symbol
            b"First Coin", // name
            b"First Coin (COIN) - Sui Move equivalent of FirstCoin ERC-20", // description
            option::none<url::Url>(), // icon URL (none)
            ctx,
        );

        // Freeze metadata so symbol/name/decimals cannot change.
        transfer::public_freeze_object(metadata);

        // Deployer receives the TreasuryCap — equivalent to
        // `_grantRole(TREASURY_ROLE, msg.sender)` in the Solidity constructor.
        transfer::public_transfer(treasury_cap, ctx.sender());
    }

    // ============================================================
    // Minting (gated by ownership of TreasuryCap == TREASURY_ROLE)
    // ============================================================

    /// Mirrors Solidity `mint(address to, uint256 amount)` — but returns the
    /// freshly minted `Coin<COIN>` to the caller's PTB rather than transferring
    /// it directly. This is the composable Sui-native form, analogous to
    /// Move's `mint(treasury_cap, amount, ...) -> Coin<COIN>`.
    ///
    /// Access control: caller must own (have a mutable reference to) the
    /// `TreasuryCap<COIN>` — the Sui-native equivalent of `onlyRole(TREASURY_ROLE)`.
    public fun mint(
        treasury_cap: &mut TreasuryCap<COIN>,
        amount: u64,
        ctx: &mut TxContext,
    ): Coin<COIN> {
        coin::mint<COIN>(treasury_cap, amount, ctx)
    }

    /// Mirrors Solidity `mintAndTransfer(address recipient, uint256 amount)`.
    /// Mints `amount` tokens and transfers them to `recipient` in one call.
    public entry fun mint_and_transfer(
        treasury_cap: &mut TreasuryCap<COIN>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let new_coin = coin::mint<COIN>(treasury_cap, amount, ctx);
        transfer::public_transfer(new_coin, recipient);
    }

    // ============================================================
    // Burning
    // ============================================================

    /// Burn a `Coin<COIN>` object. Requires the `TreasuryCap`.
    ///
    /// Note: Solidity's ERC20Burnable lets any holder burn their own tokens
    /// without privileged access. In Sui's native coin model, burning
    /// requires the `TreasuryCap`. We follow the Sui-native pattern here,
    /// which matches the Move semantics referenced in the original
    /// Solidity comments ("Move required `treasury_cap` to burn").
    public entry fun burn(
        treasury_cap: &mut TreasuryCap<COIN>,
        c: Coin<COIN>,
    ) {
        coin::burn<COIN>(treasury_cap, c);
    }

    // ============================================================
    // Test-only helpers
    // ============================================================

    /// Test-only initializer so unit tests can simulate the publish-time
    /// `init` flow (which the test framework cannot invoke directly).
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(COIN {}, ctx)
    }
}
