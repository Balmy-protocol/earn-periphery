// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategyRegistry.sol";
import { Test } from "forge-std/Test.sol";
import {
  EarnVaultCompanion,
  IPermit2,
  IEarnVault,
  INFTPermissions,
  IEarnStrategy,
  SpecialWithdrawalCode,
  StrategyId,
  IERC1271
} from "src/companion/EarnVaultCompanion.sol";
import { IDelayedWithdrawalManager } from "src/interfaces/IDelayedWithdrawalManager.sol";

contract EarnVaultCompanionTest is Test {
  IEarnVault private vault;
  IEarnStrategyRegistry private registry;
  IEarnStrategy private strategy;
  EarnVaultCompanion private companion;
  IERC20 private token;

  function setUp() public virtual {
    vault = IEarnVault(address(1));
    registry = IEarnStrategyRegistry(address(2));
    strategy = IEarnStrategy(address(3));
    companion = new EarnVaultCompanion(address(0), address(0), address(1), IPermit2(address(0)));
    token = new MyToken();
  }

  function test_permissionPermit() public {
    INFTPermissions.PositionPermissions[] memory permissions = new INFTPermissions.PositionPermissions[](0);
    uint256 deadline = block.timestamp + 1000;
    bytes memory signature = "signature";

    vm.mockCall(address(vault), abi.encodeWithSelector(INFTPermissions.permissionPermit.selector), "");
    // Make sure permissionPermit was called correctly
    vm.expectCall(
      address(vault),
      abi.encodeWithSelector(INFTPermissions.permissionPermit.selector, permissions, deadline, signature)
    );
    companion.permissionPermit(vault, permissions, deadline, signature);
  }

  function test_createPosition_native() public {
    StrategyId strategyId = StrategyId.wrap(3);
    uint256 depositAmount = 10e18;
    address depositToken = companion.NATIVE_TOKEN();
    address owner = address(9);
    INFTPermissions.PermissionSet[] memory permissions = new INFTPermissions.PermissionSet[](0);
    bytes memory validationData = "data";
    bytes memory misc = "misc";
    uint256 expectedPositionId = 4;
    uint256 expectedDeposited = 90_415;
    deal(address(this), depositAmount);

    // Simulate calls
    vm.mockCall(address(vault), abi.encodeWithSelector(IEarnVault.STRATEGY_REGISTRY.selector), abi.encode(registry));
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IEarnStrategyRegistry.getStrategy.selector, strategyId),
      abi.encode(strategy)
    );
    vm.mockCall(address(strategy), abi.encodeWithSelector(IEarnStrategy.validatePositionCreation.selector), "");
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(IEarnVault.createPosition.selector),
      abi.encode(expectedPositionId, expectedDeposited)
    );
    // Make sure approve never was called
    vm.expectCall(address(token), abi.encodeWithSelector(IERC20.approve.selector), 0);
    // Make sure strategy was called correctly
    vm.expectCall(
      address(strategy),
      abi.encodeWithSelector(IEarnStrategy.validatePositionCreation.selector, address(this), validationData)
    );
    // Make sure create was called correctly, with value
    vm.expectCall(
      address(vault),
      depositAmount,
      abi.encodeWithSelector(
        IEarnVault.createPosition.selector,
        strategyId,
        depositToken,
        depositAmount,
        owner,
        permissions,
        abi.encode(address(companion)),
        misc
      )
    );
    (uint256 positionId, uint256 assetsDeposited) = companion.createPosition{ value: depositAmount }(
      vault, strategyId, depositToken, depositAmount, owner, permissions, validationData, misc, false
    );
    assertEq(positionId, expectedPositionId);
    assertEq(assetsDeposited, expectedDeposited);
  }

  function test_createPosition_native_max() public {
    StrategyId strategyId = StrategyId.wrap(3);
    uint256 depositAmount = 10e18;
    address depositToken = companion.NATIVE_TOKEN();
    address owner = address(9);
    INFTPermissions.PermissionSet[] memory permissions = new INFTPermissions.PermissionSet[](0);
    bytes memory validationData = "data";
    bytes memory misc = "misc";
    uint256 expectedPositionId = 4;
    uint256 expectedDeposited = 90_415;
    deal(address(this), depositAmount);

    // Simulate calls
    vm.mockCall(address(vault), abi.encodeWithSelector(IEarnVault.STRATEGY_REGISTRY.selector), abi.encode(registry));
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IEarnStrategyRegistry.getStrategy.selector, strategyId),
      abi.encode(strategy)
    );
    vm.mockCall(address(strategy), abi.encodeWithSelector(IEarnStrategy.validatePositionCreation.selector), "");
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(IEarnVault.createPosition.selector),
      abi.encode(expectedPositionId, expectedDeposited)
    );
    // Make sure approve never was called
    vm.expectCall(address(token), abi.encodeWithSelector(IERC20.approve.selector), 0);
    // Make sure strategy was called correctly
    vm.expectCall(
      address(strategy),
      abi.encodeWithSelector(IEarnStrategy.validatePositionCreation.selector, address(this), validationData)
    );
    // Make sure create was called correctly, with value
    vm.expectCall(
      address(vault),
      depositAmount,
      abi.encodeWithSelector(
        IEarnVault.createPosition.selector,
        strategyId,
        depositToken,
        depositAmount,
        owner,
        permissions,
        abi.encode(address(companion)),
        misc
      )
    );
    (uint256 positionId, uint256 assetsDeposited) = companion.createPosition{ value: depositAmount }(
      vault, strategyId, depositToken, type(uint256).max, owner, permissions, validationData, misc, false
    );
    assertEq(positionId, expectedPositionId);
    assertEq(assetsDeposited, expectedDeposited);
  }

  function test_createPosition_erc20() public {
    StrategyId strategyId = StrategyId.wrap(3);
    uint256 depositAmount = 10e18;
    address depositToken = address(token);
    address owner = address(9);
    INFTPermissions.PermissionSet[] memory permissions = new INFTPermissions.PermissionSet[](0);
    bytes memory validationData = "data";
    bytes memory misc = "misc";
    uint256 expectedPositionId = 4;
    uint256 expectedDeposited = 90_415;

    // Simulate calls
    vm.mockCall(address(vault), abi.encodeWithSelector(IEarnVault.STRATEGY_REGISTRY.selector), abi.encode(registry));
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IEarnStrategyRegistry.getStrategy.selector, strategyId),
      abi.encode(strategy)
    );
    vm.mockCall(address(strategy), abi.encodeWithSelector(IEarnStrategy.validatePositionCreation.selector), "");
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(IEarnVault.createPosition.selector),
      abi.encode(expectedPositionId, expectedDeposited)
    );
    // Make sure max approve was called
    vm.expectCall(address(token), abi.encodeWithSelector(IERC20.approve.selector, address(vault), type(uint256).max));
    // Make sure strategy was called correctly
    vm.expectCall(
      address(strategy),
      abi.encodeWithSelector(IEarnStrategy.validatePositionCreation.selector, address(this), validationData)
    );
    // Make sure increase was called correctly, with no value
    vm.expectCall(
      address(vault),
      0,
      abi.encodeWithSelector(
        IEarnVault.createPosition.selector,
        strategyId,
        depositToken,
        depositAmount,
        owner,
        permissions,
        abi.encode(address(companion)),
        misc
      )
    );
    (uint256 positionId, uint256 assetsDeposited) = companion.createPosition(
      vault, strategyId, depositToken, depositAmount, owner, permissions, validationData, misc, true
    );
    assertEq(positionId, expectedPositionId);
    assertEq(assetsDeposited, expectedDeposited);
  }

  function test_increasePosition_revertWhen_NoPermission() public {
    uint256 positionId = 2;
    uint256 depositAmount = 10e18;
    address depositToken = address(token);
    // Simulate has no permissions
    vm.mockCall(address(vault), abi.encodeWithSelector(INFTPermissions.hasPermission.selector), abi.encode(false));
    vm.expectRevert(abi.encodeWithSelector(EarnVaultCompanion.UnauthorizedCaller.selector));
    companion.increasePosition(vault, positionId, depositToken, depositAmount, false);
  }

  function test_increasePosition_native() public {
    uint256 positionId = 2;
    uint256 depositAmount = 10e18;
    address depositToken = companion.NATIVE_TOKEN();
    deal(address(this), depositAmount);

    // Simulate has permissions
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(
        INFTPermissions.hasPermission.selector, positionId, address(this), companion.INCREASE_PERMISSION()
      ),
      abi.encode(true)
    );
    // Simulate increase
    vm.mockCall(address(vault), abi.encodeWithSelector(IEarnVault.increasePosition.selector), abi.encode(depositAmount));
    // Make sure approve never was called
    vm.expectCall(address(token), abi.encodeWithSelector(IERC20.approve.selector), 0);
    // Make sure increase was called correctly, with value
    vm.expectCall(
      address(vault),
      depositAmount,
      abi.encodeWithSelector(IEarnVault.increasePosition.selector, positionId, depositToken, depositAmount)
    );
    uint256 depositedAssets =
      companion.increasePosition{ value: depositAmount }(vault, positionId, depositToken, depositAmount, false);
    assertEq(depositedAssets, depositAmount);
  }

  function test_increasePosition_native_max() public {
    uint256 positionId = 2;
    uint256 depositAmount = 10e18;
    address depositToken = companion.NATIVE_TOKEN();
    deal(address(this), depositAmount);

    // Simulate has permissions
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(
        INFTPermissions.hasPermission.selector, positionId, address(this), companion.INCREASE_PERMISSION()
      ),
      abi.encode(true)
    );
    // Simulate increase
    vm.mockCall(address(vault), abi.encodeWithSelector(IEarnVault.increasePosition.selector), abi.encode(depositAmount));
    // Make sure approve never was called
    vm.expectCall(address(token), abi.encodeWithSelector(IERC20.approve.selector), 0);
    // Make sure increase was called correctly, with value
    vm.expectCall(
      address(vault),
      depositAmount,
      abi.encodeWithSelector(IEarnVault.increasePosition.selector, positionId, depositToken, depositAmount)
    );
    uint256 depositedAssets =
      companion.increasePosition{ value: depositAmount }(vault, positionId, depositToken, type(uint256).max, false);
    assertEq(depositedAssets, depositAmount);
  }

  function test_increasePosition_erc20() public {
    uint256 positionId = 2;
    uint256 depositAmount = 10e18;
    address depositToken = address(token);
    deal(address(this), depositAmount);

    // Simulate has permissions
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(
        INFTPermissions.hasPermission.selector, positionId, address(this), companion.INCREASE_PERMISSION()
      ),
      abi.encode(true)
    );
    // Simulate increase
    vm.mockCall(address(vault), abi.encodeWithSelector(IEarnVault.increasePosition.selector), abi.encode(depositAmount));
    // Make sure max approve was called
    vm.expectCall(address(token), abi.encodeWithSelector(IERC20.approve.selector, address(vault), type(uint256).max));
    // Make sure increase was called correctly, with no value
    vm.expectCall(
      address(vault),
      abi.encodeWithSelector(IEarnVault.increasePosition.selector, positionId, depositToken, depositAmount)
    );
    uint256 depositedAssets = companion.increasePosition(vault, positionId, depositToken, depositAmount, true);
    assertEq(depositedAssets, depositAmount);
  }

  function test_withdraw_revertWhen_NoPermission() public {
    // Simulate has no permissions
    vm.mockCall(address(vault), abi.encodeWithSelector(INFTPermissions.hasPermission.selector), abi.encode(false));
    vm.expectRevert(abi.encodeWithSelector(EarnVaultCompanion.UnauthorizedCaller.selector));
    companion.withdraw(vault, 2, new address[](0), new uint256[](0), address(1));
  }

  function test_withdraw() public {
    uint256 positionId = 2;
    address recipient = address(1);
    address[] memory tokens = new address[](1);
    uint256[] memory toWithdraw = new uint256[](1);
    uint256[] memory expectedWithdrawn = new uint256[](1);
    expectedWithdrawn[0] = 12_345;
    IEarnStrategy.WithdrawalType[] memory expectedTypes = new IEarnStrategy.WithdrawalType[](1);

    // Simulate has permissions
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(
        INFTPermissions.hasPermission.selector, positionId, address(this), companion.WITHDRAW_PERMISSION()
      ),
      abi.encode(true)
    );
    // Simulate withdraw
    vm.mockCall(
      address(vault), abi.encodeWithSelector(IEarnVault.withdraw.selector), abi.encode(expectedWithdrawn, expectedTypes)
    );
    // Make sure withdraw was called correctly
    vm.expectCall(
      address(vault), abi.encodeWithSelector(IEarnVault.withdraw.selector, positionId, tokens, toWithdraw, recipient)
    );
    (uint256[] memory withdrawn, IEarnStrategy.WithdrawalType[] memory types) =
      companion.withdraw(vault, positionId, tokens, toWithdraw, recipient);
    assertEq(withdrawn, expectedWithdrawn);
    assertEq(types.length, expectedTypes.length);
    assertTrue(types[0] == expectedTypes[0]);
  }

  function test_claimDelayedWithdraw() public {
    uint256 positionId = 2;
    address recipient = address(1);
    address tokenToWithdraw = address(34);
    uint256 expectedWithdrawn = 12_345;
    uint256 expectedPending = 10_000;

    IDelayedWithdrawalManager manager;

    // Simulate has permissions
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(
        INFTPermissions.hasPermission.selector, positionId, address(this), companion.WITHDRAW_PERMISSION()
      ),
      abi.encode(true)
    );

    // Simulate manager's vault
    vm.mockCall(address(manager), abi.encodeWithSelector(IDelayedWithdrawalManager.VAULT.selector), abi.encode(vault));

    // Simulate withdraw
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IDelayedWithdrawalManager.withdraw.selector, positionId, tokenToWithdraw, recipient),
      abi.encode(expectedWithdrawn, expectedPending)
    );

    (uint256 withdrawn, uint256 pendingFunds) =
      companion.claimDelayedWithdraw(manager, positionId, tokenToWithdraw, recipient);
    assertEq(withdrawn, expectedWithdrawn);
    assertEq(pendingFunds, expectedPending);
  }

  function test_claimDelayedWithdraw_revertWhen_NoPermission() public {
    uint256 positionId = 2;
    address recipient = address(1);
    address tokenToWithdraw = address(34);

    IDelayedWithdrawalManager manager;
    vm.mockCall(address(manager), abi.encodeWithSelector(IDelayedWithdrawalManager.VAULT.selector), abi.encode(vault));

    // Simulate has no permissions
    vm.mockCall(address(vault), abi.encodeWithSelector(INFTPermissions.hasPermission.selector), abi.encode(false));
    vm.expectRevert(abi.encodeWithSelector(EarnVaultCompanion.UnauthorizedCaller.selector));
    companion.claimDelayedWithdraw(manager, positionId, tokenToWithdraw, recipient);
  }

  function test_specialWithdraw_revertWhen_NoPermission() public {
    // Simulate has no permissions
    vm.mockCall(address(vault), abi.encodeWithSelector(INFTPermissions.hasPermission.selector), abi.encode(false));
    vm.expectRevert(abi.encodeWithSelector(EarnVaultCompanion.UnauthorizedCaller.selector));
    companion.specialWithdraw(vault, 2, SpecialWithdrawalCode.wrap(1), new uint256[](0), "", address(1));
  }

  function test_specialWithdraw() public {
    uint256 positionId = 2;
    SpecialWithdrawalCode code = SpecialWithdrawalCode.wrap(10);
    bytes memory data = "data";
    address recipient = address(1);
    uint256[] memory toWithdraw = new uint256[](1);
    toWithdraw[0] = 256;

    address[] memory expectedTokens = new address[](1);
    expectedTokens[0] = address(token);
    uint256[] memory expectedBalanceChanges = new uint256[](1);
    expectedBalanceChanges[0] = 67_890;
    address[] memory expectedWithdrawnTokens = new address[](1);
    expectedWithdrawnTokens[0] = address(token);
    uint256[] memory expectedWithdrawnAmounts = new uint256[](1);
    expectedWithdrawnAmounts[0] = 12_345;
    bytes memory expectedResult = "result";

    // Simulate has permissions
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(
        INFTPermissions.hasPermission.selector, positionId, address(this), companion.WITHDRAW_PERMISSION()
      ),
      abi.encode(true)
    );
    // Simulate special withdrawal
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(IEarnVault.specialWithdraw.selector),
      abi.encode(
        expectedTokens, expectedBalanceChanges, expectedWithdrawnTokens, expectedWithdrawnAmounts, expectedResult
      )
    );
    // Make sure special withdrawal was called correctly
    vm.expectCall(
      address(vault),
      abi.encodeWithSelector(IEarnVault.specialWithdraw.selector, positionId, code, toWithdraw, data, recipient)
    );
    (
      address[] memory tokens,
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    ) = companion.specialWithdraw(vault, positionId, code, toWithdraw, data, recipient);
    assertEq(tokens, expectedTokens);
    assertEq(balanceChanges, expectedBalanceChanges);
    assertEq(actualWithdrawnTokens, expectedWithdrawnTokens);
    assertEq(actualWithdrawnAmounts, expectedWithdrawnAmounts);
    assertEq(result, expectedResult);
  }

  function test_isValidSignature_valid() public {
    bytes32 hash;
    bytes memory signature = abi.encode(address(companion));
    bytes4 result = companion.isValidSignature(hash, signature);
    assertEq(result, IERC1271.isValidSignature.selector);
  }

  function test_isValidSignature_invalid() public {
    bytes32 hash;
    bytes memory signature = abi.encode(10);
    bytes4 result = companion.isValidSignature(hash, signature);
    assertNotEq(result, IERC1271.isValidSignature.selector);
  }
}

contract MyToken is ERC20 {
  constructor() ERC20("Name", "SYM") { }
}
