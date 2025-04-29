// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { FixedPointMathLib } from "solady/src/utils/FixedPointMathLib.sol";
import { AccessManager } from "./AccessManager.sol";

/// @author Swarm Markets
/// @title Asset Token Data for Asset Token Contract
/// @notice Manages interest rate calculations for Asset Tokens
contract AssetTokenData is AccessManager {
    using FixedPointMathLib for uint256;

    error MaxQtyOfAuthorizationListsError(uint256 maxQtyOfAuthorizationLists);
    error InterestRateError(uint256 interestRate, uint256 HUNDRED_PERCENT_ANNUAL);

    /// @notice Emitted when the interest rate is set
    event InterestRateStored(
        address indexed token,
        address indexed caller,
        uint256 interestRate,
        bool positiveInterest
    );

    /// @notice Emitted when the rate gets updated
    event RateUpdated(address indexed token, address indexed caller, uint256 newRate, bool positiveInterest);

    uint256 public constant HUNDRED_PERCENT_ANNUAL = 21979553151;

    /// @notice Constructor
    /// @param _maxQtyOfAuthorizationLists max qty for addresses to be added in the authorization list
    constructor(uint256 _maxQtyOfAuthorizationLists) {
        require(
            _maxQtyOfAuthorizationLists > 0 && _maxQtyOfAuthorizationLists < 100,
            MaxQtyOfAuthorizationListsError(_maxQtyOfAuthorizationLists)
        );

        maxQtyOfAuthorizationLists = _maxQtyOfAuthorizationLists;
        _initializeOwner(msg.sender);
        _setRole(msg.sender, DEFAULT_ADMIN_ROLE, true);
    }

    /// @notice Gets the interest rate and positive/negative interest value
    /// @param token address of the current token being managed
    /// @return rate uint256 the interest rate
    /// @return isPositive bool true if it is positive interest, false if it is not
    function getInterestRate(
        address token
    ) external view onlyStoredToken(token) returns (uint256 rate, bool isPositive) {
        TokenData storage data = tokensData[token];
        return (data.interestRate, data.positiveInterest);
    }

    /// @notice Gets the current rate
    /// @param token address of the current token being managed
    /// @return rate uint256 the rate
    function getCurrentRate(address token) external view onlyStoredToken(token) returns (uint256) {
        return tokensData[token].rate;
    }

    /// @notice Gets the timestamp of the last update
    /// @param token address of the current token being managed
    /// @return lastUpd uint256 the last update in block.timestamp format
    function getLastUpdate(address token) external view onlyStoredToken(token) returns (uint256) {
        return tokensData[token].lastUpdate;
    }

    /// @notice Sets the new intereset rate
    /// @param token address of the current token being managed
    /// @param interestRate the value to be set (the value is in percent per seconds)
    /// @param positiveInterest if it's a negative or positive interest
    function setInterestRate(
        address token,
        uint256 interestRate,
        bool positiveInterest
    ) external onlyStoredToken(token) {
        onlyIssuerOrGuardian(token, msg.sender);
        require(interestRate <= HUNDRED_PERCENT_ANNUAL, InterestRateError(interestRate, HUNDRED_PERCENT_ANNUAL));

        update(token);

        TokenData storage data = tokensData[token];
        data.interestRate = interestRate;
        data.positiveInterest = positiveInterest;

        emit InterestRateStored(token, msg.sender, interestRate, positiveInterest);
    }

    /// @notice Update the Structure counting the blocks since the last update and calculating the rate
    /// @param token address of the current token being managed
    function update(address token) public onlyStoredToken(token) returns (uint256 newRate) {
        TokenData storage data = tokensData[token];

        uint256 multiplier = data.positiveInterest ? DECIMALS + data.interestRate : DECIMALS - data.interestRate;
        newRate = (data.rate * multiplier.rpow(block.timestamp - data.lastUpdate, DECIMALS)) / DECIMALS;

        data.rate = newRate;
        data.lastUpdate = block.timestamp;

        emit RateUpdated(token, msg.sender, newRate, data.positiveInterest);
    }
}
