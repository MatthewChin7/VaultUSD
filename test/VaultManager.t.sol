// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import "../src/MockV3Aggregator.sol";
import "../src/PriceOracle.sol";
import "../src/StableCoin.sol";
import "../src/VaultManager.sol";

contract VaultManagerTest is Test {
    MockV3Aggregator public aggregator;
    PriceOracle public oracle;
    StableCoin public sUSD;
    VaultManager public vaultManager;

    address public user = address(1);
    address public liquidator = address(2);

    uint256 constant INITIAL_ETH_PRICE = 2000e8; // $2000 in 8 decimals
    uint256 constant INITIAL_ETH_PRICE_SCALED = 2000e18; // $2000 in 18 decimals

    function setUp() public {
        // Deploy mocks and contracts
        aggregator = new MockV3Aggregator(8, int256(INITIAL_ETH_PRICE));
        oracle = new PriceOracle(address(aggregator));
        sUSD = new StableCoin();
        vaultManager = new VaultManager(address(sUSD), address(oracle));
        
        // Transfer ownership of sUSD to VaultManager
        sUSD.transferOwnership(address(vaultManager));
    }

    function test_Deploy() public {
        assertEq(address(vaultManager.sUSD()), address(sUSD));
        assertEq(address(vaultManager.oracle()), address(oracle));
    }

    function test_CreateVault() public {
        vm.prank(user);
        vaultManager.createVault();
        
        (uint256 collateral, uint256 debt) = vaultManager.getVault(user);
        assertEq(collateral, 0);
        assertEq(debt, 0);
    }

    function test_CannotCreateVaultTwice() public {
        vm.prank(user);
        vaultManager.createVault();
        
        vm.prank(user);
        vm.expectRevert("VaultManager: vault already exists");
        vaultManager.createVault();
    }

    function test_DepositCollateral() public {
        vm.prank(user);
        vaultManager.createVault();
        
        vm.deal(user, 10 ether);
        vm.prank(user);
        vaultManager.depositCollateral{value: 5 ether}();
        
        (uint256 collateral, uint256 debt) = vaultManager.getVault(user);
        assertEq(collateral, 5 ether);
        assertEq(debt, 0);
    }

    function test_MintDebt() public {
        vm.prank(user);
        vaultManager.createVault();
        
        vm.deal(user, 10 ether);
        vm.prank(user);
        vaultManager.depositCollateral{value: 10 ether}();
        
        // Max debt = (10 ether * 2000e18) / 1.5 = 13333.33... sUSD
        // Let's mint 10000 sUSD (safe)
        uint256 debtAmount = 10000e18;
        vm.prank(user);
        vaultManager.mintDebt(debtAmount);
        
        (uint256 collateral, uint256 debt) = vaultManager.getVault(user);
        assertEq(collateral, 10 ether);
        assertEq(debt, debtAmount);
        assertEq(sUSD.balanceOf(user), debtAmount);
    }

    function test_CannotMintDebtExceedingCollateralizationRatio() public {
        vm.prank(user);
        vaultManager.createVault();
        
        vm.deal(user, 10 ether);
        vm.prank(user);
        vaultManager.depositCollateral{value: 10 ether}();
        
        // Try to mint too much debt
        // Max debt = (10 ether * 2000e18) / 1.5 = 13333.33... sUSD
        // Try to mint 15000 sUSD (too much)
        uint256 debtAmount = 15000e18;
        vm.prank(user);
        vm.expectRevert("VaultManager: would violate collateralization ratio");
        vaultManager.mintDebt(debtAmount);
    }

    function test_RepayDebt() public {
        vm.prank(user);
        vaultManager.createVault();
        
        vm.deal(user, 10 ether);
        vm.prank(user);
        vaultManager.depositCollateral{value: 10 ether}();
        
        uint256 debtAmount = 10000e18;
        vm.prank(user);
        vaultManager.mintDebt(debtAmount);
        
        // Repay half the debt
        vm.prank(user);
        vaultManager.repayDebt(5000e18);
        
        (uint256 collateral, uint256 debt) = vaultManager.getVault(user);
        assertEq(debt, 5000e18);
        assertEq(sUSD.balanceOf(user), 5000e18);
    }

    function test_WithdrawCollateral() public {
        vm.prank(user);
        vaultManager.createVault();
        
        vm.deal(user, 10 ether);
        vm.prank(user);
        vaultManager.depositCollateral{value: 10 ether}();
        
        uint256 debtAmount = 10000e18;
        vm.prank(user);
        vaultManager.mintDebt(debtAmount);
        
        // Withdraw some collateral (must maintain ratio)
        uint256 withdrawAmount = 2 ether;
        uint256 initialBalance = user.balance;
        vm.prank(user);
        vaultManager.withdrawCollateral(withdrawAmount);
        
        assertEq(user.balance, initialBalance + withdrawAmount);
        (uint256 collateral, uint256 debt) = vaultManager.getVault(user);
        assertEq(collateral, 8 ether);
    }

    function test_CannotWithdrawCollateralViolatingRatio() public {
        vm.prank(user);
        vaultManager.createVault();
        
        vm.deal(user, 10 ether);
        vm.prank(user);
        vaultManager.depositCollateral{value: 10 ether}();
        
        uint256 debtAmount = 10000e18;
        vm.prank(user);
        vaultManager.mintDebt(debtAmount);
        
        // Try to withdraw too much collateral
        vm.prank(user);
        vm.expectRevert("VaultManager: would violate collateralization ratio");
        vaultManager.withdrawCollateral(5 ether);
    }

    function test_PriceDropMakesVaultLiquidatable() public {
        vm.prank(user);
        vaultManager.createVault();
        
        vm.deal(user, 10 ether);
        vm.prank(user);
        vaultManager.depositCollateral{value: 10 ether}();
        
        uint256 debtAmount = 10000e18;
        vm.prank(user);
        vaultManager.mintDebt(debtAmount);
        
        // Initially vault should be healthy
        assertTrue(vaultManager.isHealthy(user));
        assertFalse(vaultManager.isLiquidatable(user));
        
        // Price drops to $1500 (75% of original)
        // Collateral value: 10 ether * 1500 = 15000 USD
        // Debt: 10000 sUSD
        // Ratio: 15000 / 10000 = 150% (still healthy, but close)
        
        // Price drops to $1200 (60% of original)
        // Collateral value: 10 ether * 1200 = 12000 USD
        // Debt: 10000 sUSD
        // Ratio: 12000 / 10000 = 120% (below 150% requirement, but above 110% liquidation threshold)
        
        // Price drops to $1100 (55% of original)
        // Collateral value: 10 ether * 1100 = 11000 USD
        // Debt: 10000 sUSD
        // Ratio: 11000 / 10000 = 110% (at liquidation threshold)
        
        // Price drops to $1000 (50% of original) - should be liquidatable
        // Collateral value: 10 ether * 1000 = 10000 USD
        // Debt: 10000 sUSD
        // Ratio: 10000 / 10000 = 100% (below 110% liquidation threshold)
        aggregator.updatePrice(1000e8);
        
        assertFalse(vaultManager.isHealthy(user));
        assertTrue(vaultManager.isLiquidatable(user));
    }

    function test_Liquidate() public {
        vm.prank(user);
        vaultManager.createVault();
        
        vm.deal(user, 10 ether);
        vm.prank(user);
        vaultManager.depositCollateral{value: 10 ether}();
        
        uint256 debtAmount = 10000e18;
        vm.prank(user);
        vaultManager.mintDebt(debtAmount);
        
        // Price drops to make vault liquidatable
        aggregator.updatePrice(1000e8);
        
        // Liquidator needs sUSD to repay the debt
        vm.deal(liquidator, 1 ether);
        vm.prank(liquidator);
        vaultManager.createVault();
        
        vm.deal(liquidator, 20 ether);
        vm.prank(liquidator);
        vaultManager.depositCollateral{value: 20 ether}();
        
        // Mint enough sUSD to liquidate
        vm.prank(liquidator);
        vaultManager.mintDebt(debtAmount);
        
        uint256 liquidatorBalanceBefore = liquidator.balance;
        
        // Liquidate
        vm.prank(liquidator);
        vaultManager.liquidate(user);
        
        // Liquidator should receive the collateral
        assertEq(liquidator.balance, liquidatorBalanceBefore + 10 ether);
        
        // User's vault should be cleared
        (uint256 collateral, uint256 debt) = vaultManager.getVault(user);
        assertEq(collateral, 0);
        assertEq(debt, 0);
    }

    function test_CannotLiquidateHealthyVault() public {
        vm.prank(user);
        vaultManager.createVault();
        
        vm.deal(user, 10 ether);
        vm.prank(user);
        vaultManager.depositCollateral{value: 10 ether}();
        
        uint256 debtAmount = 10000e18;
        vm.prank(user);
        vaultManager.mintDebt(debtAmount);
        
        // Vault is healthy, should not be liquidatable
        vm.prank(liquidator);
        vm.expectRevert("VaultManager: vault is not liquidatable");
        vaultManager.liquidate(user);
    }

    function test_GetMaxDebt() public {
        uint256 collateral = 10 ether;
        uint256 maxDebt = vaultManager.getMaxDebt(collateral);
        
        // Max debt = (10 ether * 2000e18) / 1.5 = 13333.33... sUSD
        uint256 expectedMaxDebt = (collateral * INITIAL_ETH_PRICE_SCALED) / 150e16;
        assertEq(maxDebt, expectedMaxDebt);
    }
}

