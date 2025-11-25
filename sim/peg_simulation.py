"""
VaultUSD Peg Stability Simulation

This simulation demonstrates how the over-collateralized stablecoin system
maintains peg stability through collateralization ratios and liquidations.
"""

import numpy as np
import matplotlib.pyplot as plt
from dataclasses import dataclass
from typing import List

@dataclass
class Vault:
    """Represents a user vault"""
    collateral_eth: float
    debt_susd: float
    owner: str

@dataclass
class SystemState:
    """Represents the overall system state"""
    total_collateral_eth: float
    total_debt_susd: float
    eth_price_usd: float
    collateralization_ratio: float
    timestamp: int

class VaultUSDSimulator:
    """Simulates the VaultUSD stablecoin system"""
    
    COLLATERALIZATION_RATIO = 1.5  # 150%
    LIQUIDATION_THRESHOLD = 1.1    # 110%
    
    def __init__(self, initial_eth_price: float = 2000.0):
        self.eth_price = initial_eth_price
        self.vaults: List[Vault] = []
        self.history: List[SystemState] = []
        
    def create_vault(self, owner: str, collateral_eth: float, debt_susd: float):
        """Create a new vault with collateral and debt"""
        vault = Vault(collateral_eth, debt_susd, owner)
        self.vaults.append(vault)
        return vault
    
    def get_vault_health(self, vault: Vault) -> float:
        """Calculate collateralization ratio for a vault"""
        if vault.debt_susd == 0:
            return float('inf')
        collateral_value = vault.collateral_eth * self.eth_price
        return collateral_value / vault.debt_susd
    
    def is_healthy(self, vault: Vault) -> bool:
        """Check if vault is above collateralization ratio"""
        return self.get_vault_health(vault) >= self.COLLATERALIZATION_RATIO
    
    def is_liquidatable(self, vault: Vault) -> bool:
        """Check if vault is below liquidation threshold"""
        if vault.debt_susd == 0:
            return False
        return self.get_vault_health(vault) < self.LIQUIDATION_THRESHOLD
    
    def liquidate_vault(self, vault: Vault):
        """Liquidate an undercollateralized vault"""
        if not self.is_liquidatable(vault):
            return False
        
        # In liquidation, debt is repaid and collateral is seized
        # For simplicity, we remove the vault
        self.vaults.remove(vault)
        return True
    
    def update_price(self, new_price: float):
        """Update ETH price and check for liquidations"""
        self.eth_price = new_price
        
        # Check all vaults for liquidation
        vaults_to_liquidate = [v for v in self.vaults if self.is_liquidatable(v)]
        for vault in vaults_to_liquidate:
            self.liquidate_vault(vault)
    
    def get_system_state(self, timestamp: int = 0) -> SystemState:
        """Get current system state"""
        total_collateral = sum(v.collateral_eth for v in self.vaults)
        total_debt = sum(v.debt_susd for v in self.vaults)
        
        if total_debt == 0:
            ratio = float('inf')
        else:
            ratio = (total_collateral * self.eth_price) / total_debt
        
        return SystemState(
            total_collateral_eth=total_collateral,
            total_debt_susd=total_debt,
            eth_price_usd=self.eth_price,
            collateralization_ratio=ratio,
            timestamp=timestamp
        )
    
    def record_state(self, timestamp: int = 0):
        """Record current system state to history"""
        self.history.append(self.get_system_state(timestamp))

def simulate_price_shock():
    """Simulate a price shock scenario"""
    sim = VaultUSDSimulator(initial_eth_price=2000.0)
    
    # Create several vaults with different collateralization levels
    sim.create_vault("user1", 10.0, 10000.0)  # 200% ratio initially
    sim.create_vault("user2", 5.0, 5000.0)    # 200% ratio initially
    sim.create_vault("user3", 3.0, 3000.0)    # 200% ratio initially
    
    # Record initial state
    sim.record_state(0)
    
    # Simulate price drops
    prices = [2000, 1800, 1600, 1400, 1200, 1000, 800]
    for i, price in enumerate(prices):
        sim.update_price(price)
        sim.record_state(i + 1)
    
    return sim

