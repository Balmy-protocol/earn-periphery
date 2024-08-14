// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IPermit2 } from "../interfaces/external/IPermit2.sol";

/**
 * @notice This contract will work as base companion for all our contracts. It will extend the capabilities of our
 *         companion contracts so that they can execute multicalls, swaps, and more
 * @dev All public functions are payable, so that they can be multicalled together with other payable functions when
 *      msg.value > 0
 */
abstract contract BaseCompanion is Ownable2Step {
  using SafeERC20 for IERC20;
  using Address for address;
  using Address for address payable;

  /// @notice The address used to represent the native token
  address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /// @notice Returns the address of the Permit2 contract
  // slither-disable-start naming-convention
  // solhint-disable-next-line var-name-mixedcase
  IPermit2 public immutable PERMIT2;
  // slither-disable-end naming-convention

  /// @notice The address of the swapper
  // slither-disable-next-line immutable-states TODO: remove once used
  address public swapper;

  /// @notice The address of the allowance target
  // slither-disable-next-line immutable-states TODO: remove once used
  address public allowanceTarget;

  constructor(address swapper_, address allowanceTarget_, address owner_, IPermit2 permit2) Ownable(owner_) {
    swapper = swapper_;
    allowanceTarget = allowanceTarget_;
    PERMIT2 = permit2;
  }

  // slither-disable-next-line locked-ether TODO: remove once send function is added
  receive() external payable { }
}
