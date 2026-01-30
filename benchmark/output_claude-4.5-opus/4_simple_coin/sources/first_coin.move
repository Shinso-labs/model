/// @title First Coin (COIN)
/// @notice Sui Move implementation of a custom fungible token
/// 
/// Key Translation Decisions:
/// - TREASURY_ROLE → TreasuryCap<FIRST_COIN> (Sui's native capability pattern)
/// - ERC20 storage → Sui's native Coin<T> objects (owned by addresses)
/// - decimals(2) → Set in create_currency during init
/// - Burning → Sui's coin::burn requires TreasuryCap (more restrictive than ERC20Burnable)
/// 
/// Security Notes:
/// - Move's resource safety prevents reentrancy by design
/// - TreasuryCap is a unique object - only one exists, providing strong access control
/// - Coin objects are owned resources - no approval/allowance pattern needed for transfers
module coin::first_coin {
    use sui::coin::{Self, Coin, TreasuryCap, CoinMetadata};
    use sui::url;

    // ============ One-Time Witness ============
    // The OTW pattern ensures create_currency can only be called once.
    // The struct name MUST match the module name in UPPERCASE.
    public struct FIRST_COIN has drop {}

    // ============ Constants ============
    /// Decimals for the coin (matches Solidity: decimals() returns 2)
    const DECIMALS: u8 = 2;

    // ============ Error Codes ============
    /// Error when trying to mint zero amount
    const EZeroAmount: u64 = 0;

    // ============ Init Function ============
    /// Module initializer - runs exactly once when the package is published.
    /// 
    /// This is equivalent to the Solidity constructor:
    /// - Creates the currency with metadata (name, symbol, decimals)
    /// - Transfers TreasuryCap to the publisher (like granting TREASURY_ROLE to msg.sender)
    /// - Makes CoinMetadata a shared immutable object for public access
    /// 
    /// @param witness - One-time witness proving this is the first call
    /// @param ctx - Transaction context (provides sender address, etc.)
    fun init(witness: FIRST_COIN, ctx: &mut TxContext) {
        // Create the currency - this can only be called once due to OTW pattern
        // Equivalent to: constructor() ERC20("First Coin", "COIN")
        let (treasury_cap, metadata) = coin::create_currency<FIRST_COIN>(
            witness,
            DECIMALS,                           // decimals: 2 (matches Solidity override)
            b"COIN",                            // symbol
            b"First Coin",                      // name
            b"A simple fungible token example", // description
            option::none<url::Url>(),           // icon URL (optional)
            ctx
        );

        // Freeze metadata so it becomes publicly readable and immutable
        // This is a common pattern for token metadata
        transfer::public_freeze_object(metadata);

        // Transfer TreasuryCap to the publisher (tx sender)
        // This is equivalent to: _grantRole(TREASURY_ROLE, msg.sender)
        // The TreasuryCap holder can mint and burn tokens
        transfer::public_transfer(treasury_cap, ctx.sender());
    }

    // ============ Entry Functions ============

    /// Mint tokens to a recipient address.
    /// 
    /// Equivalent to Solidity:
    ///   function mint(address to, uint256 amount) external onlyRole(TREASURY_ROLE)
    /// 
    /// Access Control: Only the TreasuryCap holder can call this.
    /// The capability pattern replaces role-based access control - if you have
    /// the TreasuryCap object, you can mint. No need for explicit role checks.
    /// 
    /// @param treasury_cap - Mutable reference to the treasury capability
    /// @param amount - Number of tokens to mint (in smallest units)
    /// @param recipient - Address to receive the minted tokens
    public entry fun mint(
        treasury_cap: &mut TreasuryCap<FIRST_COIN>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        // Validate amount (optional but good practice)
        assert!(amount > 0, EZeroAmount);
        
        // Mint and transfer in one operation
        // coin::mint creates a new Coin<FIRST_COIN> object
        // transfer::public_transfer sends it to the recipient
        let minted_coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(minted_coin, recipient);
    }

    /// Mint and transfer to recipient (explicit naming for API clarity).
    /// 
    /// Equivalent to Solidity:
    ///   function mintAndTransfer(address recipient, uint256 amount) external onlyRole(TREASURY_ROLE)
    /// 
    /// Note: In Sui, this is functionally identical to mint() above.
    /// Provided for API parity with the Solidity contract.
    public entry fun mint_and_transfer(
        treasury_cap: &mut TreasuryCap<FIRST_COIN>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(amount > 0, EZeroAmount);
        let minted_coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(minted_coin, recipient);
    }

    // ============ Burn Functions ============
    
    /// Burn tokens using the TreasuryCap.
    /// 
    /// IMPORTANT DIFFERENCE FROM SOLIDITY:
    /// In ERC20Burnable, any token holder can burn their own tokens.
    /// In Sui's coin module, burning requires the TreasuryCap.
    /// 
    /// This function allows the treasury holder to burn coins.
    /// The coin to burn must be passed as an owned object.
    /// 
    /// @param treasury_cap - Mutable reference to treasury capability
    /// @param coin_to_burn - The coin object to burn (consumed by this function)
    public entry fun burn(
        treasury_cap: &mut TreasuryCap<FIRST_COIN>,
        coin_to_burn: Coin<FIRST_COIN>
    ) {
        coin::burn(treasury_cap, coin_to_burn);
    }

    /// Burn a specific amount from a coin, returning any remainder.
    /// 
    /// This is useful when you want to burn part of a coin.
    /// The remainder is transferred back to the sender.
    /// 
    /// @param treasury_cap - Mutable reference to treasury capability  
    /// @param coin - The coin to burn from
    /// @param amount - Amount to burn
    public entry fun burn_amount(
        treasury_cap: &mut TreasuryCap<FIRST_COIN>,
        mut coin: Coin<FIRST_COIN>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // Split the exact amount to burn
        let to_burn = coin.split(amount, ctx);
        
        // Burn the split portion
        coin::burn(treasury_cap, to_burn);
        
        // Return remainder to sender (if any value remains)
        if (coin.value() > 0) {
            transfer::public_transfer(coin, ctx.sender());
        } else {
            // If coin is empty, destroy it
            coin.destroy_zero();
        }
    }

    // ============ Public Accessors ============
    
    /// Get the total supply of FIRST_COIN tokens.
    /// 
    /// Equivalent to Solidity: totalSupply()
    /// 
    /// @param treasury_cap - Reference to the treasury capability
    /// @return Total supply in smallest units
    public fun total_supply(treasury_cap: &TreasuryCap<FIRST_COIN>): u64 {
        coin::total_supply(treasury_cap)
    }

    // ============ Helper Functions for Programmable Transactions ============
    
    /// Split a coin into two coins.
    /// Useful for sending partial amounts in programmable transactions.
    /// 
    /// @param coin - The coin to split (mutably borrowed)
    /// @param amount - Amount to split off
    /// @return A new coin with the specified amount
    public fun split(
        coin: &mut Coin<FIRST_COIN>,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<FIRST_COIN> {
        coin.split(amount, ctx)
    }

    /// Merge two coins into one.
    /// 
    /// @param coin - The destination coin (mutably borrowed)
    /// @param other - The coin to merge in (consumed)
    public fun join(
        coin: &mut Coin<FIRST_COIN>,
        other: Coin<FIRST_COIN>
    ) {
        coin.join(other);
    }

    /// Get the value of a coin.
    /// 
    /// @param coin - Reference to the coin
    /// @return The coin's value in smallest units
    public fun value(coin: &Coin<FIRST_COIN>): u64 {
        coin.value()
    }
}
