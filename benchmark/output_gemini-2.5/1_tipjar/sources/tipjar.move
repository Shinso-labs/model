module tip_jar::tip_jar {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::event;

    /// Error codes
    const EInvalidTipAmount: u64 = 0;
    const ENotOwner: u64 = 1;
    const ENothingToWithdraw: u64 = 2;

    /// The TipJar object, which is shared and holds the accumulated tips.
    /// It includes the owner's address for public readability and tracks tip statistics.
    public struct TipJar has key, store {
        id: UID,
        /// The address of the owner, publicly readable.
        owner_address: address,
        /// Total amount of SUI received as tips.
        total_tips_received: u64,
        /// Total number of tips received.
        tip_count: u64,
        /// The internal balance of SUI accumulated from tips.
        balance: Coin<sui::sui::SUI>,
    }

    /// A capability object that grants the holder the right to perform owner-only actions.
    /// This replaces Solidity's `onlyOwner` modifier and `owner` state variable for access control.
    public struct OwnerCap has key, store {
        id: UID,
        /// The address this capability is for.
        for: address,
    }

    /// Event emitted when the TipJar is created.
    public struct TipCreatedEvent has Copy, Drop {
        owner: address,
    }

    /// Event emitted when a tip is successfully sent.
    public struct TipSentEvent has Copy, Drop {
        tipper: address,
        amount: u64,
        total_tips: u64,
        tip_count: u64,
    }

    /// Initializes the TipJar module. This function is called once when the package is published.
    /// It creates and shares the TipJar object and transfers the OwnerCap to the deployer.
    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        // Create and share the TipJar object
        transfer::share_object(TipJar {
            id: object::new(ctx),
            owner_address: sender, // Set the initial owner address
            total_tips_received: 0,
            tip_count: 0,
            balance: coin::zero(ctx), // Initialize with an empty SUI coin
        });

        // Create and transfer the OwnerCap to the deployer
        transfer::public_transfer(OwnerCap {
            id: object::new(ctx),
            for: sender,
        }, sender);

        // Emit the TipCreated event
        event::emit(TipCreatedEvent { owner: sender });
    }

    /// Allows anyone to send a tip (in SUI) to the TipJar.
    /// The received SUI is added to the TipJar's internal balance.
    public entry fun send_tip(tip_jar: &mut TipJar, tip_coin: Coin<sui::sui::SUI>, ctx: &mut TxContext) {
        let tip_amount = coin::value(&tip_coin);
        assert!(tip_amount > 0, EInvalidTipAmount);

        // Join the received tip coin into the TipJar's internal balance
        coin::join(&mut tip_jar.balance, tip_coin);

        // Update state variables
        tip_jar.total_tips_received = tip_jar.total_tips_received + tip_amount;
        tip_jar.tip_count = tip_jar.tip_count + 1;

        // Emit the TipSent event
        event::emit(TipSentEvent {
            tipper: tx_context::sender(ctx),
            amount: tip_amount,
            total_tips: tip_jar.total_tips_received,
            tip_count: tip_jar.tip_count,
        });
    }

    /// Allows the owner to withdraw all accumulated SUI from the TipJar's balance.
    /// Requires the `OwnerCap` to prove ownership.
    public entry fun withdraw(owner_cap: &OwnerCap, tip_jar: &mut TipJar, ctx: &mut TxContext) {
        // Verify that the caller is the actual owner by checking the capability
        assert!(owner_cap.for == tx_context::sender(ctx), ENotOwner);

        let balance_value = coin::value(&tip_jar.balance);
        assert!(balance_value > 0, ENothingToWithdraw);

        // Take all SUI from the TipJar's internal balance
        let withdrawn_coin = coin::take_all(&mut tip_jar.balance, ctx);

        // Transfer the withdrawn SUI to the owner's address
        transfer::public_transfer(withdrawn_coin, tx_context::sender(ctx));
    }

    /// Public view function to check if a given address is the owner of the TipJar.
    public fun is_owner(tip_jar: &TipJar, addr: address): bool {
        tip_jar.owner_address == addr
    }

    /// Public view function to get the current total tips received.
    public fun get_total_tips_received(tip_jar: &TipJar): u64 {
        tip_jar.total_tips_received
    }

    /// Public view function to get the current tip count.
    public fun get_tip_count(tip_jar: &TipJar): u64 {
        tip_jar.tip_count
    }

    /// Public view function to get the current balance held by the TipJar.
    public fun get_balance(tip_jar: &TipJar): u64 {
        coin::value(&tip_jar.balance)
    }
}