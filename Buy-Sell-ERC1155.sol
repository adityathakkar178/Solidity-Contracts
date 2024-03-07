// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MyERC1155 is ERC1155{
    struct Creators {
        address actualOwner;
        uint256 royaltyRate;
    }

    struct Seller {
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
    }

    address private _admin;
    uint256 private _tokenIdCounter;
    uint256 private _mintCommission;
    uint256 private _adminCommission; 
    uint256 private _commissionRate;
    mapping (string => bool) private _uris;
    mapping (uint256 => Creators) public creator;
    mapping (uint256=>Seller[]) public saleToken;

    constructor(uint256 _price, uint256 _adminCommissionRate) ERC1155("") {
        _admin = msg.sender;
        _mintCommission = _price;
        _commissionRate = _adminCommissionRate;
    }

    function mint(uint256 _amount, uint256 _royaltyPercentage, string memory _tokenURI) public payable {
        require(_amount > 0, "Amount must be grater than zero");
        require(bytes(_tokenURI).length > 0, "TokenURI can not be empty");
        require(!_uris[_tokenURI], "URI already exists");
        require(msg.value == _mintCommission, "Incorrect price sent");
        require(_royaltyPercentage > 0 && _royaltyPercentage <= 10, "Owner can take royalty between 1 to 10 percent");
        _tokenIdCounter++;
        uint256 id = _tokenIdCounter;
        _mint(msg.sender, id, _amount, "");
        _setURI(_tokenURI);
        _uris[_tokenURI] = true;
        _adminCommission += _mintCommission;
        creator[id] = Creators(msg.sender, _royaltyPercentage);
    }

    function mintToExisiting(uint256 _tokenId, uint256 _amount) public{
        require(msg.sender == creator[_tokenId].actualOwner, "You are not the original creator of this token");
        require(_amount > 0, "Amount must be gerater than zero");
        _mint(msg.sender, _tokenId, _amount, "");
    } 

    function sell(uint256 _tokenId, uint256 _amount, uint256 _price) public {
        require(balanceOf(msg.sender, 1) >=_amount, "Insufficient balance");
        require(_price > 0, "Price must be gerater than zero");
        saleToken[_tokenId].push(Seller(msg.sender, _tokenId, _amount, _price));
    }

    function getSellers(uint256 _tokenId) public view returns(Seller[] memory) {
        return saleToken[_tokenId];
    }

    function buy(uint256 _tokenId, uint256 _seller) public payable{
        require(saleToken[_tokenId].length > 0, "Token not for sell");
        require(msg.value == saleToken[_tokenId][_seller].price, "Incorrect amount sent");
        uint256 adminCommission = (saleToken[_tokenId][_seller].price * _commissionRate) / 100;
        uint256 royalty = 0;
        if(saleToken[_tokenId][_seller].seller != creator[_tokenId].actualOwner) {
            royalty = (saleToken[_tokenId][_seller].price * creator[_tokenId].royaltyRate) / 100;
        }
        uint256 remainingAmount = msg.value - (adminCommission + royalty);
        _safeTransferFrom(saleToken[_tokenId][_seller].seller, msg.sender, _tokenId, saleToken[_tokenId][_seller].amount, "");
        if (royalty > 0) {
            payable(creator[_tokenId].actualOwner).transfer(royalty);
        }
        payable(saleToken[_tokenId][_seller].seller).transfer(remainingAmount);
        _adminCommission += adminCommission;
        delete saleToken[_tokenId][_seller];
    }

    function withdraw() public {
        require(msg.sender == _admin, "Only admin can withdraw");
        uint256 commission = _adminCommission;
        require(commission > 0, "No commission to withdraw");
        payable(_admin).transfer(commission);
    }
}
