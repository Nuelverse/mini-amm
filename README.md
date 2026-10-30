# Mini AMM

[![CI](https://github.com/Nuelverse/mini-amm/actions/workflows/test.yml/badge.svg)](https://github.com/Nuelverse/mini-amm/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A minimal constant-product automated market maker (AMM): **one pool, two ERC20 tokens**, built with Foundry and OpenZeppelin. It is a learning project, not audited, and not for production use.

- The pool enforces `reserveA * reserveB = k`, and `k` never goes down on a swap.
- Swaps take a **0.3% fee** from the input. The fee stays in the pool, so liquidity providers earn it.
- Liquidity providers receive **LP shares**, and the pool contract is itself the LP token (an OpenZeppelin ERC20).
- `swap` has `minAmountOut` slippage protection, and every state-changing function is `nonReentrant`.

## Quick start

```bash
git clone --recurse-submodules https://github.com/Nuelverse/mini-amm.git
cd mini-amm
forge build
forge test
forge coverage
forge fmt --check
```

## How it works

### The maths

- **Swap.** Only 99.7% of the input counts in the formula, and the fee stays in the pool. With whole numbers only:
  `amountOut = reserveOut * amountIn * 997 / (reserveIn * 1000 + amountIn * 997)`
  Example: a pool of 1000 A and 1000 B, and a trader sends in 100 A. 99.7 A counts, the pool must keep 1,000,000 / 1099.7 = 909.3389 B, so the trader receives 90.6611 B. The real k afterwards is about 1,000,272.79, because the 0.3 A fee is never counted in the formula. On-chain the output is an integer, rounded down (to the last wei), so the pool never pays out more than the formula gives.
- **First deposit.** `shares = sqrt(amountA * amountB)`. Both amounts are taken exactly as offered.
- **Later deposits.** The pool only pulls the pair that matches its current ratio (see Decisions). `shares = amount * totalSupply / reserve`, using the reserve of the token that is fully used.
- **Remove liquidity.** Each token's payout is `shares * pool balance of that token / totalSupply`. Multiply first, divide last, so rounding favours the pool.

### State variables

| Variable   | Type                      | Why                                                    |
| ---------- | ------------------------- | ------------------------------------------------------ |
| `tokenA`   | `IERC20 public immutable` | First token of the pool, set once in the constructor.  |
| `tokenB`   | `IERC20 public immutable` | Second token of the pool, set once in the constructor. |
| `reserveA` | `uint256 public`          | Stored amount of tokenA the pool accounts for.         |
| `reserveB` | `uint256 public`          | Stored amount of tokenB the pool accounts for.         |

LP shares and `totalSupply` come from the inherited OpenZeppelin `ERC20` ("Mini AMM LP", symbol `MLP`).

### Function list

| Function                                                      | Who can call             | What it does                                                                                    | Reverts with                                                                           | Event              |
| ------------------------------------------------------------- | ------------------------ | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------ |
| `constructor(IERC20 _tokenA, IERC20 _tokenB)`                 | deployer                 | Sets the two tokens.                                                                            | `ZeroAddress`, `SameToken`                                                             | none               |
| `getAmountOut(amountIn, reserveIn, reserveOut)` `pure`        | anyone                   | Output of a swap after the 0.3% fee, rounded down.                                              | `ZeroReserveInAmount`, `ZeroReserveOutAmount`, `ZeroAmountIn`, `ZeroAmountOut`         | none               |
| `addLiquidity(amountADesired, amountBDesired)` `nonReentrant` | anyone (needs approvals) | Pulls the pair that matches the pool ratio, mints LP shares to the caller. Returns the shares.  | `ZeroAmountIn`, `ZeroShare`                                                            | `LiquidityAdded`   |
| `swap(tokenIn, amountIn, minAmountOut)` `nonReentrant`        | anyone (needs approval)  | Swaps `tokenIn` for the other token. Measures the amount actually received. Returns the output. | `TokenNotInPool`, `AmountOutBelowExpected`, plus the `getAmountOut` errors             | `Swapped`          |
| `removeLiquidity(amountShares)` `nonReentrant`                | LP share holders         | Burns shares and pays out a proportional slice of both tokens. Returns both amounts.            | `ZeroShare`, `NothingToBurn`, `ZeroAmountOut`, OpenZeppelin `ERC20InsufficientBalance` | `LiquidityRemoved` |

All custom errors are prefixed `MiniAMM__`. The standard ERC20 functions on the pool are the LP token.

**Order of operations.**

- `addLiquidity` and `removeLiquidity` follow checks, effects, interactions: state changes and the event come first, token transfers last.
- `swap` has to pull the input first so it can measure it (see Decisions). It then computes the output, checks `minAmountOut`, emits, pays out, and finally re-syncs the reserves. `nonReentrant` covers the window where the pool calls into a token.

### Decisions

- **Off-ratio deposits: the pool pulls only the matching pair.** It never takes an excess, so nothing needs refunding. Example: a pool of 100 A and 400 B (200 shares), and Maria offers 80 A and 160 B. 160 B needs 40 A, so the pool pulls 40 A and 160 B, and she gets 80 shares. The other 40 A never leaves her wallet. Why: a refund would add another external token call (more re-entrancy surface), and Uniswap V2's router does the same (it computes matching amounts before moving tokens). The first deposit has no ratio, so it takes both amounts as offered.
- **How the pool measures tokens it received: the pool measures.** In `swap` it reads its own token balance before and after pulling the input, and uses the difference as the amount received. Why: trusting the `amountIn` argument breaks with fee-on-transfer tokens. Example: a pool of 1000 A and 1000 B, a token that takes 10% on every transfer, 100 A sent in. The pool receives 90 A but, if it trusts the argument, pays out as if 100 came in (90 B instead of 82 B), and k falls from 1,000,000 to 991,900.
- **Reserves are re-synced to the real balances after `swap` and `removeLiquidity`** (the Uniswap V2 approach). Tokens sent directly to the pool are absorbed into the reserves and benefit the LPs (and the arbitrageurs who trade the price back). Costs: a few extra `balanceOf` reads (gas), and the re-sync has to run after the payout, so the reserve update comes after an external call (the functions are `nonReentrant`, but a token callback during the payout could read stale reserves).
- **A swap that would pay out 0 reverts** (`ZeroAmountOut`) instead of silently keeping the trader's input. Zero-amount inputs and empty reserves revert too.
- **`removeLiquidity` pays from the real token balances**, not the stored reserves, so donations are withdrawable and the last LP can always take everything out.

## Tests

`forge test` runs **35 tests in 7 files**. `forge coverage` reports 100% of lines, statements, branches and functions of `src/MiniAMM.sol`. Coverage only says the lines ran, so the tests were also checked by mutation: for the bugs listed below, a copy of the contract was changed and the named test was confirmed to fail.

| File                               | Tests       | What it checks                                                                                                                                  |
| ---------------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `test/unit/GetAmountOut.t.sol`     | 9           | Expected outputs computed independently in Python with integer math, all zero-input reverts, constructor reverts.                               |
| `test/unit/AddLiquidity.t.sol`     | 6           | First deposit, matching on either token, zero amount and zero shares reverts, event shows pulled (not offered) amounts.                         |
| `test/unit/Swap.t.sol`             | 7           | Both directions with exact outputs and reserves, wrong token, slippage boundary, zero input, donation absorbed, event.                          |
| `test/unit/RemoveLiquidity.t.sol`  | 6           | Proportional payout, last LP after a donation, all revert cases.                                                                                |
| `test/fuzz/Fuzz.t.sol`             | 3           | k never decreases on a swap (both directions); add then remove never returns more than was deposited.                                           |
| `test/invariant/Invariant.t.sol`   | 1 (2 rules) | After random sequences of swaps, adds, removes and donations: the pool's balance always covers its stored reserves, and a swap never shrinks k. |
| `test/reentrancy/Reentrancy.t.sol` | 3           | A malicious token that calls back into `swap`, `addLiquidity` and `removeLiquidity` mid-transfer is rejected by the reentrancy guard.           |

Examples of mutations that were caught: rounding up in `removeLiquidity` (fuzz), removing the reserve re-sync from `removeLiquidity` (invariant), removing `nonReentrant` from a function (its reentrancy test), removing the fee (fuzz).

## Deploy locally

`script/DeployMiniAMM.s.sol` deploys two mock ERC20 tokens, the pool, and seeds it with liquidity, so you do not need a faucet. Start a local chain, then run the script:

```bash
anvil
```

```bash
forge script script/DeployMiniAMM.s.sol --rpc-url http://127.0.0.1:8545 \
  --private-key {PRIVATE_kEY} --broadcast
```

`MockERC20` (in `test/mocks/`) has an open `mint`, so it is for **local and demo use only**.

## Known limitations

- **Not audited and not production-ready.** It is a learning project.
- **No minimum-liquidity lock.** The first depositor sets the share price, and the pool does not defend against the first-depositor share-inflation attack that Uniswap V2 mitigates by locking the first 1000 shares.
- **`addLiquidity` trusts its arguments**, unlike `swap`. A fee-on-transfer token would leave the stored reserves above the real balance until the next swap or removal re-syncs them.
- **`addLiquidity` prices shares from the stored reserves**, while `removeLiquidity` pays from the real balances. After a direct token transfer and before the next re-sync, a new depositor can capture a share of that donation.
- **No slippage protection or deadline on `addLiquidity`.** If the ratio moves between signing and mining, the caller gets a different pair. `swap` has `minAmountOut`, but no deadline either.
- **The reserve re-sync runs after an external call.** `nonReentrant` stops re-entry into the pool, but a token callback could read stale values from outside (read-only reentrancy).
- **Rounding.** The matching amounts in `addLiquidity` round down, which favours the depositor by at most a few wei. Swaps and removals round in the pool's favour.
- **Tokens are assumed to be standard ERC20s.** Rebasing and callback-style (ERC777) tokens are not supported.
- **One pool, no factory, no fee switch, no price oracle.**

## Compared with Uniswap V2

This is a simplified version of [Uniswap V2 core](https://github.com/Uniswap/v2-core). It leaves out the minimum-liquidity lock, the protocol fee, the TWAP oracle accumulators, flash swaps (optimistic transfers), the router that wraps the pair, and the factory.

## License

MIT, see [LICENSE](LICENSE).
