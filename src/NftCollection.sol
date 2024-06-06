// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";

contract NftCollection is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC2981Upgradeable, OwnableUpgradeable {
    using Strings for uint256;

    // CONSTANTS
    string public constant CANT_REVEAL = "ERC721 Collection: This collection is already revealed!";
    string public constant CANT_MINT = "ERC721 Collection: Can't mint more tokens!";
    string public constant MAX_SUPPLY = "ERC721 Collection: Max supply too low!";
    string public constant PAY = "ERC721 Collection: Not enough ETH!";

    uint256 public price; // Price to mint

    uint256 private _nextTokenId; // Supply
    uint256 private _maxSupply; // Max supply
    uint256 private _max_ammount_per_wallet; // 0 for no limit

    string public URI; // Base URI
    string public notRevealedUri; // To display if the collection is hidden

    string public uriSuffix = ".json"; // URI suffix for revealed collections

    bool public revealed; // Is the collection revealed or not?

    struct InitializationParams {
        uint256 maxS;
        uint256 price;
        uint256 maxAmount;
        uint96 royaltyAmount; // Basis points
        address initialOwner;
        address royaltyReceiver;
        string uri;
        string notRevURI;
        string name;
        string symbol;
        bool isRevealed;
        bool useRoyalties;
    }

    // Events
    event Revealed();
    event ChangePrice(uint256 _oldPrice, uint256 _newPrice);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(InitializationParams memory params) initializer public {
        __ERC721_init(params.name, params.symbol);
        __ERC721URIStorage_init();
        __Ownable_init(params.initialOwner);
        __ERC2981_init();

        if(params.maxS <= 1) {
            revert(MAX_SUPPLY);
        }

        URI = params.uri;
        notRevealedUri = params.notRevURI;
        revealed = params.isRevealed;

        _max_ammount_per_wallet = params.maxAmount;

        _maxSupply = params.maxS;
        price = params.price;

        if (params.useRoyalties) {
            _setDefaultRoyalty(params.royaltyReceiver, params.royaltyAmount);
        }
    }

    //////////////////// EXTERNAL FUNCTIONS ////////////////////

    function mint(uint256 amount) external payable {
        uint256 _toPay = amount * price;

        uint256 _balance = balanceOf(msg.sender);

        if(_max_ammount_per_wallet > 0 && _balance + amount > _max_ammount_per_wallet) {
            revert(CANT_MINT);
        }

        if(msg.value < _toPay) {
            revert(PAY);
        }

        for(uint256 i = 0; i < amount;) {
            _safeMintTo(msg.sender);

            unchecked {
                ++i;
            }
        }
    }

    function mintByOwner(address who, uint256 amount) external onlyOwner {
        uint256 _balance = balanceOf(who);

        if(_max_ammount_per_wallet > 0 && _balance + amount > _max_ammount_per_wallet) {
            revert(CANT_MINT);
        }

        for(uint256 i = 0; i < amount;) {
            _safeMintTo(who);

            unchecked {
                ++i;
            }
        }
    }

    function revealCollection() external onlyOwner {
        if (revealed == true) {
            revert(CANT_REVEAL);
        }

        revealed = true;

        emit Revealed();
    }

    function changePrice(uint256 _newPrice) external onlyOwner {
        uint256 _oldPrice = price;
        price = _newPrice;

        emit ChangePrice(_oldPrice, _newPrice);
    }

    function withdraw() external onlyOwner {
        uint256 _balance = address(this).balance;

        (bool success, ) = owner().call{value: _balance}("");

        if(!success) {
            revert(PAY);
        }
    }

    //////////////////// PUBLIC FUNCTIONS ////////////////////

    // Display token URI depending on the status of 'revealed'
    function tokenURI(uint256 _tokenId) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
         _requireOwned(_tokenId);

        if (revealed == false) {
        return notRevealedUri;
        }

        string memory currentBaseURI = URI;
        
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
            : '';
    }

    // Support interfaces
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Track total supply
    function totalSupply() public view returns(uint256) {
        return _nextTokenId;
    }

    // Display max supply
    function maxSupply() public view returns(uint256) {
        return _maxSupply;
    }

    //////////////////// INTERNAL FUNCTIONS ////////////////////

    function _safeMintTo(address to) internal {
        if(_nextTokenId == _maxSupply) {
            revert(CANT_MINT);
        }
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
    }
}