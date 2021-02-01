// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;


import "./sub_contract/ERC20Permit.sol";
import "./sub_contract/Ownable.sol";


/**
ERC Token Standard #20 Interface
https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
*/


/**
ERC20 Token, with the addition of symbol, name and decimals and assisted token transfers
*/
contract RIEToken is ERC20Permit, Ownable {
    using SafeMath for uint256;
    //Define total ICO Supply
    uint256 public _ICOSupply = 8e8 ether;
    
    //Define total devTeam allocated token funds
    uint256 public _devTeamSupply = 1e9 ether;
    
    //Define total bounty allocated token funds
    uint256 public _bountySupply = 5e8 ether;
    
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    constructor(address _owner, uint256 _totalSupply) ERC20("Ralie Token", "RIE") EIP712("Ralie Token", "1") {
 
        uint256 _ownerAddressSupply = _totalSupply.sub(_ICOSupply).sub(_devTeamSupply).sub(_bountySupply);
        
        transferOwnership(_owner);
        _mint(_owner, _ownerAddressSupply);
        _mint(0x0D82fB6990d7dC8A22f79623c3A662db099a50be, _ICOSupply);
        _mint(0xc307c195b7380656598e992cf104cF1671B35476, _devTeamSupply);
        _mint(0x801e2ab2197c1a13bB39335de47211a447Ff875F, _bountySupply);

    }


    function mintbyOwner(address account, uint256 amount) public virtual onlyOwner{
        require(totalSupply().add(amount) <= totalSupply(), "ERC20: amount higher than total supply");
        _mint(account, amount);
    }
    
    /**
    * @dev Extension of {ERC20} that allows token holders to destroy both their own
    * tokens and those that they have an allowance for, in a way that can be
    * recognized off-chain (via event analysis).
    */
    
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }
    
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }

}