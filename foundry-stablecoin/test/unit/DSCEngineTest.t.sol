// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed from, address indexed to, address indexed token, uint256 amount);

    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;

    uint256 constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 constant MIN_HEALTH_FACTOR = 1e18;
    uint256 constant LIQUIDATION_THRESHOLD = 50;

    uint256 public amountCollateral = 10 ether;
    uint256 public amountToMint = 100 ether;
    uint256 public collateralToCover = 20 ether;

    address weth;
    address wbtc;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    uint256 deployerKey;
    address USER = makeAddr("user");
    address LIQUIDATOR = makeAddr("liquidator");

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    modifier collateralDeposited() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDSC(weth, amountCollateral, amountToMint);
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
    // depositCollateral Tests ///// // Unfinished commented functions
    ////////////////////////////////

    // function testRevertsIfDepositFailed() public collateralDeposited{}

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        console.log(weth);
        // ERC20Mock(weth).approve(address(dsce), amountCollateral);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsIfUnapprovedToken() public {
        ERC20Mock susToken = new ERC20Mock("SUS", "SUS", USER, amountCollateral);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dsce.depositCollateral(address(susToken), amountCollateral);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public collateralDeposited {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInfo(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(amountCollateral, expectedDepositAmount);
    }

    function testDepositingCollateralEmitsEvent() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);

        vm.expectEmit(true, false, false, false, address(dsce));
        emit CollateralDeposited(USER, weth, amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
    }

    function testCanDepositWithoutMinting() public collateralDeposited {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    ////////////////////////////////
    // redeemCollateral Tests ////// // Unfinished commented functions
    ////////////////////////////////

    function testRevertsIfTransferFails() public {}

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDSC(weth, amountCollateral, amountToMint);
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

        assertEq(expectedCollateralValueInUsd, amountCollateral - amountToRedeem);
    }

    function testEmitCollateralRedeemedWithCorrectArgs() public collateralDeposited {
        vm.expectEmit(true, true, true, true, address(dsce));
        emit CollateralRedeemed(USER, USER, weth, amountCollateral);
        vm.startPrank(USER);
        dsce.redeemCollateral(weth, amountCollateral);
        vm.stopPrank();
    }

    function testCannotRedeemMoreThanDeposited() public collateralDeposited {
        uint256 amountToRedeem = 11 ether;
        vm.startPrank(USER);
        vm.expectRevert();
        dsce.redeemCollateral(weth, amountToRedeem);
        vm.stopPrank();
    }

    //////////////////////
    // Minting Tests /////
    //////////////////////

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDSC(weth, amountCollateral, amountToMint);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dsce.mintDSC(0);
        vm.stopPrank();
    }

    function testRevertsIfItBreaksHealthFactor() public {
        // uint256 amountToMint = 10001 ether; // Breaks Health Factor as max 10,000 DSC can be minted for 20,000 USD (10 ETH)

        // vm.prank(USER);
        // vm.expectRevert(DSCEngine.DSCEngine__HealthFactorTooLow.selector);
        // dsce.mintDSC(amountToMint);

        // More Robust:

        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();

        uint256 amountToMintHere =
            uint256(price) * ((amountCollateral * dsce.getAdditionalPrecision()) / dsce.getPrecision());

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        uint256 expectedHealthFactor =
            dsce.calculateHealthFactor(amountToMintHere, dsce.getUsdValue(weth, amountCollateral));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__HealthFactorTooLow.selector, expectedHealthFactor));
        dsce.depositCollateralAndMintDSC(weth, amountCollateral, amountToMintHere);
        vm.stopPrank();
    }

    function testCanMintAndUpdatesBalance() public collateralDeposited {
        vm.prank(USER);
        dsce.mintDSC(amountToMint);

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, amountToMint);
    }

    // function testRevertsIfMintingFails() public collateralDeposited{}

    ///////////////////
    // Burn Tests /////
    ///////////////////

    function testCannotBurnZeroAmount() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dsce.burnDSC(0);
        vm.stopPrank();
    }

    function testCannotBurnMoreThanCurrentBalance() public collateralDeposited {
        uint256 burnAmountMoreThanBalance = 101 ether;
        vm.startPrank(USER);
        dsce.mintDSC(amountToMint);
        dsc.approve(address(dsce), burnAmountMoreThanBalance);
        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BurnAmountExceededBalance.selector, burnAmountMoreThanBalance, amountToMint
            )
        );
        dsce.burnDSC(burnAmountMoreThanBalance);
        vm.stopPrank();
    }

    function testCannotBurnWithZeroBalance() public {
        vm.prank(USER);
        vm.expectRevert();
        dsce.burnDSC(1);
    }

    function testCanBurnAndUpdatesBalance() public collateralDeposited {
        vm.startPrank(USER);
        dsc.approve(address(dsce), amountToMint);
        dsce.mintDSC(amountToMint);
        dsce.burnDSC(amountToMint);
        vm.stopPrank();
        assertEq(dsc.balanceOf(USER), 0);
    }

    ////////////////////////////
    // healthFactor Tests //////
    ////////////////////////////

    function testProperlyReportsHealthFactor() public depositedCollateralAndMintedDsc {
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = dsce.getHealthFactor(USER);
        // $100 minted with $20,000 collateral at 50% liquidation threshold
        // means that we must have $200 collatareral at all times.
        // 20,000 * 0.5 = 10,000
        // 10,000 / 100 = 100 health factor
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintedDsc {
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        // Remember, we need $200 at all times if we have $100 of debt

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        uint256 userHealthFactor = dsce.getHealthFactor(USER);
        // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalDscMinted) =
        // 0.9
        assert(userHealthFactor == 0.9 ether);
    }

    ///////////////////////////
    // Liquidation Tests ////// // Unfinished commented functions
    ///////////////////////////

    // function testMustImproveHealthFactorOnLiquidation() public {}

    function testCantLiquidateGoodHealthFactor() public depositedCollateralAndMintedDsc {
        ERC20Mock(weth).mint(LIQUIDATOR, collateralToCover);

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintDSC(weth, collateralToCover, amountToMint);
        dsc.approve(address(dsce), amountToMint);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorIsOk.selector);
        dsce.liquidate(weth, USER, amountToMint);
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateralAndMintDSC(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = dsce.getHealthFactor(USER);

        ERC20Mock(weth).mint(LIQUIDATOR, collateralToCover);

        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintDSC(weth, collateralToCover, amountToMint);
        dsc.approve(address(dsce), amountToMint);
        dsce.liquidate(weth, USER, amountToMint); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function testPayoutIsCorrectAfeterLiquidation() public liquidated {
        uint256 liquidatorBalance = ERC20Mock(weth).balanceOf(LIQUIDATOR);
        uint256 expectedWeth = dsce.getTokenAmountFromUsd(weth, amountToMint)
            + (dsce.getTokenAmountFromUsd(weth, amountToMint) * dsce.getLiquidationBonus() / dsce.getLiquidationPrecision());

        assertEq(expectedWeth, liquidatorBalance);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorDscMinted,) = dsce.getAccountInfo(LIQUIDATOR);
        assertEq(liquidatorDscMinted, amountToMint);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userDscMinted,) = dsce.getAccountInfo(USER);
        assertEq(userDscMinted, 0);
    }

    //////////////////////////////////
    // View & Pure Function Tests ////
    //////////////////////////////////
    function testGetCollateralTokenPriceFeed() public view {
        address priceFeed = dsce.getCollateralTokenPriceFeed(weth);
        assertEq(priceFeed, ethUsdPriceFeed);
    }

    function testGetCollateralTokens() public view {
        address[] memory collateralTokens = dsce.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
    }

    function testGetMinHealthFactor() public view {
        uint256 minHealthFactor = dsce.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public view {
        uint256 liquidationThreshold = dsce.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValueFromInformation() public collateralDeposited {
        (, uint256 collateralValue) = dsce.getAccountInfo(USER);
        uint256 expectedCollateralValue = dsce.getUsdValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralBalance = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(collateralBalance, amountCollateral);
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralValue = dsce.getAccountCollateralValue(USER);
        uint256 expectedCollateralValue = dsce.getUsdValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetDsc() public view {
        address dscAddress = dsce.getDsc();
        assertEq(dscAddress, address(dsc));
    }

    function testLiquidationPrecision() public view {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = dsce.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }
}
