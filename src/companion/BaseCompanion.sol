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

  /**
   * @notice Returns the contract's balance of the given token
   * @dev We are making this public because it could help with simulations
   * @param token The token to check
   * @return The balance of the token
   */
  function balanceOf(address token) public view returns (uint256) {
    return token == NATIVE_TOKEN ? address(this).balance : IERC20(token).balanceOf(address(this));
  }

  ////////////////////////////////////////////////////////////////////////
  ///////////////////////////// TAKE FUNCTIONS ///////////////////////////
  ////////////////////////////////////////////////////////////////////////

  /**
   * @notice Takes the given amount of tokens from the caller and transfers it to the recipient
   * @param token The token to take
   * @param amount The amount to take
   * @param recipient The transfer's recipient
   */
  function takeFromCaller(IERC20 token, uint256 amount, address recipient) external payable {
    token.safeTransferFrom(msg.sender, recipient, amount);
  }

  ////////////////////////////////////////////////////////////////////////
  ///////////////////////////// SEND FUNCTIONS ///////////////////////////
  ////////////////////////////////////////////////////////////////////////

  /**
   * @notice Sends the specified amount of the given token to the recipient
   * @param token The token to transfer
   * @param amount The amount to transfer. If it's max(uint256), then all balance will be sent
   * @param recipient The recipient of the token balance. If it's address(0), then the sender will receive the tokens
   */
  function sendToRecipient(address token, uint256 amount, address recipient) public payable {
    if (amount == type(uint256).max) {
      amount = balanceOf(token);
    }
    if (amount == 0) {
      return;
    }
    if (recipient == address(0)) {
      recipient = msg.sender;
    }
    if (token == NATIVE_TOKEN) {
      payable(recipient).sendValue(amount);
    } else {
      IERC20(token).safeTransfer(recipient, amount);
    }
  }
}
