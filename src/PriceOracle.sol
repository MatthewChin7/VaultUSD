// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockV3Aggregator.sol";

/**
 * @title PriceOracle
 * @notice Wrapper that reads from Chainlink-style aggregator and returns 1e18 scaled price
 */
contract PriceOracle {
    MockV3Aggregator public immutable aggregator;
    uint8 public constant TARGET_DECIMALS = 18;

    constructor(address _aggregator) {
        aggregator = MockV3Aggregator(_aggregator);
    }

    /**
     * @notice Get the current price scaled to 1e18
     * @return price Price in 1e18 format
     */
    function getPrice() external view returns (uint256) {
        int256 rawPrice = aggregator.latestAnswer();
        require(rawPrice > 0, "PriceOracle: invalid price");
        
        uint8 aggregatorDecimals = aggregator.decimals();
        uint256 price = uint256(rawPrice);
        
        if (aggregatorDecimals < TARGET_DECIMALS) {
            // Scale up: multiply by 10^(18 - aggregatorDecimals)
            price = price * (10 ** (TARGET_DECIMALS - aggregatorDecimals));
        } else if (aggregatorDecimals > TARGET_DECIMALS) {
            // Scale down: divide by 10^(aggregatorDecimals - 18)
            price = price / (10 ** (aggregatorDecimals - TARGET_DECIMALS));
        }
        
        return price;
    }
}

