// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "contracts/IExecutableProposal.sol";
import "contracts/TokenManager.sol";

contract QuadraticVoting {
    
    address owner;
    uint budget;
    uint price;
    uint max_tokens;
    bool is_open;
    uint lastId;

    TokenManager tm;

    struct proposal {
        string title;
        string description;
        uint proposal_budget;
        address proposal_address;
        address creator;
        bool is_signaling;
        bool approved;
    }

    struct Paticipant {
        uint tokens;
        bool exist;
    }

    mapping (address => address) proposals_aux;//revisar
    mapping (address => address) participants;
    mapping (uint => proposal) proposals;
    uint [] array_proposals;

    constructor (uint _price, uint _max_tokens) {
        owner = msg.sender;
        price = _price;
        max_tokens = _max_tokens;
        is_open = false;
        lastId = 0;
        tm = new TokenManager());//revisar
    }
   
    modifier isOwnerContract{
        require (owner==msg.sender, "You are not the owner");
        _;
    }

    modifier isOpen{
        require (is_open==true, "The voting is not open");
        _;
    }

    modifier isApproved(uint id){
        require (!proposals[id].approved, "The proposal has been approved");
        _;
    }

    modifier proposalCreater(uint id){
        require (proposals[id].creator==msg.sender, "You are not the creater of this proposal");
        _;
    }

    modifier registeredParticipant {
        require (participants[msg.sender] != address(0), "You are not register as participant");
        _;
    }


    function openVoting() external payable isOwnerContract {
        budget = msg.value;
        is_open = true;
    }

    function addParticipant() external payable {
        //revisar
        require(!participants[msg.sender].tokens != 0, "Participant already exist");
        uint tokens = msg.value/price;
        //revisar estas dos lineas
        require(tokens <= max_tokens);
        max_tokens -= tokens;
        //
        tm.mint(msg.sender, tokens);
        participants[msg.sender] = Paticipant(tokens, true); //revisar
    }

    function removeParticipant() external {
        participants[msg.sender] = address(0);
    }

    function addProposal(string memory title, string memory description, uint proposal_budget, address a) external isOpen returns (uint){
        require (proposals_aux[a] == address(0), "This proposal already exists");
        proposals[lastId] = proposal (title, description, proposal_budget, a, msg.sender, (proposal_budget==0 ? false : true), false);
        proposals_aux[a] = a;
        array_proposals.push(lastId);
        return lastId++;
    }
    
    function cancelProposal (uint id) external isOpen isApproved(id) {
        //devolver tokens
    }

    function buyTokens() external registeredParticipant {
        //completar
    }

    function sellTokens() external registeredParticipant {
        //completar
    }

    function getERC20() external view returns (address) {
        return address(tm);
    }

    //preguntar al profe manejo de array, se reservan posiciones que pueden no usarse 
    function getPendingProposals() external view isOpen returns (uint[] memory){
        uint [] memory pending_proposals = new uint[] (array_proposals.length);
        uint index = 0;
        for(uint i = 0; i < array_proposals.length; ++i){
            if(!proposals[array_proposals[i]].approved) {
                pending_proposals[index] = array_proposals[i];
                ++index;
            }
        }
        return pending_proposals;
    }

    function getApprovedProposals() external view isOpen returns (uint[] memory){
        uint [] memory approved_proposals = new uint[] (array_proposals.length);
        uint index = 0;
        for(uint i = 0; i < array_proposals.length; ++i){
            if(proposals[array_proposals[i]].approved) {
                approved_proposals[index] = array_proposals[i];
                ++index;
            }
        }
        return approved_proposals;
    }
 
    function getSignalingProposals() external view isOpen returns (uint[] memory){
        uint [] memory signaling_proposals = new uint[] (array_proposals.length);
        uint index = 0;
        for(uint i = 0; i < array_proposals.length; ++i){
            if(proposals[array_proposals[i]].is_signaling) {
                signaling_proposals[index] = array_proposals[i];
                ++index;
            }
        }
        return signaling_proposals;
    }

    //revisar que debe devolver y si estaria bien asi
    function getProposalInfo(uint id) external view isOpen returns(string memory, string memory, uint, address) {
        return (proposals[id].title, proposals[id].description, proposals[id].proposal_budget, proposals[id].proposal_address);
    }




    //terminar estas 4 funciones
    function stake(uint id, uint num_votes) external {

    }

    function withdrawFromProposal() external{

    }

    function _checkAndExecuteProposal() internal {

    }

    function closeVoting() external isOwnerContract{
        is_open = false;
    }
}