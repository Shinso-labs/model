#[allow(unused_field)]
module hello_world::hello_world {
    use sui::event;
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// Abort code used when a requested Hello record does not exist.
    const E_NOT_FOUND: u64 = 0;

    /// Abort code used if the u64 ID counter would overflow.
    const E_ID_OVERFLOW: u64 = 1;

    /// Maximum u64 value.
    const U64_MAX: u64 = 18446744073709551615;

    /// Equivalent to Solidity string "Hello World!".
    const HELLO_WORLD_TEXT: vector<u8> = b"Hello World!";

    /// Shared registry object.
    ///
    /// This preserves the Solidity-style global storage model for callers that
    /// want `get_hello(id)` and `total_minted()` behavior.
    ///
    /// Important Sui note:
    /// Sui entry functions cannot implicitly access shared global state. A shared
    /// object must be passed explicitly. Therefore, the canonical Sui-style
    /// `mint_hello_world(ctx)` below only mints an owned object, while
    /// `mint_hello_world_recorded(registry, ctx)` also updates this registry.
    public struct Registry has key {
        id: UID,
        next_id: u64,
        hellos: Table<u64, HelloRecord>,
    }

    /// Sui-native owned Hello object minted to the transaction sender.
    ///
    /// The `minter` field records the original creator, equivalent to Solidity's
    /// stored `owner`. The current object owner is tracked by Sui object ownership.
    public struct Hello has key, store {
        id: UID,
        hello_id: u64,
        minter: address,
        text: vector<u8>,
    }

    /// Stored metadata record used by the Registry table.
    ///
    /// This preserves Solidity-style `getHello(id)` lookup behavior when using
    /// `mint_hello_world_recorded`.
    public struct HelloRecord has copy, drop, store {
        owner: address,
        text: vector<u8>,
    }

    /// Move equivalent of Solidity:
    ///
    /// `event HelloMinted(uint256 indexed id, address indexed owner, string text);`
    ///
    /// Sui events do not have Solidity-style indexed fields, but off-chain
    /// indexers can index event contents.
    public struct HelloMinted has copy, drop {
        id: u64,
        owner: address,
        text: vector<u8>,
    }

    /// Module initializer.
    ///
    /// Runs once when the package is published.
    /// Equivalent to Solidity constructor setting `nextId = 1`.
    fun init(ctx: &mut TxContext) {
        let registry = Registry {
            id: object::new(ctx),
            next_id: 1,
            hellos: table::new(ctx),
        };

        // Share the registry so callers that need Solidity-style global state can
        // use `mint_hello_world_recorded`.
        transfer::share_object(registry);
    }

    /// Canonical Sui-style mint function.
    ///
    /// This signature intentionally takes only `ctx`, matching the standard Sui
    /// hello_world example and the supplied tests:
    ///
    /// `hello_world::mint_hello_world(ctx)`
    ///
    /// It mints an owned `Hello` object to the transaction sender.
    ///
    /// Since no shared `Registry` object is passed, this function does not update
    /// the Solidity-style `hellos` table or global `next_id` counter. Use
    /// `mint_hello_world_recorded(registry, ctx)` if registry-backed lookup is
    /// required.
    public entry fun mint_hello_world(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let text = HELLO_WORLD_TEXT;

        let hello = Hello {
            id: object::new(ctx),

            // No global counter is available without passing a shared Registry.
            // This object's real unique identity is its Sui object UID.
            hello_id: 0,

            minter: sender,
            text: copy text,
        };

        transfer::public_transfer(hello, sender);

        event::emit(HelloMinted {
            id: 0,
            owner: sender,
            text,
        });
    }

    /// Solidity-style recorded mint function.
    ///
    /// This version updates the shared `Registry`, preserving the behavior of:
    ///
    /// - `nextId++`
    /// - `hellos[id] = newHello`
    /// - `getHello(id)`
    /// - `totalMinted()`
    ///
    /// Because Sui has explicit object access, callers must pass the shared
    /// `Registry` object.
    public entry fun mint_hello_world_recorded(registry: &mut Registry, ctx: &mut TxContext) {
        assert!(registry.next_id < U64_MAX, E_ID_OVERFLOW);

        let sender = tx_context::sender(ctx);
        let id = registry.next_id;

        // Solidity equivalent of `nextId++`.
        registry.next_id = registry.next_id + 1;

        let text = HELLO_WORLD_TEXT;

        // Store record in the shared registry table for `get_hello(id)`.
        table::add(
            &mut registry.hellos,
            id,
            HelloRecord {
                owner: sender,
                text: copy text,
            },
        );

        // Mint an owned Sui object to the sender.
        let hello = Hello {
            id: object::new(ctx),
            hello_id: id,
            minter: sender,
            text: copy text,
        };

        transfer::public_transfer(hello, sender);

        event::emit(HelloMinted {
            id,
            owner: sender,
            text,
        });
    }

    /// Returns data for a specific Hello record.
    ///
    /// Solidity equivalent:
    ///
    /// `getHello(uint256 id) returns (address owner, string text)`
    ///
    /// This reads from the shared `Registry`, so it only sees records created by
    /// `mint_hello_world_recorded`.
    public fun get_hello(registry: &Registry, id: u64): (address, vector<u8>) {
        assert!(table::contains(&registry.hellos, id), E_NOT_FOUND);

        let hello = table::borrow(&registry.hellos, id);
        (hello.owner, copy hello.text)
    }

    /// Returns the total number of registry-recorded Hello objects ever minted.
    ///
    /// Solidity equivalent:
    ///
    /// `totalMinted()`
    public fun total_minted(registry: &Registry): u64 {
        registry.next_id - 1
    }

    /// Returns true if a Hello record exists for the given numeric ID.
    public fun exists(registry: &Registry, id: u64): bool {
        table::contains(&registry.hellos, id)
    }

    /// Returns the application-level numeric ID stored in an owned Hello object.
    ///
    /// For objects created by `mint_hello_world`, this is `0` because that function
    /// does not use the shared Registry counter.
    ///
    /// For objects created by `mint_hello_world_recorded`, this is the registry ID.
    public fun hello_id(hello: &Hello): u64 {
        hello.hello_id
    }

    /// Returns the original minter of an owned Hello object.
    public fun minter(hello: &Hello): address {
        hello.minter
    }

    /// Returns the text stored in an owned Hello object.
    public fun text(hello: &Hello): vector<u8> {
        copy hello.text
    }
}
