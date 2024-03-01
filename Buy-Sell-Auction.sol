// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyERC721 is ERC721, ERC721URIStorage{
    struct Creatores {
        address actualOwner;
        uint256 royaltyRate;
    }

    struct SaleAccount {
        address seller;
        uint256 tokenId;
        uint256 price;
    }

    struct Auction {
        address seller;
        uint256 tokenId;
        uint256 startingPrice;
        uint256 auctionStartTime;
    }

    struct TimedAuction {
        address seller;
        uint256 tokenId;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 auctionStartTime;
        uint256 auctionEndTime;
    }

    struct Bid {
        address bidder;
        uint256 amount;
    }

    address private _admin;
    uint256 private _tokenIdCounter;
    uint256 private _adminCommission;
    uint256 private _commissionRate;
    uint256 private _mintCommission;
    mapping (string => bool) private _tokenURIs;
    mapping (uint256 => Creatores) public creator;
    mapping (uint256 => SaleAccount) public saleToken;
    mapping (uint256 => Auction) public unlimtedAuctions;
    mapping (uint256 => TimedAuction) public timedAuctions;
    mapping (uint256 => Bid[]) public bids;
    
    constructor(uint256 _price, uint256 _adminCommissionRate) ERC721("My Token", "MTK") {
        _admin = msg.sender;
        _mintCommission = _price;
        _commissionRate = _adminCommissionRate;
    }

    function mint(string memory _tokenName, string memory _tokenURI, uint256 _royaltyPercentage) public payable {
        require(bytes(_tokenName).length > 0 && bytes(_tokenURI).length > 0, "Token name, Token id, Token URI can not be empty");
        require(!_tokenURIs[_tokenURI], "Token URI already exists");
        require(msg.value == _mintCommission, "Incorrect amount sent");
        require(_royaltyPercentage > 0 && _royaltyPercentage <= 10, "Owner can take royalty between 1 to 10 percent");
        _tokenURIs[_tokenURI] = true;
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        _adminCommission += _mintCommission;
        creator[tokenId] = Creatores(msg.sender, _royaltyPercentage);
    }

    function tokenURI(uint256 _tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(_tokenId);
    }

    // Buy and Sell starts here
    function sell(uint256 _tokenId, uint256 _price) public {
        require(ownerOf(_tokenId) == msg.sender, "You are not the owner of the token");
        require(_price > 0, "Price should be greater than zero");
        saleToken[_tokenId] = SaleAccount(msg.sender, _tokenId, _price);
    }

    function buy(uint256 _tokenId) public payable {
        require(saleToken[_tokenId].seller != address(0), "Token not for sale");
        require(msg.value == saleToken[_tokenId].price, "Incorrect amount sent");
        uint256 adminCommission = (saleToken[_tokenId].price * _commissionRate) / 100;
        uint256 royalty = 0;
        if(saleToken[_tokenId].seller != creator[_tokenId].actualOwner) {
            royalty = (saleToken[_tokenId].price * creator[_tokenId].royaltyRate) / 100;
        }
        uint256 remainingAmount = msg.value - (adminCommission + royalty);
        _transfer(saleToken[_tokenId].seller, msg.sender, _tokenId);
        if (royalty > 0) {
            payable(creator[_tokenId].actualOwner).transfer(royalty);   
        }
        payable(saleToken[_tokenId].seller).transfer(remainingAmount);
        _adminCommission += adminCommission;
        delete saleToken[_tokenId];
    }
    // Buy and Sell ends here

    // Unlimited Auction starts here
    function startUnlimitedAuction(uint256 _tokenId, uint256 _startingPrice) public {
        require(ownerOf(_tokenId) == msg.sender, "You are not the owner of the token");
        require(_startingPrice > 0, "Price should be gretaer than zero");
        unlimtedAuctions[_tokenId] = Auction(msg.sender, _tokenId, _startingPrice, block.timestamp);
    }

   function placeBid(uint256 _tokenId) public payable {
        require(unlimtedAuctions[_tokenId].auctionStartTime > 0, "The auction for this token has not started yet");
        require(msg.sender != unlimtedAuctions[_tokenId].seller, "Seller can not place bid");
        require(msg.value > unlimtedAuctions[_tokenId].startingPrice, "Bid value must be greater than starting price");
        Bid memory newBid = Bid(msg.sender, msg.value);
        bids[_tokenId].push(newBid);
    } 

    function getBidders(uint256 _tokenId) public view returns (address[] memory, uint256[] memory) {
        uint256 numBids = bids[_tokenId].length;
        address[] memory bidders = new address[](numBids);
        uint256[] memory amounts = new uint256[](numBids);
        for (uint256 i = 0; i < numBids; i++) {
            bidders[i] = bids[_tokenId][i].bidder;
            amounts[i] = bids[_tokenId][i].amount;
        }
        return (bidders, amounts);
    }

    function acceptBid(uint256 _tokenId, uint256 _bidder) public {
        require(msg.sender == unlimtedAuctions[_tokenId].seller, "Only seller can call this function");
        require(_bidder < bids[_tokenId].length, "Invalid bidder");
        address selectBidder = bids[_tokenId][_bidder].bidder;
        uint256 selectAmount = bids[_tokenId][_bidder].amount;
        _transfer(unlimtedAuctions[_tokenId].seller, selectBidder, _tokenId);
        payable(unlimtedAuctions[_tokenId].seller).transfer(selectAmount);
        for (uint256 i = 0; i < bids[_tokenId].length; i++) {
            if (i != _bidder) {
                address nonSelectedAddress = bids[_tokenId][i].bidder;
                uint256 nonSelectedAmount = bids[_tokenId][i].amount;
                payable(nonSelectedAddress).transfer(nonSelectedAmount);
            }
        }
        delete bids[_tokenId];
        delete unlimtedAuctions[_tokenId];
    }

    function withdrawBid(uint256 _tokenId) public {
        require(bids[_tokenId].length > 0, "No bids for this token");
        uint256 numBids = bids[_tokenId].length;
        bool found;
        for (uint256 i = 0; i < numBids; i ++) {
            if (bids[_tokenId][i].bidder == msg.sender) {
                uint256 bidderAmount = bids[_tokenId][i].amount;
                payable(msg.sender).transfer(bidderAmount);
                found = true;
                delete bids[_tokenId][i];
                break;
            }
        }
        require(found, "You have not palced bid for this token");
    }

    function rejectBid(uint256 _tokenId, uint256 _bidder) public {
        require(msg.sender == unlimtedAuctions[_tokenId].seller, "Only seller can reject the bid");
        require(_bidder < bids[_tokenId].length, "Invalid Bidder");
        address selectBidder = bids[_tokenId][_bidder].bidder;
        uint256 selectAmount = bids[_tokenId][_bidder].amount;
        payable(selectBidder).transfer(selectAmount);
        delete bids[_tokenId][_bidder];
    }

    function withdrawAuction(uint256 _tokenId) public {
        require(msg.sender == unlimtedAuctions[_tokenId].seller, "Only seller can withdraw auction");
        for (uint256 i = 0; i < bids[_tokenId].length; i++) {
            payable(bids[_tokenId][i].bidder).transfer(bids[_tokenId][i].amount);
        }
        delete bids[_tokenId];
        delete unlimtedAuctions[_tokenId];
    }
    //Unlimeted Auction endes here

    //Timed Auction starts here
    function startTimedAuction(uint256 _tokenId, uint256 _startingPrice, uint256 _auctionEndTime) public {
        require(ownerOf(_tokenId) == msg.sender, "You are not the owner of the token");
        require(_startingPrice > 0, "Price should be gretaer than zero");
        require(_auctionEndTime > block.timestamp, "Auction end time must be greater than start time");
        timedAuctions[_tokenId] = TimedAuction(msg.sender, _tokenId, _startingPrice, 0, address(0), block.timestamp, _auctionEndTime);
    }

    function placeTimedBid(uint256 _tokenId) public payable {
        require(timedAuctions[_tokenId].auctionStartTime > 0 && block.timestamp <= timedAuctions[_tokenId].auctionEndTime, "Auction has ended");
        require(block.timestamp <= timedAuctions[_tokenId].auctionEndTime, "Auction has ended");
        require(msg.sender != timedAuctions[_tokenId].highestBidder, "You already have the highest bid");
        require(msg.sender != timedAuctions[_tokenId].seller, "Seller can not place bid");
        uint256 currentHighestBid = timedAuctions[_tokenId].highestBid;
        address currentHighestBidder = timedAuctions[_tokenId].highestBidder;
        if (currentHighestBid > 0) {
            require(msg.value > currentHighestBid, "Bid must be greater than currrent highest bid");
            payable(currentHighestBidder).transfer(currentHighestBid);
        } else {
            require(msg.value > timedAuctions[_tokenId].startingPrice, "Bid value must br greater than zero");
        }
        timedAuctions[_tokenId].highestBid = msg.value;
        timedAuctions[_tokenId].highestBidder = msg.sender;
    } 

    function claimBid(uint256 _tokenId) public {
        require(block.timestamp >= timedAuctions[_tokenId].auctionEndTime, "Auction has not ended yet");
        require(msg.sender == timedAuctions[_tokenId].highestBidder, "Only highest bidder can calim bid");
        _transfer(timedAuctions[_tokenId].seller, timedAuctions[_tokenId].highestBidder, _tokenId);
        payable(timedAuctions[_tokenId].seller).transfer(timedAuctions[_tokenId].highestBid);
        delete timedAuctions[_tokenId];
    }

    function cancleAuction(uint256 _tokenId) public {
        require(block.timestamp < timedAuctions[_tokenId].auctionEndTime, "Auction has ended");
        require(timedAuctions[_tokenId].highestBidder == address(0), "Can not withdraw Auction once bid is placed");
        require(msg.sender == timedAuctions[_tokenId].seller, "Only seller can withdraw auction");
        delete timedAuctions[_tokenId];
    }
    // Timed Auction ends here
    
    function supportsInterface(bytes4 _interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool){
        return super.supportsInterface(_interfaceId);
    }
}
