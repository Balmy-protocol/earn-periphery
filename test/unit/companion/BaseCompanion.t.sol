// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Test } from "forge-std/Test.sol";
import { BaseCompanion, IPermit2 } from "src/companion/BaseCompanion.sol";

contract BaseCompanionTest is Test {
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
  // solhint-disable no-empty-blocks
  function swap(address tokenIn, address tokenOut) external payable { }
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
    override
  { }

  // solhint-disable no-empty-blocks
  function permitTransferFrom(
    PermitBatchTransferFrom memory permit,
    SignatureTransferDetails[] calldata transferDetails,
    address owner,
    bytes calldata signature
  )
    external
    override
  { }
}

contract MyToken is ERC20 {
  constructor() ERC20("Name", "SYM") { }
}
