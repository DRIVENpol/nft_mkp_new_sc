// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

interface ISingleNft {
    function initialize(address initialOwner, string memory _name, string memory _symbol, string memory uri) external;
}

interface ICollection {
    function initialize(uint256 _maxS, uint256 _price, uint256 _maxAmount, address owner, string memory uri, string memory notRevURI, string memory _name, string memory _symbol, bool isRevealed) external;
}

contract NftLauncher is Ownable {
   /** CONSTANTS */
   string public constant PAY = "ERC721 Collection: Not enough ETH!";

    uint256 private salt;

    /** ANALYTICS */
    uint256 public singleNftsLaunched;
    uint256 public collectionsLaunched;

    /** FEES */
    uint256 public singleNftFee;
    uint256 public collectionFee;

    /** IMPLEMENTATIONS */
    address public singleNftImplementation; // Sepolia: 0x21367262125DAfD82fE32c05131e6115317eD5f1
    address public collectionImplementation; // Sepolia: 0xaEA73f38ED1dC00Fc2Fff4eA80652E65218F0c3B

    /** TRACKING */
    mapping(uint256 => address) public collections; // Salt -> Collection

    /** MAPPING */
    mapping(address => address[]) public userToSingleNft;
    mapping(address => address[]) public userToCollection;

    /** EVENTS */
    event Nft_Created(address indexed nft);

    /** CONSTRUCTOR */
    constructor(
        uint256 _singleNftFee,
        uint256 _collectionFee,
        address _singleNftImplementation,
        address _collectionImplementation
    ) Ownable(msg.sender) {
        singleNftImplementation = _singleNftImplementation;
        collectionImplementation = _collectionImplementation;

        singleNftFee = _singleNftFee;
        collectionFee = _collectionFee;
    }

    function createSingleNft(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) external payable returns(address){
        if(singleNftFee != 0 && msg.value < singleNftFee) {
            revert(PAY);
        }

        bytes32 newSalt = keccak256(abi.encodePacked(salt, _name, _symbol, msg.sender));
        address clone = Clones.cloneDeterministic(singleNftImplementation, newSalt);

        ISingleNft(clone).initialize(msg.sender, _name, _symbol, _uri);

        userToSingleNft[msg.sender].push(clone);

        collections[salt] = clone;

        unchecked {
            ++salt;
            ++singleNftsLaunched;
        }

        emit Nft_Created(clone);

        return clone;
    }

    function createCollection(
        uint256 _maxS,
        uint256 _price,
        uint256 _maxAmount,
        string memory uri, 
        string memory notRevURI, 
        string memory _name,
        string memory _symbol,
        bool isRevealed
    ) external payable returns(address) {
        if(singleNftFee != 0 && msg.value < singleNftFee) {
            revert(PAY);
        }

        bytes32 newSalt = keccak256(abi.encodePacked(salt, _name, _symbol, msg.sender));
        address clone = Clones.cloneDeterministic(collectionImplementation, newSalt);

        ICollection(clone).initialize(_maxS, _price, _maxAmount, msg.sender, uri, notRevURI, _name, _symbol, isRevealed);

        userToCollection[msg.sender].push(clone);

        collections[salt] = clone;

        unchecked {
            ++salt;
            ++collectionsLaunched;
        }


        emit Nft_Created(clone);

        return clone;
    }

    function withdrawFees() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}