// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenManager is ERC20 {
    address owner;
    uint256 max_tokens;
    uint256 total_supply;

    constructor(uint256 _max_tokens) ERC20("TokenManager", "Tm") {
        owner = msg.sender;
        max_tokens = _max_tokens;
        total_supply = 0;
    }

    modifier isOwnerContract{
        require (owner==msg.sender, "You are not the owner");
        _;
    }

    function mint(address to, uint amount) external isOwnerContract {
        require(total_supply + amount <= max_tokens, "This exceed the max tokens");
        _mint(to, amount);
        total_supply += amount;
    }

    function burn(uint amount) external isOwnerContract {
        _burn(msg.sender, amount);
        total_supply -= amount;
    }
}