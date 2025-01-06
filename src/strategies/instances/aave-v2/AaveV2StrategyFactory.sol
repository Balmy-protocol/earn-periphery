// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { AaveV2Strategy, IGlobalEarnRegistry, IAToken, IAaveV2Pool } from "./AaveV2Strategy.sol";

struct AaveV2StrategyData {
  IEarnVault earnVault;
  IGlobalEarnRegistry globalRegistry;
  IAToken aToken;
  IAaveV2Pool aaveV2Pool;
  bytes creationValidationData;
  bytes guardianData;
  bytes feesData;
  bytes liquidityMiningData;
}

contract AaveV2StrategyFactory is BaseStrategyFactory {
  constructor(AaveV2Strategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneStrategy(AaveV2StrategyData calldata strategyData) external returns (AaveV2Strategy clone) {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = AaveV2Strategy(payable(address(clone_)));
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
    AaveV2StrategyData calldata strategyData
  )
    external
    returns (AaveV2Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = AaveV2Strategy(payable(address(clone_)));
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
    AaveV2StrategyData calldata strategyData
  )
    external
    returns (AaveV2Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = AaveV2Strategy(payable(address(clone_)));
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
    AaveV2StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (AaveV2Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = AaveV2Strategy(payable(address(clone_)));
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
    AaveV2StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (AaveV2Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = AaveV2Strategy(payable(address(clone_)));
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
    AaveV2StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (AaveV2Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = AaveV2Strategy(payable(address(clone_)));
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
    IAToken aToken,
    IAaveV2Pool aaveV2Pool,
    bytes32 salt
  )
    external
    view
    returns (address clone)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, aToken, aaveV2Pool);
    return _addressOfClone2(immutableData, salt);
  }

  function _calculateImmutableData(AaveV2StrategyData calldata strategyData) internal view returns (bytes memory) {
    return _calculateImmutableData(
      strategyData.earnVault, strategyData.globalRegistry, strategyData.aToken, strategyData.aaveV2Pool
    );
  }

  function _calculateImmutableData(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IAToken aToken,
    IAaveV2Pool aaveV2Pool
  )
    internal
    view
    returns (bytes memory)
  {
    address asset = aToken.UNDERLYING_ASSET_ADDRESS();
    return abi.encodePacked(earnVault, globalRegistry, aToken, asset, aaveV2Pool);
  }
}
