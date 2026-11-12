// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SeedSale
/// @notice Fixed-price USDC → SYMP sale with caps and a fixed time window.
/// @dev SYMP has 18 decimals; USDC has 6. Price: 1000 SYMP per 1 USDC.
contract SeedSale is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // 2029-01-01 00:00:00 UTC .. 2029-01-12 23:59:59 UTC
    uint256 public constant DEFAULT_START = 1_861_920_000;
    uint256 public constant DEFAULT_END = 1_862_956_799;

    IERC20 public immutable symp;
    IERC20 public immutable usdc;
    address public immutable treasury;

    uint256 public immutable start;
    uint256 public immutable end;
    uint256 public immutable softCapUsdc;
    uint256 public immutable hardCapUsdc;
    uint256 public immutable minContributionUsdc;
    uint256 public immutable maxPerWalletUsdc;

    /// @notice SYMP (1e18) received per 1 USDC unit (1e6). Default 1000e18.
    uint256 public immutable sympPerUsdc;

    uint256 public totalRaisedUsdc;
    bool public finalized;
    mapping(address => uint256) public contributedUsdc;

    event Contributed(address indexed buyer, uint256 usdcAmount, uint256 sympAmount);
    event Finalized(uint256 totalRaisedUsdc, uint256 timestamp);
    event Withdrawn(address indexed to, uint256 usdcAmount);
    event Reclaimed(address indexed to, uint256 sympAmount);

    error SaleNotOpen();
    error SaleStillOpen();
    error AlreadyFinalized();
    error NotFinalized();
    error CapExceeded();
    error BelowMinimum();
    error SoftCapNotMet();
    error Unauthorized();
    error ZeroAddress();
    error ZeroAmount();

    constructor(
        address symp_,
        address usdc_,
        address treasury_,
        uint256 softCapUsdc_,
        uint256 hardCapUsdc_,
        uint256 minContributionUsdc_,
        uint256 maxPerWalletUsdc_,
        uint256 start_,
        uint256 end_,
        uint256 sympPerUsdc_
    ) {
        if (symp_ == address(0) || usdc_ == address(0) || treasury_ == address(0)) revert ZeroAddress();
        require(softCapUsdc_ > 0 && hardCapUsdc_ >= softCapUsdc_, "SYMP: bad caps");
        require(minContributionUsdc_ > 0 && maxPerWalletUsdc_ >= minContributionUsdc_, "SYMP: bad limits");
        require(end_ > start_, "SYMP: bad window");
        require(sympPerUsdc_ > 0, "SYMP: bad price");

        symp = IERC20(symp_);
        usdc = IERC20(usdc_);
        treasury = treasury_;
        softCapUsdc = softCapUsdc_;
        hardCapUsdc = hardCapUsdc_;
        minContributionUsdc = minContributionUsdc_;
        maxPerWalletUsdc = maxPerWalletUsdc_;
        start = start_;
        end = end_;
        sympPerUsdc = sympPerUsdc_;
    }

    function isOpen() public view returns (bool) {
        return !finalized && block.timestamp >= start && block.timestamp <= end && totalRaisedUsdc < hardCapUsdc;
    }

    function phase() external view returns (string memory) {
        if (finalized || block.timestamp > end || totalRaisedUsdc >= hardCapUsdc) return "Ended";
        if (block.timestamp < start) return "Upcoming";
        return "Open";
    }

    function quoteSymp(uint256 usdcAmount) public view returns (uint256) {
        // usdcAmount is 6 decimals; result 18 decimals: amount * sympPerUsdc / 1e6
        return (usdcAmount * sympPerUsdc) / 1e6;
    }

    function contribute(uint256 usdcAmount) external nonReentrant {
        if (!isOpen()) revert SaleNotOpen();
        if (usdcAmount == 0) revert ZeroAmount();
        if (usdcAmount < minContributionUsdc) revert BelowMinimum();

        uint256 newWalletTotal = contributedUsdc[msg.sender] + usdcAmount;
        if (newWalletTotal > maxPerWalletUsdc) revert CapExceeded();

        uint256 newRaised = totalRaisedUsdc + usdcAmount;
        if (newRaised > hardCapUsdc) revert CapExceeded();

        uint256 sympAmount = quoteSymp(usdcAmount);
        require(sympAmount > 0, "SYMP: zero out");
        require(symp.balanceOf(address(this)) >= sympAmount, "SYMP: sold out");

        contributedUsdc[msg.sender] = newWalletTotal;
        totalRaisedUsdc = newRaised;

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        symp.safeTransfer(msg.sender, sympAmount);

        emit Contributed(msg.sender, usdcAmount, sympAmount);
    }

    function finalize() external nonReentrant {
        if (finalized) revert AlreadyFinalized();
        bool afterEnd = block.timestamp > end;
        bool softMet = totalRaisedUsdc >= softCapUsdc;
        if (!afterEnd && !softMet) revert SoftCapNotMet();
        // Before end, only treasury may finalize early after soft cap.
        if (!afterEnd && msg.sender != treasury) revert Unauthorized();
        finalized = true;
        emit Finalized(totalRaisedUsdc, block.timestamp);
    }

    function withdrawUSDC(address to) external nonReentrant {
        if (!finalized) revert NotFinalized();
        if (msg.sender != treasury) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = usdc.balanceOf(address(this));
        usdc.safeTransfer(to, bal);
        emit Withdrawn(to, bal);
    }

    function reclaimUnsold(address to) external nonReentrant {
        if (!finalized) revert NotFinalized();
        if (msg.sender != treasury) revert ZeroAddress();
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = symp.balanceOf(address(this));
        symp.safeTransfer(to, bal);
        emit Reclaimed(to, bal);
    }
}
