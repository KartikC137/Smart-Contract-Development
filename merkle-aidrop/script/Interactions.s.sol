// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract ClaimAirdrop is Script {
    error ClaimAirdrop__InvalidSignature();

    address private constant CLAIMER_ADDRESS =
        0x620B143432e71e1281B0f96d6D6497Eef9221ee3; // default anvil key or sepolia
    uint256 private constant AMOUNT = 25 * 1e18;
    bytes32 PROOF_ONE =
        0x4fd31fee0e75780cd67704fbc43caee70fddcaa43631e2e1bc9fb233fada2394;
    bytes32 PROOF_TWO =
        0x81f0e530b56872b6fc3e10f8873804230663f8407e21cef901b8aeb06a25e5e2;

    bytes32[] private proof = [PROOF_ONE, PROOF_TWO];
    bytes private SIGNATURE =
        hex"fbd2270e6f23fb5fe9248480c0f4be8a4e9bd77c3ad0b1333cc60b5debc511602a2a06c24085d8d7c038bad84edc53664c8ce0346caeaa3570afec0e61144dc11c";

    function claimAirdrop(address airdropAddress) public {
        vm.startBroadcast();
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(SIGNATURE);
        MerkleAirdrop(airdropAddress).claim(
            CLAIMER_ADDRESS,
            AMOUNT,
            proof,
            v,
            r,
            s
        );
        vm.stopBroadcast();
    }

    function splitSignature(
        bytes memory sign
    ) public pure returns (uint8 v, bytes32 r, bytes32 s) {
        if (sign.length != 65) {
            revert ClaimAirdrop__InvalidSignature();
        }
        assembly {
            r := mload(add(sign, 32))
            s := mload(add(sign, 64))
            v := byte(0, mload(add(sign, 96)))
        }
    }

    function run() external {
        address mostRecentelyDeployed = DevOpsTools.get_most_recent_deployment(
            "MerkleAirdrop",
            block.chainid
        );
        claimAirdrop(mostRecentelyDeployed);
    }
}
