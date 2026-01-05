module coin::simple_coin {
    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// Treasury capability - equivalent to TREASURY_ROLE in Solidity
    /// This capability allows minting new coins
    public struct TreasuryCap has key, store {
        id: UID,
    }

    /// Initialize the coin module and create TreasuryCap
    /// Equivalent to the Solidity constructor
    fun init(ctx: &mut TxContext) {
        // Create and transfer TreasuryCap to the package publisher
        // This mirrors the _grantRole(TREASURY_ROLE, msg.sender) in Solidity
        transfer::public_transfer(
            TreasuryCap {
                id: object::new(ctx),
            },
            tx_context::sender(ctx)
        );
    }

    /// Mint new coins to a recipient
    /// Equivalent to mint(address to, uint256 amount) in Solidity
    /// Uses TreasuryCap for access control instead of onlyRole(TREASURY_ROLE)
    public entry fun mint(
        treasury_cap: &TreasuryCap,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        // Create new coins with 2 decimals (same as Solidity override)
        let coin = coin::mint<TreasuryCap>(
            treasury_cap,
            amount,
            ctx
        );

        // Transfer the newly minted coins to recipient
        transfer::public_transfer(coin, recipient);
    }

    /// Mint and transfer coins in one operation
    /// Equivalent to mintAndTransfer(address recipient, uint256 amount) in Solidity
    public entry fun mint_and_transfer(
        treasury_cap: &TreasuryCap,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        // This is essentially the same as mint() but provided for API consistency
        // with the Solidity version
        let coin = coin::mint<TreasuryCap>(
            treasury_cap,
            amount,
            ctx
        );

        transfer::public_transfer(coin, recipient);
    }

    /// Burn coins - anyone can burn their own coins
    /// Equivalent to burn(uint256 amount) in Solidity
    /// In Move, burning is done by destroying the coin object
    public entry fun burn(coin: Coin<TreasuryCap>) {
        // Destroy the coin object to burn it
        // This is simpler than Solidity's burn mechanism
        let Coin { value: _, .. } = coin;
        // Coin is destroyed here
    }

    /// Burn coins from another account using a transfer request
    /// This would require the sender to have received the coin via transfer
    /// Equivalent concept to burnFrom(address account, uint256 amount) in Solidity
    public entry fun burn_from(
        coin: Coin<TreasuryCap>,
        _ctx: &mut TxContext
    ) {
        // The coin must be transferred to this function by its owner
        // This provides the same functionality as burnFrom but with Move's
        // object ownership model
        let Coin { value: _, .. } = coin;
        // Coin is destroyed here
    }
}