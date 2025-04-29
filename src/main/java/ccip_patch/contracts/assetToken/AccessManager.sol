// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable } from "solady/src/auth/Ownable.sol";
import { EnumerableRoles } from "solady/src/auth/EnumerableRoles.sol";
import { IAuthorizationContract } from "../interfaces/IAuthorizationContract.sol";

/// @author Swarm Markets
/// @title Access Manager for AssetToken Contract
/// @notice Contract to manage the Asset Token contracts
abstract contract AccessManager is EnumerableRoles, Ownable {
    error ZeroAddressPassed();
    error NewAgentEqOldAgent(address agent);
    error ListNotOwned(address oldAgent, address sender);

    enum RoleErrorType {
        OnlyIssuerOrAdmin,
        OnlyGuardianOrAdmin,
        OnlyIssuer,
        OnlyAgent,
        OnlyIssuerOrAgent,
        OnlyIssuerOnActive,
        OnlyAgentOrIssuerOnActive,
        OnlyGuardianOnSafeguard
    }
    error RolesError(address caller, RoleErrorType role);

    enum BlacklistErrorType {
        Blacklisted,
        NotBlacklisted
    }
    error BlacklistError(address account, BlacklistErrorType errorType);

    enum AgentErrorType {
        NotExists,
        Exists,
        HasContractsAssigned
    }
    error AgentError(address token, address agent, AgentErrorType errorType);

    enum TokenErrorType {
        NotStored,
        Registered,
        NotFrozen,
        Frozen,
        NotActiveOnSafeguard
    }
    error TokenError(address token, TokenErrorType errorType);

    enum ContractErrorType {
        NotAContract,
        NotFound,
        NotManagedByCaller,
        BelongsToAgent
    }
    error ContractError(address token, address contractAddress, ContractErrorType errorType);

    enum ValidationErrorType {
        ZeroAddressesPassed,
        AuthListEmpty,
        IndexNotExists,
        RemovingFromAuthFailed,
        AuthListOwnershipTransferFailed,
        AgentWithoutContracts
    }
    error ValidationError(ValidationErrorType errorType);

    /// @notice Emitted when changed max quantity
    event ChangedMaxQtyOfAuthorizationLists(address indexed changedBy, uint newQty);

    /// @notice Emitted when Issuer is transferred
    event IssuerTransferred(address indexed _tokenAddress, address indexed _caller, address indexed _newIssuer);
    /// @notice Emitted when Guardian is transferred
    event GuardianTransferred(address indexed _tokenAddress, address indexed _caller, address indexed _newGuardian);

    /// @notice Emitted when Agent is added to the contract
    event AgentAdded(address indexed _tokenAddress, address indexed _caller, address indexed _newAgent);
    /// @notice Emitted when Agent is removed from the contract
    event AgentRemoved(address indexed _tokenAddress, address indexed _caller, address indexed _agent);

    /// @notice Emitted when an Agent list is transferred to another Agent
    event AgentAuthorizationListTransferred(
        address indexed _tokenAddress,
        address _caller,
        address indexed _newAgent,
        address indexed _oldAgent
    );

    /// @notice Emitted when an account is added to the Asset Token Blacklist
    event AddedToBlacklist(address indexed _tokenAddress, address indexed _account, address indexed _from);
    /// @notice Emitted when an account is removed from the Asset Token Blacklist
    event RemovedFromBlacklist(address indexed _tokenAddress, address indexed _account, address indexed _from);

    /// @notice Emitted when a contract is added to the Asset Token Authorization list
    event AddedToAuthorizationContracts(
        address indexed _tokenAddress,
        address indexed _contractAddress,
        address indexed _from
    );
    /// @notice Emitted when a contract is removed from the Asset Token Authorization list
    event RemovedFromAuthorizationContracts(
        address indexed _tokenAddress,
        address indexed _contractAddress,
        address indexed _from
    );

    /// @notice Emitted when an account is granted with the right to transfer on safeguard state
    event AddedTransferOnSafeguardAccount(address indexed _tokenAddress, address indexed _account);
    /// @notice Emitted when an account is revoked the right to transfer on safeguard state
    event RemovedTransferOnSafeguardAccount(address indexed _tokenAddress, address indexed _account);

    /// @notice Emitted when a new Asset Token is deployed and registered
    event TokenRegistered(address indexed _tokenAddress, address _caller);
    /// @notice Emitted when an  Asset Token is deleted
    event TokenDeleted(address indexed _tokenAddress, address _caller);

    /// @notice Emitted when the contract changes to safeguard mode
    event ChangedToSafeGuard(address indexed _tokenAddress);

    /// @notice Emitted when the contract gets frozen
    event FrozenContract(address indexed _tokenAddress);
    /// @notice Emitted when the contract gets unfrozen
    event UnfrozenContract(address indexed _tokenAddress);

    /// @notice Admin role
    uint256 public constant DEFAULT_ADMIN_ROLE = uint256(keccak256("DEFAULT_ADMIN_ROLE"));
    /// @notice Role to be able to deploy an Asset Token
    uint256 public constant ASSET_DEPLOYER_ROLE = uint256(keccak256("ASSET_DEPLOYER_ROLE"));

    /// @dev This is a WAD on DSMATH representing 1
    /// @dev This is a proportion of 1 representing 100%, equal to a WAD
    uint256 public constant DECIMALS = 10 ** 18;

    /// @notice Structure to hold the Token Data
    /// @notice guardian and issuer of the contract
    /// @notice isFrozen: boolean to store if the contract is frozen
    /// @notice isOnSafeguard: state of the contract: false is ACTIVE // true is SAFEGUARD
    /// @notice positiveInterest: if the interest will be a positvie or negative one
    /// @notice interestRate: the interest rate set in AssetTokenData.setInterestRate() (percent per seconds)
    /// @notice rate: the interest determined by the formula. Default is 10**18
    /// @notice lastUpdate: last block where the update function was called
    /// @notice blacklist: account => bool (if bool = true, account is blacklisted)
    /// @notice agents: agents => bool(true or false) (enabled/disabled agent)
    /// @notice safeguardTransferAllow: allow certain addresses to transfer even on safeguard
    /// @notice authorizationsPerAgent: list of contracts of each agent to authorize a user
    /// @notice array of addresses. Each one is a contract with the isTxAuthorized function
    struct TokenData {
        bool isFrozen;
        bool isOnSafeguard;
        bool positiveInterest;
        uint256 interestRate;
        uint256 rate;
        uint256 lastUpdate;
        address issuer;
        address guardian;
        address[] authorizationContracts;
        mapping(address => bool) blacklist;
        mapping(address => bool) agents;
        mapping(address => bool) safeguardTransferAllow;
        mapping(address => address) authorizationsPerAgent;
    }
    /// @notice mapping of TokenData, entered by token Address
    mapping(address => TokenData) public tokensData;

    /// @dev this is just to have an estimation of qty and prevent innecesary looping
    uint256 public maxQtyOfAuthorizationLists;

    modifier requireNonEmptyAddress(address _address) {
        require(_address != address(0), ZeroAddressPassed());
        _;
    }

    /// @notice Check if the token is valid
    /// @param tokenAddress address of the current token being managed
    modifier onlyStoredToken(address tokenAddress) {
        require(tokensData[tokenAddress].issuer != address(0), TokenError(tokenAddress, TokenErrorType.NotStored));
        _;
    }

    /// @notice Check if sender is an AGENT
    /// @param tokenAddress address of the current token being managed
    /// @param functionCaller the caller of the function where this is used
    modifier onlyAgent(address tokenAddress, address functionCaller) {
        require(tokensData[tokenAddress].agents[functionCaller], RolesError(functionCaller, RoleErrorType.OnlyAgent));
        _;
    }

    /// @notice Allow TRANSFER on Safeguard
    /// @param _tokenAddress address of the current token being managed
    /// @param _account the account to grant the right to transfer on safeguard state
    function allowTransferOnSafeguard(address _tokenAddress, address _account) external onlyStoredToken(_tokenAddress) {
        onlyIssuerOrGuardian(_tokenAddress, msg.sender);
        tokensData[_tokenAddress].safeguardTransferAllow[_account] = true;
        emit AddedTransferOnSafeguardAccount(_tokenAddress, _account);
    }

    /// @notice Removed TRANSFER on Safeguard
    /// @param _tokenAddress address of the current token being managed
    /// @param _account the account to be revoked from the right to transfer on safeguard state
    function preventTransferOnSafeguard(
        address _tokenAddress,
        address _account
    ) external onlyStoredToken(_tokenAddress) {
        onlyIssuerOrGuardian(_tokenAddress, msg.sender);
        tokensData[_tokenAddress].safeguardTransferAllow[_account] = false;
        emit RemovedTransferOnSafeguardAccount(_tokenAddress, _account);
    }

    function changeMaxQtyOfAuthorizationLists(uint newMaxQty) public onlyRole(DEFAULT_ADMIN_ROLE) {
        maxQtyOfAuthorizationLists = newMaxQty;
        emit ChangedMaxQtyOfAuthorizationLists(msg.sender, newMaxQty);
    }

    /**
     * @notice Checks if the user is authorized by the agent
     * @dev This function verifies if the `_from` and `_to` addresses are authorized to perform a given `_amount`
     * transaction on the asset token contract `_tokenAddress`.
     * @param _tokenAddress The address of the current token being managed
     * @param _from The address to be checked if it's authorized
     * @param _to The address to be checked if it's authorized
     * @param _amount The amount of the operation to be made
     * @return bool Returns true if `_from` and `_to` are authorized to perform the transaction
     */
    function mustBeAuthorizedHolders(
        address _tokenAddress,
        address _from,
        address _to,
        uint256 _amount
    ) external onlyStoredToken(_tokenAddress) returns (bool) {
        require(msg.sender == _tokenAddress, ContractError(_tokenAddress, msg.sender, ContractErrorType.NotAContract));
        // This line below should never happen. A registered asset token shouldn't call
        // to this function with both addresses (from - to) in ZERO
        require(_from != address(0) || _to != address(0), ValidationError(ValidationErrorType.ZeroAddressesPassed));

        address[2] memory addresses = [_from, _to];
        uint256 response = 0;
        uint256 arrayLength = addresses.length;
        TokenData storage token = tokensData[_tokenAddress];
        for (uint256 i = 0; i < arrayLength; ++i) {
            if (addresses[i] != address(0)) {
                require(!token.blacklist[addresses[i]], BlacklistError(addresses[i], BlacklistErrorType.Blacklisted));

                /// @dev the caller (the asset token contract) is an authorized holder
                if (addresses[i] == _tokenAddress && addresses[i] == msg.sender) {
                    response++;
                    // this is a resource to avoid validating this contract in other system
                    addresses[i] = address(0);
                }
                if (!token.isOnSafeguard) {
                    /// @dev on active state, issuer and agents are authorized holder
                    if (addresses[i] == token.issuer || token.agents[addresses[i]]) {
                        response++;
                        // this is a resource to avoid validating agent/issuer in other system
                        addresses[i] = address(0);
                    }
                } else {
                    /// @dev on safeguard state, guardian is authorized holder
                    if (addresses[i] == token.guardian) {
                        response++;
                        // this is a resource to avoid validating guardian in other system
                        addresses[i] = address(0);
                    }
                }

                /// each of these if statements are mutually exclusive, so response cannot be more than 2
            }
        }

        /// if response is more than 0 none of the address are:
        /// the asset token contract itself, agents, issuer or guardian
        /// if response is 1 there is one address which is one of the above
        /// if response is 2 both addresses are one of the above, no need to iterate in external list
        if (response < 2) {
            uint256 length = token.authorizationContracts.length;
            require(length > 0, ValidationError(ValidationErrorType.AuthListEmpty));
            for (uint256 i = 0; i < length; ++i) {
                if (
                    IAuthorizationContract(token.authorizationContracts[i]).isTxAuthorized(
                        _tokenAddress,
                        addresses[0],
                        addresses[1],
                        _amount
                    )
                ) {
                    return true;
                }
            }
        } else {
            return true;
        }
        return false;
    }

    /// @notice Changes the ISSUER
    /// @param _tokenAddress address of the current token being managed
    /// @param _newIssuer to be assigned in the contract
    function transferIssuer(address _tokenAddress, address _newIssuer) external onlyStoredToken(_tokenAddress) {
        TokenData storage tokenData = tokensData[_tokenAddress];
        require(
            msg.sender == tokenData.issuer || hasRole(msg.sender, DEFAULT_ADMIN_ROLE),
            RolesError(msg.sender, RoleErrorType.OnlyIssuerOrAdmin)
        );
        tokenData.issuer = _newIssuer;
        emit IssuerTransferred(_tokenAddress, msg.sender, _newIssuer);
    }

    /// @notice Changes the GUARDIAN
    /// @param _tokenAddress address of the current token being managed
    /// @param _newGuardian to be assigned in the contract
    function transferGuardian(address _tokenAddress, address _newGuardian) external onlyStoredToken(_tokenAddress) {
        TokenData storage tokenData = tokensData[_tokenAddress];
        require(
            msg.sender == tokenData.guardian || hasRole(msg.sender, DEFAULT_ADMIN_ROLE),
            RolesError(msg.sender, RoleErrorType.OnlyGuardianOrAdmin)
        );
        tokenData.guardian = _newGuardian;
        emit GuardianTransferred(_tokenAddress, msg.sender, _newGuardian);
    }

    /// @notice Adds an AGENT
    /// @param _tokenAddress address of the current token being managed
    /// @param _newAgent to be added
    function addAgent(address _tokenAddress, address _newAgent) external onlyStoredToken(_tokenAddress) {
        onlyIssuerOrGuardian(_tokenAddress, msg.sender);
        TokenData storage tokenData = tokensData[_tokenAddress];
        require(!tokenData.agents[_newAgent], AgentError(_tokenAddress, _newAgent, AgentErrorType.Exists));
        tokenData.agents[_newAgent] = true;
        emit AgentAdded(_tokenAddress, msg.sender, _newAgent);
    }

    /// @notice Deletes an AGENT
    /// @param _tokenAddress address of the current token being managed
    /// @param _agent to be removed
    function removeAgent(address _tokenAddress, address _agent) external onlyStoredToken(_tokenAddress) {
        onlyIssuerOrGuardian(_tokenAddress, msg.sender);
        TokenData storage tokenData = tokensData[_tokenAddress];
        require(tokenData.agents[_agent], AgentError(_tokenAddress, _agent, AgentErrorType.NotExists));

        require(
            !_agentHasContractsAssigned(_tokenAddress, _agent),
            AgentError(_tokenAddress, _agent, AgentErrorType.HasContractsAssigned)
        );

        delete tokenData.agents[_agent];
        emit AgentRemoved(_tokenAddress, msg.sender, _agent);
    }

    /// @notice Transfers the authorization contracts to a new Agent
    /// @param _tokenAddress address of the current token being managed
    /// @param _newAgent to link the authorization list
    /// @param _oldAgent to unlink the authrization list
    function transferAgentList(
        address _tokenAddress,
        address _newAgent,
        address _oldAgent
    ) external onlyStoredToken(_tokenAddress) {
        TokenData storage tokenData = tokensData[_tokenAddress];

        if (!tokenData.isOnSafeguard) {
            require(
                msg.sender == tokenData.issuer || tokenData.agents[msg.sender],
                RolesError(msg.sender, RoleErrorType.OnlyAgentOrIssuerOnActive)
            );
        } else {
            require(msg.sender == tokenData.guardian, RolesError(msg.sender, RoleErrorType.OnlyGuardianOnSafeguard));
        }
        require(tokenData.authorizationContracts.length > 0, ValidationError(ValidationErrorType.AuthListEmpty));
        require(_newAgent != _oldAgent, NewAgentEqOldAgent(_newAgent));
        require(tokenData.agents[_oldAgent], AgentError(_tokenAddress, _oldAgent, AgentErrorType.NotExists));

        if (msg.sender != tokenData.issuer && msg.sender != tokenData.guardian) {
            require(_oldAgent == msg.sender, ListNotOwned(_oldAgent, msg.sender));
        }
        require(tokenData.agents[_newAgent], AgentError(_tokenAddress, _newAgent, AgentErrorType.NotExists));

        (bool executionOk, bool changed) = _changeAuthorizationOwnership(_tokenAddress, _newAgent, _oldAgent);
        // this 2 lines below should never happen. The change list owner should always be successfull
        // because of the requires validating the information before calling _changeAuthorizationOwnership
        require(executionOk, ValidationError(ValidationErrorType.AuthListOwnershipTransferFailed));
        require(changed, ValidationError(ValidationErrorType.AgentWithoutContracts));
        emit AgentAuthorizationListTransferred(_tokenAddress, msg.sender, _newAgent, _oldAgent);
    }

    /// @notice Adds an address to the authorization list
    /// @param _tokenAddress address of the current token being managed
    /// @param _contractAddress the address to be added
    function addToAuthorizationList(
        address _tokenAddress,
        address _contractAddress
    ) external onlyStoredToken(_tokenAddress) onlyAgent(_tokenAddress, msg.sender) {
        require(
            _isContract(_contractAddress),
            ContractError(_tokenAddress, _contractAddress, ContractErrorType.NotAContract)
        );
        TokenData storage tokenData = tokensData[_tokenAddress];
        require(
            tokenData.authorizationsPerAgent[_contractAddress] == address(0),
            ContractError(_tokenAddress, _contractAddress, ContractErrorType.BelongsToAgent)
        );
        tokenData.authorizationContracts.push(_contractAddress);
        tokenData.authorizationsPerAgent[_contractAddress] = msg.sender;
        emit AddedToAuthorizationContracts(_tokenAddress, _contractAddress, msg.sender);
    }

    /// @notice Removes an address from the authorization list
    /// @param _tokenAddress address of the current token being managed
    /// @param _contractAddress the address to be removed
    function removeFromAuthorizationList(
        address _tokenAddress,
        address _contractAddress
    ) external onlyStoredToken(_tokenAddress) onlyAgent(_tokenAddress, msg.sender) {
        require(
            _isContract(_contractAddress),
            ContractError(_tokenAddress, _contractAddress, ContractErrorType.NotAContract)
        );
        TokenData storage tokenData = tokensData[_tokenAddress];
        require(
            tokenData.authorizationsPerAgent[_contractAddress] != address(0),
            ContractError(_tokenAddress, _contractAddress, ContractErrorType.NotFound)
        );
        require(
            tokenData.authorizationsPerAgent[_contractAddress] == msg.sender,
            ContractError(_tokenAddress, _contractAddress, ContractErrorType.NotManagedByCaller)
        );

        // this line below should never happen. The removal should always be successfull
        // because of the require validating the caller before _removeFromAuthorizationArray
        require(
            _removeFromAuthorizationArray(_tokenAddress, _contractAddress),
            ValidationError(ValidationErrorType.RemovingFromAuthFailed)
        );

        delete tokenData.authorizationsPerAgent[_contractAddress];
        emit RemovedFromAuthorizationContracts(_tokenAddress, _contractAddress, msg.sender);
    }

    /// @notice Adds an address to the blacklist
    /// @param _tokenAddress address of the current token being managed
    /// @param _account the address to be blacklisted
    function addMemberToBlacklist(address _tokenAddress, address _account) external onlyStoredToken(_tokenAddress) {
        onlyIssuerOrGuardian(_tokenAddress, msg.sender);
        TokenData storage tokenData = tokensData[_tokenAddress];
        require(!tokenData.blacklist[_account], BlacklistError(_account, BlacklistErrorType.Blacklisted));
        tokenData.blacklist[_account] = true;
        emit AddedToBlacklist(_tokenAddress, _account, msg.sender);
    }

    /// @notice Removes an address from the blacklist
    /// @param _tokenAddress address of the current token being managed
    /// @param _account the address to be removed from the blacklisted
    function removeMemberFromBlacklist(
        address _tokenAddress,
        address _account
    ) external onlyStoredToken(_tokenAddress) {
        onlyIssuerOrGuardian(_tokenAddress, msg.sender);
        TokenData storage tokenData = tokensData[_tokenAddress];
        require(tokenData.blacklist[_account], BlacklistError(_account, BlacklistErrorType.NotBlacklisted));
        delete tokenData.blacklist[_account];
        emit RemovedFromBlacklist(_tokenAddress, _account, msg.sender);
    }

    /// @notice Register the asset tokens and its rates in this contract
    /// @param _tokenAddress address of the current token being managed
    /// @param _issuer address of the contract issuer
    /// @param _guardian address of the contract guardian
    /// @return bool true if operation was successful
    function registerAssetToken(
        address _tokenAddress,
        address _issuer,
        address _guardian
    )
        external
        onlyRole(ASSET_DEPLOYER_ROLE)
        requireNonEmptyAddress(_tokenAddress)
        requireNonEmptyAddress(_issuer)
        requireNonEmptyAddress(_guardian)
        returns (bool)
    {
        TokenData storage tokenData = tokensData[_tokenAddress];
        require(tokenData.issuer == address(0), TokenError(_tokenAddress, TokenErrorType.Registered));
        require(
            _isContract(_tokenAddress),
            ContractError(_tokenAddress, address(this), ContractErrorType.NotAContract)
        );

        tokenData.issuer = _issuer;
        tokenData.guardian = _guardian;
        tokenData.rate = DECIMALS;
        tokenData.lastUpdate = block.timestamp;

        emit TokenRegistered(_tokenAddress, msg.sender);
        return true;
    }

    /// @notice Deletes the asset token from this contract
    /// @notice It has no real use (I think should be removed)
    /// @param _tokenAddress address of the current token being managed
    function deleteAssetToken(address _tokenAddress) external onlyStoredToken(_tokenAddress) {
        onlyUnfrozenContract(_tokenAddress);
        onlyIssuerOrGuardian(_tokenAddress, msg.sender);
        delete tokensData[_tokenAddress];
        emit TokenDeleted(_tokenAddress, msg.sender);
    }

    /// @notice Set the contract into Safeguard)
    /// @param _tokenAddress address of the current token being managed
    /// @return bool true if operation was successful
    function setContractToSafeguard(address _tokenAddress) external onlyStoredToken(_tokenAddress) returns (bool) {
        onlyUnfrozenContract(_tokenAddress);
        onlyActiveContract(_tokenAddress);
        require(msg.sender == _tokenAddress, ContractError(_tokenAddress, msg.sender, ContractErrorType.NotAContract));
        tokensData[_tokenAddress].isOnSafeguard = true;
        emit ChangedToSafeGuard(_tokenAddress);
        return true;
    }

    /// @notice Freeze the contract
    /// @param _tokenAddress address of the current token being managed
    /// @return bool true if operation was successful
    function freezeContract(address _tokenAddress) external onlyStoredToken(_tokenAddress) returns (bool) {
        require(msg.sender == _tokenAddress, ContractError(_tokenAddress, msg.sender, ContractErrorType.NotAContract));
        TokenData storage tokenData = tokensData[_tokenAddress];
        require(!tokenData.isFrozen, TokenError(_tokenAddress, TokenErrorType.Frozen));

        tokenData.isFrozen = true;
        emit FrozenContract(_tokenAddress);
        return true;
    }

    /// @notice Unfreeze the contract
    /// @param _tokenAddress address of the current token being managed
    /// @return bool true if operation was successful
    function unfreezeContract(address _tokenAddress) external onlyStoredToken(_tokenAddress) returns (bool) {
        require(msg.sender == _tokenAddress, ContractError(_tokenAddress, msg.sender, ContractErrorType.NotAContract));
        TokenData storage tokenData = tokensData[_tokenAddress];
        require(tokenData.isFrozen, TokenError(_tokenAddress, TokenErrorType.NotFrozen));

        tokenData.isFrozen = false;
        emit UnfrozenContract(_tokenAddress);
        return true;
    }

    /// @notice Check if the token contract is Active
    /// @param _tokenAddress address of the current token being managed
    function onlyActiveContract(address _tokenAddress) public view {
        require(
            !tokensData[_tokenAddress].isOnSafeguard,
            TokenError(_tokenAddress, TokenErrorType.NotActiveOnSafeguard)
        );
    }

    /// @notice Check if the token contract is Not frozen
    /// @param tokenAddress address of the current token being managed
    function onlyUnfrozenContract(address tokenAddress) public view {
        require(!tokensData[tokenAddress].isFrozen, TokenError(tokenAddress, TokenErrorType.Frozen));
    }

    /// @notice Check if sender is the ISSUER
    /// @param _tokenAddress address of the current token being managed
    /// @param _functionCaller the caller of the function where this is used
    function onlyIssuer(address _tokenAddress, address _functionCaller) external view {
        require(
            _functionCaller == tokensData[_tokenAddress].issuer,
            RolesError(_functionCaller, RoleErrorType.OnlyIssuer)
        );
    }

    /// @notice Check if sender is AGENT_or ISSUER
    /// @param _tokenAddress address of the current token being managed
    /// @param _functionCaller the caller of the function where this is used
    function onlyIssuerOrAgent(address _tokenAddress, address _functionCaller) external view {
        TokenData storage data = tokensData[_tokenAddress];
        require(
            _functionCaller == data.issuer || data.agents[_functionCaller],
            RolesError(_functionCaller, RoleErrorType.OnlyIssuerOrAgent)
        );
    }

    /// @notice Check if sender is GUARDIAN or ISSUER
    /// @param _tokenAddress address of the current token being managed
    /// @param _functionCaller the caller of the function where this is used
    function onlyIssuerOrGuardian(address _tokenAddress, address _functionCaller) public view {
        TokenData storage data = tokensData[_tokenAddress];
        if (data.isOnSafeguard) {
            require(
                _functionCaller == data.guardian,
                RolesError(_functionCaller, RoleErrorType.OnlyGuardianOnSafeguard)
            );
        } else {
            require(_functionCaller == data.issuer, RolesError(_functionCaller, RoleErrorType.OnlyIssuerOnActive));
        }
    }

    /// @notice Return if the account can transfer on safeguard
    /// @param _tokenAddress address of the current token being managed
    /// @param _account the account to get info from
    /// @return isAllowed bool true or false
    function isAllowedTransferOnSafeguard(
        address _tokenAddress,
        address _account
    ) external view onlyStoredToken(_tokenAddress) returns (bool isAllowed) {
        isAllowed = tokensData[_tokenAddress].safeguardTransferAllow[_account];
    }

    /// @notice Get if the contract is on SafeGuard or not
    /// @param _tokenAddress address of the current token being managed
    /// @return bool true if the contract is on SafeGuard
    function isOnSafeguard(address _tokenAddress) external view onlyStoredToken(_tokenAddress) returns (bool) {
        return tokensData[_tokenAddress].isOnSafeguard;
    }

    /// @notice Get if the contract is frozen or not
    /// @param _tokenAddress address of the current token being managed
    /// @return isFrozen bool true if the contract is frozen
    function isContractFrozen(
        address _tokenAddress
    ) external view onlyStoredToken(_tokenAddress) returns (bool isFrozen) {
        isFrozen = tokensData[_tokenAddress].isFrozen;
    }

    /// @notice Get the issuer of the asset token
    /// @param _tokenAddress address of the current token being managed
    /// @return address the issuer address
    function getIssuer(address _tokenAddress) external view onlyStoredToken(_tokenAddress) returns (address) {
        return tokensData[_tokenAddress].issuer;
    }

    /// @notice Get the guardian of the asset token
    /// @param _tokenAddress address of the current token being managed
    /// @return address the guardian address
    function getGuardian(address _tokenAddress) external view onlyStoredToken(_tokenAddress) returns (address) {
        return tokensData[_tokenAddress].guardian;
    }

    /// @notice Get if the account is blacklisted for the asset token
    /// @param _tokenAddress address of the current token being managed
    /// @return blacklisted bool true if the account is blacklisted
    function isBlacklisted(
        address _tokenAddress,
        address _account
    ) external view onlyStoredToken(_tokenAddress) returns (bool blacklisted) {
        blacklisted = tokensData[_tokenAddress].blacklist[_account];
    }

    /// @notice Get if the account is an agent of the asset token
    /// @param _tokenAddress address of the current token being managed
    /// @return _agent bool true if account is an agent
    function isAgent(
        address _tokenAddress,
        address _agentAddress
    ) external view onlyStoredToken(_tokenAddress) returns (bool _agent) {
        _agent = tokensData[_tokenAddress].agents[_agentAddress];
    }

    /// @notice Get the agent address who was responsable of the validation contract (_contractAddress)
    /// @param _tokenAddress address of the current token being managed
    /// @return addedBy address of the agent
    function authorizationContractAddedBy(
        address _tokenAddress,
        address _contractAddress
    ) external view onlyStoredToken(_tokenAddress) returns (address addedBy) {
        addedBy = tokensData[_tokenAddress].authorizationsPerAgent[_contractAddress];
    }

    /// @notice Get the position (index) in the authorizationContracts array of the authorization contract
    /// @param _tokenAddress address of the current token being managed
    /// @return uint256 the index of the array
    function getIndexByAuthorizationAddress(
        address _tokenAddress,
        address _authorizationContractAddress
    ) external view onlyStoredToken(_tokenAddress) returns (uint256) {
        TokenData storage token = tokensData[_tokenAddress];
        uint256 length = token.authorizationContracts.length;
        for (uint256 i = 0; i < length; ++i) {
            if (token.authorizationContracts[i] == _authorizationContractAddress) {
                return i;
            }
        }
        /// @dev returning this when address is not found
        return maxQtyOfAuthorizationLists + 1;
    }

    /// @notice Get the authorization contract address given an index in authorizationContracts array
    /// @param _tokenAddress address of the current token being managed
    /// @return addressByIndex address the address of the authorization contract
    function getAuthorizationAddressByIndex(
        address _tokenAddress,
        uint256 _index
    ) external view returns (address addressByIndex) {
        TokenData storage token = tokensData[_tokenAddress];
        require(_index < token.authorizationContracts.length, ValidationError(ValidationErrorType.IndexNotExists));
        addressByIndex = token.authorizationContracts[_index];
    }

    /* *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */

    /// @notice Returns true if `account` is a contract
    /// @param _contractAddress the address to be ckecked
    /// @return bool if `account` is a contract
    function _isContract(address _contractAddress) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(_contractAddress)
        }
        return size > 0;
    }

    /// @notice checks if the agent has a contract from the array list assigned
    /// @param _tokenAddress address of the current token being managed
    /// @param _agent agent to check
    /// @return bool if the agent has any contract assigned
    function _agentHasContractsAssigned(address _tokenAddress, address _agent) internal view returns (bool) {
        TokenData storage token = tokensData[_tokenAddress];
        uint256 length = token.authorizationContracts.length;
        for (uint256 i = 0; i < length; ++i) {
            if (token.authorizationsPerAgent[token.authorizationContracts[i]] == _agent) {
                return true;
            }
        }
        return false;
    }

    /// @notice changes the owner of the contracts auth array
    /// @param _tokenAddress address of the current token being managed
    /// @param _newAgent target agent to link the contracts to
    /// @param _oldAgent source agent to unlink the contracts from
    /// @return bool true if there was no error
    /// @return bool true if authorization ownership has occurred
    function _changeAuthorizationOwnership(
        address _tokenAddress,
        address _newAgent,
        address _oldAgent
    ) internal returns (bool, bool) {
        bool changed = false;
        TokenData storage token = tokensData[_tokenAddress];
        uint256 length = token.authorizationContracts.length;
        for (uint256 i = 0; i < length; ++i) {
            if (token.authorizationsPerAgent[token.authorizationContracts[i]] == _oldAgent) {
                token.authorizationsPerAgent[token.authorizationContracts[i]] = _newAgent;
                changed = true;
            }
        }
        return (true, changed);
    }

    /// @notice removes contract from auth array
    /// @param _tokenAddress address of the current token being managed
    /// @param _contractAddress to be removed
    /// @return bool if address was removed
    function _removeFromAuthorizationArray(address _tokenAddress, address _contractAddress) internal returns (bool) {
        TokenData storage token = tokensData[_tokenAddress];
        uint256 length = token.authorizationContracts.length;
        for (uint256 i = 0; i < length; ++i) {
            if (token.authorizationContracts[i] == _contractAddress) {
                token.authorizationContracts[i] = token.authorizationContracts[length - 1];
                token.authorizationContracts.pop();
                return true;
            }
        }
        // This line below should never happen. Before calling this function,
        // it is known that the address exists in the array
        return false;
    }
}
