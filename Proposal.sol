// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "contracts/IExecutableProposal.sol";

contract Proposal is IExecutableProposal {
    
    event check(uint256 proposalId, uint256 numVotes, uint256 numTokens, uint256 budget);

    function executeProposal(uint256 proposalId, uint256 numVotes, uint256 numTokens) external override payable{
        emit check(proposalId, numVotes, numTokens, msg.value);
    }
}