// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import {
  IEarnStrategy,
  StrategyId,
  IEarnVault,
  IEarnStrategyRegistry,
  SpecialWithdrawalCode
} from "../../../src/interfaces/IEarnStrategy.sol";

/// @notice An implementation of IEarnStrategy that always reverts
contract EarnStrategyDead is IEarnStrategy {
  error NotImplemented();

  // solhint-disable-next-line no-empty-blocks
  receive() external payable virtual { }

  function asset() external view virtual returns (address) {
    revert NotImplemented();
  }

  function supportedWithdrawals() external view virtual returns (WithdrawalType[] memory) {
    revert NotImplemented();
  }

  function totalBalances() external view virtual returns (address[] memory, uint256[] memory) {
    revert NotImplemented();
  }

  function deposited(address, uint256) external payable virtual returns (uint256) {
    revert NotImplemented();
  }

  function isDepositTokenSupported(address) external view virtual returns (bool) {
    revert NotImplemented();
  }

  function isSpecialWithdrawalSupported(SpecialWithdrawalCode) external view virtual returns (bool) {
    revert NotImplemented();
  }

  function vault() external view virtual returns (IEarnVault) {
    revert NotImplemented();
  }

  function registry() external view virtual returns (IEarnStrategyRegistry) {
    revert NotImplemented();
  }

  function description() external view virtual returns (string memory) {
    revert NotImplemented();
  }

  function allTokens() external view virtual returns (address[] memory) {
    revert NotImplemented();
  }

  function supportedDepositTokens() external view virtual returns (address[] memory) {
    revert NotImplemented();
  }

  function maxDeposit(address) external view virtual returns (uint256) {
    revert NotImplemented();
  }

  function supportedSpecialWithdrawals() external view virtual returns (SpecialWithdrawalCode[] memory) {
    revert NotImplemented();
  }

  function maxWithdraw() external view virtual returns (address[] memory, uint256[] memory) {
    revert NotImplemented();
  }

  function fees() external view virtual returns (FeeType[] memory, uint16[] memory) {
    revert NotImplemented();
  }

  function withdraw(
    uint256,
    address[] memory,
    uint256[] memory,
    address
  )
    external
    virtual
    returns (WithdrawalType[] memory)
  {
    revert NotImplemented();
  }

  function specialWithdraw(
    uint256,
    SpecialWithdrawalCode,
    uint256[] calldata,
    bytes calldata,
    address
  )
    external
    virtual
    returns (uint256[] memory, address[] memory, uint256[] memory, bytes memory)
  {
    revert NotImplemented();
  }

  function migrateToNewStrategy(IEarnStrategy, bytes calldata) external virtual returns (bytes memory) {
    revert NotImplemented();
  }

  function strategyRegistered(StrategyId, IEarnStrategy, bytes calldata) external virtual {
    revert NotImplemented();
  }

  function supportsInterface(bytes4) external pure virtual returns (bool) {
    revert NotImplemented();
  }

  function validatePositionCreation(address, bytes calldata) external virtual {
    revert NotImplemented();
  }
}
