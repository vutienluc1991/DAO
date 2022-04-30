// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";

// Since DAOs smart contract need to be unchangable then i dont use upgradable proxy here
// Normal DAO that support charity by transfer native EVM token to address
// Voting power based on the native amount the contributer given the smart contract
contract DAO_NFT is AccessControl {
}