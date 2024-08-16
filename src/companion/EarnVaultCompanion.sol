// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
  StrategyId,
  IEarnVault,
  INFTPermissions,
  IEarnStrategy,
  SpecialWithdrawalCode
} from "@balmy/earn-core/interfaces/IEarnVault.sol";
import { IPermit2 } from "../interfaces/external/IPermit2.sol";
import { BaseCompanion } from "./BaseCompanion.sol";

contract EarnVaultCompanion is BaseCompanion, IERC1271 {
  error UnauthorizedCaller();

  using SafeERC20 for IERC20;

  INFTPermissions.Permission public constant INCREASE_PERMISSION = INFTPermissions.Permission.wrap(0);
  INFTPermissions.Permission public constant WITHDRAW_PERMISSION = INFTPermissions.Permission.wrap(1);

  constructor(
    address swapper_,
    address allowanceTarget_,
    address owner_,
    IPermit2 permit2
  )
    BaseCompanion(swapper_, allowanceTarget_, owner_, permit2)
  { }

  function permissionPermit(
    IEarnVault vault,
    INFTPermissions.PositionPermissions[] calldata permissions,
    uint256 deadline,
    bytes calldata signature
  )
    external
    payable
  {
    vault.permissionPermit(permissions, deadline, signature);
  }

  function createPosition(
    IEarnVault vault,
    StrategyId strategyId,
    address depositToken,
    uint256 depositAmount,
    address owner_,
    INFTPermissions.PermissionSet[] calldata permissions,
    bytes calldata strategyValidationData,
    bytes calldata misc,
    bool maxApprove
  )
    external
    payable
    returns (uint256 positionId, uint256 assetsDeposited)
  {
    // Validate position creation against strategy
    IEarnStrategy strategy = vault.STRATEGY_REGISTRY().getStrategy(strategyId);
    strategy.validatePositionCreation(msg.sender, strategyValidationData);

    if (maxApprove) {
      IERC20(depositToken).forceApprove(address(vault), type(uint256).max);
    }

    // We will pass the strategy's address as the validation data so that we can verify it in `isValidSignature`
    bytes memory newValidationData = abi.encode(strategy);
    uint256 value = depositToken == NATIVE_TOKEN ? depositAmount : 0;
    // slither-disable-next-line arbitrary-send-eth,unused-return (not sure why this is necessary)
    return vault.createPosition{ value: value }({
      strategyId: strategyId,
      depositToken: depositToken,
      depositAmount: depositAmount,
      owner: owner_,
      permissions: permissions,
      strategyValidationData: newValidationData,
      misc: misc
    });
  }

  function increasePosition(
    IEarnVault vault,
    uint256 positionId,
    address depositToken,
    uint256 depositAmount,
    bool maxApprove
  )
    external
    payable
    verifyPermission(vault, positionId, INCREASE_PERMISSION)
    returns (uint256 assetsDeposited)
  {
    if (maxApprove) {
      IERC20(depositToken).forceApprove(address(vault), type(uint256).max);
    }
    uint256 value = depositToken == NATIVE_TOKEN ? depositAmount : 0;
    // slither-disable-next-line arbitrary-send-eth
    return vault.increasePosition{ value: value }({
      positionId: positionId,
      depositToken: depositToken,
      depositAmount: depositAmount
    });
  }

  function withdraw(
    IEarnVault vault,
    uint256 positionId,
    address[] calldata tokensToWithdraw,
    uint256[] calldata intendedWithdraw,
    address recipient
  )
    external
    payable
    verifyPermission(vault, positionId, WITHDRAW_PERMISSION)
    returns (uint256[] memory, IEarnStrategy.WithdrawalType[] memory)
  {
    // slither-disable-next-line unused-return (not sure why this is necessary)
    return vault.withdraw({
      positionId: positionId,
      tokensToWithdraw: tokensToWithdraw,
      intendedWithdraw: intendedWithdraw,
      recipient: recipient
    });
  }

  function specialWithdraw(
    IEarnVault vault,
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    bytes calldata withdrawalData,
    address recipient
  )
    external
    payable
    verifyPermission(vault, positionId, WITHDRAW_PERMISSION)
    returns (
      address[] memory tokens,
      uint256[] memory withdrawn,
      IEarnStrategy.WithdrawalType[] memory withdrawalTypes,
      bytes memory result
    )
  {
    // slither-disable-next-line unused-return (not sure why this is necessary)
    return vault.specialWithdraw({
      positionId: positionId,
      withdrawalCode: withdrawalCode,
      withdrawalData: withdrawalData,
      recipient: recipient
    });
  }

  modifier verifyPermission(IEarnVault vault, uint256 positionId, INFTPermissions.Permission _permission) {
    if (!vault.hasPermission(positionId, msg.sender, _permission)) revert UnauthorizedCaller();
    _;
  }

  function isValidSignature(bytes32, bytes memory signature) external view override returns (bytes4) {
    // We will only consider a signature valid if it is the address of the sender
    address strategy = abi.decode(signature, (address));
    return strategy == msg.sender ? IERC1271.isValidSignature.selector : bytes4(0);
  }
}
