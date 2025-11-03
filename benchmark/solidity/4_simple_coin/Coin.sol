// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// OpenZeppelin standard ERC-20 + roles + burnability
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title First Coin (COIN)
/// @notice Solidity equivalent of the Move coin module:
/// - `TreasuryCap<COIN>` === `TREASURY_ROLE` (minter capability)
/// - `mint`, `mint_and_transfer`, `burn` provided using ERC-20 standards
contract FirstCoin is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE"); // minter capability

    constructor() ERC20("First Coin", "COIN") {
        // Deployer receives the treasury capability (like receiving TreasuryCap in Move `init`)
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TREASURY_ROLE, msg.sender);
    }

    /// @dev Override decimals to 2 (Move: `create_currency<COIN>(..., 2, ...)`)
    function decimals() public pure override returns (uint8) {
        return 2;
    }

    /// @notice Mint `amount` tokens to `to`.
    /// @dev Mirrors Move `mint(treasury_cap, amount, ...) -> Coin<COIN>`
    function mint(address to, uint256 amount) external onlyRole(TREASURY_ROLE) {
        _mint(to, amount);
    }

    /// @notice Mint and transfer to `recipient` (syntactic sugar).
    /// @dev Mirrors Move `mint_and_transfer(treasury_cap, amount, recipient, ...)`
    function mintAndTransfer(address recipient, uint256 amount)
        external
        onlyRole(TREASURY_ROLE)
    {
        _mint(recipient, amount);
    }

    /// @notice Burn caller’s own tokens (standard ERC20Burnable).
    /// @dev Move required `treasury_cap` to burn; in ERC-20 the holder can burn freely.
    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    /// @notice Burn from `account` with allowance (standard ERC20Burnable).
    /// @dev Equivalent of handing a Coin to be burned via allowance.
    function burnFrom(address account, uint256 amount) public override {
        super.burnFrom(account, amount);
    }
}