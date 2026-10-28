# Mini AMM

A minimal constant-product automated market maker: one pool, two ERC20 tokens, built with Foundry.

The pool enforces `reserveA * reserveB = k`. Swaps take a 0.3% fee from the input, and the fee stays in the pool, so k only grows on swaps.

## How to run tests

```bash
forge build
forge test
forge coverage
```

## Design

### Math (worked out on paper)

- Swap: only 99.7% of the input counts in the formula; the fee stays in the pool.
  Example: pool of 1000 ETH and 1000 USDC, Peter swaps in 100 ETH. 99.7 ETH counts, the pool needs 1,000,000 / 1099.7 = 909.3389 USDC left, so Peter gets 90.6611 USDC. Real k afterward is about 1,000,272.79.
- First deposit: shares = sqrt(amountA \* amountB).
- Later deposits: shares = the smaller of the two deposit percentages, times the existing total shares.
- Remove liquidity: amount of each token = shares burned \* that token's balance / total shares (multiply first, divide last; rounding favors the pool).

### State variables

| Variable | Type    | Why                                           |
| -------- | ------- | --------------------------------------------- |
| tokenA   | address | first token of the pool, never changes        |
| tokenB   | address | second token of the pool, never changes       |
| reserveA | uint256 | stored amount of tokenA the pool accounts for |
| reserveB | uint256 | stored amount of tokenB the pool accounts for |

LP shares and total supply come from the inherited OpenZeppelin ERC20.

### Function list

_To be written in Stage 1 (signatures, access, checks/effects/interactions, events)._

### Decisions

- Off-ratio deposits: the pool only pulls the amounts that match its current ratio; it never takes an excess, so nothing needs refunding. Example: pool of 100 A and 400 B (200 shares), Maria offers 80 A and 160 B. 160 B needs 40 A, so the pool pulls 40 A and 160 B, and she gets 80 shares. The other 40 A never leaves her wallet. Why: a refund would add another external token call (more re-entrancy surface), and Uniswap V2's router does the same (it computes matching amounts before moving tokens). The first deposit has no ratio, so it takes both amounts as offered.
- How the pool measures tokens it received: the pool measures. In `swap` it reads its own token balance before and after pulling the input, and uses the difference as the amount received. Why: trusting the `amountIn` argument breaks with fee-on-transfer tokens. Example: pool of 1000 A and 1000 B, a token that takes 10% on every transfer, 100 A sent in. The pool receives 90 A but, if it trusts the argument, pays out as if 100 came in (90 B instead of 82 B), and k falls from 1,000,000 to 991,900. After each swap the stored reserves are re-synced to the pool's real token balances (the Uniswap V2 approach), so tokens sent directly to the pool are absorbed into the reserves and benefit the LPs (and the arbitrageurs who trade the price back). Costs: a few extra `balanceOf` reads (gas), and the re-sync has to run after the payout, so the reserve update comes after an external call (the swap is `nonReentrant`, but a token callback during the payout could read stale reserves).

## Known limitations

_To be written._
