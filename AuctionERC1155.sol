// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

contract MyERC1155 is ERC1155, ERC1155URIStorage{
    struct Auction {
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 startingPrice;
        uint256 unlimitedAuctionStartTime;
    }

    struct TimedAuction {
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 auctionStartingTime;
        uint256 auctionEndTime;
    }

    struct Bid {
        address bidder;
        uint256 biddingPrice;
    }

    address private _admin;
    uint256 private _tokenIdCounter;
    mapping (string => bool) private _uris;
    mapping (uint256 => address) private _creator;
    mapping (uint256 => mapping (address => Auction)) public unlimitedAuctions;
    mapping (uint256 => mapping (address => TimedAuction)) public timedAuctions;
    mapping (uint256 => mapping (address => Bid[])) public bidders; 

    constructor() ERC1155("") {
        _admin = msg.sender;
    }

    function mint(uint256 _amount, string memory _tokenURI) public {
        require(_amount > 0, "Amount must be grater than zero");
        require(bytes(_tokenURI).length > 0, "TokenURI can not be empty");
        require(!_uris[_tokenURI], "URI already exists");
        _tokenIdCounter++;
        uint256 id = _tokenIdCounter;
        _mint(msg.sender, id, _amount, "");
        _setURI(id, _tokenURI);
        _uris[_tokenURI] = true;
        _creator[id] = msg.sender;
    }

    function mintToExisiting(uint256 _tokenId, uint256 _amount) public{
       require(msg.sender == _creator[_tokenId], "You are not the orginal creator of this token");
        require(_amount > 0, "Amount must be gerater than zero");
        _mint(msg.sender, _tokenId, _amount, "");
    } 

    function uri(uint256 tokenId) public view override(ERC1155URIStorage, ERC1155) returns (string memory) {
        return super.uri(tokenId);
    }

    // unlimited auction starts here
    function startUnlimitedAuction(uint256 _tokenId, uint256 _amount, uint256 _startingPrice) public {
        require(_amount > 0 && _startingPrice > 0, "Amount and starting price must be greate than zero");
        require(balanceOf(msg.sender, _tokenId) >= _amount, "Insufficent balance");
        unlimitedAuctions[_tokenId][msg.sender] = Auction(msg.sender, _tokenId, _amount, _startingPrice, block.timestamp);
    }

    function placeBid(uint256 _tokenId, address _seller) public payable {
        require(msg.sender != unlimitedAuctions[_tokenId][_seller].seller, "Seller can not place bid");
        require(msg.value > unlimitedAuctions[_tokenId][_seller].startingPrice, "Bidding price must be greater than starting price");
        bidders[_tokenId][_seller].push(Bid(msg.sender, msg.value));
    }

    function acceptBid(uint256 _tokenId, uint256 _bid) public {
        Auction memory auction = unlimitedAuctions[_tokenId][msg.sender];
        Bid memory selectedBid = bidders[_tokenId][msg.sender][_bid];
        require(msg.sender == auction.seller, "Only seller can accept a bid");
        require(selectedBid.biddingPrice >= auction.startingPrice, "Bid price must be equal or greater than starting price");
        safeTransferFrom(auction.seller, selectedBid.bidder, _tokenId, auction.amount, "");
        payable(auction.seller).transfer(selectedBid.biddingPrice);
        uint256 numBidders = bidders[_tokenId][msg.sender].length;
        for (uint256 i = 0; i < numBidders; i++) {
            if (i != _bid) {
                Bid storage remainingBid = bidders[_tokenId][msg.sender][i];
                payable(remainingBid.bidder).transfer(remainingBid.biddingPrice);
            }
        }
        delete bidders[_tokenId][msg.sender];
        delete unlimitedAuctions[_tokenId][msg.sender];
    }

    function withdrawBid(uint256 _tokenId, address _seller) public {
        uint256 numBids = bidders[_tokenId][_seller].length;
        bool found = false;
        for (uint256 i = 0; i < numBids; i++) {
            if (bidders[_tokenId][_seller][i].bidder == msg.sender) {
                Bid memory withdrawnBid = bidders[_tokenId][_seller][i];                
                payable(msg.sender).transfer(withdrawnBid.biddingPrice);                
                delete bidders[_tokenId][_seller][i];
                found = true;
                break;
            }
        }
        require(found, "No bid to withdraw for this seller's auction");
    }

   function rejectBid(uint256 _tokenId, uint256 _bid) public {
        require(msg.sender == unlimitedAuctions[_tokenId][msg.sender].seller, "Only seller can reject a bid");
        Bid memory rejectedBid = bidders[_tokenId][msg.sender][_bid];
        payable(rejectedBid.bidder).transfer(rejectedBid.biddingPrice);
        delete bidders[_tokenId][msg.sender][_bid];
    }

    function withdrawAuction(uint256 _tokenId) public {
        require(msg.sender == unlimitedAuctions[_tokenId][msg.sender].seller, "Only seller can withdraw auction");
        require(bidders[_tokenId][msg.sender].length == 0, "Cannot withdraw auction once bids have been placed");
        delete unlimitedAuctions[_tokenId][msg.sender];
    }


    // Unlimited auction ends here

    // Timed auction starts here 
    function startTimedAuction(uint256 _tokenId, uint256 _amount, uint256 _startingPrice, uint256 _auctionEndTime) public {
        require(_amount > 0 && _startingPrice > 0, "Amount and starting price must be greater than zero");
        require(balanceOf(msg.sender, _tokenId) >= _amount, "Insufficient balance");
        timedAuctions[_tokenId][msg.sender] = TimedAuction(msg.sender, _tokenId, _amount, _startingPrice, 0, address(0), block.timestamp, _auctionEndTime);
    }

    function placeTimedBid(uint256 _tokenId, address _seller) public payable{
        require(block.timestamp <= timedAuctions[_tokenId][_seller].auctionEndTime, "Auction has ended");
        require(msg.sender != timedAuctions[_tokenId][_seller].seller, "Seller can not place bid");
        require(msg.sender != timedAuctions[_tokenId][_seller].highestBidder, "You already have highest bid");
        address currentHighestBidder = timedAuctions[_tokenId][_seller].highestBidder;
        uint256 currentHighestBid = timedAuctions[_tokenId][_seller].highestBid;
        if (currentHighestBid > 0) {
            require(msg.value > currentHighestBid, "Bid must be greater than previous bid");
            payable(currentHighestBidder).transfer(currentHighestBid);
        } else {
            require(msg.value > timedAuctions[_tokenId][_seller].startingPrice, "Bid must be greater than the starting price");
        }
        timedAuctions[_tokenId][_seller].highestBid = msg.value;
        timedAuctions[_tokenId][_seller].highestBidder = msg.sender;
    }

    function claimBid(uint256 _tokenId, address _seller) public {
        require(block.timestamp >= timedAuctions[_tokenId][_seller].auctionEndTime, "Auction has not ended yet");
        require(msg.sender == timedAuctions[_tokenId][_seller].highestBidder, "Highest bidder can claim the bid");
        _safeTransferFrom(timedAuctions[_tokenId][_seller].seller, timedAuctions[_tokenId][_seller].highestBidder, _tokenId, timedAuctions[_tokenId][_seller].amount, "");
       payable(timedAuctions[_tokenId][_seller].seller).transfer(timedAuctions[_tokenId][_seller].highestBid);
       delete timedAuctions[_tokenId][_seller]; 
    }

    function cancelAuction(uint256 _tokenId) public {
        require(block.timestamp < timedAuctions[_tokenId][msg.sender].auctionEndTime, "Auction has ended");
        require(msg.sender == timedAuctions[_tokenId][msg.sender].seller, "Only seller can cancel the auction");
        require(timedAuctions[_tokenId][msg.sender].highestBidder == address(0), "Can not withdraw auction once bid has placed");
        delete timedAuctions[_tokenId][msg.sender];
    }
    // Timed auction ends here
}
