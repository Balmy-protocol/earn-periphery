// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20MintableBurnableMock is ERC20 {
  constructor() ERC20("ERC20Mock", "E20M") { }

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external {
    _burn(account, amount);
  }

}
