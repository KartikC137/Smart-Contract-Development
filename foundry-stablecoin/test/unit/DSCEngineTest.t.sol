// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;

    uint256 constant AMOUNT_COLLATERAL = 10 ether;
    uint256 constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 constant AMOUNT_TO_MINT = 100 ether;

    address weth;
    address wbtc;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    uint256 deployerKey;
    address USER = makeAddr("user");

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    modifier collateralDeposited() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    //////////////////////////
    // Constructor Tests /////
    //////////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenArrayNotEqualToPriceArray() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        tokenAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeOfSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////////////
    // Price Feed Tests /////
    /////////////////////////

    function testGetUsdValue() public {
        (ethUsdPriceFeed,, weth,,) = config.activeNetworkConfig();
        uint256 ethAmount = 15e18;
        // 15 ETH * 2000 USD = 30000 USD = 30000e18
        uint256 expected = 30000e18;
        uint256 actualPrice = dsce.getUsdValue(weth, ethAmount);

        assertEq(actualPrice, expected);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        // $2000 / ETH => 100 / 2000 = 0.05 ETH
        uint256 expectedTokenAmount = 0.05 ether;

        uint256 actualTokenAmount = dsce.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(actualTokenAmount, expectedTokenAmount);
    }

    ////////////////////////////////
    // depositCollateral Tests /////
    ////////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        console.log(weth);
        // ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsIfUnapprovedToken() public {
        ERC20Mock susToken = new ERC20Mock("SUS", "SUS", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dsce.depositCollateral(address(susToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public collateralDeposited {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInfo(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testDepositingCollateralEmitsEvent() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectEmit(true, false, false, false, address(dsce));
        emit CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    // function testRevertsIfDepositFailed() public collateralDeposited{

    // }

    function testCanDepositWithoutMinting() public collateralDeposited {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    /////////////////////////////////
    // redeemCollateral Tests //////
    ////////////////////////////////
    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public collateralDeposited {
        uint256 amountToRedeem = 6 ether;

        vm.prank(USER);
        dsce.redeemCollateral(weth, amountToRedeem);

        // should be 4 ether left
        uint256 expectedCollateralValueInUsd = dsce.getTokenAmountFromUsd(weth, dsce.getAccountCollateralValue(USER));
        console.log("balance after redeeming is:", expectedCollateralValueInUsd);

        assertEq(expectedCollateralValueInUsd, AMOUNT_COLLATERAL - amountToRedeem);
    }

    //////////////////////
    // Minting Tests /////
    //////////////////////

    function testCannotMintZeroAmount() public {}
    function testCanMint() public {}
}
