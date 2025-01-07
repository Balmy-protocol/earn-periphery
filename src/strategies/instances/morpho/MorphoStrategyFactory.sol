// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { MorphoStrategy, IGlobalEarnRegistry, IERC4626 } from "./MorphoStrategy.sol";

struct MorphoStrategyData {
  IEarnVault earnVault;
  IGlobalEarnRegistry globalRegistry;
  IERC4626 morphoVault;
  bytes creationValidationData;
  bytes guardianData;
  bytes feesData;
  bytes liquidityMiningData;
}

contract MorphoStrategyFactory is BaseStrategyFactory {
  constructor(MorphoStrategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneStrategy(MorphoStrategyData calldata strategyData) public returns (MorphoStrategy clone) {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = MorphoStrategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init({
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
  }

  function cloneStrategyAndRegister(
    address owner,
    MorphoStrategyData calldata strategyData
  )
    external
    returns (MorphoStrategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = MorphoStrategy(payable(address(clone_)));
    strategyId = clone.initAndRegister({
      owner: owner,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function cloneStrategyWithId(
    StrategyId strategyId,
    MorphoStrategyData calldata strategyData
  )
    external
    returns (MorphoStrategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = MorphoStrategy(payable(address(clone_)));
    emit StrategyCloned(clone, strategyId);
    clone.initWithId({
      strategyId_: strategyId,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
  }

  function clone2Strategy(
    MorphoStrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (MorphoStrategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = MorphoStrategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init({
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
  }

  function clone2StrategyAndRegister(
    address owner,
    MorphoStrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (MorphoStrategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = MorphoStrategy(payable(address(clone_)));
    strategyId = clone.initAndRegister({
      owner: owner,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function clone2StrategyWithId(
    StrategyId strategyId,
    MorphoStrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (MorphoStrategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = MorphoStrategy(payable(address(clone_)));
    emit StrategyCloned(clone, strategyId);
    clone.initWithId({
      strategyId_: strategyId,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
  }

  function addressOfClone2(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault,
    bytes32 salt
  )
    external
    view
    returns (address clone)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, erc4626Vault);
    return _addressOfClone2(immutableData, salt);
  }

  function _calculateImmutableData(MorphoStrategyData calldata strategyData) internal view returns (bytes memory) {
    return _calculateImmutableData(strategyData.earnVault, strategyData.globalRegistry, strategyData.morphoVault);
  }

  function _calculateImmutableData(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault
  )
    internal
    view
    returns (bytes memory)
  {
    address asset = erc4626Vault.asset();
    return abi.encodePacked(earnVault, globalRegistry, erc4626Vault, asset);
  }
}
