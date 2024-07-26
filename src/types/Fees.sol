  // SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

struct Fees {
  uint16 depositFee;
  uint16 withdrawFee;
  uint16 performanceFee;
  uint16 saveFee;
}

using { equals } for Fees global;

// slither-disable-next-line dead-code
function equals(Fees memory fees1, Fees memory fees2) pure returns (bool) {
  return fees1.depositFee == fees2.depositFee && fees1.withdrawFee == fees2.withdrawFee
    && fees1.performanceFee == fees2.performanceFee && fees1.saveFee == fees2.saveFee;
}
