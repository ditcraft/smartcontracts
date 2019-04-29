pragma solidity 0.4.25;

import "./libraries/SafeMath.sol";

/**
 * @title Knowledge-Token
 *
 * @dev Implementation of the knowledge token that is being used for knowledge-extractable voting
 * This implementation has the additional functionality of mapping an address to string labels
 * instead of mapping them directly to uint256 balances. It also implements locking, unlocking and
 * minting and burning functions.
 */
contract KNWToken {
    using SafeMath for uint256;

    event Mint(address indexed who, string label, uint256 value);
    event Burn(address indexed who, string label, uint256 value);

    mapping (address => mapping (string => uint256)) private _balances;
    mapping (address => mapping (string => uint256)) private _lockedBalances;

    mapping (address => mapping (uint256 => string)) private _labels;
    mapping (address => uint256) private _labelCount;
    mapping (address => mapping (string => bool)) private _usedLabel;

    uint256 private _totalSupply;
    mapping (string => uint256) private _labelSupply;
    
    string constant public symbol = "KNW";
    string constant public name = "Knowledge Token";
    uint8 constant public decimals = 18;

    mapping (address => bool) public authorizedAddresses;

    constructor() public {
        authorizedAddresses[msg.sender] = true;
    }

    /**
     * @dev Adds an address that will be able to access the authorized functions
     * @param _address An address of a new authorized voting contract
     */
    function authorizeAddress(address _address) external returns (bool success) {
        require(_address != address(0), "Authorized contracts' address can't be empty");
        require(authorizedAddresses[msg.sender], "Only authorized addresses can do this");
        authorizedAddresses[_address] = true;
        return true;
    }

    /**
     * @dev Removes an address that will be able to access the authorized functions
     * @param _address An address of a new authorized voting contract
     */
    function removeAddress(address _address) external returns (bool success) {
        require(_address != address(0), "Authorized contracts' address can't be empty");
        require(authorizedAddresses[msg.sender], "Only authorized addresses can do this");
        authorizedAddresses[_address] = false;
        return true;
    }
    
    /**
     * @dev Total number of tokens for all labels
     * @return A uint256 representing the total token amount
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Number of tokens for a certain label
     * @param _label The label of the tokens
     * @return A uint256 representing the token amount for this label
     */
    function totalLabelSupply(string _label) external view returns (uint256 totalSupplyOfLabel) {
        return _labelSupply[_label];
    }

    /**
     * @dev Gets the balance for a specified address for a certain label
     * @param _address The address to query the balance of
     * @param _label The label of the requested balance
     * @return A uint256 representing the amount owned be the passed address for the specified label
     */
    function balanceOfLabel(address _address, string _label) external view returns (uint256 balance) {
        return _balances[_address][_label];
    }

    /**
     * @dev Gets the non-locked balance for a specified address for a certain label
     * @param _address The address to query the free balance of
     * @param _label The label of the requested free balance
     * @return A uint256 representing the non-locked amount owned be the passed address for the specified label
     */
    function freeBalanceOfLabel(address _address, string _label) external view returns (uint256 freeBalance) {
        return _balances[_address][_label].sub(_lockedBalances[_address][_label]);
    }

    /**
     * @dev Gets a specific label of an address
     * @param _address The address to query the free balance of
     * @param _labelID The id of the label
     * @return The label (string)
     */
    function labelOfAddress(address _address, uint256 _labelID) external view returns (string memory label) {
        return _labels[_address][_labelID];
    }

    /**
     * @dev Get the amount of labels that an address has
     * @param _address The address to query the label count
     * @return A uint256 representing the aount of labels that an address hat
     */
    function labelCountOfAddress(address _address) external view returns (uint256 labelCount) {
        return _labelCount[_address];
    }

    /**
     * @dev Locks a non-locked amount of tokens for an address at a certain label
     * @param _address The address to lock the free balance of
     * @param _label The label of the free balance that ought to be locked
     * @param _amount The amount of tokens that ought to be locked
     * @return A boolean that indicates if the operation was successful
     */
    function lockTokens(address _address, string _label, uint256 _amount) external onlyAuthorizedAddress(msg.sender) returns (bool success) {
        uint256 freeTokens = _balances[_address][_label].sub(_lockedBalances[_address][_label]);
        require(freeTokens >= _amount, "Can't lock more tokens than available");
        _lockedBalances[_address][_label] = _lockedBalances[_address][_label].add(_amount);
        return true;
    }

    /**
     * @dev Unlocks the specified amount of tokens
     * @param _address The address to unlock a certain balance of
     * @param _label The label of the amount that ought to be unlocked
     * @param _amount The amount of tokens that is requested to be unlocked
     * @return A boolean that indicates if the operation was successful
     */
    function unlockTokens(address _address, string _label, uint256 _amount) external onlyAuthorizedAddress(msg.sender) returns (bool success) {
        require(_lockedBalances[_address][_label] <= _balances[_address][_label], "Cant lock more KNW than an address has");
        _lockedBalances[_address][_label] = _lockedBalances[_address][_label].sub(_amount);
        return true;
    }

    /**
     * @dev Mints new tokens according to the specified minting method and the winning percentage
     * @param _address The address to receive new KNW tokens
     * @param _label The label that new token will be minted for
     * @param _amount The amount of tokens to be minted
     * @return A boolean that indicates if the operation was successful
     */
    function mint(address _address, string _label, uint256 _amount) external onlyAuthorizedAddress(msg.sender) returns (bool success) {
        require(_address != address(0), "Address can't be empty");
        require(bytes(_label).length > 0, "Knowledge-Label can't be empty");

        _totalSupply = _totalSupply.add(_amount);
        _labelSupply[_label] = _labelSupply[_label].add(_amount);
        _balances[_address][_label] = _balances[_address][_label].add(_amount);
        
        // If the address hasn't used this label before, this label will be added to the list
        if(!_usedLabel[_address][_label]) {
            _labelCount[_address] = _labelCount[_address].add(1);
            _labels[_address][_labelCount[_address]] = _label;
            _usedLabel[_address][_label] = true;
        }

        emit Mint(_address, _label, _amount);
        return true;
    }

    /**
     * @dev Burns tokens accoring to the specified burning method and the winning percentage
     * @param _address The address to receive new KNW tokens
     * @param _label The label that new token will be minted for
     * @param _amount The amount of tokens that will be burned
     * @return A boolean that indicates if the operation was successful
     */
    function burn(address _address, string _label, uint256 _amount) external onlyAuthorizedAddress(msg.sender) returns (bool success) {
        require(_address != address(0), "Address can't be empty");
        require(bytes(_label).length > 0, "Knowledge-Label can't be empty");
        require(_balances[_address][_label] >= _amount, "Can't burn more KNW than the address holds");

        _totalSupply = _totalSupply.sub(_amount);
        _labelSupply[_label] = _labelSupply[_label].sub(_amount);
        _balances[_address][_label] = _balances[_address][_label].sub(_amount);
        
        emit Burn(_address, _label, _amount);
        return true;
    }

    modifier onlyAuthorizedAddress(address _address) {
        require(authorizedAddresses[_address]);
        _;
    }
}