// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title MiniAMM
/// @notice A minimal constant-product AMM pool (reserveA * reserveB = k) with a 0.3% swap fee.
contract MiniAMM is ERC20, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20;

    /// @notice First token of the pool, set once in the constructor.
    IERC20 public immutable tokenA;
    /// @notice Second token of the pool, set once in the constructor.
    IERC20 public immutable tokenB;

    /// @notice Stored amount of tokenA the pool accounts for (re-synced to the real balance after swaps and removals).
    uint256 public reserveA;
    /// @notice Stored amount of tokenB the pool accounts for (re-synced to the real balance after swaps and removals).
    uint256 public reserveB;

    /// @notice Thrown when the reserve of the token being taken out is zero.
    error MiniAMM__ZeroReserveOutAmount();
    /// @notice Thrown when the reserve of the token being put in is zero.
    error MiniAMM__ZeroReserveInAmount();
    /// @notice Thrown when the input amount is zero.
    error MiniAMM__ZeroAmountIn();
    /// @notice Thrown when the output amount is zero.
    error MiniAMM__ZeroAmountOut();
    /// @notice Thrown when the address passed is a zero address
    error MiniAMM__ZeroAddress();
    /// @notice Thrown when one address is passed as both token
    error MiniAMM__SameToken();
    /// @notice Thrown when the shares amount to be minted is Zero
    error MiniAMM__ZeroShare();
    /// @notice Thrown when the token passed to `swap` is neither tokenA nor tokenB.
    error MiniAMM__TokenNotInPool();
    /// @notice Thrown when a swap would return less than the caller's `minAmountOut`.
    error MiniAMM__AmountOutBelowExpected();
    /// @notice Thrown when liquidity is removed from a pool with no shares in circulation.
    error MiniAMM__NothingToBurn();

    /// @notice Emitted when liquidity is added.
    /// @param depositor Address that added the liquidity and received the shares.
    /// @param sharesAmount LP shares minted.
    /// @param amountA Amount of tokenA actually pulled (not the amount offered).
    /// @param amountB Amount of tokenB actually pulled (not the amount offered).
    event LiquidityAdded(address indexed depositor, uint256 sharesAmount, uint256 amountA, uint256 amountB);
    /// @notice Emitted on every swap.
    /// @param swapper Address that swapped.
    /// @param tokenIn Token the swapper sent in.
    /// @param amountIn Amount of `tokenIn` the pool measured as received.
    /// @param amountOut Amount of the other token sent to the swapper.
    event Swapped(address indexed swapper, IERC20 tokenIn, uint256 amountIn, uint256 amountOut);
    /// @notice Emitted when liquidity is removed.
    /// @param user Address that burned shares and received the tokens.
    /// @param sharesAmount LP shares burned.
    /// @param amountA Amount of tokenA paid out.
    /// @param amountB Amount of tokenB paid out.
    event LiquidityRemoved(address indexed user, uint256 sharesAmount, uint256 amountA, uint256 amountB);

    /// @notice Creates the pool for two distinct ERC20 tokens.
    /// @param _tokenA First token of the pool.
    /// @param _tokenB Second token of the pool.
    constructor(IERC20 _tokenA, IERC20 _tokenB) ERC20("Mini AMM LP", "MLP") {
        if (address(_tokenA) == address(0) || address(_tokenB) == address(0)) {
            revert MiniAMM__ZeroAddress();
        }
        if (address(_tokenA) == address(_tokenB)) {
            revert MiniAMM__SameToken();
        }
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    /// @dev Sets both stored reserves to the pool's real token balances. Tokens sent directly to the pool are
    /// absorbed here, so they benefit the LPs. Must run after the payout, which is why it comes after an external call.
    function _syncReserves() private {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));
    }

    /**
     * @notice Swaps `amountIn` of `tokenIn` for the other token of the pool, after the 0.3% fee.
     * @dev The pool measures what it received (balance after minus balance before) instead of trusting `amountIn`,
     * so fee-on-transfer tokens cannot make k fall. `nonReentrant` protects the pull-before-payout order.
     * @param tokenIn Token the caller sends in; must be tokenA or tokenB.
     * @param amountIn Amount the caller sends; the pool uses the amount it actually received.
     * @param minAmountOut Slippage protection: reverts if the output would be lower than this.
     * @return amountOut Amount of the other token sent to the caller.
     */
    function swap(IERC20 tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        if (tokenIn != (tokenA) && tokenIn != (tokenB)) {
            revert MiniAMM__TokenNotInPool();
        }
        uint256 reserveIn;
        uint256 reserveOut;
        IERC20 tokenOut;
        if (tokenIn == tokenA) {
            reserveIn = reserveA;
            reserveOut = reserveB;
            tokenOut = tokenB;
        } else {
            reserveIn = reserveB;
            reserveOut = reserveA;
            tokenOut = tokenA;
        }
        uint256 tokenReserveBalanceBefore = tokenIn.balanceOf(address(this));
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 exactAmountIn = tokenIn.balanceOf(address(this)) - tokenReserveBalanceBefore;
        amountOut = getAmountOut(exactAmountIn, reserveIn, reserveOut);
        if (amountOut < minAmountOut) {
            revert MiniAMM__AmountOutBelowExpected();
        }
        emit Swapped(msg.sender, tokenIn, exactAmountIn, amountOut);
        tokenOut.safeTransfer(msg.sender, amountOut);
        _syncReserves();
    }

    /**
     * @notice Computes how much of the output token a swap returns, after the 0.3% fee.
     * @dev Only 99.7% of `amountIn` counts in the formula (997/1000); the fee stays in the pool.
     * Multiplies before dividing, so the single division rounds down in the pool's favour.
     * @param amountIn Amount of the input token the trader sends.
     * @param reserveIn Pool balance of the input token before the swap.
     * @param reserveOut Pool balance of the output token before the swap.
     * @return Amount of the output token the trader receives (rounded down).
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        // Checks
        if (reserveIn == 0) {
            revert MiniAMM__ZeroReserveInAmount();
        }
        if (reserveOut == 0) {
            revert MiniAMM__ZeroReserveOutAmount();
        }
        if (amountIn == 0) {
            revert MiniAMM__ZeroAmountIn();
        }

        uint256 amountOut = (reserveOut * amountIn * 997) / (reserveIn * 1000 + amountIn * 997);
        if (amountOut == 0) {
            revert MiniAMM__ZeroAmountOut();
        }
        return amountOut;
    }

    /**
     * @notice Adds liquidity and mints LP shares to the caller.
     * @dev First deposit: both amounts are taken as offered and shares = sqrt(a * b). Later deposits: only the pair
     * that matches the pool ratio is pulled (the rest stays with the caller) and shares = amount * totalSupply / reserve.
     * The caller must have approved the pool for the pulled amounts.
     * @param amountADesired Most tokenA the caller is willing to deposit.
     * @param amountBDesired Most tokenB the caller is willing to deposit.
     * @return shares LP shares minted to the caller.
     */
    function addLiquidity(uint256 amountADesired, uint256 amountBDesired)
        external
        nonReentrant
        returns (uint256 shares)
    {
        if (amountADesired == 0 || amountBDesired == 0) {
            revert MiniAMM__ZeroAmountIn();
        }
        uint256 amountA;
        uint256 amountB;

        if (totalSupply() == 0) {
            // first deposit calculation
            amountA = amountADesired;
            amountB = amountBDesired;
            shares = Math.sqrt(amountADesired * amountBDesired);
        } else {
            uint256 bNeeded = amountADesired * reserveB / reserveA; // the B that goes with A
            if (bNeeded <= amountBDesired) {
                // calculate B needed for A
                amountA = amountADesired;
                amountB = bNeeded;
                shares = (amountADesired * totalSupply()) / reserveA;
            } else {
                uint256 aNeeded = (amountBDesired * reserveA) / reserveB; // the A that goes with B
                amountA = aNeeded;
                amountB = amountBDesired;
                shares = (amountBDesired * totalSupply()) / reserveB;
            }
        }
        if (shares == 0) {
            revert MiniAMM__ZeroShare();
        }
        reserveA += amountA;
        reserveB += amountB;
        _mint(msg.sender, shares);
        // False positive: the "external call" the linter sees is `Math.sqrt`, an internal library function.
        // forge-lint: disable-next-line(reentrancy-events)
        emit LiquidityAdded(msg.sender, shares, amountA, amountB);

        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);
    }

    /**
     * @notice Burns `amountShares` LP shares and pays out a proportional slice of both tokens.
     * @dev Amounts = shares * real token balance / totalSupply (multiply first, rounding favours the pool), so tokens
     * donated to the pool are withdrawable by LPs. Reverts if either amount rounds down to zero.
     * @param amountShares LP shares to burn.
     * @return amountA Amount of tokenA paid out.
     * @return amountB Amount of tokenB paid out.
     */
    function removeLiquidity(uint256 amountShares) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        if (amountShares == 0) {
            revert MiniAMM__ZeroShare();
        }
        if (totalSupply() == 0) {
            revert MiniAMM__NothingToBurn();
        }
        amountA = (amountShares * tokenA.balanceOf(address(this))) / totalSupply();
        amountB = (amountShares * tokenB.balanceOf(address(this))) / totalSupply();

        if (amountA == 0 || amountB == 0) {
            revert MiniAMM__ZeroAmountOut();
        }

        // OZ handles InsufficientBalance and burns
        _burn(msg.sender, amountShares);
        emit LiquidityRemoved(msg.sender, amountShares, amountA, amountB);
        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);
        _syncReserves();
    }
}
