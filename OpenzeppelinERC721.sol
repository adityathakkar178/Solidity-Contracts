// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyERC721 is ERC721 {
    uint256 private _tokenIdCounter = 0;
    string private _baseUri;
    mapping (uint256 => string) private _tokenURIs; 

    constructor() ERC721("My Token", "MTK") {}

    function mint(string memory _tokenName, string memory _tokenURI) public {
        require(bytes(_tokenName).length > 0 && bytes(_tokenURI).length > 0, "Token name, Token id, Token URI can not be empty");
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }

    function setBaseURI(string memory _baseURI) public {
        _baseUri = _baseURI;
    }

    function _setTokenURI(uint256 _tokenId, string memory _tokenURI) internal {
        _tokenURIs[_tokenId] = _tokenURI;
    }

    function getTokenURI(uint256 _tokenId) public view returns(string memory) {
        require(ownerOf(_tokenId) != address(0), "Token Id does not exist");
        return string(abi.encodePacked(_baseUri, _tokenURIs[_tokenId]));
    } 
}