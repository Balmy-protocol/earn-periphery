// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { CompoundV2Strategy, IGlobalEarnRegistry, ICERC20, IComptroller, IERC20 } from "./CompoundV2Strategy.sol";

struct CompoundV2StrategyData {
  IEarnVault earnVault;
  IGlobalEarnRegistry globalRegistry;
  address asset;
  ICERC20 cToken;
  IComptroller comptroller;
  IERC20 comp;
  bytes tosData;
  bytes guardianData;
  bytes feesData;
  string description;
}

contract CompoundV2StrategyFactory is BaseStrategyFactory {
  constructor(CompoundV2Strategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneStrategy(CompoundV2StrategyData calldata strategyData) external returns (CompoundV2Strategy clone) {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = CompoundV2Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init(strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description);
  }

  function cloneStrategyAndRegister(
    address owner,
    CompoundV2StrategyData calldata strategyData
  )
    external
    returns (CompoundV2Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = CompoundV2Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(
      owner, strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description
    );
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function clone2Strategy(CompoundV2StrategyData calldata strategyData) external returns (CompoundV2Strategy clone) {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData);
    clone = CompoundV2Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init(strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description);
  }

  function clone2StrategyAndRegister(
    address owner,
    CompoundV2StrategyData calldata strategyData
  )
    external
    returns (CompoundV2Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData);
    clone = CompoundV2Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(
      owner, strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description
    );
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function clone3Strategy(
    CompoundV2StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (CompoundV2Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    (IEarnBalmyStrategy clone_) = _clone3(immutableData, salt);
    clone = CompoundV2Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init(strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description);
  }

  function clone3StrategyAndRegister(
    address owner,
    CompoundV2StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (CompoundV2Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    (IEarnBalmyStrategy clone_) = _clone3(immutableData, salt);
    clone = CompoundV2Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(
      owner, strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description
    );
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function addressOfClone2(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    address asset,
    ICERC20 cToken,
    IComptroller comptroller,
    IERC20 comp
  )
    external
    view
    returns (address clone)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, asset, cToken, comptroller, comp);
    return _addressOfClone2(immutableData);
  }

  function _calculateImmutableData(CompoundV2StrategyData calldata strategyData) internal pure returns (bytes memory) {
    return _calculateImmutableData(
      strategyData.earnVault,
      strategyData.globalRegistry,
      strategyData.asset,
      strategyData.cToken,
      strategyData.comptroller,
      strategyData.comp
    );
  }

  function _calculateImmutableData(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    address asset,
    ICERC20 cToken,
    IComptroller comptroller,
    IERC20 comp
  )
    internal
    pure
    returns (bytes memory)
  {
    return abi.encodePacked(earnVault, globalRegistry, asset, cToken, comptroller, comp);
  }
}
