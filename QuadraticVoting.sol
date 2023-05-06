// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "contracts/TokenManager.sol";
import "contracts/Proposal.sol";

contract QuadraticVoting {

    address owner;      //Owner del contrato
    uint256 budget;     //Presupuesto
    uint256 price;      //Precio de los tokens
    uint256 lastId;     //Guardamos el id de cada una de las propuestas a partir de 1
    uint256 num_participants;   //Numero de participantes
    uint256 num_pending_proposals;  //Numero de propuestas pendientes
    bool is_open;   //Votacion abierta

    TokenManager tm;    //Tokens

    struct proposal {   //Guarda informacion de cada propuesta y de sus votantes
        string title;
        string description;
        uint256 proposal_budget;
        uint256 num_tokens;
        uint256 votes;
        address proposal_address;
        address creator;
        bool approved;
        address[] voters;
    }

    struct Paticipant { //Informacion de los participantes sobre sus tokens y lo que han votado
        uint248 tokens;
        uint8 exist;
        mapping (uint256 => uint256) votes;
    }

    mapping (address => uint256) proposals_aux;
    mapping (address => Paticipant) participants;   //Mapping de direccion y participante
    mapping (uint256 => proposal) proposals;        //Mapping de id con la propuesta
    uint256 [] array_proposals; //Array de propuestas

    constructor (uint256 _price, uint256 _max_tokens) {
        owner = msg.sender;
        price = _price;
        is_open = false;
        lastId = 1;
        num_participants = 0;
        num_pending_proposals = 0;
        tm = new TokenManager(_max_tokens);
    }
    // Modificador para comprobar si votas/retiras mas de 0 votos
    modifier enoughVotes (uint256 num_votes){
        require(num_votes > 0, "The number of votes must be higher than zero");
        _;
    }
    // Modificador para comprobar si es el dueno del contrato
    modifier isOwnerContract{
        require (owner==msg.sender, "You are not the owner");
        _;
    }
    // Modificador para comprobar si la votacion esta abierta
    modifier isOpen{
        require (is_open==true, "The voting is not open");
        _;
    }
    //Modificador para compronar si una propuesta esta aprobada
    modifier isApproved(uint256 id){
        require (!proposals[id].approved, "The proposal has been approved");
        _;
    }
    //Modificador para comprobar si es el creador de la propuesta
    modifier proposalCreator(uint256 id){
        require (proposals[id].creator==msg.sender, "You are not the creator of this proposal");
        _;
    }
    //Modificador para comprobar si existe un participante
    modifier registeredParticipant {
        require (participants[msg.sender].exist == 1, "You are not register as participant");
        _;
    }


    function openVoting() external payable isOwnerContract {
        require(msg.value > 0, "You must open the voting with any budget"); //Necesitas abrir el proceso de votación con un presupuesto
        budget = msg.value;
        is_open = true;
    }

    function addParticipant() external payable {
        require(participants[msg.sender].exist == 0, "Participant already exist");  //El participante existe
        uint256 tokens = msg.value/price;
        require(tokens > 0);   //Necesitas depositar al menos 1 token
        tm.mint(msg.sender, tokens);            //Se minan los tokens correspondientes
        participants[msg.sender].tokens = uint248(tokens);  //Para que ocupe menos en memoria, en un mismo bloque guardamos el número de 
        participants[msg.sender].exist = 1;     //tokens y si existe o no como participante
        ++num_participants;
    }

    function removeParticipant() external registeredParticipant{
        participants[msg.sender].exist = 0;
        --num_participants;
    }

    function addProposal(string memory title, string memory description, uint256 proposal_budget, address a) external isOpen returns (uint){
        require (a != address(0), "This proposal doesn't exist");    //La propuesta no existe
        proposals[lastId].title = title;
        proposals[lastId].description = description;
        proposals[lastId].proposal_budget = proposal_budget;
        proposals[lastId].num_tokens = 0;
        proposals[lastId].votes = 0;
        proposals[lastId].proposal_address = a;
        proposals[lastId].creator = msg.sender;
        if(proposal_budget != 0) ++num_pending_proposals;
        proposals[lastId].approved = false;
        proposals_aux[a] = lastId;
        array_proposals.push(lastId);
        //se devuelve el lastId y tras devolverse se incrementa su valor
        return lastId++;
    }
    
    function cancelProposal (uint256 id) external isOpen isApproved(id) proposalCreator(id) {
        for(uint i = 0; i < proposals[id].voters.length; i++){
            uint256 tokens = participants[proposals[id].voters[i]].votes[id]**2;
            participants[proposals[id].voters[i]].votes[id] -=  participants[proposals[id].voters[i]].votes[id];
            participants[proposals[id].voters[i]].tokens += uint248(tokens);
            proposals[id].num_tokens -= tokens;
            tm.transfer(proposals[id].voters[i], tokens);
        }
        if(proposals[id].proposal_budget != 0) --num_pending_proposals;
    }

    function buyTokens() external payable registeredParticipant {
        require (msg.value>=price, "You cannot buy tokens with that price");
        uint256 tokens = msg.value/price;
        tm.mint(msg.sender, tokens); //Minamos tokens y se lo anadimos al participante
        participants[msg.sender].tokens += uint248(tokens);
    }

    function sellTokens() external registeredParticipant {
        uint256 tokens = participants[msg.sender].tokens;
        tm.transferFrom(msg.sender, address(this), tokens); //Le devolvemos su dinero y quemamos los tokens
        tm.burn(tokens);
        participants[msg.sender].tokens = 0;
        payable(msg.sender).transfer(tokens*price);
    }

    function getERC20() external view returns (address) {
        return address(tm);
    }

    function getPendingProposals() external view isOpen returns (uint256[] memory){
        uint256 [] memory pending_proposals = new uint256[] (num_pending_proposals);
        uint256 index = 0;
        for(uint256 i = 0; i < array_proposals.length; ++i){
            if(!proposals[array_proposals[i]].approved && proposals[array_proposals[i]].proposal_budget != 0) {
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
        uint256[] memory result = new uint256[](index);
        for (uint256 i = 0; i < index; ++i) result[i] = approved_proposals[i];
        assembly{mstore(result,index)}  //Guardamos el array de aprobadas
        return result;
    }
 
    function getSignalingProposals() external view isOpen returns (uint256[] memory){
        uint256 [] memory signaling_proposals = new uint256[] (array_proposals.length);
        uint256 index = 0;
        for(uint256 i = 0; i < array_proposals.length; ++i){
            if(proposals[array_proposals[i]].proposal_budget == 0) {
                signaling_proposals[index] = array_proposals[i];
                ++index;
            }
        }
        uint256[] memory result = new uint256[](index);
        for (uint256 i = 0; i < index; ++i) result[i] = signaling_proposals[i];
        assembly{mstore(result,index)}  //Guardamos el array de signal
        return result;
    }

    function getProposalInfo(uint256 id) external view isOpen returns(string memory, string memory, uint, address) {
        return (proposals[id].title, proposals[id].description, proposals[id].proposal_budget, proposals[id].proposal_address); //Damos solo la informacion basica
    }

    function stake(uint256 id, uint256 num_votes) external enoughVotes(num_votes) registeredParticipant {
        uint256 tokens = (participants[msg.sender].votes[id] + num_votes)**2 - (participants[msg.sender].votes[id])**2;
        require (participants[msg.sender].tokens >= tokens, "You don't have enough token to vote"); //No tiene tokens para votar
        if(proposals[id].approved){
            budget += (tokens * price);
            participants[msg.sender].tokens -= uint248(tokens);
            tm.transferFrom(msg.sender, address(this), tokens);
        }
        else{
            if(participants[msg.sender].votes[id] == 0) proposals[id].voters.push(msg.sender);
            participants[msg.sender].votes[id] += num_votes;
            participants[msg.sender].tokens -= uint248(tokens);
            proposals[id].num_tokens += tokens;
            proposals[id].votes += num_votes;
            tm.transferFrom(msg.sender, address(this), tokens);
            _checkAndExecuteProposal(id);
        }
    }

    function withdrawFromProposal(uint256 id, uint256 num_votes) external enoughVotes(num_votes) registeredParticipant isApproved(id) {
        require(participants[msg.sender].votes[id] >= num_votes, "You don't have enough votes to withdraw"); //No tiene los votos para retirarlos
        uint256 tokens = (participants[msg.sender].votes[id])**2 - (participants[msg.sender].votes[id] - num_votes)**2;
        participants[msg.sender].votes[id] -= num_votes;
        participants[msg.sender].tokens += uint248(tokens);
        proposals[id].num_tokens -= tokens;
        proposals[id].votes -= num_votes;
        tm.transfer(msg.sender, tokens);
    }

    function _checkAndExecuteProposal(uint256 id) internal {
        if(proposals[id].proposal_budget == 0) {
            if(!is_open) {
                Proposal(proposals[id].proposal_address).executeProposal{value: proposals[id].proposal_budget}(id, proposals[id].num_tokens, proposals[id].num_tokens);
            proposals[id].approved = true;
            }
        }
        else {
            uint256 threshold;
            if(budget != 0) threshold = (2 * num_participants + ((proposals[id].proposal_budget * num_participants) / (budget * price))) + num_pending_proposals * 10;  //Calculo de umbral
            else threshold = num_pending_proposals;
            if(proposals[id].proposal_budget <= budget + (proposals[id].num_tokens * price) && (proposals[id].votes*10) > threshold) {
                Proposal(proposals[id].proposal_address).executeProposal{value: proposals[id].proposal_budget, gas:10000}(id, proposals[id].num_tokens, proposals[id].num_tokens);
                proposals[id].approved = true;
                budget += (proposals[id].num_tokens * price);
                budget -= proposals[id].proposal_budget;
                --num_pending_proposals;
                tm.burn(proposals[id].num_tokens);
            }
        }
    }

    function closeVoting() external isOwnerContract isOpen{
        for(uint256 j = 0; j < array_proposals.length; j++){
            uint256 id = array_proposals[j];
            if(!proposals[id].approved) {
                if(proposals[id].proposal_budget == 0) _checkAndExecuteProposal(id);
                else --num_pending_proposals;
                for(uint i = 0; i < proposals[id].voters.length; i++){
                    uint256 tokens = participants[proposals[id].voters[i]].votes[id]**2;
                    participants[proposals[id].voters[i]].votes[id] -=  participants[proposals[id].voters[i]].votes[id];
                    participants[proposals[id].voters[i]].tokens += uint248(tokens);
                    proposals[id].num_tokens -= tokens;
                    tm.transfer(proposals[id].voters[i], tokens);
                }
            }
            delete proposals[id];       //Eliminamos cada una de las propuestas al cerrar la votacion para poder realizar otros sistemas de votacion de manera posterior
        }
        payable(owner).transfer(budget);
        lastId = 1;
        num_participants = 0;   //Eliminamos a los participantes
        delete array_proposals; //Borramos el array de propuestas por el mismo motivo
        is_open = false;    //Cerramos la votacion
    }
}