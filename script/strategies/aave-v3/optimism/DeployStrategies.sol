// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IAToken } from "../BaseDeployStrategies.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    address[] memory judges = new address[](1);
    address msig = getMsig();
    judges[0] = msig;

    vm.startBroadcast();
    deployPeriphery();
    _deployAaveV3Strategies({
      guardians: _getGuardiansArray(BALMY_GUARDIAN, true),
      judges: judges,
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      guard: "",
      version: "v3"
    });
    _deployAaveV3Strategies({
      guardians: _getGuardiansArray(HYPERNATIVE_GUARDIAN, false),
      judges: judges,
      tosGroup: HYPERNATIVE_GUARDIAN_TOS_GROUP,
      guard: "hypernative",
      version: "v1"
    });
    vm.stopBroadcast();
  }

  function _deployAaveV3Strategies(
    address[] memory guardians,
    address[] memory judges,
    bytes32 tosGroup,
    string memory guard,
    string memory version
  )
    internal
  {
    address aaveV3Pool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address aaveV3Rewards = 0x929EC64c34a17401F460460D4B9390518E5B473e;

    // WETH
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - weth - ", guard)
    });

    // Bridged USDC
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x625E7708f30cA75bfd92586e17077590C60eb4cD),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - bridged usdc - ", guard)
    });

    // WBTC
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x078f358208685046a11C85e8ad32895DED33A249),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - wbtc - ", guard)
    });

    // USDT
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x6ab707Aca953eDAeFBc4fD23bA73294241490620),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - usdt - ", guard)
    });

    // OP
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x513c7E3a9c69cA3e22550eF58AC1C0088e918FFf),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - op - ", guard)
    });

    // SUSD
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - susd - ", guard)
    });

    // USDC
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x38d693cE1dF5AaDF7bC62595A37D667aD57922e5),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - usdc - ", guard)
    });

    // DAI
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - dai - ", guard)
    });

    // LUSD
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x8Eb270e296023E9D92081fdF967dDd7878724424),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - lusd - ", guard)
    });
  }
}
