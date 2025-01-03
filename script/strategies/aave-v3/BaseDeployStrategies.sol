// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "../../BaseDeployPeriphery.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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
import { console2 } from "forge-std/console2.sol";

contract BaseDeployStrategies is BaseDeployPeriphery {
  function deployAaveV3Strategy(
    address aaveV3Pool,
    address aaveV3Rewards,
    IAToken aToken,
    bytes32 tosGroup,
    bytes32 signerGroup,
    address[] memory guardians,
    address[] memory judges
  )
    internal
    returns (IEarnBalmyStrategy strategy, StrategyId strategyId)
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
    bytes memory manager1Data = tosGroup != bytes32(0) ? abi.encode(tosGroup) : bytes("");
    bytes memory manager2Data = signerGroup != bytes32(0) ? abi.encode(signerGroup) : bytes("");

    bytes[] memory validationManagersStrategyData = new bytes[](2);
    validationManagersStrategyData[0] = manager1Data;
    validationManagersStrategyData[1] = manager2Data;
    bytes memory creationValidationData = abi.encode(registryData, validationManagersStrategyData);
    bytes memory guardianData = guardians.length > 0 || judges.length > 0 ? abi.encode(guardians, judges) : bytes("");
    bytes memory feesData = "";
    string memory symbol = ERC20(aToken.UNDERLYING_ASSET_ADDRESS()).symbol();
    (strategy, strategyId) = aaveV3StrategyFactory.cloneStrategyAndRegister(
      admin,
      AaveV3StrategyData(
        IEarnVault(vault),
        IGlobalEarnRegistry(globalRegistry),
        aToken,
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
