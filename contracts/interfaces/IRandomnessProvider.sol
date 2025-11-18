// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRandomnessProvider {
    function requestRandomWords(uint32 numWords) external returns (uint256 requestId);
}
