// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { LibComet, ICometRewards, ICERC20 } from "src/strategies/layers/connector/compound-v3/LibComet.sol";

abstract contract LibCometTest is Test {
  function _chain() internal pure virtual returns (string memory);
  function _accounts() internal pure virtual returns (address[] memory);
  function _blocks() internal pure virtual returns (uint256[] memory);
  function _comets() internal pure virtual returns (address[] memory);
  function _rewards() internal pure virtual returns (address);

  function test_getRewardsOwed() public {
    uint256[] memory blocks = _blocks();
    address[] memory comets = _comets();
    address[] memory accounts = _accounts();
    ICometRewards cometRewards = ICometRewards(_rewards());

    for (uint256 i = 0; i < blocks.length; i++) {
      // We reset the fork for each block number, to make sure all state is cleaned up
      vm.selectFork(vm.createFork(vm.rpcUrl(_chain()), blocks[i]));
      for (uint256 j = 0; j < comets.length; j++) {
        ICERC20 comet = ICERC20(comets[j]);
        // We'll first perform or view calls, and then we'll perform the non-payable calls
        ICometRewards.RewardOwed[] memory allRewardsOwed = new ICometRewards.RewardOwed[](accounts.length);
        for (uint256 k = 0; k < accounts.length; k++) {
          (address rewardToken, uint256 rewardsOwed) = LibComet.getRewardsOwed(cometRewards, comet, accounts[k]);
          allRewardsOwed[k] = ICometRewards.RewardOwed({ token: rewardToken, owed: rewardsOwed });
        }

        for (uint256 k = 0; k < accounts.length; k++) {
          ICometRewards.RewardOwed memory rewardOwed = cometRewards.getRewardOwed(address(comet), accounts[k]);
          assertEq(rewardOwed.token, allRewardsOwed[k].token);
          assertEq(rewardOwed.owed, allRewardsOwed[k].owed);
        }
      }
    }
  }
}


contract LibCometTestEthereum is LibCometTest {
  function _chain() internal pure override returns (string memory) {
    return "mainnet";
  }

  function _rewards() internal pure override returns (address) {
    return 0x1B0e765F6224C21223AeA2af16c1C46E38885a40;
  }

  function _accounts() internal pure override returns (address[] memory accounts) {
    accounts = new address[](4);
    accounts[0] = 0x7f714b13249BeD8fdE2ef3FBDfB18Ed525544B03;
    accounts[1] = 0x741AA7CFB2c7bF2A1E7D4dA2e3Df6a56cA4131F3;
    accounts[2] = 0xEB74EC1d4C1DAB412D5d6674F6833FD19d3118Ce;
    accounts[3] = 0xDfb0CD3AD4254140622CfDB1bD21159d10961593;
  }

  function _blocks() internal pure override returns (uint256[] memory blocks) {
    blocks = new uint256[](10);
    blocks[0] = 20_683_535;
    blocks[1] = 20_763_535;
    blocks[2] = 20_843_535;
    blocks[3] = 20_923_535;
    blocks[4] = 21_003_535;
    blocks[5] = 21_083_535;
    blocks[6] = 21_163_535;
    blocks[7] = 21_243_535;
    blocks[8] = 21_323_535;
    blocks[9] = 21_403_535;
  }

  function _comets() internal pure override returns (address[] memory comets) {
    comets = new address[](4);
    comets[0] = 0xc3d688B66703497DAA19211EEdff47f25384cdc3; // cUSDCv3
    comets[1] = 0xA17581A9E3356d9A858b789D68B4d866e593aE94; // cWETHv3
    comets[2] = 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840; // cUSDTv3
    comets[3] = 0x3D0bb1ccaB520A66e607822fC55BC921738fAFE3; // cwstETHv3

  }
}