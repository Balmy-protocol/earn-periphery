// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { StrategyId, IEarnVault, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { AaveV3Strategy, IGlobalEarnRegistry, IAToken, IAaveV3Pool, IAaveV3Rewards } from "./AaveV3Strategy.sol";

struct AaveV3StrategyImmutableData {
  IEarnVault earnVault;
  IGlobalEarnRegistry globalRegistry;
  IAToken aToken;
  IAaveV3Pool aaveV3Pool;
  IAaveV3Rewards aaveV3Rewards;
}

contract AaveV3StrategyFactory is BaseStrategyFactory {
  constructor(AaveV3Strategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneAndRegister(
    IEarnStrategyRegistry strategyRegistry,
    address owner,
    AaveV3StrategyImmutableData memory strategyImmutableData,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (AaveV3Strategy clone, StrategyId strategyId)
  {
    address asset = strategyImmutableData.aToken.UNDERLYING_ASSET_ADDRESS();
    bytes memory immutableData = abi.encodePacked(
      strategyImmutableData.earnVault,
      strategyImmutableData.globalRegistry,
      strategyImmutableData.aToken,
      asset,
      strategyImmutableData.aaveV3Pool,
      strategyImmutableData.aaveV3Rewards
    );
    (IEarnBalmyStrategy clone_, StrategyId stratId) = _cloneAndRegister(strategyRegistry, owner, immutableData);
    clone = AaveV3Strategy(payable(address(clone_)));
    strategyId = stratId;
    clone.init(tosData, guardianData, feesData, description);
  }

  function clone2AndRegister(
    IEarnStrategyRegistry strategyRegistry,
    address owner,
    AaveV3StrategyImmutableData memory strategyImmutableData,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (AaveV3Strategy clone, StrategyId strategyId)
  {
    address asset = strategyImmutableData.aToken.UNDERLYING_ASSET_ADDRESS();
    bytes memory immutableData = abi.encodePacked(
      strategyImmutableData.earnVault,
      strategyImmutableData.globalRegistry,
      strategyImmutableData.aToken,
      asset,
      strategyImmutableData.aaveV3Pool,
      strategyImmutableData.aaveV3Rewards
    );
    (IEarnBalmyStrategy clone_, StrategyId stratId) = _clone2AndRegister(strategyRegistry, owner, immutableData);
    clone = AaveV3Strategy(payable(address(clone_)));
    strategyId = stratId;
    clone.init(tosData, guardianData, feesData, description);
  }

  function clone3AndRegister(
    IEarnStrategyRegistry strategyRegistry,
    address owner,
    AaveV3StrategyImmutableData memory strategyImmutableData,
    bytes32 salt,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (AaveV3Strategy clone, StrategyId strategyId)
  {
    address asset = strategyImmutableData.aToken.UNDERLYING_ASSET_ADDRESS();
    bytes memory immutableData = abi.encodePacked(
      strategyImmutableData.earnVault,
      strategyImmutableData.globalRegistry,
      strategyImmutableData.aToken,
      asset,
      strategyImmutableData.aaveV3Pool,
      strategyImmutableData.aaveV3Rewards
    );
    (IEarnBalmyStrategy clone_, StrategyId stratId) = _clone3AndRegister(strategyRegistry, owner, immutableData, salt);
    clone = AaveV3Strategy(payable(address(clone_)));
    strategyId = stratId;
    clone.init(tosData, guardianData, feesData, description);
  }

  function addressOfClone2(AaveV3StrategyImmutableData memory strategyImmutableData) external returns (address clone) {
    address asset = strategyImmutableData.aToken.UNDERLYING_ASSET_ADDRESS();
    bytes memory data = abi.encodePacked(
      strategyImmutableData.earnVault,
      strategyImmutableData.globalRegistry,
      strategyImmutableData.aToken,
      asset,
      strategyImmutableData.aaveV3Pool,
      strategyImmutableData.aaveV3Rewards
    );
    return _addressOfClone2(data);
  }
}
