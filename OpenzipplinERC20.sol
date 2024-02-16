// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyERC20 is ERC20{
    struct Sale {
       uint256 tokenForSell;
       uint256 price;
    }
    
    address private _admin;
    uint256 private constant _SUPPLYCAP = 100000;
    mapping (address => Sale) public sale;

    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 10000 * (10 ** uint256(decimals())));
        _admin = msg.sender;
    }

    function increaseAllowance(address _spender, uint256 _value) public returns (bool) {
        require(_spender != msg.sender, "Spender cannot increase the allowance");
        require(allowance(msg.sender, _spender) > 0, "Allowance should be approved");
        require(_value > 0, "Allowance value must be greater than zero");
        require(balanceOf(msg.sender) >= allowance(msg.sender, _spender) + _value, "Insufficient Balance");
        approve( _spender, allowance(msg.sender, _spender) + _value);
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _value) public returns (bool) {
        require(_spender != msg.sender, "Spender cannot decrease the allowance");
        require(allowance(msg.sender, _spender) > 0, "Allowance should be approved");
        require(_value > 0, "Allowance value must be grester than zero");
        require(allowance(msg.sender, _spender) >= _value, "Allowance should be greater than decreasing value");
        approve(_spender, allowance(msg.sender, _spender) - _value);
        return true;
    }

    function mint(address to, uint256 _value) public  {
        require(msg.sender == _admin, "Only admin can mint the tokens");
        require(_value > 0, "Token value must be greater than zero");
        require(totalSupply() + _value <= _SUPPLYCAP * (10 ** uint256(decimals())), "Exceeded supply cap");
        _mint(to, _value);
    }

    function burn(uint256 _value) public {
        require(balanceOf(msg.sender) >= _value, "Insufficient Balance");
        _burn(msg.sender, _value);
    }

    function sell(uint256 _amount, uint256 _price) public {
        require(balanceOf(msg.sender) >= _amount && balanceOf(msg.sender) > 0, "User should have enough balance");
        sale[msg.sender] = Sale(_amount, _price);
    }

    function buy(address _seller, uint256 _amount) public payable {
        require(sale[_seller].tokenForSell > 0 && sale[_seller].tokenForSell >= _amount, "No tokens available for sale from this seller");
        require(_amount > 0, "Buyer can not buy zero tokens");
        uint totalPrice =  _amount * sale[_seller].price;
        uint commission = totalPrice / 10;
        uint remainingPrice  = totalPrice - commission;
        require(msg.value == totalPrice, "Incorrect amount sent");
        _transfer(_seller, msg.sender, _amount);
        sale[_seller].tokenForSell -= _amount;
        payable(_admin).transfer(commission);
        payable(_seller).transfer(remainingPrice);
    }
}