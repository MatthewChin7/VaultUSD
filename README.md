# VaultUSD

An over-collateralized stablecoin system built on Foundry. VaultUSD (sUSD) is a decentralized stablecoin backed by ETH collateral, maintaining stability through collateralization ratios and automated liquidations.

## Overview

VaultUSD implements a minimal over-collateralized stablecoin protocol where:

- **Users deposit ETH** as collateral to open vaults
- **Users mint sUSD** (stablecoin) against their collateral up to a 150% collateralization ratio
- **Liquidations occur** automatically when collateralization drops below 110%
- **Peg stability** is maintained through the over-collateralization mechanism

## Architecture

### Core Contracts

- **`StableCoin.sol`**: ERC20 stablecoin token (sUSD) with mint/burn functionality
- **`VaultManager.sol`**: Manages vaults, collateral deposits, debt minting, and liquidations
- **`PriceOracle.sol`**: Wrapper for price feeds that returns 1e18 scaled prices
- **`MockV3Aggregator.sol`**: Chainlink-style mock price feed for testing

### Key Parameters

- **Collateralization Ratio**: 150% (minimum required to mint debt)
- **Liquidation Threshold**: 110% (vaults below this can be liquidated)
- **Collateral Type**: ETH (native)

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Python 3.8+ (for simulations)
- Jupyter Notebook (optional, for interactive simulations)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd VaultUSD
```

2. Install Foundry dependencies:
```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install foundry-rs/forge-std --no-commit
```

3. Install Python dependencies:
```bash
pip install numpy matplotlib
```

### Build

```bash
forge build
```

### Test

```bash
forge test
```

Run tests with verbose output:
```bash
forge test -vvv
```

### Deploy

1. Set your private key in an environment variable:
```bash
export PRIVATE_KEY=your_private_key_here
```

2. Deploy to a network:
```bash
forge script script/deploy.s.sol:DeployScript --rpc-url <RPC_URL> --broadcast --verify
```

## Usage

### Creating a Vault

```solidity
// 1. Create a vault
vaultManager.createVault();

// 2. Deposit ETH collateral
vaultManager.depositCollateral{value: 10 ether}();

// 3. Mint sUSD debt (up to collateralization ratio)
vaultManager.mintDebt(10000e18);
```

### Managing a Vault

```solidity
// Withdraw collateral (must maintain 150% ratio)
vaultManager.withdrawCollateral(2 ether);

// Repay debt
vaultManager.repayDebt(5000e18);
```

### Liquidations

When a vault's collateralization drops below 110%, anyone can liquidate it:

```solidity
// Liquidator repays the debt and receives the collateral
vaultManager.liquidate(vaultOwner);
```

## Simulation

The project includes a Python simulation demonstrating peg stability under price shocks:

### Run Python Script

```bash
cd sim
python peg_simulation.py
```

### Run Jupyter Notebook

```bash
cd sim
jupyter notebook peg_simulation.ipynb
```

The simulation shows:
- System response to ETH price drops
- Liquidation mechanics
- Collateralization ratio dynamics
- Debt and collateral tracking

## Project Structure

```
VaultUSD/
├── src/
│   ├── StableCoin.sol          # Stablecoin token contract
│   ├── VaultManager.sol        # Core vault management logic
│   ├── PriceOracle.sol         # Price feed wrapper
│   └── MockV3Aggregator.sol    # Mock price feed for testing
├── test/
│   └── VaultManager.t.sol      # Comprehensive test suite
├── script/
│   └── deploy.s.sol            # Deployment script
├── sim/
│   ├── peg_simulation.py       # Python simulation script
│   └── peg_simulation.ipynb    # Jupyter notebook
├── docs/
│   └── whitepaper.md           # Technical whitepaper
├── foundry.toml                # Foundry configuration
└── README.md                   # This file
```

## Security Considerations

- **Reentrancy Protection**: All external calls are protected with `nonReentrant`
- **Access Control**: Only VaultManager can mint/burn sUSD
- **Price Oracle**: Uses mock oracle for testing; production should use Chainlink
- **Overflow Protection**: Uses Solidity 0.8.20 built-in overflow checks

## Testing

The test suite covers:
- Vault creation and management
- Collateral deposits and withdrawals
- Debt minting and repayment
- Liquidation mechanics
- Price shock scenarios
- Edge cases and error conditions

Run specific tests:
```bash
forge test --match-test test_Liquidate
```

## Documentation

- **Whitepaper**: See `docs/whitepaper.md` for detailed technical documentation
- **Code Comments**: All contracts are fully documented with NatSpec comments

## Future Enhancements

Potential improvements for production:
- Stability fees (interest on debt)
- Partial liquidations
- Multi-collateral support
- Governance mechanism
- Real Chainlink price feeds
- Flash loan protection
- Gas optimization

## License

MIT

## Contributing

This is a minimal implementation for educational and interview purposes. For production use, additional security audits and features would be required.

## Disclaimer

This code is provided for educational purposes only. It has not been audited and should not be used in production without comprehensive security reviews.

