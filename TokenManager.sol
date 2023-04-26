// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenManager is ERC20 {
    //revisar
    address owner;

    constructor() ERC20("TokenManager", "Tm") {
        owner = msg.sender;
    }
    //controlar quien puede ejecutar esta funcion
    function mint(address to, uint amount) external {
        _mint(to, amount);
    }

    function burn(uint amount) external {
        _burn(msg.sender, amount);
    }
}