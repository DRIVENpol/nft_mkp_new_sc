// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SingleNft is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, OwnableUpgradeable {
    uint256 private _nextTokenId;

    string public URI;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, string memory _name, string memory _symbol, string memory uri) initializer public {
        __ERC721_init(_name, _symbol);
        __ERC721URIStorage_init();
        __Ownable_init(initialOwner);

        URI = uri;

        _safeMintTo(initialOwner);
    }

    function _safeMintTo(address to) internal {
        if(_nextTokenId > 0) {
            revert("Only one token can be minted!");
        }
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        _requireOwned(tokenId);

        return URI;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function totalSupply() public view returns(uint256) {
        return _nextTokenId;
    }
}