// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title TodoList
/// @notice Solidity equivalent of the Sui Move `todo_list` module.
/// @dev Each user can own multiple independent TodoLists, each with a dynamic array of strings.
contract TodoList {
    // == Types ==
    struct List {
        uint256 id;
        address owner;
        string[] items;
        bool exists;
    }

    // == Storage ==
    uint256 private nextId;
    mapping(uint256 => List) private lists;
    mapping(address => uint256[]) private ownerLists;

    // == Events ==
    event ListCreated(uint256 indexed id, address indexed owner);
    event ItemAdded(uint256 indexed id, string item);
    event ItemRemoved(uint256 indexed id, uint256 index, string item);
    event ListDeleted(uint256 indexed id, address indexed owner);

    // == Constructor ==
    constructor() {
        nextId = 1;
    }

    // == External API ==

    /// @notice Create a new todo list (Move: `new(ctx)`).
    /// @return listId The ID of the newly created list.
    function newList() external returns (uint256 listId) {
        listId = nextId++;
        List storage list = lists[listId];
        list.id = listId;
        list.owner = msg.sender;
        list.exists = true;
        ownerLists[msg.sender].push(listId);
        emit ListCreated(listId, msg.sender);
    }

    /// @notice Add a new todo item (Move: `add(list, item)`).
    /// @param listId The ID of the list.
    /// @param item The todo text to add.
    function add(uint256 listId, string calldata item) external {
        List storage list = _requireOwner(listId);
        list.items.push(item);
        emit ItemAdded(listId, item);
    }

    /// @notice Remove an item by index (Move: `remove(list, index)`).
    /// @param listId The ID of the list.
    /// @param index The zero-based index of the item to remove.
    /// @return removedItem The text of the removed item.
    function remove(uint256 listId, uint256 index) external returns (string memory removedItem) {
        List storage list = _requireOwner(listId);
        require(index < list.items.length, "Index out of bounds");
        removedItem = list.items[index];

        // Shift the last element to fill the gap (preserves gas efficiency)
        list.items[index] = list.items[list.items.length - 1];
        list.items.pop();

        emit ItemRemoved(listId, index, removedItem);
    }

    /// @notice Delete an entire list (Move: `delete(list)`).
    /// @param listId The ID of the list to delete.
    function deleteList(uint256 listId) external {
        List storage list = _requireOwner(listId);
        delete lists[listId];
        emit ListDeleted(listId, msg.sender);
    }

    /// @notice Get the number of items in a list (Move: `length(list)`).
    /// @param listId The ID of the list.
    /// @return The number of todo items.
    function length(uint256 listId) external view returns (uint256) {
        return lists[listId].items.length;
    }

    /// @notice View a specific item by index.
    function getItem(uint256 listId, uint256 index) external view returns (string memory) {
        require(lists[listId].exists, "List not found");
        require(index < lists[listId].items.length, "Index out of bounds");
        return lists[listId].items[index];
    }

    /// @notice Return all list IDs owned by a user.
    function getListsOf(address user) external view returns (uint256[] memory) {
        return ownerLists[user];
    }

    // == Internal helper ==
    function _requireOwner(uint256 listId) internal view returns (List storage) {
        List storage list = lists[listId];
        require(list.exists, "List not found");
        require(list.owner == msg.sender, "Not list owner");
        return list;
    }
}