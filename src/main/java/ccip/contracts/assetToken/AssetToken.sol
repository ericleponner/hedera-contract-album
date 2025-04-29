// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ERC20 } from "solady/src/tokens/ERC20.sol";
import { ReentrancyGuard } from "solady/src/utils/ReentrancyGuard.sol";
import { AssetTokenData } from "./AssetTokenData.sol";

/// @author Swarm Markets
/// @title AssetToken
/// @notice Main Asset Token Contract
contract AssetToken is ERC20, ReentrancyGuard {
    error ZeroAddressPassed();
    error WrongKYA(string kya);

    enum RequestErrorType {
        NotExists,
        Completed,
        Cancelled,
        UnstakeRequested
    }
    error RequestError(uint256 requestID, RequestErrorType errorType);

    enum AmountErrorType {
        ZeroAmount,
        NotEnoughFunds,
        MaxStatePercentReached,
        AmountExceedsStaked,
        MinRedemptionAmountNotReached
    }
    error AmountError(uint256 value1, uint256 value2, AmountErrorType errorType);

    enum ContractErrorType {
        NotAuthorizedOnActive,
        NotAllowedOnSafeguard,
        FreezingError,
        UnfreezingError,
        SafeguardChangeError,
        ContractIsActiveNotOnSafeguard
    }
    error ContractError(address contractAddress, ContractErrorType errorType);

    /// @notice Emitted when the address of the asset token data is set
    event AssetTokenDataChanged(address indexed oldAddress, address indexed newAddress, address indexed caller);

    /// @notice Emitted when kya string is set
    event KyaChanged(string kya, address indexed caller);

    /// @notice Emitted when minimumRedemptionAmount is set
    event MinimumRedemptionAmountChanged(uint256 newAmount, address indexed caller);

    /// @notice Emitted when a mint request is requested
    event MintRequested(
        uint256 indexed mintRequestID,
        address indexed destination,
        uint256 amount,
        address indexed caller
    );

    /// @notice Emitted when a mint request gets approved
    event MintApproved(
        uint256 indexed mintRequestID,
        address indexed destination,
        uint256 amountMinted,
        address indexed caller
    );

    /// @notice Emitted when a redemption request is requested
    event RedemptionRequested(
        uint256 indexed redemptionRequestID,
        uint256 assetTokenAmount,
        uint256 underlyingAssetAmount,
        bool fromStake,
        address indexed caller
    );

    /// @notice Emitted when a redemption request is cancelled
    event RedemptionCanceled(
        uint256 indexed redemptionRequestID,
        address indexed requestReceiver,
        string motive,
        address indexed caller
    );

    /// @notice Emitted when a redemption request is approved
    event RedemptionApproved(
        uint256 indexed redemptionRequestID,
        uint256 assetTokenAmount,
        uint256 underlyingAssetAmount,
        address indexed requestReceiver,
        address indexed caller
    );

    /// @notice Emitted when the token gets bruned
    event TokenBurned(uint256 amount, address indexed caller);

    /// @notice Emitted when the contract change to safeguard
    event SafeguardUnstaked(uint256 amount, address indexed caller);

    /// @dev This is a WAD on DSMATH representing 1
    /// @dev This is a proportion of 1 representing 100%, equal to a WAD
    uint256 public constant DECIMALS_HUNDRED_PERCENT = 10 ** 18;

    /// @dev Used to check access to functions as a kindof modifiers
    uint256 private constant ACTIVE_CONTRACT = 1 << 0;
    uint256 private constant UNFROZEN_CONTRACT = 1 << 1;
    uint256 private constant ONLY_ISSUER = 1 << 2;
    uint256 private constant ONLY_ISSUER_OR_GUARDIAN = 1 << 3;
    uint256 private constant ONLY_ISSUER_OR_AGENT = 1 << 4;

    string private constant AUTOMATIC_REDEMPTION_APPROVAL = "AutomaticRedemptionApproval";

    string private NAME;
    string private SYMBOL;

    /// @notice AssetTokenData Address
    address public assetTokenDataAddress;

    /// @notice Structure to hold the Mint Requests
    struct MintRequest {
        address destination;
        uint256 amount;
        string referenceTo;
        bool completed;
    }
    /// @notice Mint Requests mapping and last ID
    mapping(uint256 => MintRequest) public mintRequests;
    uint256 public mintRequestID;

    /// @notice Structure to hold the Redemption Requests
    struct RedemptionRequest {
        address sender;
        string receipt;
        uint256 assetTokenAmount;
        uint256 underlyingAssetAmount;
        bool completed;
        bool fromStake;
        string approveTxID;
        address canceledBy;
    }
    /// @notice Redemption Requests mapping and last ID
    mapping(uint256 => RedemptionRequest) public redemptionRequests;
    uint256 public redemptionRequestID;

    /// @notice stakedRedemptionRequests is map from requester to request ID
    /// @notice exists to detect that sender already has request from stake function
    mapping(address => uint256) public stakedRedemptionRequests;

    /// @notice mapping to hold each user safeguardStake amoun
    mapping(address => uint256) public safeguardStakes;

    /// @notice sum of the total stakes amounts
    uint256 public totalStakes;

    /// @notice the percetage (on 18 digits)
    /// @notice if this gets overgrown the contract change state
    uint256 public statePercent;

    /// @notice know your asset string
    string public kya;

    /// @notice minimum Redemption Amount (in Asset token value)
    uint256 public minimumRedemptionAmount;

    modifier requireNonEmptyAddress(address _address) {
        require(_address != address(0), ZeroAddressPassed());
        _;
    }

    /// @notice Constructor: sets the state variables and provide proper checks to deploy
    /// @param _assetTokenData the asset token data contract address
    /// @param _statePercent the state percent to check the safeguard convertion
    /// @param _kya verification link
    /// @param _minimumRedemptionAmount less than this value is not allowed
    /// @param _name of the token
    /// @param _symbol of the token
    constructor(
        address _assetTokenData,
        uint256 _statePercent,
        string memory _kya,
        uint256 _minimumRedemptionAmount,
        string memory _name,
        string memory _symbol
    ) requireNonEmptyAddress(_assetTokenData) {
        require(_statePercent > 0, AmountError(_statePercent, 0, AmountErrorType.ZeroAmount));
        require(
            _statePercent <= DECIMALS_HUNDRED_PERCENT,
            AmountError(_statePercent, DECIMALS_HUNDRED_PERCENT, AmountErrorType.MaxStatePercentReached)
        );
        require(bytes(_kya).length > 3, WrongKYA(_kya));

        NAME = _name;
        SYMBOL = _symbol;
        // IT IS THE WAD EQUIVALENT USED IN DSMATH
        assetTokenDataAddress = _assetTokenData;
        statePercent = _statePercent;
        kya = _kya;
        minimumRedemptionAmount = _minimumRedemptionAmount;
    }

    /// @notice Approves the Mint Request
    /// @param _mintRequestID the ID to be referenced in the mapping
    /// @param _referenceTo reference comment for the issuer
    function approveMint(uint256 _mintRequestID, string memory _referenceTo) public nonReentrant {
        _checkAccessToFunction(ACTIVE_CONTRACT | ONLY_ISSUER);

        MintRequest storage s_req = mintRequests[_mintRequestID];
        MintRequest memory m_req = s_req;
        require(m_req.destination != address(0), RequestError(_mintRequestID, RequestErrorType.NotExists));
        require(!m_req.completed, RequestError(_mintRequestID, RequestErrorType.Completed));

        s_req.completed = true;
        s_req.referenceTo = _referenceTo;

        uint256 currentRate = AssetTokenData(assetTokenDataAddress).update(address(this));
        uint256 amountToMint = (m_req.amount * DECIMALS_HUNDRED_PERCENT) / currentRate;

        _mint(m_req.destination, amountToMint);
        emit MintApproved(_mintRequestID, m_req.destination, amountToMint, msg.sender);
    }

    /// @notice Approves the Redemption Requests
    /// @param _redemptionRequestID redemption request ID to be referenced in the mapping
    /// @param _approveTxID the transaction ID
    function approveRedemption(uint256 _redemptionRequestID, string memory _approveTxID) public {
        _checkAccessToFunction(ONLY_ISSUER_OR_GUARDIAN);
        RedemptionRequest storage s_req = redemptionRequests[_redemptionRequestID];
        RedemptionRequest storage m_req = s_req;

        require(m_req.canceledBy == address(0), RequestError(_redemptionRequestID, RequestErrorType.Cancelled));
        require(m_req.sender != address(0), RequestError(_redemptionRequestID, RequestErrorType.NotExists));
        require(!m_req.completed, RequestError(_redemptionRequestID, RequestErrorType.Completed));
        if (m_req.fromStake)
            require(
                AssetTokenData(assetTokenDataAddress).isOnSafeguard(address(this)),
                ContractError(address(this), ContractErrorType.ContractIsActiveNotOnSafeguard)
            );

        s_req.completed = true;
        s_req.approveTxID = _approveTxID;
        _burn(address(this), m_req.assetTokenAmount);

        emit RedemptionApproved(
            _redemptionRequestID,
            m_req.assetTokenAmount,
            m_req.underlyingAssetAmount,
            m_req.sender,
            msg.sender
        );
    }

    /// @notice Requests an amount of assetToken Redemption
    /// @param _assetTokenAmount the amount of Asset Token to be redeemed
    /// @param _destination the off chain hash of the redemption transaction
    /// @return reqId uint256 redemptionRequest ID to be referenced in the mapping
    function requestRedemption(
        uint256 _assetTokenAmount,
        string calldata _destination
    ) external nonReentrant returns (uint256 reqId) {
        require(_assetTokenAmount > 0, AmountError(_assetTokenAmount, 0, AmountErrorType.ZeroAmount));
        uint256 balance = balanceOf(msg.sender);
        require(balance >= _assetTokenAmount, AmountError(_assetTokenAmount, balance, AmountErrorType.NotEnoughFunds));

        AssetTokenData assetTknDtaContract = AssetTokenData(assetTokenDataAddress);
        address issuer = assetTknDtaContract.getIssuer(address(this));
        address guardian = assetTknDtaContract.getGuardian(address(this));
        bool isOnSafeguard = assetTknDtaContract.isOnSafeguard(address(this));

        if ((!isOnSafeguard && msg.sender != issuer) || (isOnSafeguard && msg.sender != guardian)) {
            uint256 _minimumRedemptionAmount = minimumRedemptionAmount;
            require(
                _assetTokenAmount >= _minimumRedemptionAmount,
                AmountError(_assetTokenAmount, _minimumRedemptionAmount, AmountErrorType.MinRedemptionAmountNotReached)
            );
        }

        uint256 rate = assetTknDtaContract.update(address(this));
        uint256 underlyingAssetAmount = (_assetTokenAmount * rate) / DECIMALS_HUNDRED_PERCENT;

        reqId = redemptionRequestID + 1;
        redemptionRequestID = reqId;

        redemptionRequests[reqId] = RedemptionRequest(
            msg.sender,
            _destination,
            _assetTokenAmount,
            underlyingAssetAmount,
            false,
            false,
            "",
            address(0)
        );

        /// @dev make the transfer to the contract for the amount requested (18 digits)
        _transfer(msg.sender, address(this), _assetTokenAmount);

        /// @dev approve instantly when called by issuer or guardian
        if ((!isOnSafeguard && msg.sender == issuer) || (isOnSafeguard && msg.sender == guardian)) {
            approveRedemption(reqId, AUTOMATIC_REDEMPTION_APPROVAL);
        }

        emit RedemptionRequested(reqId, _assetTokenAmount, underlyingAssetAmount, false, msg.sender);
    }

    /// @notice Performs the Safeguard Stake
    /// @param _amount the assetToken amount to be staked
    /// @param _receipt the off chain hash of the redemption transaction
    function safeguardStake(uint256 _amount, string calldata _receipt) external nonReentrant {
        _checkAccessToFunction(ACTIVE_CONTRACT);
        uint256 balance = balanceOf(msg.sender);
        require(balance >= _amount, AmountError(_amount, balance, AmountErrorType.NotEnoughFunds));

        uint256 _totalStakes = totalStakes + _amount;

        if ((_totalStakes * DECIMALS_HUNDRED_PERCENT) / totalSupply() >= statePercent) {
            require(
                AssetTokenData(assetTokenDataAddress).setContractToSafeguard(address(this)),
                ContractError(address(this), ContractErrorType.SafeguardChangeError)
            );
            /// @dev now the contract is on safeguard
        }

        uint256 _requestID = stakedRedemptionRequests[msg.sender];
        if (_requestID == 0) {
            /// @dev zero means that it's new request
            uint256 reqId = redemptionRequestID + 1;
            _requestID = reqId;

            redemptionRequestID = reqId;
            redemptionRequests[reqId] = RedemptionRequest(
                msg.sender,
                _receipt,
                _amount,
                0,
                false,
                true,
                "",
                address(0)
            );
            stakedRedemptionRequests[msg.sender] = reqId;
        } else {
            /// @dev non zero means the request already exist and need only add amount
            redemptionRequests[_requestID].assetTokenAmount += _amount;
        }

        safeguardStakes[msg.sender] += _amount;
        totalStakes = _totalStakes;

        _transfer(msg.sender, address(this), _amount);

        emit RedemptionRequested(
            _requestID,
            redemptionRequests[_requestID].assetTokenAmount,
            redemptionRequests[_requestID].underlyingAssetAmount,
            true,
            msg.sender
        );
    }

    /// @notice Sets Asset Token Data Address
    /// @param _newAddress value to be set
    function setAssetTokenData(address _newAddress) external requireNonEmptyAddress(_newAddress) {
        _checkAccessToFunction(UNFROZEN_CONTRACT | ONLY_ISSUER_OR_GUARDIAN);
        address oldAddress = assetTokenDataAddress;
        assetTokenDataAddress = _newAddress;
        emit AssetTokenDataChanged(oldAddress, _newAddress, msg.sender);
    }

    /// @notice Requests a mint to the caller
    /// @param _amount the amount to mint in asset token format
    /// @return uint256 request ID to be referenced in the mapping
    function requestMint(uint256 _amount) external returns (uint256) {
        return _requestMint(_amount, msg.sender);
    }

    /// @notice Requests a mint to the _destination address
    /// @param _amount the amount to mint in asset token format
    /// @param _destination the receiver of the tokens
    /// @return uint256 request ID to be referenced in the mapping
    function requestMint(uint256 _amount, address _destination) external returns (uint256) {
        return _requestMint(_amount, _destination);
    }

    /// @notice Sets the verification link
    /// @param _kya value to be set
    function setKya(string calldata _kya) external {
        _checkAccessToFunction(ONLY_ISSUER_OR_GUARDIAN | UNFROZEN_CONTRACT);
        require(bytes(_kya).length > 3, WrongKYA(_kya));
        kya = _kya;
        emit KyaChanged(_kya, msg.sender);
    }

    /// @notice Sets the _minimumRedemptionAmount
    /// @param _minimumRedemptionAmount value to be set
    function setMinimumRedemptionAmount(uint256 _minimumRedemptionAmount) external {
        _checkAccessToFunction(ONLY_ISSUER_OR_GUARDIAN | UNFROZEN_CONTRACT);
        minimumRedemptionAmount = _minimumRedemptionAmount;
        emit MinimumRedemptionAmountChanged(_minimumRedemptionAmount, msg.sender);
    }

    /// @notice Freeze the contract
    function freezeContract() external {
        _checkAccessToFunction(ONLY_ISSUER_OR_GUARDIAN);
        require(
            AssetTokenData(assetTokenDataAddress).freezeContract(address(this)),
            ContractError(address(this), ContractErrorType.FreezingError)
        );
    }

    /// @notice unfreeze the contract
    function unfreezeContract() external {
        _checkAccessToFunction(ONLY_ISSUER_OR_GUARDIAN);
        require(
            AssetTokenData(assetTokenDataAddress).unfreezeContract(address(this)),
            ContractError(address(this), ContractErrorType.UnfreezingError)
        );
    }

    /// @notice Burns a certain amount of tokens
    /// @param _amount qty of assetTokens to be burned
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
        emit TokenBurned(_amount, msg.sender);
    }

    /// @notice Approves the Redemption Requests
    /// @param _redemptionRequestID redemption request ID to be referenced in the mapping
    /// @param _motive motive of the cancelation
    function cancelRedemptionRequest(uint256 _redemptionRequestID, string calldata _motive) external {
        RedemptionRequest storage s_req = redemptionRequests[_redemptionRequestID];
        RedemptionRequest memory m_req = s_req;
        require(m_req.sender != address(0), RequestError(_redemptionRequestID, RequestErrorType.NotExists));
        require(m_req.canceledBy == address(0), RequestError(_redemptionRequestID, RequestErrorType.Cancelled));
        require(!m_req.completed, RequestError(_redemptionRequestID, RequestErrorType.Completed));
        require(!m_req.fromStake, RequestError(_redemptionRequestID, RequestErrorType.UnstakeRequested));

        if (msg.sender != m_req.sender) {
            // not owner of the redemption so guardian or issuer should be the caller
            AssetTokenData(assetTokenDataAddress).onlyIssuerOrGuardian(address(this), msg.sender);
        }

        s_req.assetTokenAmount = 0;
        s_req.underlyingAssetAmount = 0;
        s_req.canceledBy = msg.sender;

        _transfer(address(this), m_req.sender, m_req.assetTokenAmount);

        emit RedemptionCanceled(_redemptionRequestID, m_req.sender, _motive, msg.sender);
    }

    /// @notice Calls to UnStake all the funds
    function safeguardUnstake() external {
        _safeguardUnstake(safeguardStakes[msg.sender]);
    }

    /// @notice Calls to UnStake with a certain amount
    /// @param _amount to be unStaked in asset token
    function safeguardUnstake(uint256 _amount) external {
        _safeguardUnstake(_amount);
    }

    /// @dev Returns the name of the token.
    function name() public view override returns (string memory) {
        return NAME;
    }

    /// @dev Returns the symbol of the token.
    function symbol() public view override returns (string memory) {
        return SYMBOL;
    }

    /// @notice Performs the Mint Request to the destination address
    /// @param _amount entered in the external functions
    /// @param _destination the receiver of the tokens
    /// @return reqId uint256 request ID to be referenced in the mapping
    function _requestMint(uint256 _amount, address _destination) private returns (uint256 reqId) {
        _checkAccessToFunction(ACTIVE_CONTRACT | UNFROZEN_CONTRACT | ONLY_ISSUER_OR_AGENT);
        require(_amount > 0, AmountError(_amount, 0, AmountErrorType.ZeroAmount));

        reqId = mintRequestID + 1;
        mintRequestID = reqId;

        mintRequests[reqId] = MintRequest(_destination, _amount, "", false);

        if (msg.sender == AssetTokenData(assetTokenDataAddress).getIssuer(address(this))) {
            approveMint(reqId, "IssuerMint");
        }

        emit MintRequested(reqId, _destination, _amount, msg.sender);
    }

    /// @notice Hook to be executed before every transfer and mint
    /// @notice This overrides the ERC20 defined function
    /// @param _from the sender
    /// @param _to the receipent
    /// @param _amount the amount (it is not used  but needed to be defined to override)
    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal override {
        //  on safeguard the only available transfers are from allowed addresses and guardian
        //  or from an authorized user to this contract
        //  address(this) is added as the _from for approving redemption (burn)
        //  address(this) is added as the _to for requesting redemption (transfer to this contract)
        //  address(0) is added to the condition to allow burn on safeguard
        _checkAccessToFunction(UNFROZEN_CONTRACT);
        AssetTokenData assetTknDtaContract = AssetTokenData(assetTokenDataAddress);

        bool mbah = assetTknDtaContract.mustBeAuthorizedHolders(address(this), _from, _to, _amount);
        if (assetTknDtaContract.isOnSafeguard(address(this))) {
            /// @dev  State is SAFEGUARD
            if (
                // receiver is NOT this contract AND sender is NOT this contract AND sender is NOT guardian
                _to != address(this) &&
                _from != address(this) &&
                _from != assetTknDtaContract.getGuardian(address(this))
            ) {
                require(
                    assetTknDtaContract.isAllowedTransferOnSafeguard(address(this), _from),
                    ContractError(address(this), ContractErrorType.NotAllowedOnSafeguard)
                );
            } else {
                require(mbah, ContractError(address(this), ContractErrorType.NotAuthorizedOnActive));
            }
        } else {
            /// @dev State is ACTIVE
            // this is mint or transfer
            // mint signature: ==> _beforeTokenTransfer(address(0), account, amount);
            // burn signature: ==> _beforeTokenTransfer(account, address(0), amount);
            require(mbah, ContractError(address(this), ContractErrorType.NotAuthorizedOnActive));
        }

        super._beforeTokenTransfer(_from, _to, _amount);
    }

    /// @notice Performs the UnStake with a certain amount
    /// @param _amount to be unStaked in asset token
    function _safeguardUnstake(uint256 _amount) private {
        _checkAccessToFunction(ACTIVE_CONTRACT | UNFROZEN_CONTRACT);
        require(_amount > 0, AmountError(_amount, 0, AmountErrorType.ZeroAmount));
        uint256 _safeguardStakes = safeguardStakes[msg.sender];
        require(
            _safeguardStakes >= _amount,
            AmountError(_amount, _safeguardStakes, AmountErrorType.AmountExceedsStaked)
        );

        safeguardStakes[msg.sender] = _safeguardStakes - _amount;
        totalStakes -= _amount;
        redemptionRequests[stakedRedemptionRequests[msg.sender]].assetTokenAmount -= _amount;

        _transfer(address(this), msg.sender, _amount);

        emit SafeguardUnstaked(_amount, msg.sender);
    }

    /// @notice kindof modifier to frist-check data on functions
    /// @param modifiers an array containing the modifiers to check (the enums)
    function _checkAccessToFunction(uint256 modifiers) private view {
        bool found;
        AssetTokenData assetTknDtaContract = AssetTokenData(assetTokenDataAddress);
        if (modifiers & ACTIVE_CONTRACT != 0) {
            assetTknDtaContract.onlyActiveContract(address(this));
            found = true;
        }
        if (modifiers & UNFROZEN_CONTRACT != 0) {
            assetTknDtaContract.onlyUnfrozenContract(address(this));
            found = true;
        }
        if (modifiers & ONLY_ISSUER != 0) {
            assetTknDtaContract.onlyIssuer(address(this), msg.sender);
            found = true;
        }
        if (modifiers & ONLY_ISSUER_OR_GUARDIAN != 0) {
            assetTknDtaContract.onlyIssuerOrGuardian(address(this), msg.sender);
            found = true;
        }
        if (modifiers & ONLY_ISSUER_OR_AGENT != 0) {
            assetTknDtaContract.onlyIssuerOrAgent(address(this), msg.sender);
            found = true;
        }
        require(found, "AssetToken: access not found");
    }
}
