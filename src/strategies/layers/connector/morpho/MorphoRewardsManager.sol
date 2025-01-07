// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { IUniversalRewardsDistributor } from "./IUniversalRewardsDistributor.sol";
import { MorphoConnector } from "./MorphoConnector.sol";

/**
 * @notice This manager is in charge of claiming and configuring Morpho rewards for Balmy strategies. While anyone can
 *         claim rewards, only users with the MANAGE_CONFIGURATION_ROLE can configure them. This is because
 *         configuration can affect the rate emission, and exposing this to the public could lead to abuse.
 */
contract MorphoRewardsManager is AccessControlDefaultAdminRules {
  struct Claims {
    IUniversalRewardsDistributor rewardsDistributor;
    MorphoConnector connector;
    Claim[] claims;
  }

  struct Claim {
    address rewardToken;
    uint256 claimable;
    bytes32[] proof;
  }

  struct Configuration {
    MorphoConnector connector;
    address[] tokens;
  }

  /// @notice The role that allows configuration of rewards
  bytes32 public constant MANAGE_CONFIGURATION_ROLE = keccak256("MANAGE_CONFIGURATION_ROLE");

  constructor(address owner_, address[] memory initialAdmins) AccessControlDefaultAdminRules(3 days, owner_) {
    for (uint256 i = 0; i < initialAdmins.length; ++i) {
      _grantRole(MANAGE_CONFIGURATION_ROLE, initialAdmins[i]);
    }
  }

  /// @notice Claims rewards for a list of strategies
  function claimRewards(Claims[] calldata allClaims) external {
    for (uint256 i = 0; i < allClaims.length; ++i) {
      _claimTokens(allClaims[i]);
    }
  }

  /// @notice Configures rewards for a list of strategies
  function configureRewards(
    Configuration[] calldata configurations,
    uint256 duration
  )
    external
    onlyRole(MANAGE_CONFIGURATION_ROLE)
  {
    for (uint256 i = 0; i < configurations.length; ++i) {
      // slither-disable-next-line calls-loop
      configurations[i].connector.configureRewards(configurations[i].tokens, duration);
    }
  }

  /// @notice Claims and configured rewards for a list of strategies
  function claimAndConfigureRewards(
    Claims[] calldata allClaims,
    uint256 duration
  )
    external
    onlyRole(MANAGE_CONFIGURATION_ROLE)
  {
    for (uint256 i = 0; i < allClaims.length; ++i) {
      address[] memory tokens = _claimTokens(allClaims[i]);
      // slither-disable-next-line calls-loop
      allClaims[i].connector.configureRewards(tokens, duration);
    }
  }

  function _claimTokens(Claims calldata claims) internal returns (address[] memory tokens) {
    tokens = new address[](claims.claims.length);
    for (uint256 i = 0; i < claims.claims.length; ++i) {
      Claim memory claim_ = claims.claims[i];
      // slither-disable-next-line unused-return,calls-loop
      claims.rewardsDistributor.claim(address(claims.connector), claim_.rewardToken, claim_.claimable, claim_.proof);
      tokens[i] = claim_.rewardToken;
    }
  }
}
