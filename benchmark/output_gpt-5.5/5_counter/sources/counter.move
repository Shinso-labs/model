module counter::counter;

use sui::event;
use sui::object::{Self as object, ID, UID};
use sui::transfer;
use sui::tx_context::{Self as tx_context, TxContext};

/// Move arithmetic aborts on overflow, but we keep an explicit overflow check
/// to mirror Solidity 0.8+ checked arithmetic semantics.
const MAX_U64: u64 = 18446744073709551615;

/// Abort codes.
///
/// `EOVERFLOW` is intentionally `0` to preserve compatibility with tests that
/// expect abort code `0`.
const EOVERFLOW: u64 = 0;
const ENOT_OWNER: u64 = 1;

/// Sui-native representation of the Solidity ERC-721 Counter token.
///
/// The original Solidity contract has:
/// - ERC-721 token ownership
/// - `mapping(uint256 => uint256) private _value`
/// - global incrementing token IDs
///
/// This Sui version represents each counter as one shared object. The object ID
/// is the Sui-native token identifier. Because shared objects are not owned by a
/// single address, ERC-721-style ownership is represented explicitly by the
/// `owner` field.
///
/// Anyone can increment because the object is shared.
/// Only `owner` can call `set_value`.
public struct Counter has key {
    id: UID,

    /// Sui-native token ID.
    token_id: ID,

    /// Simulated ERC-721 owner.
    owner: address,

    /// Current counter value.
    value: u64,
}

/// Equivalent to Solidity:
/// `event CounterCreated(uint256 indexed tokenId, address indexed owner);`
public struct CounterCreated has copy, drop {
    token_id: ID,
    owner: address,
}

/// Equivalent to Solidity:
/// `event Incremented(uint256 indexed tokenId, uint256 newValue);`
public struct Incremented has copy, drop {
    token_id: ID,
    new_value: u64,
}

/// Equivalent to Solidity:
/// `event ValueSet(uint256 indexed tokenId, uint256 newValue);`
public struct ValueSet has copy, drop {
    token_id: ID,
    new_value: u64,
}

/// ERC-721-style ownership transfer event.
public struct OwnershipTransferred has copy, drop {
    token_id: ID,
    previous_owner: address,
    new_owner: address,
}

/// Create and mint a new counter NFT to the transaction sender with value `0`.
///
/// Solidity equivalent:
/// `function create() external returns (uint256 tokenId)`
///
/// The previous version used `public entry fun`. In Move 2024, `public`
/// functions are already callable from PTBs, so the unnecessary `entry`
/// modifier has been removed to satisfy the linter.
public fun create(ctx: &mut TxContext) {
    let sender = tx_context::sender(ctx);

    let uid = object::new(ctx);
    let token_id = object::uid_to_inner(&uid);

    let counter = Counter {
        id: uid,
        token_id,
        owner: sender,
        value: 0,
    };

    event::emit(CounterCreated {
        token_id,
        owner: sender,
    });

    // Shared object so anyone can call `increment`.
    transfer::share_object(counter);
}

/// Anyone can increment the shared counter by 1.
///
/// Solidity equivalent:
/// `function increment(uint256 tokenId) external`
///
/// `entry` was removed because `public` functions are PTB-callable in Move 2024.
public fun increment(counter: &mut Counter) {
    assert!(counter.value < MAX_U64, EOVERFLOW);

    counter.value = counter.value + 1;

    event::emit(Incremented {
        token_id: counter.token_id,
        new_value: counter.value,
    });
}

/// Set the counter to an arbitrary value.
///
/// Solidity equivalent:
/// `function setValue(uint256 tokenId, uint256 newValue) external`
///
/// Solidity checked:
/// `ownerOf(tokenId) == msg.sender`
///
/// Here, because the object is shared, ownership is checked against the stored
/// `owner` field.
///
/// `entry` was removed because `public` functions are PTB-callable in Move 2024.
public fun set_value(counter: &mut Counter, new_value: u64, ctx: &mut TxContext) {
    assert!(counter.owner == tx_context::sender(ctx), ENOT_OWNER);

    counter.value = new_value;

    event::emit(ValueSet {
        token_id: counter.token_id,
        new_value,
    });
}

/// Transfer ERC-721-style ownership of the shared counter object.
///
/// Since the object itself is shared, this updates the internal owner field.
/// Only the current owner may transfer ownership.
///
/// `entry` was removed because `public` functions are PTB-callable in Move 2024.
public fun transfer_ownership(
    counter: &mut Counter,
    new_owner: address,
    ctx: &mut TxContext,
) {
    let sender = tx_context::sender(ctx);
    assert!(counter.owner == sender, ENOT_OWNER);

    counter.owner = new_owner;

    event::emit(OwnershipTransferred {
        token_id: counter.token_id,
        previous_owner: sender,
        new_owner,
    });
}

/// Read current value.
///
/// Solidity equivalent:
/// `function getValue(uint256 tokenId) external view returns (uint256)`
public fun get_value(counter: &Counter): u64 {
    counter.value
}

/// Return the current ERC-721-style owner address.
public fun owner(counter: &Counter): address {
    counter.owner
}

/// Return this counter's Sui-native token ID.
public fun token_id(counter: &Counter): ID {
    counter.token_id
}

/// Return this counter object's ID.
public fun id(counter: &Counter): ID {
    object::id(counter)
}
