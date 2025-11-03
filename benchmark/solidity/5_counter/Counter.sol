// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title Counter NFT (shared increment, owner-settable)
/// @notice Anyone can increment a counter; only the NFT owner can set its value.
contract Counter is ERC721 {
    using Counters for Counters.Counter;

    // tokenId => current value
    mapping(uint256 => uint256) private _value;

    Counters.Counter private _ids;

    event CounterCreated(uint256 indexed tokenId, address indexed owner);
    event Incremented(uint256 indexed tokenId, uint256 newValue);
    event ValueSet(uint256 indexed tokenId, uint256 newValue);

    constructor() ERC721("Counter", "CNTR") {}

    /// @notice Create and mint a new counter NFT to the caller with initial value 0.
    /// @return tokenId The id of the newly created counter.
    function create() external returns (uint256 tokenId) {
        tokenId = _ids.current();
        _ids.increment();
        _safeMint(msg.sender, tokenId);
        _value[tokenId] = 0;
        emit CounterCreated(tokenId, msg.sender);
    }

    /// @notice Anyone can increment a counter by 1 (shared access).
    function increment(uint256 tokenId) external {
        require(_exists(tokenId), "Counter: nonexistent");
        _value[tokenId] += 1;
        emit Incremented(tokenId, _value[tokenId]);
    }

    /// @notice Set the counter to an arbitrary value (only owner).
    function setValue(uint256 tokenId, uint256 newValue) external {
        require(ownerOf(tokenId) == msg.sender, "Counter: not owner");
        _value[tokenId] = newValue;
        emit ValueSet(tokenId, newValue);
    }

    /// @notice Read current value.
    function getValue(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Counter: nonexistent");
        return _value[tokenId];
    }
}