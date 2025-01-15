// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "./ERC20.sol";
import "./ERC20Burnable.sol";
import "./ERC20Pausable.sol";
import "./Ownable.sol";

contract RXRToken is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
    uint256 public _maxSupply; //铸币上限

    constructor(address initialOwner)
        ERC20("RXRToken", "RXR")
        Ownable(initialOwner)
    {
        _maxSupply = 380000000 * 10 ** 18;
        _mint(initialOwner, _maxSupply);
    }

    function getMaxSupply() external view returns (uint256) {
      return _maxSupply;
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }

}