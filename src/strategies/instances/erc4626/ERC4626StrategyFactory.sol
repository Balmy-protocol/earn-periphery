// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { StrategyId, IEarnVault, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { ERC4626Strategy, IGlobalEarnRegistry, IERC4626 } from "./ERC4626Strategy.sol";

contract ERC4626StrategyFactory is BaseStrategyFactory {
  constructor(ERC4626Strategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneAndRegister(
    IEarnStrategyRegistry strategyRegistry,
    address owner,
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (ERC4626Strategy clone, StrategyId strategyId)
  {
    address asset = erc4626Vault.asset();
    bytes memory immutableData = abi.encodePacked(earnVault, globalRegistry, erc4626Vault, asset);
    (IEarnBalmyStrategy clone_, StrategyId stratId) = _cloneAndRegister(strategyRegistry, owner, immutableData);
    clone = ERC4626Strategy(address(clone_));
    strategyId = stratId;
    clone.init(tosData, guardianData, feesData, description);
  }

  function clone2AndRegister(
    IEarnStrategyRegistry strategyRegistry,
    address owner,
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (ERC4626Strategy clone, StrategyId strategyId)
  {
    address asset = erc4626Vault.asset();
    bytes memory immutableData = abi.encodePacked(earnVault, globalRegistry, erc4626Vault, asset);
    (IEarnBalmyStrategy clone_, StrategyId stratId) = _clone2AndRegister(strategyRegistry, owner, immutableData);
    clone = ERC4626Strategy(address(clone_));
    strategyId = stratId;
    clone.init(tosData, guardianData, feesData, description);
  }

  function clone3AndRegister(
    IEarnStrategyRegistry strategyRegistry,
    address owner,
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault,
    bytes32 salt,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (ERC4626Strategy clone, StrategyId strategyId)
  {
    address asset = erc4626Vault.asset();
    bytes memory immutableData = abi.encodePacked(earnVault, globalRegistry, erc4626Vault, asset);
    (IEarnBalmyStrategy clone_, StrategyId stratId) = _clone3AndRegister(strategyRegistry, owner, immutableData, salt);
    clone = ERC4626Strategy(address(clone_));
    strategyId = stratId;
    clone.init(tosData, guardianData, feesData, description);
  }

  function addressOfClone2(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault
  )
    external
    view
    returns (address clone)
  {
    address asset = erc4626Vault.asset();
    bytes memory data = abi.encodePacked(earnVault, globalRegistry, erc4626Vault, asset);
    return _addressOfClone2(data);
  }
}
