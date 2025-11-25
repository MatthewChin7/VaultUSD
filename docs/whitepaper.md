# VaultUSD Whitepaper

## An Over-Collateralized Stablecoin Protocol

**Version 1.0**  
**Date: 2024**

---

## Abstract

VaultUSD (sUSD) is a minimal over-collateralized stablecoin protocol that maintains a 1:1 peg with the US Dollar through an over-collateralization mechanism. Users deposit ETH as collateral and can mint sUSD up to a 150% collateralization ratio. The system ensures stability through automated liquidations when collateralization drops below 110%.

## 1. Introduction

### 1.1 Problem Statement

Stablecoins are essential infrastructure for DeFi, providing price stability in volatile crypto markets. However, existing stablecoin designs face challenges:

- **Algorithmic stablecoins** (e.g., TerraUSD) can lose peg during market stress
- **Fiat-backed stablecoins** (e.g., USDC) require centralized custodians
- **Over-collateralized stablecoins** (e.g., DAI) provide decentralization but require complex governance

VaultUSD aims to provide a simple, transparent, and secure over-collateralized stablecoin with minimal complexity.

### 1.2 Design Goals

1. **Simplicity**: Minimal codebase, easy to audit and understand
2. **Security**: Over-collateralization ensures solvency
3. **Decentralization**: No central authority, permissionless
4. **Stability**: Automated liquidations maintain peg

## 2. System Architecture

### 2.1 Core Components

#### StableCoin (sUSD)
- ERC20 token representing the stablecoin
- Only VaultManager can mint/burn tokens
- Maintains 1:1 peg with USD through collateralization

#### VaultManager
- Manages user vaults
- Enforces collateralization ratios
- Executes liquidations
- Handles all minting and burning of sUSD

#### PriceOracle
- Provides ETH/USD price feed
- Scales prices to 1e18 format for consistency
- Uses Chainlink-style aggregator interface

### 2.2 Vault System

Each user can create one vault that holds:
- **Collateral**: ETH deposited by the user
- **Debt**: sUSD minted against the collateral

The vault's health is measured by its collateralization ratio:

```
Collateralization Ratio = (Collateral × ETH Price) / Debt
```

## 3. Mechanism Design

### 3.1 Collateralization Requirements

**Minimum Collateralization Ratio: 150%**

Users must maintain at least 150% collateralization to:
- Mint new debt
- Withdraw collateral
- Keep the vault active

**Example:**
- User deposits 10 ETH at $2000/ETH = $20,000 collateral value
- Maximum debt: $20,000 / 1.5 = $13,333 sUSD
- User can mint up to 13,333 sUSD

### 3.2 Liquidation Mechanism

**Liquidation Threshold: 110%**

When a vault's collateralization drops below 110%, it becomes liquidatable:

1. Anyone can call `liquidate(vaultOwner)`
2. Liquidator repays the vault's debt in sUSD
3. Liquidator receives all vault collateral
4. Vault is cleared (debt and collateral set to 0)

**Liquidation Incentive:**
- Liquidator receives collateral worth more than the debt repaid
- The difference (collateral value - debt) is the liquidation incentive
- This ensures liquidations happen quickly, protecting the system

### 3.3 Price Oracle

The system relies on accurate ETH/USD prices:

- Uses Chainlink-style aggregator interface
- Prices scaled to 1e18 for precision
- In production, should use Chainlink oracles
- For testing, uses MockV3Aggregator

**Price Update Frequency:**
- Oracle prices should update frequently (e.g., every block)
- Stale prices can lead to incorrect liquidations or missed liquidations

## 4. Economic Model

### 4.1 Stability Mechanism

The peg is maintained through:

1. **Over-collateralization**: All debt backed by >150% collateral value
2. **Liquidations**: Remove undercollateralized positions
3. **Arbitrage**: If sUSD < $1, users can mint and sell; if sUSD > $1, users can buy and repay

### 4.2 Risk Parameters

| Parameter | Value | Purpose |
|-----------|-------|---------|
| Collateralization Ratio | 150% | Minimum required to mint debt |
| Liquidation Threshold | 110% | Below this, vaults can be liquidated |
| Collateral Type | ETH | Native Ethereum |

### 4.3 Failure Modes

#### Scenario 1: Rapid Price Drop
- **Risk**: ETH price drops faster than liquidations can occur
- **Mitigation**: 40% buffer (150% - 110%) provides time for liquidations
- **Remaining Risk**: Flash crashes could still cause issues

#### Scenario 2: Oracle Failure
- **Risk**: Stale or incorrect prices
- **Mitigation**: Use multiple oracles in production, circuit breakers
- **Remaining Risk**: Oracle manipulation attacks

