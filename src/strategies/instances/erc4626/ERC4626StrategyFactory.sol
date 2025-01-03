// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { ERC4626Strategy, IGlobalEarnRegistry, IERC4626 } from "./ERC4626Strategy.sol";

struct ERC4626StrategyData {
  IEarnVault earnVault;
  IGlobalEarnRegistry globalRegistry;
  IERC4626 erc4626Vault;
  bytes creationValidationData;
  bytes guardianData;
  bytes feesData;
  bytes liquidityMiningData;
  string description;
}

contract ERC4626StrategyFactory is BaseStrategyFactory {
  constructor(ERC4626Strategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneStrategy(ERC4626StrategyData calldata strategyData) public returns (ERC4626Strategy clone) {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = ERC4626Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init({
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
    });
  }

  function cloneStrategyAndRegister(
    address owner,
    ERC4626StrategyData calldata strategyData
  )
    external
    returns (ERC4626Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = ERC4626Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister({
      owner: owner,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
    });
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function cloneStrategyWithId(
    StrategyId strategyId,
    ERC4626StrategyData calldata strategyData
  )
    external
    returns (ERC4626Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = ERC4626Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, strategyId);
    clone.initWithId({
      strategyId_: strategyId,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
    });
  }

  function clone2Strategy(
    ERC4626StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (ERC4626Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = ERC4626Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init({
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
    });
  }

  function clone2StrategyAndRegister(
    address owner,
    ERC4626StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (ERC4626Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = ERC4626Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister({
      owner: owner,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
    });
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function clone2StrategyWithId(
    StrategyId strategyId,
    ERC4626StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (ERC4626Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = ERC4626Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, strategyId);
    clone.initWithId({
      strategyId_: strategyId,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
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

  function _calculateImmutableData(ERC4626StrategyData calldata strategyData) internal view returns (bytes memory) {
    return _calculateImmutableData(strategyData.earnVault, strategyData.globalRegistry, strategyData.erc4626Vault);
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
