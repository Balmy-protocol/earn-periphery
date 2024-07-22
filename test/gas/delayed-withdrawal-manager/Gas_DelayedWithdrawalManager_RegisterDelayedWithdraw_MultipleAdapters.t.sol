// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { EarnVault, IEarnVault, StrategyId } from "@balmy/earn-core/vault/EarnVault.sol";
import {
  EarnStrategyRegistry, IEarnStrategyRegistry
} from "@balmy/earn-core/strategy-registry/EarnStrategyRegistry.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  DelayedWithdrawalManager,
  IDelayedWithdrawalManager,
  IDelayedWithdrawalAdapter
} from "@balmy/earn-core/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { INFTPermissions, IERC721 } from "@balmy/nft-permissions/interfaces/INFTPermissions.sol";
import { PermissionUtils } from "@balmy/nft-permissions-test/PermissionUtils.sol";
import { EarnStrategyStateBalanceMock } from "@balmy/earn-core-test/mocks/strategies/EarnStrategyStateBalanceMock.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import { StrategyUtils } from "@balmy/earn-core-test/utils/StrategyUtils.sol";
import { ERC20MintableBurnableMock } from "@balmy/earn-core-test/mocks/ERC20/ERC20MintableBurnableMock.sol";
import { BaseDelayedWithdrawalGasTest } from "./BaseDelayedWithdrawalGasTest.sol";

contract GasDelayedWithdrawalManagerRegisterDelayedWithdraw is BaseDelayedWithdrawalGasTest {
  using StrategyUtils for IEarnStrategyRegistry;

  function setUp() public virtual override {
    super.setUp();

    // setUp
    IDelayedWithdrawalAdapter adapter = strategy.delayedWithdrawalAdapter(tokenByPosition[positions[1]]);
    vm.prank(address(adapter));
    delayedWithdrawalManager.registerDelayedWithdraw(positions[1], tokenByPosition[positions[1]]);

    // Update strategy to register a new adapter
    IEarnStrategyRegistry strategyRegistry = delayedWithdrawalManager.STRATEGY_REGISTRY();
    IEarnStrategy newStrategy = StrategyUtils.deployStateStrategy(tokens);
    strategyRegistry.proposeStrategyUpdate(strategyId, newStrategy, "0x");
    vm.warp(block.timestamp + strategyRegistry.STRATEGY_UPDATE_DELAY()); //Waiting for the delay...
    strategyRegistry.updateStrategy(strategyId, "0x");

    // Register new strategy adapter
    adapter = newStrategy.delayedWithdrawalAdapter(tokenByPosition[positions[1]]);
    vm.prank(address(adapter));
  }

  function test_Gas_registerDelayedWithdraw_twoAdapters() public {
    delayedWithdrawalManager.registerDelayedWithdraw(positions[1], tokenByPosition[positions[1]]);
  }
}