#### Scenario 3: Liquidation Inefficiency
- **Risk**: Liquidations don't happen fast enough
- **Mitigation**: Liquidation incentive encourages quick action
- **Remaining Risk**: Network congestion could delay liquidations

#### Scenario 4: Insufficient Liquidity
- **Risk**: Not enough liquidators with sUSD to liquidate
- **Mitigation**: Liquidators can mint sUSD to liquidate
- **Remaining Risk**: Gas costs might make small liquidations unprofitable

## 5. Security Considerations

### 5.1 Smart Contract Security

**Implemented Protections:**
- Reentrancy guards on all external calls
- Access control (only VaultManager can mint/burn)
- Overflow protection (Solidity 0.8.20)
- Input validation

**Production Recommendations:**
- Comprehensive security audit
- Formal verification of critical functions
- Bug bounty program
- Time-locked upgrades (if governance added)

### 5.2 Economic Security

**Collateralization Buffer:**
- 40% buffer (150% - 110%) protects against price volatility
- Assumes ETH price doesn't drop >40% before liquidation

**Liquidation Efficiency:**
- Liquidators have strong incentive (collateral > debt)
- Should ensure liquidations happen quickly

## 6. Comparison with Existing Systems

### 6.1 vs. MakerDAO (DAI)

| Feature | VaultUSD | MakerDAO |
|---------|----------|----------|
| Complexity | Minimal | High (governance, multiple collaterals) |
| Collateral | ETH only | Multiple assets |
| Stability Fee | None | Yes (variable) |
| Governance | None | MKR token holders |

**VaultUSD Advantages:**
- Simpler, easier to audit
- Lower gas costs
- No governance overhead

**MakerDAO Advantages:**
- More mature, battle-tested
- Multi-collateral reduces risk concentration
- Governance allows parameter adjustments

### 6.2 vs. Liquity (LUSD)

| Feature | VaultUSD | Liquity |
|---------|----------|---------|
| Collateralization | 150% | 110% |
| Stability Pool | No | Yes |
| Redemptions | No | Yes (at face value) |

**VaultUSD Advantages:**
- Higher safety margin
- Simpler design

**Liquity Advantages:**
- Lower collateralization requirement
- Stability pool provides additional security

## 7. Limitations and Future Work

### 7.1 Current Limitations

1. **Single Collateral**: Only ETH supported
2. **No Stability Fee**: No mechanism to incentivize debt repayment
3. **No Governance**: Parameters are hardcoded
4. **Mock Oracle**: Uses mock price feed (not production-ready)
5. **Full Liquidation**: No partial liquidations
6. **No Redemptions**: Can't redeem sUSD for collateral at face value

### 7.2 Future Enhancements

**Short-term:**
- Add stability fees (interest on debt)
- Implement partial liquidations
- Add real Chainlink price feeds
- Gas optimizations

**Medium-term:**
- Multi-collateral support (WBTC, stETH, etc.)
- Governance mechanism for parameter adjustments
- Stability pool (like Liquity)
- Redemption mechanism

**Long-term:**
- Cross-chain support
- Advanced liquidation strategies
- Risk management modules
- Integration with DeFi protocols

## 8. Conclusion

VaultUSD presents a minimal, secure, and transparent over-collateralized stablecoin design. While simpler than existing systems like MakerDAO, it provides core functionality for maintaining a stable peg through over-collateralization and automated liquidations.

The system is designed for educational purposes and demonstrates key concepts in DeFi stablecoin design. For production use, additional features, security audits, and risk management would be required.

### Key Takeaways

1. **Over-collateralization** provides a robust foundation for stability
2. **Automated liquidations** protect the system from undercollateralization
3. **Simplicity** reduces attack surface and improves auditability
4. **Trade-offs** exist between simplicity and feature richness

---

## References

- MakerDAO Whitepaper: https://makerdao.com/whitepaper/
- Liquity Protocol: https://www.liquity.org/
- Chainlink Price Feeds: https://docs.chain.link/docs/price-feeds/

## Appendix A: Mathematical Formulations

### Maximum Debt Calculation

```
maxDebt = (collateral × ethPrice) / collateralizationRatio
```

### Collateralization Ratio

```
ratio = (collateral × ethPrice) / debt
```

### Liquidation Condition

```
if (collateral × ethPrice) / debt < liquidationThreshold:
    vault is liquidatable
```

## Appendix B: Code Examples

See the main repository for:
- Contract implementations (`src/`)
- Test suite (`test/`)
- Deployment scripts (`script/`)
- Simulations (`sim/`)

