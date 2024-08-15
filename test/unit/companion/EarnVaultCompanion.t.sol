// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Test } from "forge-std/Test.sol";
import {
  EarnVaultCompanion,
  IPermit2,
  IEarnVault,
  INFTPermissions,
  IEarnStrategy
} from "src/companion/EarnVaultCompanion.sol";

contract EarnVaultCompanionTest is Test {
  IEarnVault private vault;
  EarnVaultCompanion private companion;
  IERC20 private token;

  function setUp() public virtual {
    vault = IEarnVault(address(1));
    companion = new EarnVaultCompanion(address(0), address(0), address(1), IPermit2(address(0)));
    token = new MyToken();
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
}

contract MyToken is ERC20 {
  constructor() ERC20("Name", "SYM") { }
}
