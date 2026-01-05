module todo_list::todo_list {
    use sui::event;
    use sui::object::{Self, UID};
    use sui::string::{Self, String};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::vector;

    /// Error codes for clearer aborts.
    const E_NOT_FOUND: u64 = 0;
    const E_NOT_OWNER: u64 = 1;
    const E_INDEX_OOB: u64 = 2;
    const E_OWNER_LIST_MISSING: u64 = 3;

    /// Per-list data stored inside the shared registry.
    struct List has store, drop {
        owner: address,
        items: vector<String>,
    }

    /// Shared registry that mirrors Solidity's global mappings and counter.
    public struct Registry has key {
        id: UID,
        next_id: u64,
        lists: Table<u64, List>,
        owner_lists: Table<address, vector<u64>>,
    }

    /// Events mirroring the Solidity contract.
    struct ListCreated has store, drop {
        list_id: u64,
        owner: address,
    }

    struct ItemAdded has store, drop {
        list_id: u64,
        item: String,
    }

    struct ItemRemoved has store, drop {
        list_id: u64,
        index: u64,
        item: String,
    }

    struct ListDeleted has store, drop {
        list_id: u64,
        owner: address,
    }

    /// Initializes the shared registry (runs once on publish).
    fun init(ctx: &mut TxContext) {
        let registry = Registry {
            id: object::new(ctx),
            next_id: 1,
            lists: table::new<u64, List>(ctx),
            owner_lists: table::new<address, vector<u64>>(ctx),
        };
        transfer::share_object(registry);
    }

    /// Create a new todo list; returns its numeric ID.
    public entry fun new_list(registry: &mut Registry, ctx: &TxContext): u64 {
        let sender = tx_context::sender(ctx);
        let list_id = registry.next_id;
        registry.next_id = list_id + 1;

        let list = List {
            owner: sender,
            items: vector::empty<String>(),
        };
        table::add(&mut registry.lists, list_id, list);

        if (table::contains(&registry.owner_lists, sender)) {
            let owner_vec = table::borrow_mut(&mut registry.owner_lists, sender);
            vector::push_back(owner_vec, list_id);
        } else {
            let mut v = vector::empty<u64>();
            vector::push_back(&mut v, list_id);
            table::add(&mut registry.owner_lists, sender, v);
        };

        event::emit(ListCreated { list_id, owner: sender });
        list_id
    }

    /// Add a todo item to a list you own.
    public entry fun add(registry: &mut Registry, list_id: u64, item: String, ctx: &TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(table::contains(&registry.lists, list_id), E_NOT_FOUND);
        let list = table::borrow_mut(&mut registry.lists, list_id);
        assert!(list.owner == sender, E_NOT_OWNER);

        // Clone the string so we can both store it and emit it.
        let item_for_store = string::from_utf8(string::bytes(&item));
        vector::push_back(&mut list.items, item_for_store);
        event::emit(ItemAdded { list_id, item });
    }

    /// Remove an item by index from a list you own; returns the removed item.
    public entry fun remove(registry: &mut Registry, list_id: u64, index: u64, ctx: &TxContext): String {
        let sender = tx_context::sender(ctx);
        assert!(table::contains(&registry.lists, list_id), E_NOT_FOUND);
        let list = table::borrow_mut(&mut registry.lists, list_id);
        assert!(list.owner == sender, E_NOT_OWNER);

        let len = vector::length(&list.items);
        assert!(index < len, E_INDEX_OOB);

        let removed = vector::swap_remove(&mut list.items, index);
        event::emit(ItemRemoved { list_id, index, item: string::from_utf8(string::bytes(&removed)) });
        removed
    }

    /// Delete an entire list you own and remove its index from your registry entry.
    public entry fun delete_list(registry: &mut Registry, list_id: u64, ctx: &TxContext) {
        let sender = tx_context::sender(ctx);
        assert!(table::contains(&registry.lists, list_id), E_NOT_FOUND);
        {
            let list_ref = table::borrow(&registry.lists, list_id);
            assert!(list_ref.owner == sender, E_NOT_OWNER);
        };
        let _dropped = table::remove(&mut registry.lists, list_id);
        remove_id_from_owner(&mut registry.owner_lists, sender, list_id);
        event::emit(ListDeleted { list_id, owner: sender });
    }

    /// Return the number of items in a list.
    public fun length(registry: &Registry, list_id: u64): u64 {
        assert!(table::contains(&registry.lists, list_id), E_NOT_FOUND);
        let list = table::borrow(&registry.lists, list_id);
        vector::length(&list.items)
    }

    /// Get a specific item by index (returns a fresh copy of the string).
    public fun get_item(registry: &Registry, list_id: u64, index: u64): String {
        assert!(table::contains(&registry.lists, list_id), E_NOT_FOUND);
        let list = table::borrow(&registry.lists, list_id);
        let len = vector::length(&list.items);
        assert!(index < len, E_INDEX_OOB);

        let item_ref = vector::borrow(&list.items, index);
        string::from_utf8(string::bytes(item_ref))
    }

    /// Get all list IDs owned by a user (copied out to a new vector).
    public fun get_lists_of(registry: &Registry, user: address): vector<u64> {
        if (!table::contains(&registry.owner_lists, user)) {
            return vector::empty<u64>();
        };
        let stored = table::borrow(&registry.owner_lists, user);
        clone_u64_vector(stored)
    }

    /// Helper: remove a list ID from an owner's index vector.
    fun remove_id_from_owner(owner_lists: &mut Table<address, vector<u64>>, owner: address, list_id: u64) {
        assert!(table::contains(owner_lists, owner), E_OWNER_LIST_MISSING);
        let vec_ref = table::borrow_mut(owner_lists, owner);
        let len = vector::length(vec_ref);
        let mut i = 0;
        let mut found = false;
        while (i < len) {
            let val = *vector::borrow(vec_ref, i);
            if (val == list_id) {
                let _ = vector::swap_remove(vec_ref, i);
                found = true;
                break;
            };
            i = i + 1;
        };
        assert!(found, E_OWNER_LIST_MISSING);
    }

    /// Helper: deep-copy a vector<u64>.
    fun clone_u64_vector(v: &vector<u64>): vector<u64> {
        let len = vector::length(v);
        let mut out = vector::empty<u64>();
        let mut i = 0;
        while (i < len) {
            let val = *vector::borrow(v, i);
            vector::push_back(&mut out, val);
            i = i + 1;
        };
        out
    }
}