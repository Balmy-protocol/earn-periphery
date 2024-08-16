// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IEarnVault, INFTPermissions } from "@balmy/earn-core/interfaces/IEarnVault.sol";
import { IPermit2 } from "../interfaces/external/IPermit2.sol";
import { BaseCompanion } from "./BaseCompanion.sol";

contract EarnVaultCompanion is BaseCompanion {
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

  modifier verifyPermission(IEarnVault vault, uint256 positionId, INFTPermissions.Permission _permission) {
    if (!vault.hasPermission(positionId, msg.sender, _permission)) revert UnauthorizedCaller();
    _;
  }
}
