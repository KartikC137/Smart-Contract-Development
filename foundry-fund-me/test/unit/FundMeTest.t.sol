// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

//types of testing:
// 1. Unit Testing - testing a single unit of code
// 2. Integration Testing -  testing how code works with other code
// 3. Forked - Testing on a simulated real environment
// 4. Staging - Testing in a real environment

contract FundMeTest is Test {
    uint256 private constant AGGREGATOR_VERSION = 6;
    FundMe fundMe;
    uint256 constant SEND_VALUE = 0.1 ether; // 1e18
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    address USER = makeAddr("user");

    // first function that is called after every test (each function is a sepearate test)
    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testVersion() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 6);
    }

    modifier funded() {
        vm.prank(USER); // next tx will be by the USER
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // if next line pass, it should revert
        // assert(This tx fails/reverts)
        fundMe.fund(); // send 0 value
    }

    function testFundUpdatesFundedDataStructure() public funded {
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public funded {
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        //fund contract

        //user is not the owner
        vm.expectRevert();
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithDrawWithASingleFunder() public funded {
        //Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        // uint256 gasStart = gasleft(); // ex 1000
        // vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner()); // costs: 200
        fundMe.withdraw();

        // uint256 gasEnd = gasleft(); // 800
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        // console.log(gasUsed);
        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endignFundMeBalance = address(fundMe).balance;
        assertEq(endignFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFunders() public funded {
        //Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            //Below function does vm.prank to ith address and vm.deal to same together
            hoax(address(i), SEND_VALUE); //address needs uint160 type
            fundMe.fund{value: SEND_VALUE}();
        }

        //Act
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        //Assert
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }
}
