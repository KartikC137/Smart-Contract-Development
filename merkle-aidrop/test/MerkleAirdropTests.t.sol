// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {DosaToken} from "../src/DosaToken.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";
import {DeployMerkleAirdrop} from "../script/DeployMerkleAirdrop.s.sol";

contract MerkleAirdropTests is ZkSyncChainChecker, Test {
    MerkleAirdrop public airdrop;
    DosaToken public dosa;

    uint256 public amountToClaim = 25 * 1e18;
    uint256 public amountToSend = amountToClaim * 4;

    bytes32 public merkleRoot =
        0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    bytes32 proofOne =
        0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 proofTwo =
        0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] public proof = [proofOne, proofTwo];
    address user;
    uint256 privKey;

    function setUp() external {
        if (!isZkSyncChain()) {
            // deploy with the script
            DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
            (airdrop, dosa) = deployer.deployMerkleAirdrop();
        } else {
            dosa = new DosaToken();
            airdrop = new MerkleAirdrop(merkleRoot, dosa);
            dosa.mint(dosa.owner(), amountToSend);
            dosa.transfer(address(airdrop), amountToSend);
        }
        (user, privKey) = makeAddrAndKey("user");
    }

    function testUsersCanClaim() external {
        uint256 startingBalance = dosa.balanceOf(user);

        vm.prank(user);
        airdrop.claim(user, amountToClaim, proof);

        uint256 endingBalance = dosa.balanceOf(user);
        console.log("Starting balance: ", startingBalance);
        console.log("Ending balance: ", endingBalance);

        assertEq(endingBalance - startingBalance, amountToClaim);
    }
}
