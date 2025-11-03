// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TipJar {
    address public owner;
    uint256 public totalTipsReceived;
    uint256 public tipCount;

    event TipCreated(address indexed owner);
    event TipSent(address indexed tipper, uint256 amount, uint256 totalTips, uint256 tipCount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalTipsReceived = 0;
        tipCount = 0;
        emit TipCreated(owner);
    }

    /// @notice Send a tip (in native ETH) to the owner
    function sendTip() external payable {
        uint256 tipAmount = msg.value;
        require(tipAmount > 0, "Invalid tip amount");

        // forwarding the tip to the owner
        (bool success, ) = owner.call{value: tipAmount}("");
        require(success, "Transfer failed");

        // update state
        totalTipsReceived += tipAmount;
        tipCount += 1;

        emit TipSent(msg.sender, tipAmount, totalTipsReceived, tipCount);
    }

    /// @notice Owner can withdraw any leftover funds (just in case)
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Nothing to withdraw");
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdraw failed");
    }

    /// @notice Check if a given address is the owner
    function isOwner(address addr) external view returns (bool) {
        return (addr == owner);
    }
}