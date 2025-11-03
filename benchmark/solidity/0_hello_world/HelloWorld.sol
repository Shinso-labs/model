// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title HelloWorld
/// @notice Solidity equivalent of the Sui Move "hello_world" module.
/// @dev Each call to `mintHelloWorld()` mints a new Hello struct with text "Hello World!"
contract HelloWorld {
    // == Types ==
    struct Hello {
        uint256 id;
        address owner;
        string text;
    }

    // == Storage ==
    uint256 private nextId;
    mapping(uint256 => Hello) private hellos;

    // == Events ==
    event HelloMinted(uint256 indexed id, address indexed owner, string text);

    // == Constructor ==
    constructor() {
        nextId = 1;
    }

    // == External API ==

    /// @notice Mints a new Hello object with the text "Hello World!"
    /// @dev Equivalent to Move's `mint_hello_world(ctx)`.
    function mintHelloWorld() external {
        uint256 id = nextId++;
        Hello memory newHello = Hello({
            id: id,
            owner: msg.sender,
            text: "Hello World!"
        });

        hellos[id] = newHello;
        emit HelloMinted(id, msg.sender, newHello.text);
    }

    /// @notice Returns data for a specific Hello object.
    /// @param id The Hello ID.
    /// @return owner The address that minted it.
    /// @return text The Hello World message.
    function getHello(uint256 id) external view returns (address owner, string memory text) {
        Hello storage h = hellos[id];
        return (h.owner, h.text);
    }

    /// @notice Total Hello objects ever minted.
    function totalMinted() external view returns (uint256) {
        return nextId - 1;
    }
}