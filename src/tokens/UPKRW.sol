// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "../interfaces/IERC20.sol";

/// @title UPKRW
/// @author KORACLE
/// @notice UPside KRW - ERC20 token representing Korean Won
contract UPKRW is IERC20 {
    string public constant name = "UPside KRW";
    string public constant symbol = "UPKRW";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    mapping(address => bool) public minters;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyMinter() {
        require(minters[msg.sender], "Not minter");
        _;
    }

    constructor(address _owner) {
        require(_owner != address(0), "Zero address");
        owner = _owner;
        minters[_owner] = true;

        // Mint initial supply: 1 billion tokens (1,000,000,000 * 10^18)
        uint256 initialSupply = 1_000_000_000 * 10**18;
        totalSupply = initialSupply;
        balanceOf[_owner] = initialSupply;

        emit OwnershipTransferred(address(0), _owner);
        emit MinterAdded(_owner);
        emit Transfer(address(0), _owner, initialSupply);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Mint new tokens (only minters)
    function mint(address to, uint256 amount) external onlyMinter {
        require(to != address(0), "Mint to zero address");

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    /// @notice Burn tokens
    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        emit Transfer(msg.sender, address(0), amount);
    }

    /// @notice Add minter
    function addMinter(address minter) external onlyOwner {
        require(minter != address(0), "Zero address");
        require(!minters[minter], "Already minter");

        minters[minter] = true;
        emit MinterAdded(minter);
    }

    /// @notice Remove minter
    function removeMinter(address minter) external onlyOwner {
        require(minters[minter], "Not minter");

        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    /// @notice Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");

        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
