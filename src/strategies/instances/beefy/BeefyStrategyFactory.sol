// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { StrategyId, IEarnVault, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { BeefyStrategy, IBeefyVault } from "./BeefyStrategy.sol";

contract BeefyStrategyFactory is BaseStrategyFactory {
  constructor(BeefyStrategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneAndRegister(
    IEarnStrategyRegistry strategyRegistry,
    address owner,
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IBeefyVault beefyVault,
    address asset,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (BeefyStrategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = abi.encodePacked(earnVault, globalRegistry, beefyVault, asset);
    (IEarnBalmyStrategy clone_, StrategyId stratId) = _cloneAndRegister(strategyRegistry, owner, immutableData);
    clone = BeefyStrategy(payable(address(clone_)));
    strategyId = stratId;
    clone.init(tosData, guardianData, feesData, description);
  }

  function clone2AndRegister(
    IEarnStrategyRegistry strategyRegistry,
    address owner,
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IBeefyVault beefyVault,
    address asset,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (BeefyStrategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = abi.encodePacked(earnVault, globalRegistry, beefyVault, asset);
    (IEarnBalmyStrategy clone_, StrategyId stratId) = _clone2AndRegister(strategyRegistry, owner, immutableData);
    clone = BeefyStrategy(payable(address(clone_)));
    strategyId = stratId;
    clone.init(tosData, guardianData, feesData, description);
  }

  function clone3AndRegister(
    IEarnStrategyRegistry strategyRegistry,
    address owner,
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IBeefyVault beefyVault,
    address asset,
    bytes32 salt,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (BeefyStrategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = abi.encodePacked(earnVault, globalRegistry, beefyVault, asset);
    (IEarnBalmyStrategy clone_, StrategyId stratId) = _clone3AndRegister(strategyRegistry, owner, immutableData, salt);
    clone = BeefyStrategy(payable(address(clone_)));
    strategyId = stratId;
    clone.init(tosData, guardianData, feesData, description);
  }

  function addressOfClone2(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IBeefyVault beefyVault,
    address asset
  )
    external
    view
    returns (address clone)
  {
    bytes memory data = abi.encodePacked(earnVault, globalRegistry, beefyVault, asset);
    return _addressOfClone2(data);
  }
}
