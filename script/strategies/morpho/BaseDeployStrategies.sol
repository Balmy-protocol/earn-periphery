// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "../../BaseDeployPeriphery.sol";

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnVault.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import {
  MorphoStrategyFactory,
  MorphoStrategy,
  IERC4626,
  MorphoStrategyData
} from "src/strategies/instances/morpho/MorphoStrategyFactory.sol";
import { IEarnBalmyStrategy } from "src/interfaces/IEarnBalmyStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { console2 } from "forge-std/console2.sol";

import { Fees } from "src/types/Fees.sol";

contract BaseDeployStrategies is BaseDeployPeriphery {
  function deployMorphoStrategy(
    IERC4626 mToken,
    bytes32 tosGroup,
    bytes32 signerGroup,
    address[] memory guardians,
    address[] memory judges,
    Fees memory fees,
    bytes32 guard,
    string memory description,
    address[] memory rewardTokens
  )
    internal
    returns (IEarnBalmyStrategy strategy, StrategyId strategyId)
  {
    return deployMorphoStrategyWithId(
      mToken,
      tosGroup,
      signerGroup,
      guardians,
      judges,
      fees,
      guard,
      description,
      rewardTokens,
      StrategyIdConstants.NO_STRATEGY
    );
  }

  function deployMorphoStrategyWithId(
    IERC4626 mToken,
    bytes32 tosGroup,
    bytes32 signerGroup,
    address[] memory guardians,
    address[] memory judges,
    Fees memory fees,
    bytes32 guard,
    string memory description,
    address[] memory rewardTokens,
    StrategyId initialStrategyId
  )
    internal
    returns (IEarnBalmyStrategy strategy, StrategyId strategyId)
  {
    console2.log("MorphoStrategyFactory creation code: ");
    console2.logBytes(abi.encodePacked(type(MorphoStrategyFactory).creationCode));
    address implementation = deployContract("V6_S_MORPHO", abi.encodePacked(type(MorphoStrategy).creationCode));
    console2.log("Implementation deployed: ", implementation);
    MorphoStrategyFactory morphoStrategyFactory = MorphoStrategyFactory(
      deployContract(
        "V6_F_MORPHO", abi.encodePacked(type(MorphoStrategyFactory).creationCode, abi.encode(implementation))
      )
    );
    console2.log("Factory deployed: ", address(morphoStrategyFactory));
    address vault = getDeployedAddress("V2_VAULT");
    console2.log("Vault deployed: ", vault);
    address globalRegistry = getDeployedAddress("V2_GLOBAL_REGISTRY");
    console2.log("Global registry deployed: ", globalRegistry);

    bytes memory registryData = "";
    bytes memory manager1Data = tosGroup != bytes32(0) ? abi.encode(tosGroup) : bytes("");
    bytes memory manager2Data = signerGroup != bytes32(0) ? abi.encode(signerGroup) : bytes("");

    bytes[] memory validationManagersStrategyData = new bytes[](2);
    validationManagersStrategyData[0] = manager1Data;
    validationManagersStrategyData[1] = manager2Data;
    bytes memory creationValidationData = abi.encode(registryData, validationManagersStrategyData);
    bytes memory guardianData = guardians.length > 0 || judges.length > 0 ? abi.encode(guardians, judges) : bytes("");
    bytes memory liquidityMiningData = "";
    bytes memory feesData = fees.equals(DEFAULT_FEES) ? bytes("") : abi.encode(fees);
    bytes32 salt = keccak256(abi.encode("V1_S_MORPHO", guard));

    address computedAddress =
      morphoStrategyFactory.addressOfClone2(IEarnVault(vault), IGlobalEarnRegistry(globalRegistry), mToken, salt);
    if (computedAddress.code.length > 0) {
      console2.log("Strategy already deployed", computedAddress);
    } else {
      if (initialStrategyId == StrategyIdConstants.NO_STRATEGY) {
        (strategy, strategyId) = morphoStrategyFactory.clone2StrategyAndRegister(
          admin,
          MorphoStrategyData(
            IEarnVault(vault),
            IGlobalEarnRegistry(globalRegistry),
            mToken,
            creationValidationData,
            guardianData,
            feesData,
            liquidityMiningData,
            rewardTokens
          ),
          salt
        );
      } else {
        strategyId = initialStrategyId;
        strategy = morphoStrategyFactory.clone2StrategyWithId(
          StrategyId(initialStrategyId),
          MorphoStrategyData(
            IEarnVault(vault),
            IGlobalEarnRegistry(globalRegistry),
            mToken,
            creationValidationData,
            guardianData,
            feesData,
            liquidityMiningData,
            rewardTokens
          ),
          salt
        );
      }
      console2.log(string.concat(description, ":"), address(strategy));
      console2.log(string.concat(description, " id:"), StrategyId.unwrap(strategyId));
    }
  }
}
