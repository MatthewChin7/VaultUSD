# Setup Guide

Quick setup instructions for VaultUSD.

## 1. Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## 2. Install Dependencies

```bash
# Install OpenZeppelin contracts
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Install Forge standard library
forge install foundry-rs/forge-std --no-commit
```

## 3. Build

```bash
forge build
```

## 4. Test

```bash
forge test
```

## 5. Install Python Dependencies (for simulations)

```bash
pip install -r requirements.txt
```

## Troubleshooting

### Import errors

If you see import errors, make sure:
1. Dependencies are installed in `lib/` directory
2. `remappings.txt` is present in the root
3. Run `forge remappings` to verify paths

### Build errors

- Ensure Solidity version matches (0.8.20)
- Check that all dependencies are installed
- Run `forge clean` and rebuild

