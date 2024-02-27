// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

interface ERC165 {
    function supportsInterface(bytes4 interfaceId) external pure returns (bool);
}

contract ERC721 is ERC165{
    mapping (address => uint256) public  balance;
    mapping (string => uint256) public tokens;
    mapping (uint256 => address) public owner;
    mapping (uint256 => address) private _approved;
    mapping (address => mapping (address => bool)) private _approvedForAll;
    mapping (uint256 => string) private _tokenURIs; 
    string private _baseUri;
    uint256 private _tokenIdCounter = 0;

    event Transfer(address indexed from, address indexed to, uint256 _tokenId);
    event Approval(address indexed owner, address indexed approve, uint256 _tokenId);
    event ApprovalForAll(address indexed owner, address operator, bool _approve);
    
    function mint(string memory _tokenName, string memory _tokenURI) public {
        require(bytes(_tokenName).length > 0 && bytes(_tokenURI).length > 0, "Token name, Token id, Token URI can not be empty");
        _tokenIdCounter++;
        uint256 _tokenId = _tokenIdCounter;
        require(owner[_tokenId] == address(0), "Token Id already exists");
        owner[_tokenId] = msg.sender;
        balance[msg.sender]++;
        tokens[_tokenName] = _tokenId;
        setTokenURI(_tokenId, _tokenURI);
    }

    function setBaseURI(string memory _baseURI) public {
        _baseUri = _baseURI;
    }

    function setTokenURI(uint256 _tokenId, string memory _tokenURI) internal {
        _tokenURIs[_tokenId] = _tokenURI;
    }

    function getTokenURI(uint256 _tokenId) public view returns(string memory) {
        require(owner[_tokenId] != address(0), "Token Id does not exist");
        return string(abi.encodePacked(_baseUri, _tokenURIs[_tokenId]));
    }

    function balanceOf(address _owner) public view returns(uint256) {
        return balance[_owner];
    }

    function ownerOf(uint256 _tokenId) public view returns(address) {
        return owner[_tokenId];
    }

    function approve(address _approve, uint256 _tokenId) public {
        require(owner[_tokenId] != address(0), "Token Id does not exist");
        require(msg.sender == owner[_tokenId], "Only owner of the token can approve");
        _approved[_tokenId] = _approve;
        emit Approval(msg.sender, _approve, _tokenId);
    }

    function getApproved(uint256 _tokenId) public view returns(address) {
        return _approved[_tokenId];
    } 

    function setApprovalForAll(address _operator, bool _approve) public {
        _approvedForAll[msg.sender][_operator] = _approve;
        emit ApprovalForAll(msg.sender, _operator, _approve);
    }

    function isApproveForAll(address _owner, address _operator) public view returns(bool) {
        return _approvedForAll[_owner][_operator];
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) public {
        require(_to != _from, "You can not transfer tokens to your own account");
        owner[_tokenId] = _to;
        balance[_from]--;
        balance[_to]++;
        emit Transfer(_from, _to, _tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public {
        transferFrom(_from, _to, _tokenId);
        require(OnERC721Receiver(_to).onERC721Recieved(msg.sender, _from, _tokenId, "") == ERC721_RECEIVED, "Transaction failed");
        emit Transfer(_from, _to, _tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) public {
        transferFrom(_from, _to, _tokenId);
        require(OnERC721Receiver(_to).onERC721Recieved(msg.sender, _from, _tokenId, _data) == ERC721_RECEIVED, "Transaction failed");
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == this.supportsInterface.selector || interfaceId == 0x80ac58cd;
    }
}

interface OnERC721Receiver {
    function onERC721Recieved(address operator, address from, uint256 _tokenId, bytes calldata data) external returns(bytes4) ;
}

bytes4 constant ERC721_RECEIVED = 0x150b7a02; 
