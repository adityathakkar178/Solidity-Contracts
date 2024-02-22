// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ICO is ERC20 {
    struct PreSaleAccounts {
        uint256 tokenAmount;
        uint256 price;
        bool whileListAccounts;
    }

    struct SaleAccounts {
        uint256 tokenAmount;
        uint256 price;
    }

    address private _admin;
    uint256 public preSalePrice;
    uint256 public preSaleLimit;
    uint256 public salePrice;
    uint256 public saleLimit;
    uint256 public saleStartTime;
    uint256 public saleEndTime;
    uint256 private _totalPriceEarned;
    mapping (address => PreSaleAccounts) public preSaleAccount;
    mapping (address => SaleAccounts) public saleAccount;

    event WhileListUpdated(address indexed account, bool allowed);
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);

    constructor(
        uint256 _preSalePrice, 
        uint256 _preSaleLimit, 
        uint256 _salePrice, 
        uint256 _saleLimit, 
        uint256 _saleStartTime, 
        uint256 _saleEndTime) ERC20("MyToken", "MTK") {
        _mint(msg.sender, 10000 * (10 ** uint(decimals())));
        _admin = msg.sender;
        preSalePrice = _preSalePrice;
        preSaleLimit = _preSaleLimit;
        salePrice = _salePrice;
        saleLimit = _saleLimit;
        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;
    }

    modifier onlyAdmin() {
        require(msg.sender == _admin, "Only admin can call this function");
        _;
    }

    function addToWhiteList(address[] memory _accounts) public onlyAdmin {
        for (uint256 i = 0; i < _accounts.length; i++) {
            preSaleAccount[_accounts[i]].whileListAccounts = true;
            emit WhileListUpdated(_accounts[i], true);
        }
    }

    function preSale(uint256 _amount) public payable {
        require(block.timestamp < saleStartTime, "Presale is not active");
        require(preSaleAccount[msg.sender].whileListAccounts, "Account is not whileListed");
        require(_amount > 0, "Token amount can not be zero");
        require(preSaleAccount[msg.sender].tokenAmount + _amount <= preSaleLimit, "Exceeds presale limit");
        uint256 totalCost = _amount * preSalePrice;
        require(msg.value == totalCost, "Incorrect Amount sent");
        _transfer(_admin, msg.sender, _amount);
        preSaleAccount[msg.sender].tokenAmount += _amount;
        preSaleAccount[msg.sender].price += totalCost;
        _totalPriceEarned += totalCost;
        emit TokensPurchased(msg.sender, _amount, totalCost);
    }

    function sale(uint256 _amount) public payable {
        require(block.timestamp >= saleStartTime && block.timestamp <= saleEndTime, "Sale is not active");
        require(_amount > 0, "Token amount can not be zero");
        require(saleAccount[msg.sender].tokenAmount + _amount <= saleLimit, "Exceeds sale limit");
        uint256 totalCost = _amount * salePrice;
        require(msg.value == totalCost, "Incorrect Amount sent");
        _transfer(_admin, msg.sender, _amount);
        saleAccount[msg.sender].tokenAmount += _amount;
        saleAccount[msg.sender].price += totalCost;
        _totalPriceEarned += totalCost;
        emit TokensPurchased(msg.sender, _amount, totalCost);
    }

    function withdraw() public onlyAdmin {
        uint256 profit = _totalPriceEarned;
        require(profit > 0, "No profit is availabel to withdraw");
        _totalPriceEarned = 0;
        payable(_admin).transfer(profit);
    }
}