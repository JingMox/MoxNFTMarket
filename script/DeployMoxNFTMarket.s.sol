// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ExtendedERC20} from "../src/ExtendedERC20.sol";
import {MoxNFTMarket} from "../src/MoxNFTMarket.sol";
import {MoxNFT} from "../src/ERC721.sol";

contract DeployMoxNFTMarketScript is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY"); // Read private key from environment variable
        vm.startBroadcast(pk);
        ExtendedERC20 token = new ExtendedERC20(); // Deploy Moxius payment token
        new MoxNFTMarket(address(token)); // Deploy MoxNFTMarket contract
        new MoxNFT(); // Deploy Mox Genesis NFT contract
        vm.stopBroadcast();
    }
}
