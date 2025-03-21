// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721A.sol";


contract LPNFT is ERC721A, Ownable {
    uint256 public _maxSupply;

    event NftHunt(address user, uint256 quantity);

    constructor(address initialOwner) ERC721A("RXRLab", "RXRLP") Ownable(initialOwner){
        _maxSupply = 16000;
    }

    //
    function mint(address user, uint256 quantity) external onlyOwner {
      require(totalSupply() + quantity <= _maxSupply, "Exceeds maximum supply"); 
      _mint(user, quantity);

      emit NftHunt(user, quantity);      
    }

}
