// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { LibComet, ICometRewards, ICERC20 } from "src/strategies/layers/connector/compound-v3/LibComet.sol";

abstract contract LibCometTest is Test {
  function _chain() internal pure virtual returns (string memory);
  function _accounts() internal pure virtual returns (address[] memory);
  function _blocks() internal pure virtual returns (uint256 from, uint256 to, uint256 amount);
  function _comets() internal pure virtual returns (address[] memory);
  function _rewards() internal pure virtual returns (address);

  function test_getRewardsOwed() public {
    uint256[] memory blocks = _calculateBlocks();
    address[] memory comets = _comets();
    address[] memory accounts = _accounts();
    ICometRewards cometRewards = ICometRewards(_rewards());

    for (uint256 i = 0; i < blocks.length; i++) {
      // We reset the fork for each block number, to sure all state is cleaned up
      // We set the fork to be able to read the current block number
      vm.createSelectFork(_chain(), blocks[i]);
      for (uint256 j = 0; j < comets.length; j++) {
        ICERC20 comet = ICERC20(comets[j]);
        // We'll first perform our view calls, and then we'll perform the non-payable calls
        ICometRewards.RewardOwed[] memory allRewardsOwed = new ICometRewards.RewardOwed[](accounts.length);
        for (uint256 k = 0; k < accounts.length; k++) {
          (address rewardToken, uint256 rewardsOwed) = LibComet.getRewardsOwed(cometRewards, comet, accounts[k]);
          allRewardsOwed[k] = ICometRewards.RewardOwed({ token: rewardToken, owed: rewardsOwed });
        }

        for (uint256 k = 0; k < accounts.length; k++) {
          ICometRewards.RewardOwed memory rewardOwed;
          try cometRewards.getRewardOwed(address(comet), accounts[k]) returns (ICometRewards.RewardOwed memory result) {
            rewardOwed = result;
          } catch {
            rewardOwed = ICometRewards.RewardOwed({ token: address(0), owed: 0 });
          }
          assertEq(rewardOwed.token, allRewardsOwed[k].token);
          assertEq(rewardOwed.owed, allRewardsOwed[k].owed);
        }
      }
    }
  }

  function _calculateBlocks() private pure returns (uint256[] memory) {
    (uint256 from, uint256 to, uint256 amount) = _blocks();
    uint256[] memory blocks = new uint256[](amount);
    uint256 step = (to - from) / blocks.length;
    for (uint256 i = 0; i < blocks.length; i++) {
      blocks[i] = from + (step * i);
    }
    return blocks;
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

  function _blocks() internal pure override returns (uint256 from, uint256 to, uint256 amount) {
    from = 21_000_000;
    to = 21_695_945;
    amount = 5;
  }

  function _comets() internal pure override returns (address[] memory comets) {
    comets = new address[](4);
    comets[0] = 0xc3d688B66703497DAA19211EEdff47f25384cdc3; // cUSDCv3
    comets[1] = 0xA17581A9E3356d9A858b789D68B4d866e593aE94; // cWETHv3
    comets[2] = 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840; // cUSDTv3
    comets[3] = 0x3D0bb1ccaB520A66e607822fC55BC921738fAFE3; // cwstETHv3
  }
}

contract LibCometTestArbitrum is LibCometTest {
  function _chain() internal pure override returns (string memory) {
    return "arbitrum_one";
  }

  function _rewards() internal pure override returns (address) {
    return 0x88730d254A2f7e6AC8388c3198aFd694bA9f7fae;
  }

  function _accounts() internal pure override returns (address[] memory accounts) {
    accounts = new address[](3);
    accounts[0] = 0xD9bd04Be0eCe9095580756db19C81D9700B4f2fe;
    accounts[1] = 0x44377949bcf05704A78801639668f9F5B0307951;
    accounts[2] = 0xAbfEdf8BAce3EC43051826315c6b65e3D8153B84;
  }

  function _blocks() internal pure override returns (uint256 from, uint256 to, uint256 amount) {
    from = 200_000_000;
    to = 298_855_593;
    amount = 5;
  }

  function _comets() internal pure override returns (address[] memory comets) {
    comets = new address[](3);
    comets[0] = 0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf; // cUSDCv3
    comets[1] = 0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486; // cWETHv3
    comets[2] = 0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07; // cUSDTv3
  }
}

contract LibCometTestBase is LibCometTest {
  function _chain() internal pure override returns (string memory) {
    return "base";
  }

  function _rewards() internal pure override returns (address) {
    return 0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;
  }

  function _accounts() internal pure override returns (address[] memory accounts) {
    accounts = new address[](3);
    accounts[0] = 0x011b0a055E02425461A1ae95B30F483c4fF05bE7;
    accounts[1] = 0x3eC6f5793ce4B90F2B7381516c91ACc4cf169553;
    accounts[2] = 0x2b4eF83aeE6bb3Dd5253dAa7d0756Ef5bD95f40f;
  }

  function _blocks() internal pure override returns (uint256 from, uint256 to, uint256 amount) {
    from = 20_500_000;
    to = 25_475_763;
    amount = 5;
  }

  function _comets() internal pure override returns (address[] memory comets) {
    comets = new address[](3);
    comets[0] = 0x784efeB622244d2348d4F2522f8860B96fbEcE89; // cAEROv3
    comets[1] = 0x6103DB328d4864dc16BD2F0eE1B9A92e3F87f915; // cWETHv3
    comets[2] = 0xb125E6687d4313864e53df431d5425969c15Eb2F; // cUSDSCv3
  }
}

contract LibCometTestOptimism is LibCometTest {
  function _chain() internal pure override returns (string memory) {
    return "optimism";
  }

  function _rewards() internal pure override returns (address) {
    return 0x443EA0340cb75a160F31A440722dec7b5bc3C2E9;
  }

  function _accounts() internal pure override returns (address[] memory accounts) {
    accounts = new address[](3);
    accounts[0] = 0xd0B37FB296D0548E7CC9047A49F4C5C809B4f6Da;
    accounts[1] = 0xC459a8D257aa70678FAb1032A437b8B0cA8B2613;
    accounts[2] = 0xC459a8D257aa70678FAb1032A437b8B0cA8B2613;
  }

  function _blocks() internal pure override returns (uint256 from, uint256 to, uint256 amount) {
    from = 125_500_000;
    to = 131_071_059;
    amount = 5;
  }

  function _comets() internal pure override returns (address[] memory comets) {
    comets = new address[](3);
    comets[0] = 0x2e44e174f7D53F0212823acC11C01A11d58c5bCB; // cUSDCv3
    comets[1] = 0x995E394b8B2437aC8Ce61Ee0bC610D617962B214; // cUSDTv3
    comets[2] = 0xE36A30D249f7761327fd973001A32010b521b6Fd; // cWETHv3
  }
}