def plot_simulation(sim: VaultUSDSimulator):
    """Plot simulation results"""
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    
    timestamps = [s.timestamp for s in sim.history]
    prices = [s.eth_price_usd for s in sim.history]
    total_debt = [s.total_debt_susd for s in sim.history]
    total_collateral = [s.total_collateral_eth for s in sim.history]
    ratios = [min(s.collateralization_ratio, 5.0) for s in sim.history]  # Cap at 5 for visualization
    
    # Price over time
    axes[0, 0].plot(timestamps, prices, 'b-', linewidth=2, marker='o')
    axes[0, 0].axhline(y=2000, color='r', linestyle='--', alpha=0.5, label='Initial Price')
    axes[0, 0].set_xlabel('Time Step')
    axes[0, 0].set_ylabel('ETH Price (USD)')
    axes[0, 0].set_title('ETH Price Shock')
    axes[0, 0].grid(True, alpha=0.3)
    axes[0, 0].legend()
    
    # Total debt over time
    axes[0, 1].plot(timestamps, total_debt, 'r-', linewidth=2, marker='s')
    axes[0, 1].set_xlabel('Time Step')
    axes[0, 1].set_ylabel('Total Debt (sUSD)')
    axes[0, 1].set_title('Total System Debt')
    axes[0, 1].grid(True, alpha=0.3)
    
    # Total collateral over time
    axes[1, 0].plot(timestamps, total_collateral, 'g-', linewidth=2, marker='^')
    axes[1, 0].set_xlabel('Time Step')
    axes[1, 0].set_ylabel('Total Collateral (ETH)')
    axes[1, 0].set_title('Total System Collateral')
    axes[1, 0].grid(True, alpha=0.3)
    
    # System collateralization ratio
    axes[1, 1].plot(timestamps, ratios, 'purple', linewidth=2, marker='d')
    axes[1, 1].axhline(y=1.5, color='orange', linestyle='--', alpha=0.5, label='Min Ratio (150%)')
    axes[1, 1].axhline(y=1.1, color='red', linestyle='--', alpha=0.5, label='Liquidation (110%)')
    axes[1, 1].set_xlabel('Time Step')
    axes[1, 1].set_ylabel('Collateralization Ratio')
    axes[1, 1].set_title('System Collateralization Ratio')
    axes[1, 1].grid(True, alpha=0.3)
    axes[1, 1].legend()
    
    plt.tight_layout()
    plt.savefig('sim/peg_simulation_results.png', dpi=300, bbox_inches='tight')
    print("Simulation plot saved to sim/peg_simulation_results.png")
    plt.show()

def main():
    """Run the simulation"""
    print("VaultUSD Peg Stability Simulation")
    print("=" * 50)
    
    sim = simulate_price_shock()
    
    print(f"\nInitial State:")
    initial = sim.history[0]
    print(f"  ETH Price: ${initial.eth_price_usd:.2f}")
    print(f"  Total Collateral: {initial.total_collateral_eth:.2f} ETH")
    print(f"  Total Debt: {initial.total_debt_susd:.2f} sUSD")
    print(f"  System Ratio: {initial.collateralization_ratio:.2%}")
    
    print(f"\nFinal State:")
    final = sim.history[-1]
    print(f"  ETH Price: ${final.eth_price_usd:.2f}")
    print(f"  Total Collateral: {final.total_collateral_eth:.2f} ETH")
    print(f"  Total Debt: {final.total_debt_susd:.2f} sUSD")
    print(f"  System Ratio: {final.collateralization_ratio:.2%}")
    print(f"  Active Vaults: {len(sim.vaults)}")
    
    print("\nGenerating plots...")
    plot_simulation(sim)

if __name__ == "__main__":
    main()

