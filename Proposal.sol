// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "contracts/IExecutableProposal.sol";

contract Proposal is IExecutableProposal {
  
    function executeProposal(uint proposalId, uint numVotes, uint numTokens) external override payable{

    }
}