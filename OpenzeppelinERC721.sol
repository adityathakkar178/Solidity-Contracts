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
        uint256 highestBid;
        address highestBidder;
        uint256 auctionStartTime;
        uint256 auctionEndTime;
    }

    address private _admin;
    uint256 private _tokenIdCounter;
    uint256 private _adminCommission;
    uint256 private _commissionRate;
    uint256 private _mintCommission;
    mapping (string => bool) private _tokenURIs;
    mapping (uint256 => Creatores) public creator;
    mapping (uint256 => SaleAccount) public saleToken;
    mapping (uint256 => Auction) public auctions;
    
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

    function startAuction(uint256 _tokenId, uint256 _startingPrice, uint256 _auctionEndTime) public {
        require(ownerOf(_tokenId) == msg.sender, "You are not the owner of the token");
        require(_startingPrice > 0, "Price should be gretaer than zero");
        require(_auctionEndTime > block.timestamp, "Auction end time must be greater than start time");
        auctions[_tokenId] = Auction(msg.sender, _tokenId, _startingPrice, 0, address(0), block.timestamp, _auctionEndTime);
    }

   function placeBid(uint256 _tokenId) public payable {
        require(block.timestamp <= auctions[_tokenId].auctionEndTime, "Auction has ended");
        require(msg.sender != auctions[_tokenId].highestBidder, "You already have the highest bid");
        require(msg.sender != auctions[_tokenId].seller, "Seller can not place bid");
        uint256 currentHighestBid = auctions[_tokenId].highestBid;
        address currentHighestBidder = auctions[_tokenId].highestBidder;
        if (currentHighestBid > 0) {
            require(msg.value > currentHighestBid, "Bid must be greater than currrent highest bid");
            payable(currentHighestBidder).transfer(currentHighestBid);
        } else {
            require(msg.value > auctions[_tokenId].startingPrice, "Bid value must br freater than zero");
        }
        auctions[_tokenId].highestBid = msg.value;
        auctions[_tokenId].highestBidder = msg.sender;
    } 

    function transferAfterAuction(uint256 _tokenId) public {
        require(block.timestamp >= auctions[_tokenId].auctionEndTime, "Auction has not ended yet");
        require(msg.sender == auctions[_tokenId].seller, "Only seller can call this function");
        _transfer(auctions[_tokenId].seller, auctions[_tokenId].highestBidder, _tokenId);
        payable(auctions[_tokenId].seller).transfer(auctions[_tokenId].highestBid);
        delete auctions[_tokenId];
    }

    function withdrawBid(uint256 _tokenId) public {
        require(auctions[_tokenId].highestBidder == msg.sender, "You have not placed the highest bid");
        require(block.timestamp < auctions[_tokenId].auctionEndTime, "Auction has ended");
        uint256 bidderAmount = auctions[_tokenId].highestBid;
        auctions[_tokenId].highestBid = 0;
        auctions[_tokenId].highestBidder = address(0);
        payable(msg.sender).transfer(bidderAmount);
    }

    function rejectBid(uint256 _tokenId) public {
        require(block.timestamp >= auctions[_tokenId].auctionEndTime, "Auction has not ended yet");
        require(msg.sender == auctions[_tokenId].seller, "Only seller can reject the bid");
        require(auctions[_tokenId].highestBid > 0, "There is no bid to reject");
        uint256 currentHighestBid = auctions[_tokenId].highestBid;
        address currentHighestBidder = auctions[_tokenId].highestBidder;
        auctions[_tokenId].highestBid = 0;
        auctions[_tokenId].highestBidder = address(0);
        payable(currentHighestBidder).transfer(currentHighestBid);
    }

    function withdrawAuction(uint256 _tokenId) public {
        require(block.timestamp < auctions[_tokenId].auctionEndTime, "Auction has ended");
        require(msg.sender == auctions[_tokenId].seller, "Only seller can withdraw auction");
        uint256 currentHighestBid = auctions[_tokenId].highestBid;
        address currentHighestBidder = auctions[_tokenId].highestBidder;
        if (currentHighestBidder != address(0)) {
            payable(currentHighestBidder).transfer(currentHighestBid);
        }
        delete auctions[_tokenId];
    }
    
    function supportsInterface(bytes4 _interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool){
        return super.supportsInterface(_interfaceId);
    }
}
