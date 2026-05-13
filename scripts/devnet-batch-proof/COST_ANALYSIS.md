# Devnet Batch cost analysis

This document decomposes the latest `scripts/devnet-batch-proof/` devnet runs into:

- **total CU** — `meta.computeUnitsConsumed`
- **token inner CU** — sum of `Program Tokenkeg... consumed ...` log lines
- **residual CU** — `total - token inner CU`

The residual bucket is **not** "SDK wrapper only". It includes the caller program's own work, Solana CPI/runtime framing around the invoke, and any local staging / account-flattening cost outside the token program.

## Key result

The dominant penalty is **not** local Zig SDK batch staging.

Evidence:

1. `batchPrepared*` only improves on `batch*` by **15-59 CU** across the devnet proofs.
2. The token program's own inner Batch execution is already **~217-242 CU more expensive** than executing the direct child transfers separately.
3. Even after subtracting token inner cost, the batched paths still carry additional outer residual cost versus the direct double-CPI baselines.

So the current evidence points to **token-program-side Batch envelope/dispatch cost as the primary reason these proofs do not show net CU savings**, with local wrapper staging a smaller secondary factor.

## Latest measured signatures

| Label | Signature |
|---|---|
| transfer_double | `GLSQ8wuAFPB4LH9dW7CVqAQHJ3eHED7QfGuTTFpyVZcpvn3M3XLs2zV2vt2HvD7ppW1Ghyxa9BvZe1e1Z5Y4W5j` |
| transfer_batch | `3NSmcvQ4JSqEEvo6MnBQbTSyPNa9iMSww7gNqGa8ruvzjE44XLyzhaM27TVPnT9CwmTtSy57u3yvtLgDCW1FaH5L` |
| transfer_batch_prepared | `gm8upNj6sUq7LbLsg9xT2TjKmFRTkTV1sqeSfqkPzEv5bhrQkmUmymYYYUyfhHMnFqADFJqwwFxrEyEFE4nZ2TB` |
| transfer_checked_double | `2jLQ7tMhzhXrwJSGXFZaxn1UQudiJchANZSmDzFNqBZzQojnruXGb9Z32nYmMEJGio3tczRkDPfr4yRQoy28TvBi` |
| transfer_checked_batch | `qpwamSChYK6bMJtR2en3W63y38VYNjfQzuaDbfFhvo5XLjnVAmdHKPGUSg59gNBcrFq3xzttENntX5W94bNoQFf` |
| transfer_checked_batch_prepared | `37yjowYG36xuAxcxRLGpMzqZkGKzQ7xVjsHMk5TXmQ9nGC23EsA2Aw5VJ69Hhu7TornSp6tzDeUB2ChE3GXMGc9z` |
| mixed_checked_double | `5dJiowUL3JsvSgqAyFsKKAYHCVjJLDDS6xNbpJQkDpvzmZ1qAfmLRVGcrCzjoh8LqRbNqLCdAFqtqR5ZbZSq9Dx7` |
| mixed_checked_batch | `4gDecrmTXZh8TvELKjgkzJt9nsHSNcDCB7oyk9ajE9RXzwyucppqrHWPdQjHCn9QZCATzXkeNa2rhxFGhUY6JTi2` |
| mixed_checked_batch_prepared | `3dX2Gk4ULkK5a511RJSPQQjGXnU6QYT6EbZ8VDRbKZeo8Kgp5UTPvDE2Y39qCpcVEY7iMk8LFspQ9YWywLWtZNzX` |
| swap_checked_double | `5Hqfe4tEWhdyBW9DQwcRgn9PBVuZin7XPastgxGJ2hvkhnhcnRYgT8frgW95fkzsywiuUVd1H5Jpzs7F4wXkbHmE` |
| swap_checked_batch | `oJKKemcwoW41BPX8vjPo74Me89KkRK8vSwA8oEFWFdFYcsoCwchmLmQtqcJnj6KT6j4ReFj69JBWwzEANv7ZT5v` |
| swap_checked_batch_prepared | `2DSXtmXQ2nHq1kSMnv15Z5wegjpbv2LNHAYKUkMigorQB9XeLAQqWNjdPTRJwEscCEg3TufsDnUJCdY95LPjy4Wp` |
| router_swap_checked_double | `33LXL3EyLYfHXcdX1UFpsvpBCSuk3Z5LtxbxZV99gjHTqeEXZJkr81sv4kTDXXTAdD8GvvBHBKBcyRQcLpFXWZYX` |
| router_swap_checked_batch | `2JVeYnuveYaBV35okvCmokZCz7cfRG3nS82EZQpetKAm68yoWS6XpucWjBJDCkn2ATZV9782ok1krDYftm4Es8h4` |
| router_swap_checked_batch_prepared | `2WXWqsroWKr5fw8uRZTRRz7yC7gS9SNNU8cSK6A4HbHed66YkUeBEH9Cxxbh2cgrWEi9w5jLJ2AperLkv63kJJUh` |

