pragma solidity ^0.4.11;

import "./inc/Pausable.sol";
import './inc/ERC20.sol';
import './inc/SafeMath.sol';
import './inc/StandardToken.sol';

contract GBT {
  function parentChange(address,uint);
  function parentFees(address);
  function setHGT(address _hgt);
}


contract HelloGoldToken is ERC20, SafeMath, Pausable, StandardToken {

  string public name;
  string public symbol;
  uint8  public decimals;

  GBT  goldtoken;
  

  function setGBT(address gbt_) onlyOwner {
    goldtoken = GBT(gbt_);
  }

  function GBTAddress() constant returns (address) {
    return address(goldtoken);
  }

  function HelloGoldToken(address _reserve) {
    name = "HelloGold Token";
    symbol = "HGT";
    decimals = 8;
 
    totalSupply = 1 * 10 ** 9 * 10 ** uint256(decimals);
    balances[_reserve] = totalSupply;
  }


  function parentChange(address _to) internal {
    require(address(goldtoken) != 0x0);
    goldtoken.parentChange(_to,balances[_to]);
  }
  function parentFees(address _to) internal {
    require(address(goldtoken) != 0x0);
    goldtoken.parentFees(_to);
  }

  function transferFrom(address _from, address _to, uint256 _value) returns (bool success){
    parentFees(_from);
    parentFees(_to);
    success = super.transferFrom(_from,_to,_value);
    parentChange(_from);
    parentChange(_to);
    return;
  }

  function transfer(address _to, uint _value) whenNotPaused returns (bool success)  {
    parentFees(msg.sender);
    parentFees(_to);
    success = super.transfer(_to,_value);
    parentChange(msg.sender);
    parentChange(_to);
    return;
  }

  function approve(address _spender, uint _value) whenNotPaused returns (bool success)  {
    return super.approve(_spender,_value);
  }

}
