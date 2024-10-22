// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import {
  IDelayedWithdrawalAdapter,
  IDelayedWithdrawalManager,
  IEarnVault
} from "src/interfaces/IDelayedWithdrawalAdapter.sol";
import { IEarnStrategy, StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

struct Request {
  uint256 amount;
  uint256 deadline;
}

contract ERC4626DelayedWithdrawalAdapter is IDelayedWithdrawalAdapter {
  using Math for uint256;
  using SafeERC20 for IERC20;

  /// @notice The id for the Delayed Withdrawal Manager
  bytes32 public constant DELAYED_WITHDRAWAL_MANAGER = keccak256("DELAYED_WITHDRAWAL_MANAGER");

  IGlobalEarnRegistry public immutable registry;

  address internal immutable _farmToken;
  uint256 internal immutable _delay;
  mapping(uint256 positionId => Request[] requestIds) internal _pendingWithdrawals;

  constructor(IGlobalEarnRegistry _registry, address farmToken_, uint256 delay_) {
    registry = _registry;
    _farmToken = farmToken_;
    _delay = delay_;
  }

  function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
    return interfaceId == type(IDelayedWithdrawalAdapter).interfaceId;
  }

  function estimatedPendingFunds(uint256 positionId, address) external view override returns (uint256 pendingAmount) {
    Request[] memory requests = _pendingWithdrawals[positionId];
    // slither-disable-next-line incorrect-equality
    if (requests.length == 0) {
      return 0;
    }

    for (uint256 i; i < requests.length; ++i) {
      if (requests[i].deadline > block.timestamp) {
        pendingAmount += IERC4626(_farmToken).previewRedeem(requests[i].amount);
      }
    }
  }

  function withdrawableFunds(uint256 positionId, address) external view override returns (uint256 withdrawableAmount) {
    Request[] memory requests = _pendingWithdrawals[positionId];
    // slither-disable-next-line incorrect-equality
    if (requests.length == 0) {
      return 0;
    }

    for (uint256 i; i < requests.length; ++i) {
      if (requests[i].deadline <= block.timestamp) {
        withdrawableAmount += IERC4626(_farmToken).previewRedeem(requests[i].amount);
      }
    }
  }

  function initiateDelayedWithdrawal(uint256 positionId, address, uint256 amount) external override {
    IDelayedWithdrawalManager delayedWithdrawalManager = manager();
    IEarnVault vault_ = delayedWithdrawalManager.VAULT();
    StrategyId strategyId = vault_.positionsStrategy(positionId);
    IEarnStrategy strategy = vault_.STRATEGY_REGISTRY().getStrategy(strategyId);
    if (msg.sender != address(strategy)) {
      revert UnauthorizedPositionStrategy();
    }
    Request[] storage requests = _pendingWithdrawals[positionId];
    bool needsToRegister = requests.length == 0;
    requests.push(Request({ amount: IERC4626(_farmToken).previewWithdraw(amount), deadline: block.timestamp + _delay }));
    if (needsToRegister) {
      delayedWithdrawalManager.registerDelayedWithdraw(positionId, (IERC4626(_farmToken).asset()));
    }
  }

  // slither-disable-start assembly
  function withdraw(
    uint256 positionId,
    address,
    address recipient
  )
    external
    override
    onlyManager
    returns (uint256 withdrawn, uint256 stillPending)
  {
    Request[] memory requests = _pendingWithdrawals[positionId];
    if (requests.length == 0) {
      return (0, 0);
    }
    uint256 numberOfRequestsPending = 0;
    for (uint256 i; i < requests.length; ++i) {
      if (requests[i].deadline > block.timestamp) {
        stillPending += IERC4626(_farmToken).previewRedeem(requests[i].amount);
        if (numberOfRequestsPending != i) {
          requests[numberOfRequestsPending] = requests[i];
        }
        ++numberOfRequestsPending;
      } else {
        withdrawn += IERC4626(_farmToken).previewRedeem(requests[i].amount);
      }
    }

    if (numberOfRequestsPending != requests.length) {
      // Resize the array
      // solhint-disable-next-line no-inline-assembly
      assembly {
        mstore(requests, numberOfRequestsPending)
      }
    }
    _pendingWithdrawals[positionId] = requests;
    IERC4626(_farmToken).withdraw(withdrawn, recipient, address(this));
  }

  function manager() public view returns (IDelayedWithdrawalManager) {
    return IDelayedWithdrawalManager(registry.getAddressOrFail(DELAYED_WITHDRAWAL_MANAGER));
  }

  function vault() public view override returns (IEarnVault) {
    return manager().VAULT();
  }

  modifier onlyManager() {
    if (msg.sender != address(manager())) revert UnauthorizedDelayedWithdrawalManager();
    _;
  }
}
