// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title TestFaucet
/// @notice Faucet for distributing test tokens (UPKRW & UPETH) - one claim per address
contract TestFaucet {
    address public immutable owner;

    IERC20 public immutable upkrw;
    IERC20 public immutable upeth;

    uint256 public constant UPKRW_AMOUNT = 50_000_000 * 10**18;  // 5000만 UPKRW
    uint256 public constant UPETH_AMOUNT = 10 * 10**18;          // 10 UPETH

    mapping(address => bool) public hasClaimed;

    event Claimed(address indexed user, uint256 upkrwAmount, uint256 upethAmount);
    event Withdrawn(address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _upkrw, address _upeth) {
        owner = msg.sender;
        upkrw = IERC20(_upkrw);
        upeth = IERC20(_upeth);
    }

    /// @notice Claim test tokens (once per address)
    function claim() external {
        require(!hasClaimed[msg.sender], "Already claimed");

        hasClaimed[msg.sender] = true;

        // Transfer tokens
        require(upkrw.transfer(msg.sender, UPKRW_AMOUNT), "UPKRW transfer failed");
        require(upeth.transfer(msg.sender, UPETH_AMOUNT), "UPETH transfer failed");

        emit Claimed(msg.sender, UPKRW_AMOUNT, UPETH_AMOUNT);
    }

    /// @notice Check remaining balance in faucet
    function getRemainingBalance() external view returns (uint256 upkrwBalance, uint256 upethBalance) {
        upkrwBalance = upkrw.balanceOf(address(this));
        upethBalance = upeth.balanceOf(address(this));
    }

    /// @notice Withdraw all tokens back to owner (emergency recovery)
    function withdrawAll() external onlyOwner {
        uint256 upkrwBal = upkrw.balanceOf(address(this));
        uint256 upethBal = upeth.balanceOf(address(this));

        if (upkrwBal > 0) {
            upkrw.transfer(owner, upkrwBal);
            emit Withdrawn(address(upkrw), upkrwBal);
        }

        if (upethBal > 0) {
            upeth.transfer(owner, upethBal);
            emit Withdrawn(address(upeth), upethBal);
        }
    }

    /// @notice Withdraw specific token amount to owner
    function withdraw(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(owner, amount), "Transfer failed");
        emit Withdrawn(token, amount);
    }
}
