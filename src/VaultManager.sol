// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./StableCoin.sol";
import "./PriceOracle.sol";

/**
 * @title VaultManager
 * @notice Manages vaults for over-collateralized stablecoin system
 * @dev Users deposit ETH as collateral and can mint sUSD up to a collateralization ratio
 */
contract VaultManager is ReentrancyGuard, Ownable {
    StableCoin public immutable sUSD;
    PriceOracle public immutable oracle;
    
    // Collateralization ratio: 150% = 150e16 (1.5 * 1e18)
    uint256 public constant COLLATERALIZATION_RATIO = 150e16; // 150%
    uint256 public constant LIQUIDATION_THRESHOLD = 110e16; // 110%
    
    struct Vault {
        uint256 collateral; // Amount of ETH deposited
        uint256 debt;       // Amount of sUSD minted
        bool exists;
    }
    
    mapping(address => Vault) public vaults;
    address[] public vaultOwners;
    
    event VaultCreated(address indexed owner);
    event CollateralDeposited(address indexed owner, uint256 amount);
    event CollateralWithdrawn(address indexed owner, uint256 amount);
    event DebtMinted(address indexed owner, uint256 amount);
    event DebtRepaid(address indexed owner, uint256 amount);
    event VaultLiquidated(address indexed owner, address indexed liquidator, uint256 collateralSeized);
    
    constructor(address _sUSD, address _oracle) Ownable(msg.sender) {
        sUSD = StableCoin(_sUSD);
        oracle = PriceOracle(_oracle);
    }
    
    /**
     * @notice Create a new vault
     */
    function createVault() external {
        require(!vaults[msg.sender].exists, "VaultManager: vault already exists");
        vaults[msg.sender] = Vault({
            collateral: 0,
            debt: 0,
            exists: true
        });
        vaultOwners.push(msg.sender);
        emit VaultCreated(msg.sender);
    }
    
    /**
     * @notice Deposit ETH as collateral
     */
    function depositCollateral() external payable nonReentrant {
        require(vaults[msg.sender].exists, "VaultManager: vault does not exist");
        require(msg.value > 0, "VaultManager: must deposit ETH");
        
        vaults[msg.sender].collateral += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }
    
    /**
     * @notice Withdraw collateral (must maintain collateralization ratio)
     * @param amount Amount of ETH to withdraw
     */
    function withdrawCollateral(uint256 amount) external nonReentrant {
        Vault storage vault = vaults[msg.sender];
        require(vault.exists, "VaultManager: vault does not exist");
        require(amount > 0, "VaultManager: amount must be > 0");
        require(amount <= vault.collateral, "VaultManager: insufficient collateral");
        
        uint256 newCollateral = vault.collateral - amount;
        require(
            _isHealthy(newCollateral, vault.debt),
            "VaultManager: would violate collateralization ratio"
        );
        
        vault.collateral = newCollateral;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "VaultManager: ETH transfer failed");
        
        emit CollateralWithdrawn(msg.sender, amount);
    }
    
    /**
     * @notice Mint sUSD debt (must maintain collateralization ratio)
     * @param amount Amount of sUSD to mint
     */
    function mintDebt(uint256 amount) external nonReentrant {
        Vault storage vault = vaults[msg.sender];
        require(vault.exists, "VaultManager: vault does not exist");
        require(amount > 0, "VaultManager: amount must be > 0");
        
        uint256 newDebt = vault.debt + amount;
        require(
            _isHealthy(vault.collateral, newDebt),
            "VaultManager: would violate collateralization ratio"
        );
        
        vault.debt = newDebt;
        sUSD.mint(msg.sender, amount);
        
        emit DebtMinted(msg.sender, amount);
    }
    
    /**
     * @notice Repay sUSD debt
     * @param amount Amount of sUSD to repay
     */
    function repayDebt(uint256 amount) external nonReentrant {
        Vault storage vault = vaults[msg.sender];
        require(vault.exists, "VaultManager: vault does not exist");
        require(amount > 0, "VaultManager: amount must be > 0");
        require(amount <= vault.debt, "VaultManager: amount exceeds debt");
        
        vault.debt -= amount;
        sUSD.burn(msg.sender, amount);
        
        emit DebtRepaid(msg.sender, amount);
    }
    
    /**
     * @notice Liquidate an undercollateralized vault
     * @param vaultOwner Address of the vault owner to liquidate
     */
    function liquidate(address vaultOwner) external nonReentrant {
        Vault storage vault = vaults[vaultOwner];
        require(vault.exists, "VaultManager: vault does not exist");
        require(
            _isLiquidatable(vault.collateral, vault.debt),
            "VaultManager: vault is not liquidatable"
        );
        
        // Liquidator repays the debt and receives collateral
        uint256 debtToRepay = vault.debt;
        uint256 collateralToSeize = vault.collateral;
        
        // Burn the liquidator's sUSD
        sUSD.burn(msg.sender, debtToRepay);
        
        // Clear the vault
        vault.collateral = 0;
        vault.debt = 0;
        
        // Send collateral to liquidator
        (bool success, ) = msg.sender.call{value: collateralToSeize}("");
        require(success, "VaultManager: ETH transfer failed");
        
        emit VaultLiquidated(vaultOwner, msg.sender, collateralToSeize);
    }
    
    /**
     * @notice Check if vault is healthy (above collateralization ratio)
     */
    function isHealthy(address vaultOwner) external view returns (bool) {
        Vault memory vault = vaults[vaultOwner];
        if (!vault.exists) return false;
        return _isHealthy(vault.collateral, vault.debt);
    }
    
    /**
     * @notice Check if vault is liquidatable (below liquidation threshold)
     */
    function isLiquidatable(address vaultOwner) external view returns (bool) {
        Vault memory vault = vaults[vaultOwner];
        if (!vault.exists) return false;
        return _isLiquidatable(vault.collateral, vault.debt);
    }
    
    /**
     * @notice Get vault info
     */
    function getVault(address vaultOwner) external view returns (uint256 collateral, uint256 debt) {
        Vault memory vault = vaults[vaultOwner];
        return (vault.collateral, vault.debt);
    }
    
    /**
     * @notice Get maximum debt that can be minted for given collateral
     */
    function getMaxDebt(uint256 collateral) external view returns (uint256) {
        uint256 ethPrice = oracle.getPrice();
        // Max debt = (collateral * ethPrice) / collateralizationRatio
        return (collateral * ethPrice) / COLLATERALIZATION_RATIO;
    }
    
    /**
     * @notice Internal: Check if vault is healthy
     */
    function _isHealthy(uint256 collateral, uint256 debt) internal view returns (bool) {
        if (debt == 0) return true;
        
        uint256 ethPrice = oracle.getPrice();
        uint256 collateralValue = collateral * ethPrice;
        uint256 minCollateralValue = (debt * COLLATERALIZATION_RATIO) / 1e18;
        
        return collateralValue >= minCollateralValue;
    }
    
    /**
     * @notice Internal: Check if vault is liquidatable
     */
    function _isLiquidatable(uint256 collateral, uint256 debt) internal view returns (bool) {
        if (debt == 0) return false;
        
        uint256 ethPrice = oracle.getPrice();
        uint256 collateralValue = collateral * ethPrice;
        uint256 minCollateralValue = (debt * LIQUIDATION_THRESHOLD) / 1e18;
        
        return collateralValue < minCollateralValue;
    }
}

