// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {MoodNFT} from "src/MoodNFT.sol";

contract MintMoodNFT is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "MoodNFT",
            block.chainid
        );

        mintNFTOnContract(mostRecentlyDeployed);
    }

    function mintNFTOnContract(address contractAddress) public {
        vm.startBroadcast();
        MoodNFT(contractAddress).mintNft();
        vm.stopBroadcast();
    }
}

contract FlipMood is Script {
    uint256 tokenId = 1;

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "MoodNFT",
            block.chainid
        );
        if (tokenId == 0) {
            tokenId = 1;
        } else {
            tokenId = 0;
        }
        flipMoodOnContract(tokenId, mostRecentlyDeployed);
    }

    function flipMoodOnContract(
        uint256 tokenId,
        address contractAddress
    ) public {
        vm.startBroadcast();
        MoodNFT(contractAddress).flipMood(tokenId);
        vm.stopBroadcast();
    }
}
