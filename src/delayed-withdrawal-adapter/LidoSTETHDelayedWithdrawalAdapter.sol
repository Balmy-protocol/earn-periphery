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

interface ILidoSTETHQueue {
  function requestWithdrawals(uint256[] memory _amounts, address _owner) external returns (uint256[] memory requestIds);
  function getWithdrawalStatus(uint256[] memory _requestIds)
    external
    view
    returns (WithdrawalRequestStatus[] memory statuses);
  function claimWithdrawalsTo(uint256[] memory _requestIds, uint256[] memory _hints, address _recipient) external;
  function findCheckpointHints(
    uint256[] memory _requestIds,
    uint256 _firstIndex,
    uint256 _lastIndex
  )
    external
    view
    returns (uint256[] memory hintIds);
}

struct WithdrawalRequestStatus {
  uint256 amountOfStETH;
  uint256 amountOfShares;
  address owner;
  uint256 timestamp;
  bool isFinalized;
  bool isClaimed;
}

contract LidoSTETHDelayedWithdrawalAdapter is IDelayedWithdrawalAdapter {
  using Math for uint256;
  using SafeERC20 for IERC20;

  /// @notice The id for the Delayed Withdrawal Manager
  bytes32 public constant DELAYED_WITHDRAWAL_MANAGER = keccak256("DELAYED_WITHDRAWAL_MANAGER");

  IGlobalEarnRegistry public immutable registry;

  // slither-disable-start naming-convention
  // solhint-disable-next-line const-name-snakecase
  address internal constant _stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
  // slither-disable-end naming-convention
  address internal constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  ILidoSTETHQueue internal immutable _queue;
  mapping(uint256 positionId => uint256[] requestIds) internal _pendingWithdrawals;

  constructor(IGlobalEarnRegistry _registry, ILidoSTETHQueue queue_) {
    registry = _registry;
    _queue = queue_;
    maxApproveVault();
  }

  /// @notice Performs a max approve to the vault, so that we can deposit without any worries
  function maxApproveVault() public {
    // slither-disable-next-line unused-return
    IERC20(_stETH).forceApprove(address(_queue), type(uint256).max);
  }

  function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
    return interfaceId == type(IDelayedWithdrawalAdapter).interfaceId;
  }

  function estimatedPendingFunds(uint256 positionId, address) external view override returns (uint256 pendingAmount) {
    uint256[] memory requestIds = _pendingWithdrawals[positionId];
    // slither-disable-next-line incorrect-equality
    if (requestIds.length == 0) {
      return 0;
    }
    WithdrawalRequestStatus[] memory statuses = _queue.getWithdrawalStatus(requestIds);
    for (uint256 i; i < statuses.length; ++i) {
      if (!statuses[i].isFinalized) {
        pendingAmount += statuses[i].amountOfStETH;
      }
    }
  }

  function withdrawableFunds(uint256 positionId, address) external view override returns (uint256 withdrawableAmount) {
    uint256[] memory requestIds = _pendingWithdrawals[positionId];
    // slither-disable-next-line incorrect-equality
    if (requestIds.length == 0) {
      return 0;
    }
    WithdrawalRequestStatus[] memory statuses = _queue.getWithdrawalStatus(requestIds);
    for (uint256 i; i < statuses.length; ++i) {
      if (statuses[i].isFinalized) {
        withdrawableAmount += statuses[i].amountOfStETH;
      }
    }
  }

  function initiateDelayedWithdrawal(uint256 positionId, address, uint256) external override {
    IDelayedWithdrawalManager delayedWithdrawalManager = manager();
    IEarnVault vault_ = delayedWithdrawalManager.VAULT();
    StrategyId strategyId = vault_.positionsStrategy(positionId);
    IEarnStrategy strategy = vault_.STRATEGY_REGISTRY().getStrategy(strategyId);
    if (msg.sender != address(strategy)) {
      revert UnauthorizedPositionStrategy();
    }

    // stETH is a rebasing token, so maybe the balance will differ from the amount requested in a wei
    uint256 realAmount = IERC20(_stETH).balanceOf(address(this));
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = realAmount;
    // slither-disable-next-line reentrancy-benign
    uint256[] memory requestIds = _queue.requestWithdrawals(amounts, address(this));
    uint256[] storage pendingRequestIds = _pendingWithdrawals[positionId];
    bool needsToRegister = pendingRequestIds.length == 0;
    pendingRequestIds.push(requestIds[0]);
    if (needsToRegister) {
      delayedWithdrawalManager.registerDelayedWithdraw(positionId, _ETH);
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
    uint256[] memory requestIds = _pendingWithdrawals[positionId];
    if (requestIds.length == 0) {
      return (0, 0);
    }
    WithdrawalRequestStatus[] memory statuses = _queue.getWithdrawalStatus(requestIds);
    uint256[] memory requestsToClaim = new uint256[](requestIds.length);
    uint256 numberOfRequestsToClaim = 0;
    uint256 numberOfRequestsPending = 0;
    for (uint256 i; i < statuses.length; ++i) {
      if (!statuses[i].isFinalized) {
        stillPending += statuses[i].amountOfStETH;
        if (numberOfRequestsPending != i) {
          requestIds[numberOfRequestsPending] = requestIds[i];
        }
        ++numberOfRequestsPending;
      } else {
        withdrawn += statuses[i].amountOfStETH;
        requestsToClaim[numberOfRequestsToClaim++] = requestIds[i];
      }
    }

    if (numberOfRequestsToClaim != requestsToClaim.length) {
      // Resize the array
      // solhint-disable-next-line no-inline-assembly
      assembly {
        mstore(requestsToClaim, numberOfRequestsToClaim)
      }
    }

    if (numberOfRequestsPending != requestIds.length) {
      // Resize the array
      // solhint-disable-next-line no-inline-assembly
      assembly {
        mstore(requestIds, numberOfRequestsPending)
      }
    }
    _pendingWithdrawals[positionId] = requestIds;

    uint256[] memory hints = _queue.findCheckpointHints(requestsToClaim, 1, requestsToClaim.length + 1);
    // slither-disable-next-line reentrancy-no-eth
    _queue.claimWithdrawalsTo(requestsToClaim, hints, recipient);
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
