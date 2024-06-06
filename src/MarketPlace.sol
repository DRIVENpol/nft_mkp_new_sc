
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @author Rev3al LLC
 * @title NFT Marketplace Smart Contract
 */

/** IMPORTS */
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
}
interface IERC2981 {
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (
        address receiver,
        uint256 royaltyAmount
    );
}
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

contract Rev3al_Marketplace is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {

    uint256 public marketItemId;

    // Market Item
    struct MarketItem {
        uint256 nftId; // Nft ID
        uint256 price; // Nft Price
        address collection; // Collection Address
        address seller; // Seller Address
    }

    // Market Item Props
    struct MarketItemProps {
        uint256 bidEndDate; // Bid End Date
        bool onSale; // On Sale
        bool onAuction; // On Auction
    }

    // Bid struct
    struct Bid {
        uint256 marketItemId; // For which market item
        uint256 amount; // Bid Amount
        address bidder; // Bidder Address
    }

    // Bids array
    Bid[] public bids;

    // Market Items
    mapping(uint256 => MarketItem) public marketItems;
    // Market Item Props
    mapping(uint256 => MarketItemProps) public marketItemProps;

    // Events
    event NewMarketItem(
        uint256 nftId,
        uint256 price,
        address indexed collection,
        address indexed seller
    );
    event MarketItemSold(
        uint256 nftId,
        uint256 price,
        address indexed collection,
        address indexed seller,
        address indexed buyer
    );
    event DeleteNft(
        uint256 marketItemId,
        address indexed seller
    );
    event NewBid(
        uint256 marketItemId,
        uint256 amount,
        address indexed bidder
    );
    event WithdrawBid(
        uint256 marketItemId,
        uint256 amount,
        address indexed bidder
    );
    event ExtendBidTime(
        uint256 marketItemId,
        uint256 bidEndDate
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin
    ) initializer public {
        __Ownable_init(_admin);
        __UUPSUpgradeable_init();
        __Pausable_init();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    // Pause/unpause the smartcontract
    function togglePause() external onlyOwner {
        if(paused()) {
            _unpause();
        } else {
            _pause();
        }
    }

    // List an NFT for sale or auction
    // @param _collection: Address of the NFT Collection
    // @param _nftId: NFT ID
    // @param _price: NFT Price
    // @param _bidEndDate: Bid End Date
    // @param _onAuction: Is the NFT on auction
    function listNftForSale(
        address _collection,
        uint256 _nftId,
        uint256 _price,
        uint256 _bidEndDate,
        bool _onAuction
    ) external payable whenNotPaused {
        // Validate the collection address
        _checkValidAddress(_collection);

        // check if the allowance of the NFT is given to the marketplace
        if(IERC721(_collection).getApproved(_nftId) != address(this)) {
            revert("Marketplace Not Approved");
        }

        // If the item is on auction, validate the bid end date
        if(_onAuction) {
            if(_bidEndDate == 0 || _bidEndDate < block.timestamp) {
                revert("Invalid Bid End Date");
            }
        }

        // Link the market item props to marketItemProps[marketItemId]
        marketItemProps[marketItemId] = MarketItemProps({
            bidEndDate: _bidEndDate,
            onSale: _onAuction ? false : true,
            onAuction: _onAuction
        });

        // Link the market item to marketItems[marketItemId]
        marketItems[marketItemId] = MarketItem({
            nftId: _nftId,
            price: _price,
            collection: _collection,
            seller: msg.sender
        });

        unchecked {
            marketItemId++;
        }

        emit NewMarketItem(_nftId, _price, _collection, msg.sender);
    }

    // Delist an NFT from the marketplace
    // @param _marketItemId: Market Item ID
    function closeMarketItem(uint256 _marketItemId) external whenNotPaused {
        if(_marketItemId >= marketItemId) {
            revert("Invalid Market Item");
        }

        MarketItem storage _marketItem = marketItems[_marketItemId];

        // If the caller is not the seller, revert
        if(_marketItem.seller != msg.sender) {
            revert("Unauthorized");
        }

        // Delete the market item and market item props
        delete marketItems[_marketItemId];
        delete marketItemProps[_marketItemId];

        emit DeleteNft(_marketItemId, msg.sender);
    }

    // Pause an NFT from the marketplace
    function pauseMarketItem(uint256 _marketItemId) external whenNotPaused {
        if(_marketItemId >= marketItemId) {
            revert("Invalid Market Item");
        }

        MarketItemProps storage _marketItemProps = marketItemProps[_marketItemId];

        // If the caller is not the seller, revert
        if(marketItems[_marketItemId].seller != msg.sender) {
            revert("Unauthorized");
        }

        // If the item is not on sale, revert
        if(!_marketItemProps.onSale) {
            revert("Item Not On Sale");
        }

        // Update the market item props
        _marketItemProps.onSale = false;

        emit DeleteNft(_marketItemId, msg.sender);
    }

    // Unpause a paused market item
    function unpauseMarketItem(uint256 _marketItemId) external whenNotPaused {
        if(_marketItemId >= marketItemId) {
            revert("Invalid Market Item");
        }

        MarketItem storage _marketItem = marketItems[_marketItemId];
        MarketItemProps storage _marketItemProps = marketItemProps[_marketItemId];

        // If the caller is not the seller, revert
        if(_marketItem.seller != msg.sender) {
            revert("Unauthorized");
        }

        // If the item is on sale, revert
        if(_marketItemProps.onSale) {
            revert("Item Already On Sale");
        }

        // Update the market item props
        _marketItemProps.onSale = true;

        emit NewMarketItem(_marketItem.nftId, _marketItem.price, _marketItem.collection, _marketItem.seller);
    }

    function changePrice(uint256 _marketItemId, uint256 _price) external whenNotPaused {
        if(_marketItemId >= marketItemId) {
            revert("Invalid Market Item");
        }

        MarketItem storage _marketItem = marketItems[_marketItemId];

        // If the caller is not the seller, revert
        if(_marketItem.seller != msg.sender) {
            revert("Unauthorized");
        }

        // Update the price
        _marketItem.price = _price;
    }

    function toggleOnAuction(uint256 _marketItemId) external whenNotPaused {
        if(_marketItemId >= marketItemId) {
            revert("Invalid Market Item");
        }

        MarketItemProps storage _marketItemProps = marketItemProps[_marketItemId];

        // If the caller is not the seller, revert
        if(marketItems[_marketItemId].seller != msg.sender) {
            revert("Unauthorized");
        }

        // If the item is not on sale, revert
        if(!_marketItemProps.onSale) {
            revert("Item Not On Sale");
        }

        // Update the market item props
        _marketItemProps.onAuction = !_marketItemProps.onAuction;
        _marketItemProps.onSale = !_marketItemProps.onSale;
    }

    function extendBidTime(uint256 _marketItemId, uint256 _bidEndDate) external whenNotPaused {
        if(_marketItemId >= marketItemId) {
            revert("Invalid Market Item");
        }

        MarketItem storage _marketItem = marketItems[_marketItemId];
        MarketItemProps storage _marketItemProps = marketItemProps[_marketItemId];

        // If the caller is not the seller, revert
        if(_marketItem.seller != msg.sender) {
            revert("Unauthorized");
        }

        // If the item is not on auction, revert
        if(!_marketItemProps.onAuction) {
            revert("Item Not On Auction");
        }

        // If the end date is in the past, revert
        if(_bidEndDate < block.timestamp) {
            revert("Invalid Bid End Date");
        }

        // Update the market item props
        _marketItemProps.bidEndDate = _bidEndDate;

        emit ExtendBidTime(_marketItemId, _bidEndDate);
    }

    // Buy an NFT from the marketplace
    // @param _marketItemId: Market Item ID
    // @param _receiver: Receiver Of The Nft
    function buyMarketItem(uint256 _marketItemId, address _receiver) external payable whenNotPaused {
        _checkValidAddress(_receiver);

        if(_marketItemId >= marketItemId) {
            revert("Invalid Market Item");
        }

        MarketItem storage _marketItem = marketItems[_marketItemId];

        // Check if the item is on sale. If not, revert
        if(!marketItemProps[_marketItemId].onSale) {
            revert("Item Not On Sale");
        }

        // Check if the item is on auction. If yes, revert as the item can't be bought directly
        if(marketItemProps[_marketItemId].onAuction) {
            revert("Direct Buy Not Allowed");
        }

        // If msg.value != _marketItem.price, revert
        if(msg.value != _marketItem.price) {
            revert("Invalid Price");
        }

        // Fetch royalty info
        (uint256 _royalties, address _royaltyRecevier) = _checkRoyalties(_marketItem.collection, _marketItem.nftId);

        // Transfer the NFT to the buyer
        IERC721(_marketItem.collection).transferFrom(_marketItem.seller, _receiver, _marketItem.nftId);

        // If there are royalties, transfer the royalties to the receiver
        if(_royalties > 0) {
           (bool _success, ) = _royaltyRecevier.call{value: _royalties}("");

              if(!_success) {
                revert("Royalties Transfer Failed");
              }
        }

        // Transfer the amount to the seller
        (bool _successBuy, ) = _marketItem.seller.call{value: msg.value - _royalties}("");

        if(!_successBuy) {
            revert("Transfer Failed");
        }

        // Delete the market item and market item props
        delete marketItems[_marketItemId];
        delete marketItemProps[_marketItemId];

        emit MarketItemSold(_marketItem.nftId, _marketItem.price, _marketItem.collection, _marketItem.seller, msg.sender);
    }

    // Bid on an NFT
    // @param _marketItemId: Market Item ID
    // @param _amount: Bid Amount
    function bid(uint256 _marketItemId, uint256 _amount) external payable whenNotPaused {
        if(_marketItemId >= marketItemId) {
            revert("Invalid Market Item");
        }

        MarketItemProps storage _marketItemProps = marketItemProps[_marketItemId];

        // Check if the item is on auction. If not, revert
        if(!_marketItemProps.onAuction) {
            revert("Item Not On Auction");
        }

        // Check if the bid end date has passed. If yes, revert
        if(_marketItemProps.bidEndDate < block.timestamp) {
            revert("Bid Ended");
        }

        // If msg.value != _amount, revert
        if(msg.value != _amount) {
            revert("Invalid Amount");
        }

        // Add the bid to the bids array
        bids.push(Bid({
            marketItemId: _marketItemId,
            amount: _amount,
            bidder: msg.sender
        }));

        emit NewBid(_marketItemId, _amount, msg.sender);
    }

    // Withdraw a bid
    // @param _bidId: Bid ID
    function withdrawBid(uint256 _bidId) external payable whenNotPaused {

        Bid storage _bid = bids[_bidId];

        // If the bidder is not the sender, revert
        if(_bid.bidder != msg.sender) {
            revert("Unauthorized");
        }

        // We transfer the bid amount back to the bidder
        (bool _success, ) = msg.sender.call{value: _bid.amount}("");

        if(!_success) {
            revert("Withdraw Failed");
        }

        // Delete the bid
        delete bids[_bidId];

        emit WithdrawBid(_bid.marketItemId, _bid.amount, msg.sender);
    }

    // Accept a bid by the market item seller
    function acceptBid(uint256 _bidId) external payable whenNotPaused {
        Bid storage _bid = bids[_bidId];

        uint256 _marketItemId = _bid.marketItemId;

        MarketItem storage _marketItem = marketItems[_marketItemId];
        MarketItemProps storage _marketItemProps = marketItemProps[_marketItemId];

        // If the caller is not the seller, revert
        if(_marketItem.seller != msg.sender) {
            revert("Unauthorized");
        }

        // If the owner of the NFT removes the NFT from auction, revert
        if(!_marketItemProps.onAuction) {
            revert("Can't accept bids on non-auction items!");
        }

        // We fetch the royalties and the receiver
        (uint256 _royalties, address _royaltyReceiver) = _checkRoyalties(_marketItem.collection, _marketItem.nftId);

        // Transfer the NFT to the bidder
        IERC721(_marketItem.collection).transferFrom(_marketItem.seller, _bid.bidder, _marketItem.nftId);

        // Transfer the bid amount to the seller
        (bool _success, ) = _marketItem.seller.call{value: _bid.amount - _royalties}("");

        if(!_success) {
            revert("Transfer Failed");
        }

        // If there are royalties, transfer the royalties to the receiver
        if(_royalties > 0 && _checkValidAddress(_royaltyReceiver)) {
            (bool _successRoyalties, ) = _royaltyReceiver.call{value: _royalties}("");

            if(!_successRoyalties) {
                revert("Royalties Transfer Failed");
            }
        }

        // Delete the market item and market item props
        delete marketItems[_marketItemId];
        delete marketItemProps[_marketItemId];

        emit MarketItemSold(_marketItem.nftId, _bid.amount, _marketItem.collection, _marketItem.seller, _bid.bidder);
        emit WithdrawBid(_marketItemId, _bid.amount, _bid.bidder);
    }

    // Public functions
    function getMarketItemDetails(uint256 _marketItemId) external view returns (MarketItem memory, MarketItemProps memory) {
        return (marketItems[_marketItemId], marketItemProps[_marketItemId]);
    }

    function getBidsLength() external view returns (uint256) {
        return bids.length;
    }

    function getBid(uint256 _bidId) external view returns (Bid memory) {
        return bids[_bidId];
    }

    // Internal functions
    function _checkValidAddress(address _address) internal pure returns (bool){
        if(_address == address(0) || _address == address(0xdead)) {
            revert("Invalid Address");
        }

        return true;
    }

    function _checkRoyalties(address _collection, uint256 _nftId) internal view returns (uint256, address) {
        if(IERC165(_collection).supportsInterface(type(IERC2981).interfaceId)) {
            (address receiver, uint256 royaltyAmount) = IERC2981(_collection).royaltyInfo(_nftId, 0);
            return (royaltyAmount, receiver);
        }
        return (0, address(0xdead));
    }
}