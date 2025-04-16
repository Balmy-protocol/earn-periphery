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
    address aaveV3Pool = 0xb50201558B00496A145fE76f7424749556E326D8;
    address aaveV3Rewards = 0xaD4F91D26254B6B0C6346b390dDA2991FDE2F20d;

    // WETH
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xa818F1B57c201E092C4A2017A91815034326Efd1),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - weth - ", guard)
    });

    // WstETH
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x23e4E76D01B2002BE436CE8d6044b0aA2f68B68a),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - wsteth - ", guard)
    });

    // GNO
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xA1Fa064A85266E2Ca82DEe5C5CcEC84DF445760e),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - gno - ", guard)
    });

    // USDC
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xc6B7AcA6DE8a6044E0e32d0c841a89244A10D284),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - usdc - ", guard)
    });

    // WXDAI
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xd0Dd6cEF72143E22cCED4867eb0d5F2328715533),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - wxdai - ", guard)
    });

    //EUR.e
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xEdBC7449a9b594CA4E053D9737EC5Dc4CbCcBfb2),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - eur.e - ", guard)
    });

    //sDAI
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x7a5c3860a77a8DC1b225BD46d0fb2ac1C6D191BC),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - sdai - ", guard)
    });

    //USDC.e
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xC0333cb85B59a788d8C7CAe5e1Fd6E229A3E5a65),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - usdc.e - ", guard)
    });
  }
}