## Cost breakdown by family

### 1. Transfer

| Path | Total CU | Token inner CU | Residual CU |
|---|---:|---:|---:|
| direct double | 2408 | 152 | 2256 |
| batch | 2728 | 369 | 2359 |
| batchPrepared | 2713 | 369 | 2344 |

Delta vs direct double:

- batch: `+320 total = +217 token inner + +103 residual`
- batchPrepared: `+305 total = +217 token inner + +88 residual`

### 2. TransferChecked

| Path | Total CU | Token inner CU | Residual CU |
|---|---:|---:|---:|
| direct double | 2538 | 210 | 2328 |
| batch | 3144 | 452 | 2692 |
| batchPrepared | 3125 | 452 | 2673 |

Delta vs direct double:

- batch: `+606 total = +242 token inner + +364 residual`
- batchPrepared: `+587 total = +242 token inner + +345 residual`

### 3. Mixed signer TransferChecked

| Path | Total CU | Token inner CU | Residual CU |
|---|---:|---:|---:|
| direct double | 2590 | 210 | 2380 |
| batch | 3246 | 448 | 2798 |
| batchPrepared | 3211 | 448 | 2763 |

Delta vs direct double:

- batch: `+656 total = +238 token inner + +418 residual`
- batchPrepared: `+621 total = +238 token inner + +383 residual`

### 4. Swap-style two-mint TransferChecked

| Path | Total CU | Token inner CU | Residual CU |
|---|---:|---:|---:|
| direct double | 2596 | 210 | 2386 |
| batch | 3277 | 447 | 2830 |
| batchPrepared | 3235 | 447 | 2788 |

Delta vs direct double:

- batch: `+681 total = +237 token inner + +444 residual`
- batchPrepared: `+639 total = +237 token inner + +402 residual`

### 5. Router-style stateful swap TransferChecked

| Path | Total CU | Token inner CU | Residual CU |
|---|---:|---:|---:|
| direct double | 2807 | 210 | 2597 |
| batch | 3485 | 447 | 3038 |
| batchPrepared | 3426 | 447 | 2979 |

Delta vs direct double:

- batch: `+678 total = +237 token inner + +441 residual`
- batchPrepared: `+619 total = +237 token inner + +382 residual`

## What this says about Circular's model

Circular's README frames the Batch gain as an expected result of paying token CPI overhead once instead of twice. That model is directionally reasonable, but these devnet measurements show two important caveats:

1. **Batch's token-program execution is not free**
   - direct child token work:
     - `Transfer`: `76 + 76 = 152`
     - `TransferChecked` families: `105 + 105 = 210`
   - Batch token work:
     - `Transfer`: `369`
     - checked families: `447-452`

   So the token program's Batch path itself adds roughly **+217 to +242 CU** over the sum of the direct child token instructions.

2. **The caller-side residual also rises on batched paths**
   - even after removing token inner cost, batched paths still show `+88` to `+444` residual CU versus direct double-CPI baselines.
   - `batchPrepared*` reduces only a small slice of that residual, which is why it saves tens, not hundreds, of CU.

## Current attribution

Based on the evidence in this repo today:

- **Primary contributor**: token-program-side Batch envelope/dispatch/security cost
- **Secondary contributor**: caller-side residual cost around the batched invoke
- **Minor contributor**: local SDK runtime-account staging / wrapper flattening

That means the present result is **not** best explained by a broken Zig wrapper. The wrapper can still be improved, but it is not the dominant reason Batch loses on these proofs.

## Practical implication

For this repo's current direct, mixed-signer, swap-style, and router-style devnet proofs:

- Batch reliably reduces `2 token invokes -> 1 token invoke`
- `batchPrepared*` is consistently the cheapest local API
- but **none of these shapes recovers enough CU to beat the direct two-CPI baseline**

If Batch wins elsewhere, it likely requires a meaningfully different baseline or downstream flow than the lean direct paths exercised here.
