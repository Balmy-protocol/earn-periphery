// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Test } from "forge-std/Test.sol";
import { BaseCompanion, IPermit2, Ownable } from "src/companion/BaseCompanion.sol";

contract BaseCompanionTest is Test {
  event SwapperChanged(address newSwapper, address newAllowanceTarget);

  BaseCompanionInstance private companion;
  Swapper private swapper;
  address private owner = address(1);
  IPermit2 private permit2 = new Permit2();
  IERC20 private token;

  function setUp() public virtual {
    swapper = new Swapper();
    companion = new BaseCompanionInstance(address(swapper), address(swapper), owner, permit2);
    token = new MyToken();
  }

  function test_constructor() public {
    assertEq(companion.swapper(), address(swapper));
    assertEq(companion.allowanceTarget(), address(swapper));
    assertEq(companion.owner(), owner);
    assertEq(address(companion.PERMIT2()), address(permit2));
    assertEq(companion.NATIVE_TOKEN(), address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));
  }

  function test_balanceOf_native() public {
    uint256 amount = 10e18;
    deal(address(companion), amount);
    assertEq(companion.balanceOf(companion.NATIVE_TOKEN()), amount);
  }

  function test_balanceOf_erc20() public {
    uint256 amount = 10e18;
    deal(address(token), address(companion), amount);
    assertEq(companion.balanceOf(address(token)), amount);
  }

  function test_takeFromCaller() public {
    uint256 amount = 10e18;
    address recipient = address(1);

    deal(address(token), address(this), amount);
    token.approve(address(companion), amount);

    companion.takeFromCaller(token, amount, recipient);
    assertEq(token.balanceOf(address(this)), 0);
    assertEq(token.balanceOf(recipient), amount);
  }

  function test_permitTakeFromCaller() public {
    address token_ = address(token);
    uint256 amount = 10e18;
    uint256 nonce = 11_223_344_556_677;
    uint256 deadline = 1_234_567_890;
    bytes memory signature = "my signature";
    address recipient = address(1);

    vm.expectCall(
      address(companion.PERMIT2()),
      abi.encodeWithSelector(
        0x30f28b7a, // This is the selector
        IPermit2.PermitTransferFrom({
          permitted: IPermit2.TokenPermissions({ token: token_, amount: amount }),
          nonce: nonce,
          deadline: deadline
        }),
        IPermit2.SignatureTransferDetails({ to: recipient, requestedAmount: amount }),
        address(this),
        signature
      )
    );
    companion.permitTakeFromCaller(token_, amount, nonce, deadline, signature, recipient);
  }

  function test_batchPermitTakeFromCaller() public {
    address token_ = address(token);
    uint256 amount = 10e18;
    uint256 nonce = 11_223_344_556_677;
    uint256 deadline = 1_234_567_890;
    bytes memory signature = "my signature";
    address recipient = address(1);

    IPermit2.TokenPermissions[] memory tokens = new IPermit2.TokenPermissions[](1);
    tokens[0] = IPermit2.TokenPermissions({ token: token_, amount: amount });

    IPermit2.SignatureTransferDetails[] memory details = new IPermit2.SignatureTransferDetails[](1);
    details[0] = IPermit2.SignatureTransferDetails({ to: recipient, requestedAmount: tokens[0].amount });

    vm.expectCall(
      address(companion.PERMIT2()),
      abi.encodeWithSelector(
        0xedd9444b, // This is the selector
        IPermit2.PermitBatchTransferFrom({ permitted: tokens, nonce: nonce, deadline: deadline }),
        details,
        address(this),
        signature
      )
    );
    companion.batchPermitTakeFromCaller(tokens, nonce, deadline, signature, recipient);
  }

  function test_sendToRecipient_native() public {
    uint256 totalAmount = 10e18;
    uint256 amount = totalAmount / 2;
    address recipient = address(1);
    uint256 recipientInitialBalance = recipient.balance;
    deal(address(companion), totalAmount);

    companion.sendToRecipient(companion.NATIVE_TOKEN(), amount, recipient);
    assertEq(address(companion).balance, totalAmount - amount);
    assertEq(recipient.balance - recipientInitialBalance, amount);
  }

  function test_sendToRecipient_max() public {
    uint256 amount = 10e18;
    address recipient = address(1);
    deal(address(token), address(companion), amount);

    companion.sendToRecipient(address(token), type(uint256).max, recipient);
    assertEq(token.balanceOf(address(companion)), 0);
    assertEq(token.balanceOf(recipient), amount);
  }

  function test_sendToRecipient_zeroAddressRecipient() public {
    uint256 amount = 10e18;
    deal(address(token), address(companion), amount);

    companion.sendToRecipient(address(token), amount, address(0));
    assertEq(token.balanceOf(address(companion)), 0);
    assertEq(token.balanceOf(address(this)), amount);
  }

  function test_sendToRecipient_zeroAmount() public {
    companion.sendToRecipient(address(token), type(uint256).max, address(0));

    // Make sure it never was called
    vm.expectCall(address(token), abi.encodeWithSelector(IERC20.transfer.selector), 0);
  }

  function test_runSwap() public {
    uint256 amount = 10e18;
    deal(address(this), amount);

    bytes memory result =
      companion.runSwap{ value: amount }(address(0), amount, abi.encodeWithSelector(swapper.swap.selector));
    uint256 resultUint = abi.decode(result, (uint256));

    assertEq(resultUint, amount);
    assertEq(address(swapper).balance, amount);
  }

  function test_runSwap_withAllowanceToken() public {
    vm.expectCall(address(token), abi.encodeWithSelector(token.approve.selector, address(swapper), type(uint256).max));
    bytes memory result = companion.runSwap(address(token), 0, abi.encodeWithSelector(swapper.swap.selector));
    uint256 resultUint = abi.decode(result, (uint256));

    assertEq(resultUint, 0);
    assertEq(address(swapper).balance, 0);
  }

  function test_setSwapper() public {
    address newSwapper = address(1);
    address newAllowanceTarget = address(2);
    vm.expectEmit();
    emit SwapperChanged(newSwapper, newAllowanceTarget);
    vm.prank(owner);
    companion.setSwapper(newSwapper, newAllowanceTarget);
    assertEq(companion.swapper(), newSwapper);
    assertEq(companion.allowanceTarget(), newAllowanceTarget);
  }

  function test_setSwapper_revertWhen_notOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    companion.setSwapper(address(1), address(1));
  }
}

contract BaseCompanionInstance is BaseCompanion {
  constructor(
    address swapper_,
    address allowanceTarget_,
    address owner_,
    IPermit2 permit2
  )
    BaseCompanion(swapper_, allowanceTarget_, owner_, permit2)
  { }
}

contract Swapper {
  function swap() external payable returns (uint256) {
    return msg.value;
  }
}

contract Permit2 is IPermit2 {
  // solhint-disable no-empty-blocks
  function DOMAIN_SEPARATOR() external view override returns (bytes32) { }

  // solhint-disable no-empty-blocks
  function permitTransferFrom(
    PermitTransferFrom calldata permit,
    SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes calldata signature
  )
    external
  { }

  // solhint-disable no-empty-blocks
  function permitTransferFrom(
    PermitBatchTransferFrom memory permit,
    SignatureTransferDetails[] calldata transferDetails,
    address owner,
    bytes calldata signature
  )
    external
  { }
}

contract MyToken is ERC20 {
  constructor() ERC20("Name", "SYM") { }
}
