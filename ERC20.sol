// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

contract ERC20 {
    string public tokenName;
    string public tokenSymbol;
    uint256 public tokenSupply; 
    uint8 public tokenDecimal;
    address public admin;
    uint256 public constant supplyCap = 100000;
    mapping (address => uint256) public balance;
    mapping (address => mapping (address => uint256)) public tokenAllowance; 

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor(string memory _name, string memory _symbol, uint8 _decimal) {
        admin = msg.sender;
        tokenName = _name;
        tokenSymbol = _symbol;
        tokenDecimal = _decimal;
        tokenSupply = 10000 * (10 ** uint256(tokenDecimal));
        balance[admin] = tokenSupply;
    }

    function name() public view returns(string memory) {
        return tokenName;
    }

    function symbol() public view returns(string memory) {
        return tokenSymbol;
    }

    function decimal() public view returns(uint8) {
        return tokenDecimal;
    }   

    function totalSupply() public view returns(uint256) {
        return tokenSupply;
    }

    function balanceOf(address _owner) public view returns(uint256) {
        return balance[_owner];
    }

    function transfer(address  _to, uint256 _value) public returns (bool) {
        require(_to != msg.sender, "You can not transfer tokens to your own account");
        require(_value > 0, "You can not transfer zero");
        require(balance[msg.sender] >= _value, "Insufficient balance");
        balance[msg.sender] -= _value;
        balance[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns(bool) {
        require(_spender != msg.sender, "Spender cannot approve the allowance");
        require(_value > 0, "Allowance value must be greater than zero");
        require(balance[msg.sender] >= _value, "Insufficient balance");
        tokenAllowance[msg.sender][_spender] = _value ;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns(uint) {
        return tokenAllowance[_owner][_spender];
    }
    
    function increaseAllowance(address _spender, uint256 _value) public returns(bool) {
        require(_spender != msg.sender, "Spender cannot increase the allowance");
        require(tokenAllowance[msg.sender][_spender] > 0, "Allowance should be approved");
        require(_value > 0, "Allowance value must be greater than zero");
        require(balance[msg.sender] >= tokenAllowance[msg.sender][_spender] + _value, "Insufficient Balance"); 
        tokenAllowance[msg.sender][_spender] += _value;
        emit Approval(msg.sender, _spender, tokenAllowance[msg.sender][_spender]);
        return true;
    }  

    function decreaseAllowance(address _spender, uint256 _value) public returns(bool) {
        require(_spender != msg.sender, "Spender cannot decrease the allowance");
        require(tokenAllowance[msg.sender][_spender] > 0, "Allowance should be approved");
        require(_value > 0, "Allowance value must be grester than zero");
        require(tokenAllowance[msg.sender][_spender] >= _value, "Allowance should be greater than decreasing value");
        tokenAllowance[msg.sender][_spender] -= _value;
        emit Approval(msg.sender, _spender, tokenAllowance[msg.sender][_spender]);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns(bool) {
        require(_to != _from, "You can not transfer tokens to your own account");
        require(_to != msg.sender, "Spender cannot transfer to his own account");
        require(_value > 0, "You can not transfer zero");
        require(balance[_from] >= _value, "Insufficient balance");
        require(tokenAllowance[_from][msg.sender] >= _value , "Allowance exceeded");
        balance[_from] -= _value;
        balance[_to] += _value;
        tokenAllowance[_from][msg.sender] -= _value ;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function mint(address _to, uint256 _value) public {
        require(msg.sender == admin, "Only admin can mint the tokens");
        require(_value > 0, "Token value must be greater than zero");
        require(tokenSupply + _value <= supplyCap * (10 ** uint256(tokenDecimal)), "Exceeded supply cap");
        tokenSupply += _value;
        balance[_to] += _value;
    }

    function burn(uint256 _value) public {
        require(balance[msg.sender] >= _value, "Insufficient Balance");
        balance[msg.sender] -= _value;
        tokenSupply -= _value;
    }
}
