// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StableCoin
 * @notice VaultUSD (sUSD) - An over-collateralized stablecoin
 * @dev Only the VaultManager can mint and burn tokens
 */
contract StableCoin is ERC20, Ownable {
    constructor() ERC20("VaultUSD", "sUSD") Ownable(msg.sender) {}

    /**
     * @notice Mint tokens (only callable by owner, which should be VaultManager)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens (only callable by owner, which should be VaultManager)
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}

