// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MoxNFTMarket} from "../src/MoxNFTMarket.sol";
import {ExtendedERC20} from "../src/ExtendedERC20.sol";
import {MoxNFT} from "../src/ERC721.sol";

contract MoxNFTMarketTest is Test {
    MoxNFTMarket public market;
    ExtendedERC20 public paymentToken;
    MoxNFT public nft;

    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");
    address public stranger = makeAddr("stranger");

    uint256 public constant LIST_PRICE = 100 * 10 ** 18;
    uint256 public tokenId;

    function setUp() public {
        // Deploy token, market, and NFT contracts
        paymentToken = new ExtendedERC20();
        market = new MoxNFTMarket(address(paymentToken));
        nft = new MoxNFT();

        // Mint NFT to seller
        tokenId = nft.mint(seller);

        // Allocate 1000 MOX payment tokens to buyer
        bool success = paymentToken.transfer(buyer, 1000 * 10 ** 18);
        assertTrue(success);
    }

    function testListNFT() public {
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        uint256 listingId = market.list(address(nft), tokenId, LIST_PRICE);
        vm.stopPrank();

        (address listSeller, address listNftContract, uint256 listTokenId, uint256 listPrice, bool isActive) =
            market.listings(listingId);

        assertEq(listSeller, seller);
        assertEq(listNftContract, address(nft));
        assertEq(listTokenId, tokenId);
        assertEq(listPrice, LIST_PRICE);
        assertTrue(isActive);
    }

    function testCancelListing() public {
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        uint256 listingId = market.list(address(nft), tokenId, LIST_PRICE);

        market.cancelListing(listingId);
        vm.stopPrank();

        (,,,, bool isActive) = market.listings(listingId);
        assertFalse(isActive);
    }

    function testRevert_CancelListingNotSeller() public {
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        uint256 listingId = market.list(address(nft), tokenId, LIST_PRICE);
        vm.stopPrank();

        vm.prank(stranger);
        vm.expectRevert("MoxNFTMarket: caller is not the seller");
        market.cancelListing(listingId);
    }

    function testBuyNFT_Standard() public {
        // Seller lists NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        uint256 listingId = market.list(address(nft), tokenId, LIST_PRICE);
        vm.stopPrank();

        // Buyer purchases NFT
        vm.startPrank(buyer);
        paymentToken.approve(address(market), LIST_PRICE);
        market.buyNFT(listingId);
        vm.stopPrank();

        // Verify token balances and NFT ownership
        assertEq(paymentToken.balanceOf(seller), LIST_PRICE);
        assertEq(paymentToken.balanceOf(buyer), 900 * 10 ** 18);
        assertEq(nft.ownerOf(tokenId), buyer);

        (,,,, bool isActive) = market.listings(listingId);
        assertFalse(isActive);
    }

    function testBuyNFT_CallbackHook() public {
        // Seller lists NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        uint256 listingId = market.list(address(nft), tokenId, LIST_PRICE);
        vm.stopPrank();

        // Buyer purchases using token callback hook in a single step
        vm.prank(buyer);
        bytes memory data = abi.encode(listingId);
        paymentToken.transferWithCallbackAndData(address(market), LIST_PRICE, data);

        // Verify token balances and NFT ownership
        assertEq(paymentToken.balanceOf(seller), LIST_PRICE);
        assertEq(paymentToken.balanceOf(buyer), 900 * 10 ** 18);
        assertEq(nft.ownerOf(tokenId), buyer);

        (,,,, bool isActive) = market.listings(listingId);
        assertFalse(isActive);
    }

    function testRevert_BuyInsufficientBalance() public {
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        uint256 listingId = market.list(address(nft), tokenId, LIST_PRICE);
        vm.stopPrank();

        vm.startPrank(stranger); // Zero balance
        paymentToken.approve(address(market), LIST_PRICE);
        vm.expectRevert("MoxNFTMarket: insufficient token balance");
        market.buyNFT(listingId);
        vm.stopPrank();
    }

    function testRevert_SellerCannotBuyOwnNFT() public {
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        uint256 listingId = market.list(address(nft), tokenId, LIST_PRICE);

        paymentToken.approve(address(market), LIST_PRICE);
        vm.expectRevert("MoxNFTMarket: caller is the seller");
        market.buyNFT(listingId);
        vm.stopPrank();
    }
}
