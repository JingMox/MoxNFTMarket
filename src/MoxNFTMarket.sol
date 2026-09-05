// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ERC721.sol";
import "./ERC20.sol";
import "./ExtendedERC20.sol";

// Interface for receiving token callback hooks
interface ITokenReceiver {
    function tokensReceived(address from, uint256 amount, bytes calldata data) external returns (bool);
}

contract MoxNFTMarket is ITokenReceiver {
    IExtendedERC20 public paymentToken;

    struct Listing {
        address seller; // Seller address
        address nftContract; // NFT contract address
        uint256 tokenId; // NFT token ID
        uint256 price; // Price in payment token units
        bool isActive; // Whether listing is active
    }

    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;

    // Events for NFT listing, sale, and cancellation
    event NFTListed(
        uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price
    );
    event NFTSold(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address nftContract,
        uint256 tokenId,
        uint256 price
    );
    event NFTListingCancelled(uint256 indexed listingId);

    constructor(address _paymentTokenAddress) {
        require(_paymentTokenAddress != address(0), "MoxNFTMarket: payment token address cannot be zero");
        paymentToken = IExtendedERC20(_paymentTokenAddress);
    }

    function list(address _nftContract, uint256 _tokenId, uint256 _price) external returns (uint256) {
        require(_price > 0, "MoxNFTMarket: price must be greater than zero");
        require(_nftContract != address(0), "MoxNFTMarket: NFT contract address cannot be zero");

        IERC721 nftContract = IERC721(_nftContract);
        address owner = nftContract.ownerOf(_tokenId);
        require(
            owner == msg.sender || nftContract.isApprovedForAll(owner, msg.sender)
                || nftContract.getApproved(_tokenId) == msg.sender,
            "MoxNFTMarket: caller is not owner nor approved"
        );

        uint256 listingId = nextListingId;
        listings[listingId] =
            Listing({seller: owner, nftContract: _nftContract, tokenId: _tokenId, price: _price, isActive: true});

        nextListingId++;

        emit NFTListed(listingId, owner, _nftContract, _tokenId, _price);

        return listingId;
    }

    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.isActive, "MoxNFTMarket: listing is not active");
        require(listing.seller == msg.sender, "MoxNFTMarket: caller is not the seller");

        listing.isActive = false;

        emit NFTListingCancelled(listingId);
    }

    function buyNFT(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "MoxNFTMarket: listing is not active");
        require(listing.seller != msg.sender, "MoxNFTMarket: caller is the seller");
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "MoxNFTMarket: insufficient token balance");

        listing.isActive = false;

        bool success = paymentToken.transferFrom(msg.sender, listing.seller, listing.price);
        require(success, "MoxNFTMarket: token transfer failed");

        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);

        emit NFTSold(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
    }

    function tokensReceived(address from, uint256 amount, bytes calldata data) external override returns (bool) {
        require(msg.sender == address(paymentToken), "MoxNFTMarket: caller is not the payment token contract");
        require(data.length == 32, "MoxNFTMarket: invalid data length");
        uint256 listingId = abi.decode(data, (uint256));

        Listing storage listing = listings[listingId];
        require(listing.isActive, "MoxNFTMarket: listing is not active");

        require(amount == listing.price, "MoxNFTMarket: incorrect payment amount");

        listing.isActive = false;

        bool success = paymentToken.transfer(listing.seller, amount);
        require(success, "MoxNFTMarket: token transfer failed");

        IERC721(listing.nftContract).transferFrom(listing.seller, from, listing.tokenId);

        emit NFTSold(listingId, from, listing.seller, listing.nftContract, listing.tokenId, amount);

        return true;
    }

    function buyNFTWithCallback(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "MoxNFTMarket: listing is not active");
        require(listing.seller != msg.sender, "MoxNFTMarket: caller is the seller");

        require(paymentToken.balanceOf(msg.sender) >= listing.price, "MoxNFTMarket: insufficient token balance");

        bytes memory data = abi.encode(_listingId);

        bool success = paymentToken.transferWithCallbackAndData(address(this), listing.price, data);
        require(success, "MoxNFTMarket: token transfer with callback failed");
    }
}
