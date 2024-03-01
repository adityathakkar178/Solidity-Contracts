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

    address private _admin;
    uint256 private _tokenIdCounter;
    uint256 private _adminCommission;
    uint256 private _commissionRate;
    uint256 private _mintCommission;
    mapping (string => bool) private _tokenURIs;
    mapping (uint256 => Creatores) public creator;
    mapping (uint256 => SaleAccount) public saleToken;
    
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
    
    function supportsInterface(bytes4 _interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool){
        return super.supportsInterface(_interfaceId);
    }
}
