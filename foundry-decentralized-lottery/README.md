# MY Contract is Deployed at [0xeC1DAAc61c3Ba95db4Fd6434271c38A3a1B804e5](https://sepolia.etherscan.io/address/0xeC1DAAc61c3Ba95db4Fd6434271c38A3a1B804e5)

- This smart contract allows you to set up a decentralized lottery which promises winners their money.The winners are selected every 30 seconds by default (can be changed) automatically.Their selection is verifiably random and transparent.

# Getting Started

## Requirements

- [npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)
- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/KartikC137/Smart-Contract-Development.git
cd foundry-decentralized-lottery
make install
```

### Optional Gitpod

If you can't or don't want to run and install locally, you can work with this repo in Gitpod. If you do this, you can skip the `clone this repo` part.

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#github.com/Cyfrin/foundry-smart-contract-lottery-cu)

# Usage

## Start a local node

```
make anvil
```

## Libraries

If you're having a hard time installing the chainlink library, you can optionally run this command.

```
forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
```

## Deploy

This will default to your local node. You need to have it running in another terminal in order for it to deploy.

```
make deploy
```

## Deploy - Other Network

[See below](#deployment-to-a-testnet-or-mainnet)

## Testing

- Currently only unit tests are written for this contract.You can check them out in test/ directory

### To run the tests:

```
forge test
```

or

```
forge test --fork-url $SEPOLIA_RPC_URL
```

### Test Coverage

```
forge coverage
```

# Deployment to a testnet or mainnet

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables. You can add them to a `.env` file, similar to what you see in `.env.example`.

- `PRIVATE_KEY`: The private key of your account (like from [metamask](https://metamask.io/)). **NOTE:** FOR DEVELOPMENT, PLEASE USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.
  - You can [learn how to export it here](https://metamask.zendesk.com/hc/en-us/articles/360015289632-How-to-Export-an-Account-Private-Key).
- `SEPOLIA_RPC_URL`: This is url of the sepolia testnet node you're working with. You can get setup with one for free from [Alchemy](https://alchemy.com/?a=673c802981)

Optionally, add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/).

1. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some testnet ETH. You should see the ETH show up in your metamask.

2. Deploy

```
make deploy-sepolia
```

This will setup a ChainlinkVRF Subscription for you. If you already have one, update it in the `scripts/HelperConfig.s.sol` file. It will also automatically add your contract as a consumer. If there was an [error in creating or funding a subscription click here](#problems-that-might-occur-while-deployement)

3. Register a Chainlink Automation Upkeep

[You can follow the documentation if you get lost.](https://docs.chain.link/chainlink-automation/compatible-contracts)

Go to [automation.chain.link](https://automation.chain.link/new) and register a new upkeep. Choose `Custom logic` as your trigger mechanism for automation. Your UI will look something like this once completed:

![Automation](./img/automation.png)

## Scripts

After deploying to a testnet or local net, you can run the scripts.

Using cast deployed locally example:

```
cast send <RAFFLE_CONTRACT_ADDRESS> "enterRaffle()" --value 0.1ether --private-key <PRIVATE_KEY> --rpc-url $SEPOLIA_RPC_URL
```

## Estimate gas

You can estimate how much gas things cost by running:

```
forge snapshot
```

And you'll see an output file called `.gas-snapshot`

# Problems that might occur while deployement

## The VRF Subscription wasn't created/funded:

- You can manually [create and fund subscription here](https://vrf.chain.link/)
  - Then, get the Subscription Id and paste it in script/HelperConfig.sol in the "NetworkConfig" struct.

# Formatting

To run code formatting:

```
forge fmt
```

# Additional Info:

Some users were having a confusion that whether Chainlink-brownie-contracts is an official Chainlink repository or not. Here is the info.
Chainlink-brownie-contracts is an official repo. The repository is owned and maintained by the chainlink team for this very purpose, and gets releases from the proper chainlink release process. You can see it's still the `smartcontractkit` org as well.

https://github.com/smartcontractkit/chainlink-brownie-contracts

## Let's talk about what "Official" means

The "official" release process is that chainlink deploys it's packages to [npm](https://www.npmjs.com/package/@chainlink/contracts). So technically, even downloading directly from `smartcontractkit/chainlink` is wrong, because it could be using unreleased code.

So, then you have two options:

1. Download from NPM and have your codebase have dependencies foreign to foundry
2. Download from the chainlink-brownie-contracts repo which already downloads from npm and then packages it nicely for you to use in foundry.

## Summary

1. That is an official repo maintained by the same org
2. It downloads from the official release cycle `chainlink/contracts` use (npm) and packages it nicely for digestion from foundry.
