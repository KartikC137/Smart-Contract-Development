// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCEngine
 * @author Kartik Kumbhar
 *
 * The System is designed to be as minimal as possible, and have the tokens maintain a 1 token == 1$ Peg
 * This StableCoin has properties:
 * 1. Exogenous Collateral
 * 2. Dollar Pegged
 * 3. Algorithmically Stable
 *
 * It is similar to DAI if had no governance, no fees, and was only backed by WETH AND WBTC.
 * DSC System should always be Over Collateralized, at no point should the value of all collateral be <= value of all the DSC.
 * @notice This contract is the core of DSC System. It handles all the logic for mining and redeeming DSC, as well as depositing & Withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 */
contract DSCEngine is ReentrancyGuard {
    //////////////////
    // Errors      ///
    //////////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeOfSameLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__DepositFailed();
    error DSCEngine__HealthFactorTooLow();
    error DSCEngine__MintingFailed();

    ////////////////////////
    // State Variables   ///
    ////////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //200% OVER COLLATERALIZED
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amount) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    //////////////
    // Events  ///
    //////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    //////////////////
    // Modifiers   ///
    //////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    //////////////////
    // Functions   ///
    //////////////////
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddress, address dscAddress) {
        // USD Price Feeds
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeOfSameLength();
        }
        // For example ETH / USD, BTC / USD etc
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////////////////
    // External Functions   ///
    ///////////////////////////

    function depositCollateralAndMintDSC() external {}

    /* 
     * @notice follows CEI
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__DepositFailed();
        }
    }

    function redeemCollateralForDSC() external {}

    function redeemCollateral() external {}

    /*
     * @notice follows CEI
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * @notice they must have more collateral than the minimum threshold
     */
    function mintDSC(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        // Checking if they have enough collateral
        revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintingFailed();
        }
    }

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    //////////////////////////////////////////////////
    // Private & Internal Functions View function  ///
    //////////////////////////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUsd)
    {
        totalDSCMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /*
    * Returns how close to liquidation the user is
    * If a user goess below 1 health factor, then they can get liquidated
    */
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted
        // total collateral Value
        (uint256 totalDSCMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThresold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        // ex for 1000 ETH collateral,
        // 1000 ETH * 50 / 100 = 50000 / 100 = 500
        // cannot mint more than 500 DSC, hence 200% overcollateralized

        // $150 ETH / 100 DSC = 1.5
        // 150 * 50  / 100 = 75
        // 75 / 100 = 0.75 < 1

        return (collateralAdjustedForThresold * PRECISION / totalDSCMinted);
    }

    // 1. Check health factor (If they have enough collateral)
    // 2. If not, revert
    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorTooLow();
        }
    }

    //////////////////////////////////////////////////
    // Public & External Functions View Functions  ///
    //////////////////////////////////////////////////

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token, get the amount they have deposited and map it to the price to get the USD value
        for (uint256 i = 0; i <= s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // if 1ETH =  $1000, the rounded value from chainlink is 1000 * 1e8

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION; // (1000 * 1e8 * 1e10) = 1000 * 1e18
    }
}
