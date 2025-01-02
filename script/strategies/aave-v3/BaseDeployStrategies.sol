// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeploy } from "../../BaseDeploy.sol";
import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnVault.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import {
  AaveV3StrategyFactory,
  AaveV3Strategy,
  IAaveV3Pool,
  IAaveV3Rewards,
  IAToken,
  AaveV3StrategyData
} from "src/strategies/instances/aave-v3/AaveV3StrategyFactory.sol";
import { IEarnBalmyStrategy } from "src/interfaces/IEarnBalmyStrategy.sol";
import { StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { DeployVault } from "../../DeployVault.sol";
import { console2 } from "forge-std/console2.sol";

contract BaseDeployStrategies is BaseDeploy {
  function setUp() public override {
    super.setUp();
    // Assume vault is already deployed
    DeployVault deployVault = new DeployVault();
    deployVault.run();
  }

  function deployAaveV3Strategy(
    address aaveV3Pool,
    address aaveV3Rewards,
    address aToken,
    string memory symbol,
    bool isProtected
  )
    internal
  {
    address implementation = deployContract("V1_S_AAVEV3", abi.encodePacked(type(AaveV3Strategy).creationCode));
    AaveV3StrategyFactory aaveV3StrategyFactory = AaveV3StrategyFactory(
      deployContract(
        "V1_F_AAVEV3", abi.encodePacked(type(AaveV3StrategyFactory).creationCode, abi.encode(implementation))
      )
    );
    address vault = getDeployedAddress("V1_VAULT");
    address globalRegistry = getDeployedAddress("V1_GLOBAL_REGISTRY");

    bytes memory registryData = "";
    bytes memory manager1Data = abi.encode(TOS_GROUP);
    bytes memory manager2Data = "";
    if (isProtected) {
      // solhint-disable-next-line mi
      manager2Data = abi.encode(SIGNER_GROUP);
    }

    bytes[] memory validationManagersStrategyData = new bytes[](2);
    validationManagersStrategyData[0] = manager1Data;
    validationManagersStrategyData[1] = manager2Data;
    bytes memory creationValidationData = abi.encode(registryData, validationManagersStrategyData);
    bytes memory guardianData = "";
    bytes memory feesData = "";
    (IEarnBalmyStrategy strategy, StrategyId strategyId) = aaveV3StrategyFactory.cloneStrategyAndRegister(
      admin,
      AaveV3StrategyData(
        IEarnVault(vault),
        IGlobalEarnRegistry(globalRegistry),
        IAToken(aToken),
        IAaveV3Pool(aaveV3Pool),
        IAaveV3Rewards(aaveV3Rewards),
        creationValidationData,
        guardianData,
        feesData,
        string.concat(
          "Earn returns with one of DeFi's most reliable lending markets. When you deposit ",
          symbol,
          // solhint-disable-next-line max-line-length
          " into Aave, your funds automatically generate interest by being lent to trusted borrowers - offering better returns than traditional savings. The protocol has handled over $100 billion in loans with a spotless security record, while keeping your funds available to withdraw at any time."
        )
      )
    );
    console2.log("Strategy:", address(strategy));
    console2.log("Strategy ID:", StrategyId.unwrap(strategyId));
  }
}
