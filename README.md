# LooksRare Aggregator contest details
- Total Prize Pool: $60,500 USDC
  - HM awards: $42,500 USDC
  - QA report awards: $5,000 USDC
  - Gas report awards: $2,500 USDC
  - Judge + presort awards: $10,000 USDC
  - Scout awards: $500 USDC
- Join [C4 Discord](https://discord.gg/code4rena) to register
- Submit findings [using the C4 form](https://code4rena.com/contests/2022-11-looksrare-contest/submit)
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts November 8, 2022 20:00 UTC
- Ends November 13, 2022 20:00 UTC

## C4udit / Publicly Known Issues

The C4audit output for the contest can be found here, [include link to C4udit report], within an hour of contest opening.

*Note for C4 wardens: Anything included in the C4udit output is considered a publicly known issue and is ineligible for awards.*

[ ⭐️ SPONSORS ADD INFO HERE ]

# Overview

The main contracts below and the contracts they inherited from are under the scope of this audit.

- [LooksRareAggregator](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/LooksRareAggregator.sol): An NFT liquidity aggregator that allows anyone to buy ERC721/ERC1155 tokens from multiple
  marketplaces in a single transaction. Users can only execute trades through proxies that have been whitelisted
  by the contract owner.

- [ERC20EnabledLooksRareAggregator](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/ERC20EnabledLooksRareAggregator.sol): The entrypoint for purchases that are denominated in ERC20 tokens instead of
  native ETH. It still executes trades through LooksRareAggregator. The purpose of having an extra aggregator is to prevent LooksRareAggregator's ownership from being compromised and malicious proxies can steal users' ERC20 tokens.

- [LooksRareProxy](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/proxies/LooksRareProxy.sol) : A proxy to execute trades on LooksRare.

- [SeaportProxy](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/proxies/SeaportProxy.sol): A proxy to execute trades on Seaport.

# Architecture

![LooksRareAggregator](https://github.com/code-423n4/2022-11-looksrare/blob/main/looksrare-aggregator-architecture.jpeg)
![ERC20EnabledLooksRareAggregator](https://github.com/code-423n4/2022-11-looksrare/blob/main/looksrare-erc20-aggregator-architecture.jpeg)

# Scope

| Contract | SLOC | Purpose | Libraries used |
| ----------- | ----------- | ----------- | ----------- |
| [IERC20EnabledLooksRareAggregator](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/interfaces/IERC20EnabledLooksRareAggregator.sol) | 12 | ERC20EnabledLooksRareAggregator interface | N/A |
| [ILooksRareAggregator](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/interfaces/ILooksRareAggregator.sol) | 32 | LooksRareAggregator interface | N/A |
| [IProxy](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/interfaces/IProxy.sol) | 16 | Generic proxy interface | N/A |
| [SeaportInterface](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/interfaces/SeaportInterface.sol) | 70 | Seaport interface | N/A |
| [ConsiderationEnums](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/libraries/seaport/ConsiderationEnums.sol) | 53 | Seaport consideration enums | N/A |
| [ConsiderationStructs](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/libraries/seaport/ConsiderationStructs.sol) | 122 | Seaport consideration structs | N/A |
| [OrderEnums](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/libraries/OrderEnums.sol) | 2 | Aggregator order enums | N/A |
| [OrderStructs](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/libraries/OrderStructs.sol) | 22 | Aggregator order structs | N/A |
| [LooksRareProxy](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/proxies/LooksRareProxy.sol) | 101 | Execute trades on LooksRare protocol (calls LooksRare) | [@looksrare/contracts-exchange-v1](https://github.com/looksrare/contracts-exchange-v1) |
| [SeaportProxy](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/proxies/SeaportProxy.sol) | 206 | Execute trades on Seaport (calls Seaport) | N/A |
| [ERC20EnabledLooksRareAggregator](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/ERC20EnabledLooksRareAggregator.sol) | 35 | Aggregate ERC20 trades to different marketplaces | N/A |
| [LooksRareAggregator](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/LooksRareAggregator.sol) | 169 | Aggregate trades to different marketplaces | N/A |
| [TokenReceiver](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/TokenReceiver.sol) | 29 | Contains callbacks that enable contracts to receive ERC721/ERC1155 tokens | N/A |
| [TokenTransferrer](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/TokenTransferrer.sol) | 19 | Enable contracts to make outward ERC721/ERC1155 token transfers | N/A |
| [TokenRescuer](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/TokenRescuer.sol) | 18 | Enable owners to rescue trapped tokens from contracts | N/A |
| [ReentrancyGuard](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/ReentrancyGuard.sol) | 14 | Prevent re-entrancy attacks | N/A |
| [OwnableTwoSteps](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/OwnableTwoSteps.sol) | 59 | Contract ownership logic, specifically 2 steps ownership transfers | N/A |
| [SignatureChecker](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/SignatureChecker.sol) | 50 | Enable contracts to validate EIP-712 signatures | N/A |
| [LowLevelERC20Approve](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/lowLevelCallers/LowLevelERC20Approve.sol) | 16 | Enable contracts to make ERC20 approvals | N/A |
| [LowLevelERC20Transfer](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/lowLevelCallers/LowLevelERC20Transfer.sol) | 31 | Enable contracts to make ERC20 transfers | N/A |
| [LowLevelERC721Transfer](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/lowLevelCallers/LowLevelERC721Transfer.sol) | 14 | Enable contracts to make ERC721 transfers | N/A |
| [LowLevelERC1155Transfer](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/lowLevelCallers/LowLevelERC1155Transfer.sol) | 30 | Enable contracts to make ERC1155 transfers | N/A |
| [LowLevelETH](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/lowLevelCallers/LowLevelETH.sol) | 33 | Enable contracts to make ETH transfers | N/A |
| [IERC20](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/interfaces/IERC20.sol) | 15 | ERC20 interface | N/A |
| [IERC721](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/interfaces/IERC721.sol) | 28 | ERC721 interface | N/A |
| [IERC1155](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/interfaces/IERC1155.sol) | 34 | ERC1155 interface | N/A |

# Out of Scope

- [V0Aggregator](https://github.com/code-423n4/2022-11-looksrare/blob/main/contracts/prototype/V0Aggregator.sol)
- [@looksrare/contract-exchange-v1](https://github.com/looksrare/contracts-exchange-v1)

## Focus

The main area of focus is on the 2 aggregators and the 2 proxies,

1. whether it is possible for a buyer to execute a malicious function call
2. whether it is possible for any tokens (ETH / ERC20 / ER721 / ERC1155) to be trapped inside the contracts
3. whether it is possible for any assets to be stolen


# Additional Context

## Fees

Fees logic is only implemented in SeaportProxy because the LooksRare protocol already charges a fee.

Contract owners can set the fee basis point and recipient for each proxy. Before executing a trade, the client should fetch each proxy's
fee data and include the returned basis points in the trade data's `maxFeeBp` parameter to prevent the fee basis points from suddenly icnreasing
beyond the buyer's acceptable fee levels.

If a trade contains multiple orders and they are denominated in different currencies, they should be sorted by currency in the client to reduce
the number of ETH/ERC20 transfers.

## Atomicity

Buyers can decide whether they want their transactions to be all-or-nothing or accepting partial executions with the bool flag `isAtomic`.

## Proxies

Proxies can only be called in the context of `LooksRareAggregator` through `delegatecall`.
The line `if (address(this) != aggregator) revert InvalidCaller();` does it.

## Scoping Details
```
- If you have a public code repo, please share it here: N/A
- How many contracts are in scope?: 26
- Total SLoC for these contracts?: 1230
- How many external imports are there?: 11
- How many separate interfaces and struct definitions are there for the contracts within scope?: 7
- Does most of your code generally use composition or inheritance?: Yes
- How many external calls?: 3
- What is the overall line coverage percentage provided by your tests?: Should be 90%+
- Is there a need to understand a separate part of the codebase / get context in order to audit this part of the protocol?: True.
- Please describe required context: The project integrates with Seaport and LooksRare's exchange protocol.
- Does it use an oracle?: False
- Does the token conform to the ERC20 standard?: We aren't creating a new token.
- Are there any novel or unique curve logic or mathematical models?: No
- Does it use a timelock function?: Yes but only for contract ownership management and not business critical functions.
- Is it an NFT?: No
- Does it have an AMM?: No
- Is it a fork of a popular project?: False
- Does it use rollups?: False
- Is it multi-chain?: False
- Does it use a side-chain?: False
```

# Installation

```
yarn install
```

# Tests

## Foundry tests

```
forge test # via_ir: true
FOUNDRY_PROFILE=local forge test # via_ir: false
```

## Gas benchmark

```
forge test --match-contract GemSwapBenchmarkTest
forge test --match-contract LooksRareProxyBenchmarkTest
forge test --match-contract SeaportProxyBenchmarkTest
```

## Static analysis

```
pip3 install slither-analyzer
pip3 install solc-select
solc-select install 0.8.17
solc-select use 0.8.17
slither --solc solc-0.8.17 .
```

### Notes on slither

- There are a number of ignored detectors in `slither.config.json`. We have reviewed every warning and deemed those to be safe
to ignore.

- You will run into the error `Missing function Incorrect ternary conversion marketplace.fulfillAdvancedOrder{value: if currency == address(0) then price else 0}(advancedOrder,new CriteriaResolver[](0),bytes32(0),recipient) contracts/proxies/SeaportProxy.sol#199-218` when you first run `slither`, the solution is to move `currency == address(0) ? price : 0` to its own variable. Although we have `via_ir` turned on for production environment, we have decided to keep it turned off locally as it takes a long time to build. Therefore we are not able to make this ternary operator its own variable without running into the `Stack Too Deep` error.

## Coverage

```
forge coverage --report lcov
LCOV_EXCLUDE=("test/*" "contracts/prototype/*")
echo $LCOV_EXCLUDE | xargs lcov --output-file lcov-filtered.info --remove lcov.info
genhtml lcov-filtered.info --output-directory out
open out/index.html
```
