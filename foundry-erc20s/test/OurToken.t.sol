// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployOurToken} from "../script/DeployOurToken.s.sol";
import {OurToken} from "../src/OurToken.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract OurTokenTests is StdCheats, Test {
    OurToken public ourToken;
    DeployOurToken public deployer;

    address nana = makeAddr("nana");
    address patekar = makeAddr("patekar");

    uint256 public constant STARTING_BALANCE = 100 ether;

    function setUp() public {
        deployer = new DeployOurToken();
        ourToken = deployer.run();
        vm.prank(msg.sender);
        ourToken.transfer(nana, STARTING_BALANCE);
    }

    function testInitialSupply() public view {
        assertEq(ourToken.totalSupply(), deployer.INITIAL_SUPPLY());
    }

    function testNanaBalance() public view {
        assertEq(STARTING_BALANCE, ourToken.balanceOf(nana));
    }

    function testTransfer() public {
        uint256 amount = 100 ether;

        vm.prank(nana);
        ourToken.transfer(patekar, amount);

        assertEq(STARTING_BALANCE - amount, ourToken.balanceOf(nana));
        assertEq(ourToken.balanceOf(patekar), amount);
    }

    function testTransferInsufficientBalance() public {
        uint256 amount = 200 * 10 ** ourToken.decimals(); // More than nana's balance

        vm.prank(nana);
        vm.expectRevert();
        ourToken.transfer(patekar, amount);
    }

    function testTransferFrom() public {
        uint256 allowanceAmount = 50 * 10 ** ourToken.decimals();
        uint256 transferAmount = 30 * 10 ** ourToken.decimals();

        vm.prank(nana);
        ourToken.approve(patekar, allowanceAmount);

        vm.prank(patekar);
        ourToken.transferFrom(nana, patekar, transferAmount);

        assertEq(
            ourToken.allowance(nana, patekar),
            allowanceAmount - transferAmount
        );
        assertEq(ourToken.balanceOf(nana), 70 * 10 ** ourToken.decimals());
        assertEq(ourToken.balanceOf(patekar), transferAmount);
    }

    function testAllowances() public {
        //transferFrom
        uint256 initialAllowance = 1000;
        //nana approves patekar to spend tokens on his behalf
        vm.prank(nana);
        ourToken.approve(patekar, initialAllowance);
        uint256 transferAmount = 500;
        vm.prank(patekar);
        ourToken.transferFrom(nana, patekar, transferAmount);
        assertEq(transferAmount, ourToken.balanceOf(patekar));
        assertEq(STARTING_BALANCE - transferAmount, ourToken.balanceOf(nana));
    }

    function testTransferFromExceedsAllowance() public {
        uint256 allowanceAmount = 50 * 10 ** ourToken.decimals();
        uint256 transferAmount = 60 * 10 ** ourToken.decimals(); // Exceeds allowance

        vm.prank(nana);
        ourToken.approve(patekar, allowanceAmount);

        vm.prank(patekar);
        vm.expectRevert();
        ourToken.transferFrom(nana, patekar, transferAmount);
    }

    function testMultipleAllowances() public {
        uint256 allowance1 = 40 * 10 ** ourToken.decimals();
        uint256 allowance2 = 30 * 10 ** ourToken.decimals();

        vm.prank(nana);
        ourToken.approve(patekar, allowance1);

        vm.prank(nana);
        ourToken.approve(patekar, allowance2); // Overwrite previous allowance

        assertEq(ourToken.allowance(nana, patekar), allowance2);
    }
}
