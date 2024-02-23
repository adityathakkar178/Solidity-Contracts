// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

contract bank2{
    struct Account {
        uint balance;
        bool hasDeposited;
    } 

    struct Loan {
        uint amount;
        uint startTime;
        uint loanInterest;
    }

    struct Deposit {
        uint amount;
        uint startTime;
        uint duration;
        uint depositeInterest;
        uint penalty;
        bool withdrawn;
    }

    struct Investor {
        uint sharesOwned;
        uint cost;
        uint startTime;
    }

    enum Duration {
        DAYS_7,
        DAYS_14,
        DAYS_28
    }
    
    mapping (address => Account) public accounts;   
    mapping (address => Loan) public loans;
    mapping (address => Deposit) public fixDeposit;
    mapping (address => Investor) public sharesOwner;
    address public admin;
    uint public adminInvesment;
    uint public interestRate;
    uint public depositInterestRate;
    uint public penaltyRate;
    uint public totalProfitearned;
    uint public totalShares = 100 ;
    uint public remainingShares;

    constructor(uint _initialInterest, uint _depositInterestRate, uint _penaltyRate) payable   {
        admin = msg.sender;
        adminInvesment = msg.value;
        interestRate = _initialInterest;
        depositInterestRate = _depositInterestRate;
        penaltyRate = _penaltyRate;
        sharesOwner[admin].sharesOwned = 51;
        remainingShares = totalShares - sharesOwner[admin].sharesOwned;
        sharesOwner[admin].startTime = block.timestamp;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    function deposit() public payable {
        require(msg.value > 0, "You can not deppsit Zero");
        Account storage userAccount = accounts[msg.sender];
        userAccount.balance += msg.value;
        userAccount.hasDeposited = true;
    }

    function withdraw(uint _amount) public  {  
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(accounts[msg.sender].balance >= _amount, "Insuffcient Balance");
        accounts[msg.sender].balance -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    function transferr(address payable  _to, uint _amount) public {
        require(accounts[msg.sender].balance >= _amount, "Insuffcient Balance");
        require(accounts[_to].hasDeposited, "Reciver has not interacted with the contract");    
        accounts[msg.sender].balance -= _amount;
        accounts[_to].balance += _amount;
    }

    function setLoanInterest(uint _interestRate) public onlyAdmin {
        require(_interestRate > 0, "Interest rate can not be zero");
        interestRate = _interestRate;
    }

    function setdepositInterest(uint _depositInterestRate) public onlyAdmin {
        require(_depositInterestRate > 0, "Interest rate can not be zero");
        depositInterestRate = _depositInterestRate;
    }

    function setPenalty(uint _penalty) public onlyAdmin {
        require(_penalty > 0, "Interest rate can not be zero");
        penaltyRate = _penalty;
    }

    function takeLoan(uint _amount) public {
        require(accounts[msg.sender].hasDeposited, "User must deposited to take loan");
        require(loans[msg.sender].amount == 0, "User can not take new loan untill old loan is paid");
        require(_amount > 0, "Loan must be graeter than zero");
        require(_amount <= 2 ether, "Loan must be less than 2 ethers");
        require(_amount <= adminInvesment, "Total loan must be less than admins invesments");
        loans[msg.sender] = Loan(_amount, block.timestamp, interestRate);
        adminInvesment -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    function repayLoan() public payable {
        require(loans[msg.sender].amount > 0, "You have no loan to repay");
        require(msg.value > 0, "Repay amount should be greater than 0");
        require(msg.value <= loans[msg.sender].amount, "Repayment Amount Should be less than or equal to the loan aamount");
        uint actualDuration = (block.timestamp - loans[msg.sender].startTime);
        uint interest = (msg.value * interestRate * actualDuration) / (100 * 365 days);
        uint amount = msg.value + interest;
        require(amount >= msg.value, "Amount deducting from the balance should repayment amount plus interest");
        loans[msg.sender].amount = loans[msg.sender].amount - msg.value;
        totalProfitearned += interest; 
    }

    function openFixDeposit(Duration _duration) public payable  {
        require(accounts[msg.sender].hasDeposited, "User should interact with the contract to do fix deposite");
        require(fixDeposit[msg.sender].amount == 0, "User can not do new fix deposite until old deposite is withdrawn");
        require(msg.value >= 1 ether && msg.value <= 5 ether, "Deposite Amout should be less than or equal to 5 ethers and more than or equal 1 ether");
        uint durationDays;
        if (_duration == Duration.DAYS_7) {
            durationDays = 7;
        } else if (_duration == Duration.DAYS_14) {
            durationDays = 14;
        } else if (_duration == Duration.DAYS_28) {
            durationDays = 28;
        } else {
            revert("user can open a fixed deposit of 3 time periods only 7 days, 14 days, 28 days");
        }
        fixDeposit[msg.sender] = Deposit(msg.value, block.timestamp, (durationDays * 1 days), depositInterestRate, penaltyRate, false);
    } 

    function claimFd() public {
        require(!fixDeposit[msg.sender].withdrawn, "User has no deposit to withdraw");
        require(block.timestamp >= fixDeposit[msg.sender].startTime + fixDeposit[msg.sender].duration, "Deposit period has not elapsed");
        uint depositInterest = (fixDeposit[msg.sender].amount * depositInterestRate * fixDeposit[msg.sender].duration) / (100 * 365 days);
        uint totalReturn = fixDeposit[msg.sender].amount + depositInterest;
        require(adminInvesment >= depositInterest, "Admins invsetment should have enough balance to pay the interest");
        adminInvesment -= depositInterest;
        payable(msg.sender).transfer(totalReturn);
        fixDeposit[msg.sender].amount -= fixDeposit[msg.sender].amount;
        fixDeposit[msg.sender].withdrawn = true;
    }

    function breakFd() public {
        require(!fixDeposit[msg.sender].withdrawn, "User has no deposit to withdraw");
        require(block.timestamp < fixDeposit[msg.sender].startTime + fixDeposit[msg.sender].duration, "Deposit period has already elapsed");
        uint userPenalty = (fixDeposit[msg.sender].amount * penaltyRate) / 100;
        totalProfitearned += userPenalty;
        uint remainingDeposit = fixDeposit[msg.sender].amount - userPenalty;
        payable(msg.sender).transfer(remainingDeposit);
        fixDeposit[msg.sender].amount -= fixDeposit[msg.sender].amount;
        fixDeposit[msg.sender].withdrawn = true;
    }

    function buyShares(uint _sharesToBuy) public payable {
        require(msg.value > 0, "You can not buy zero shares");
        uint shareCost = _sharesToBuy * 1 ether;
        require(msg.value == shareCost, "payment for shares should be equal to share cost");
        require(remainingShares >= _sharesToBuy, "Insuffcient Shares");
        remainingShares -= _sharesToBuy;
        sharesOwner[msg.sender].sharesOwned += _sharesToBuy;
        sharesOwner[msg.sender].cost += shareCost;
        sharesOwner[msg.sender].startTime = block.timestamp;
    }

    function claimShareProfit() public {
        require(sharesOwner[msg.sender].sharesOwned >0, "You should have shares to claim");
        require(block.timestamp >= sharesOwner[msg.sender].startTime + 1 days, "You need to invest for at least 24 hours");
        uint invesetmentDuration = (block.timestamp - sharesOwner[msg.sender].startTime) / 1 days;
        uint profit = (sharesOwner[msg.sender].cost * sharesOwner[msg.sender].sharesOwned * invesetmentDuration) / (totalShares * 100);
        sharesOwner[msg.sender].startTime = block.timestamp;
        payable(msg.sender).transfer(profit);
    }

    function withdrawProfit() public onlyAdmin {
        uint profit = totalProfitearned;
        require(profit > 0, "No profit is availabel to withdraw");
        totalProfitearned = 0;
        payable(admin).transfer(profit);
    }
}
