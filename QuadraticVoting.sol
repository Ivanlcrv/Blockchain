// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "contracts/IExecutableProposal.sol";
import "contracts/TokenManager.sol";

contract QuadraticVoting {
    
    address owner;
    uint256 budget;
    uint256 price;
    uint256 max_tokens;
    uint256 lastId;
    bool is_open;

    TokenManager tm;

    
    struct proposal {
        string title;
        string description;
        uint256 proposal_budget;
        uint256 num_tokens;
        address proposal_address;
        address creator;
        bool is_signaling;
        bool approved;
        address[] voters;
    }

    struct Paticipant {
        uint256 tokens;
        mapping (uint256 => uint256) votes;
    }

    mapping (address => uint256) proposals_aux;//revisar
    mapping (address => Paticipant) participants;
    mapping (uint256 => proposal) proposals;
    uint256 [] array_proposals;

    constructor (uint256 _price, uint256 _max_tokens) {
        owner = msg.sender;
        price = _price;
        max_tokens = _max_tokens;
        is_open = false;
        lastId = 1;
        tm = new TokenManager();//revisar
    }
   
    modifier isOwnerContract{
        require (owner==msg.sender, "You are not the owner");
        _;
    }

    modifier isOpen{
        require (is_open==true, "The voting is not open");
        _;
    }

    modifier isApproved(uint256 id){
        require (!proposals[id].approved, "The proposal has been approved");
        _;
    }

    modifier proposalCreater(uint256 id){
        require (proposals[id].creator==msg.sender, "You are not the creater of this proposal");
        _;
    }

    modifier registeredParticipant {
        require (participants[msg.sender].tokens >= 0, "You are not register as participant");
        _;
    }


    function openVoting() external payable isOwnerContract {
        budget = msg.value;
        is_open = true;
    }

    function addParticipant() external payable {
        //revisar
        require(participants[msg.sender].tokens == 0, "Participant already exist");
        uint256 tokens = msg.value/price;
        //revisar estas dos lineas
        require(tokens <= max_tokens);
        max_tokens -= tokens;
        //
        tm.mint(msg.sender, tokens);
        participants[msg.sender].tokens = tokens; //revisar
    }

    function removeParticipant() external {
        uint256 tokens = participants[msg.sender].tokens;
        tm.burn(tokens);
        participants[msg.sender].tokens = 0; //revisar    
        payable(address(this)).transfer(tokens*price);
    }

    function addProposal(string memory title, string memory description, uint256 proposal_budget, address a) external isOpen returns (uint){
        require (proposals_aux[a] == 0, "This proposal already exists");
        proposals[lastId].title = title;
        proposals[lastId].description = description;
        proposals[lastId].proposal_budget = proposal_budget;
        proposals[lastId].num_tokens = 0;
        proposals[lastId].proposal_address = a;
        proposals[lastId].creator = msg.sender;
        proposals[lastId].is_signaling = (proposal_budget==0 ? false : true);
        proposals[lastId].approved = false;
        proposals_aux[a] = lastId;
        array_proposals.push(lastId);
        return lastId++;
    }
    
    function cancelProposal (uint256 id) external isOpen isApproved(id) {
        for(uint i = 0; i < proposals[id].voters.length; i++){
            uint256 tokens = participants[proposals[id].voters[i]].votes[id]**2;
            tm.transferFrom(address(this), msg.sender, tokens);
            participants[msg.sender].votes[id] -=  participants[proposals[id].voters[i]].votes[id];
            participants[msg.sender].tokens += tokens;
            proposals[id].num_tokens -= tokens;
        }
    }

    function buyTokens() external payable registeredParticipant {
        uint256 tokens = msg.value/price;
        //revisar estas dos lineas
        require(tokens <= max_tokens);
        max_tokens -= tokens;
        //
        tm.mint(msg.sender, tokens);
        participants[msg.sender].tokens += tokens; //revisar
    }

    function sellTokens() external registeredParticipant {
        uint256 tokens = participants[msg.sender].tokens;
        tm.burn(tokens);
        participants[msg.sender].tokens = 0; //revisar    
        payable(address(this)).transfer(tokens*price);
        max_tokens += tokens;
    }

    function getERC20() external view returns (address) {
        return address(tm);
    }

    //preguntar al profe manejo de array, se reservan posiciones que pueden no usarse 
    function getPendingProposals() external view isOpen returns (uint256[] memory){
        uint256 [] memory pending_proposals = new uint256[] (array_proposals.length);
        uint256 index = 0;
        for(uint256 i = 0; i < array_proposals.length; ++i){
            if(!proposals[array_proposals[i]].approved) {
                pending_proposals[index] = array_proposals[i];
                ++index;
            }
        }
        return pending_proposals;
    }

    function getApprovedProposals() external view isOpen returns (uint256[] memory){
        uint256 [] memory approved_proposals = new uint256[] (array_proposals.length);
        uint256 index = 0;
        for(uint256 i = 0; i < array_proposals.length; ++i){
            if(proposals[array_proposals[i]].approved) {
                approved_proposals[index] = array_proposals[i];
                ++index;
            }
        }
        return approved_proposals;
    }
 
    function getSignalingProposals() external view isOpen returns (uint256[] memory){
        uint256 [] memory signaling_proposals = new uint256[] (array_proposals.length);
        uint256 index = 0;
        for(uint256 i = 0; i < array_proposals.length; ++i){
            if(proposals[array_proposals[i]].is_signaling) {
                signaling_proposals[index] = array_proposals[i];
                ++index;
            }
        }
        return signaling_proposals;
    }

    //revisar que debe devolver y si estaria bien asi
    function getProposalInfo(uint256 id) external view isOpen returns(string memory, string memory, uint, address) {
        return (proposals[id].title, proposals[id].description, proposals[id].proposal_budget, proposals[id].proposal_address);
    }

    function stake(uint256 id, uint256 num_votes) external {
        require(num_votes > 0, "The number of votes must be higher than zero");
        uint256 tokens = (participants[msg.sender].votes[id] + num_votes)**2 - (participants[msg.sender].votes[id])**2;
        require (participants[msg.sender].tokens >= tokens, "You don't have enough token to vote");
        if(participants[msg.sender].votes[id] == 0) proposals[id].voters.push(msg.sender);
        participants[msg.sender].votes[id] += num_votes;
        participants[msg.sender].tokens -= tokens;
        tm.transferFrom(msg.sender, address(this), tokens);
        proposals[id].num_tokens += tokens;
    }

    function withdrawFromProposal(uint256 id, uint256 num_votes) external{
        require(num_votes > 0, "The number of votes must be higher than zero");
        require(!proposals[id].approved, "The proposal has been approved");
        require(participants[msg.sender].votes[id] >= num_votes, "You don't have enough votes to withdraw");
        uint256 tokens = (participants[msg.sender].votes[id])**2 - (participants[msg.sender].votes[id] - num_votes)**2;
        tm.transferFrom(address(this), msg.sender, tokens);
        participants[msg.sender].votes[id] -= num_votes;
        participants[msg.sender].tokens += tokens;
        proposals[id].num_tokens -= tokens;
    }

    function _checkAndExecuteProposal() internal {

    }

    function closeVoting() external isOwnerContract{
        is_open = false;
    }
}