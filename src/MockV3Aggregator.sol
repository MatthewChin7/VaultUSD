// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockV3Aggregator
 * @notice Chainlink-style price feed mock for testing
 */
contract MockV3Aggregator {
    uint8 public immutable decimals;
    int256 private _latestAnswer;
    uint256 private _updatedAt;

    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals;
        _latestAnswer = _initialAnswer;
        _updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (1, _latestAnswer, _updatedAt, _updatedAt, 1);
    }

    function latestAnswer() external view returns (int256) {
        return _latestAnswer;
    }

    function updatePrice(int256 _newPrice) external {
        _latestAnswer = _newPrice;
        _updatedAt = block.timestamp;
        emit AnswerUpdated(_newPrice, 1, _updatedAt);
    }
}

