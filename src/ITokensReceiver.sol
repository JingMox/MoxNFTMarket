// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ITokensReceiver {
    function tokensReceived(address from, uint256 amount) external returns (bool);
    function tokensReceived(address from, uint256 amount, bytes calldata data) external returns (bool);
}

