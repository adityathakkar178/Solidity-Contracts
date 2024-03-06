// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

contract ERC1155 {
    uint256 private _tokenIdCounter;
    mapping (uint256 => mapping (address => uint256)) private _balance;
    mapping (address => mapping (address => bool)) private _approve;
    mapping (uint256 => string) private _tokenURIs;
    mapping (uint256 => address) private _creator;
    mapping (string => bool) private _uris;

    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);
    event TransferBatch(address indexed  _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values);
    event ApproveForAll(address indexed _owner, address indexed _operaor, bool _approve);
    event URI(string _value, uint256 indexed _id);

    function mint(uint256 _amount, string memory _tokenURI) public {
        require(_amount > 0, "Amount must be gretaer than zero");
        require(bytes(_tokenURI).length > 0, "Token URI can not be empty");
        require(!_uris[_tokenURI], "URI already exists");
        _tokenIdCounter++;
        uint256 id = _tokenIdCounter;
        _balance[id][msg.sender] = _amount;
        _tokenURIs[id] = _tokenURI;
        _uris[_tokenURI] = true;
        _creator[id] = msg.sender;
        emit URI(_tokenURI, id);
    }

    function mintToExisitingTokens(uint256 _tokenId, uint256 _amount) public {
        require(msg.sender == _creator[_tokenId], "You are not the orginal creator of this token");
        require(_amount > 0, "Amount must be greater tha zero");
        _balance[_tokenId][msg.sender] += _amount;
    }

    function getTokenURI(uint256 _tokenId) public view returns(string memory) {
        return _tokenURIs[_tokenId];
    }

    function balanceOf(address _owner, uint256 _id) public view returns(uint256) {
        return _balance[_id][_owner];
    }

    function balanceOfBatch(address[] memory _owners, uint256[] memory _ids) public view returns(uint256[] memory) {
        require(_owners.length == _ids.length, "Length of owners and ids should be equal");
        uint256[] memory balances = new uint256[](_owners.length);
        for (uint256 i = 0; i < _owners.length; i++) {
            balances[i] = balanceOf(_owners[i], _ids[i]);
        }
        return balances;
    }

    function setApprovalForAll(address _operator, bool _approved) public {
        _approve[msg.sender][_operator] = _approved;
        emit ApproveForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(address _owner, address _operator) public view returns(bool) {
        return _approve[_owner][_operator];
    }

    function safeTrasferFrom(address _from, address _to, uint256 _id, uint256 _value) public {
        require(msg.sender == _from || isApprovedForAll(_from, msg.sender), "You are not approved to transfer this tokens");
        require(_to != _from, "You can not transfer to your own account");
        require(_to != msg.sender, "Operator can not send token to his own account");
        require(_balance[_id][_from] >= _value, "Insufficient balance");
        _balance[_id][_from] -= _value;
        _balance[_id][_to] += _value;
        emit TransferSingle(msg.sender, _from, _to, _id, _value);
    }

    function safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _values) public {
        require(msg.sender == _from || isApprovedForAll(_from, msg.sender), "You are not approved to transfer this tokens");
        require(_to != _from, "You can not transfer to your own account");
        require(_to != msg.sender, "Operator can not send token to his own account");
        require(_ids.length == _values.length, "Length of ids and values must match");
        for (uint256 i = 0; i < _ids.length; i++) {
            require(_balance[_ids[i]][_from] >= _values[i], "Insufficient balance");
            _balance[_ids[i]][_from] -= _values[i];
            _balance[_ids[i]][_to] += _values[i];
        }
        emit TransferBatch(msg.sender, _from, _to, _ids, _values);
    }
}
