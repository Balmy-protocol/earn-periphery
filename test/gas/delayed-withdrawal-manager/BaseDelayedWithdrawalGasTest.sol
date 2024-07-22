// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { EarnVault, IEarnVault, StrategyId, IEarnNFTDescriptor } from "@balmy/earn-core/vault/EarnVault.sol";
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

contract BaseDelayedWithdrawalGasTest is PRBTest {
  using StrategyUtils for IEarnStrategyRegistry;

  DelayedWithdrawalManager public delayedWithdrawalManager;

  uint256[] public positions;
  mapping(uint256 position => address token) public tokenByPosition;
  IEarnStrategy public strategy;
  StrategyId public strategyId;
  address[] public tokens = new address[](2);
  address public owner = address(3);

  function setUp() public virtual {
    tokens = new address[](2);
    IEarnStrategyRegistry strategyRegistry = new EarnStrategyRegistry();
    IEarnNFTDescriptor nftDescriptor;
    EarnVault vault = new EarnVault(strategyRegistry, address(1), CommonUtils.arrayOf(address(2)), nftDescriptor);
    ERC20MintableBurnableMock erc20 = new ERC20MintableBurnableMock();
    erc20.approve(address(vault), type(uint256).max);

    uint104 amountToDeposit1 = 1_000_000;
    uint104 amountToDeposit2 = 1_000_001;
    uint104 amountToDeposit3 = 1_000_003;
    erc20.mint(address(this), amountToDeposit3);

    tokens[0] = Token.NATIVE_TOKEN;
    tokens[1] = address(erc20);
    uint256 position;
    (strategyId, strategy) = strategyRegistry.deployStateStrategy(tokens);

    (position,) = vault.createPosition{ value: amountToDeposit1 }(
      strategyId, tokens[0], amountToDeposit1, owner, PermissionUtils.buildEmptyPermissionSet(), "", ""
    );
    positions.push(position);
    tokenByPosition[position] = tokens[0];

    (position,) = vault.createPosition{ value: amountToDeposit2 }(
      strategyId, tokens[0], amountToDeposit2, owner, PermissionUtils.buildEmptyPermissionSet(), "", ""
    );
    positions.push(position);
    tokenByPosition[position] = tokens[0];

    (position,) = vault.createPosition(
      strategyId, tokens[1], amountToDeposit3, owner, PermissionUtils.buildEmptyPermissionSet(), "", ""
    );
    positions.push(position);
    tokenByPosition[position] = tokens[1];
    delayedWithdrawalManager = new DelayedWithdrawalManager(vault);
  }
}
