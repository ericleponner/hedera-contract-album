// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.28;

import { Ownable } from "solady/src/auth/Ownable.sol";
import { EnumerableRoles } from "solady/src/auth/EnumerableRoles.sol";
import { AssetToken } from "../assetToken/AssetToken.sol";

/**
 * @title AssetTokenCCIPCompatible
 * @notice This abstract contract extends the AssetToken functionality by implementing an annual fee mechanism.
 * @dev Tracks the time since the last operation and calculates fees to be minted periodically based on the annual fee rate.
 * Fees are minted to the fee receiver as defined in the BundleStorage contract.
 * @author Swarm
 */
contract AssetTokenCCIPCompatible is AssetToken, Ownable, EnumerableRoles {
    uint256 public constant MINTER_ROLE = uint256(keccak256("MINTER_ROLE"));

    /// @notice Constructor: sets the state variables and provide proper checks to deploy
    /// @param _assetTokenData the asset token data contract address
    /// @param _statePercent the state percent to check the safeguard convertion
    /// @param _kya verification link
    /// @param _minimumRedemptionAmount less than this value is not allowed
    /// @param _name of the token
    /// @param _symbol of the token
    constructor(
        address _assetTokenData,
        address _owner,
        uint256 _statePercent,
        string memory _kya,
        uint256 _minimumRedemptionAmount,
        string memory _name,
        string memory _symbol
    ) AssetToken(_assetTokenData, _statePercent, _kya, _minimumRedemptionAmount, _name, _symbol) {
        _initializeOwner(_owner);
    }

    /**
     * @notice Mints a specified amount of tokens to a given address.
     * @dev Only accounts with the MINTER role can call this function.
     *
     * @param account The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address account, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }
}
