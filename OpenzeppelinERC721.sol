// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyERC721 is ERC721, ERC721URIStorage{
    uint256 private _tokenIdCounter = 0;
    string private _baseUri;
    mapping (string => bool) private _tokenURIs;
    
    constructor() ERC721("My Token", "MTK") {}

    function mint(string memory _tokenName, string memory _tokenURI) public {
        require(bytes(_tokenName).length > 0 && bytes(_tokenURI).length > 0, "Token name, Token id, Token URI can not be empty");
        require(!_tokenURIs[_tokenURI], "Token URI already exists");
        _tokenURIs[_tokenURI] = true;
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }

    function _baseURI() internal view override returns(string memory) {
        return _baseUri;
    }

    function setBaseURI(string memory _baseTokenURI) public {
        _baseUri = _baseTokenURI;
    } 

    function tokenURI(uint256 _tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(_tokenId);
    }
    
    function supportsInterface(bytes4 _interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool){
        return super.supportsInterface(_interfaceId);
    }
}
