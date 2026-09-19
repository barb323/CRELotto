# Foundry Lottery (Chainlink CRE + VRF)

A decentralized weekly lottery built with **Foundry**, **Chainlink CRE** and **Chainlink VRF v2.5**.

Players can enter by paying **0.01 ETH**.  
Every **Sunday at 20:00 UTC**, Chainlink CRE automatically triggers the lottery via a Forwarder.  
The contract then requests a random number from Chainlink VRF, selects a winner and sends the entire prize pool to the winner.

**Live on Sepolia:**  
[`0x7b8218b8A813E5E29bC38C1e4FF04Ca8e4A19a20`](https://sepolia.etherscan.io/address/0x7b8218b8A813E5E29bC38C1e4FF04Ca8e4A19a20)

---

## Features

- Entrance fee: **0.01 ETH**
- Minimum **2 players** required to draw
- Fully automated weekly draw every **Sunday 20:00** via **Chainlink CRE**
- Verifiable randomness with **Chainlink VRF v2.5**
- Automatic prize payout to the winner
- Written & tested with **Foundry**
- Deployment scripts for Sepolia
- OpenZeppelin contracts used for security

---

## Tech Stack

- Solidity
- Foundry (Forge, Cast, Anvil)
- Chainlink CRE (workflow + Forwarder)
- Chainlink VRF v2.5
- OpenZeppelin

---

### Project Structure
CRELotto/
├── contracts/
│   ├── src/
│   ├── test/
│   └── script/
│
├── my-workflow/
│   ├── main.ts
│   └── config.staging.json
│
├── project.yaml
├── secrets.yaml
├── .gitignore
├── README.md
└── .env


---

### How the Lottery Works
Player
  │
  │ 0.01 ETH
  ▼
Lottery Contract
  │
  │ Every Sunday
  ▼
Chainlink CRE
  │
  │ Forwarder
  ▼
Lottery Contract
  │
  │ Request randomness
  ▼
Chainlink VRF
  │
  │ Random number
  ▼
Lottery Contract
  │
  │ Select winner
  ▼
Winner receives prize pool

---

## Getting Started

### 1. Clone the repository
//noch verbessern
```bash
git clone https://github.com/barb323/CRELotto.git cd CRELotto
```

### 2. Install dependencies
```bash
cd contracts 
forge install
```
### 3. Configure environment Variables

Create a .env file in the CRELotto Folder and configure your own credentials:

SEPOLIA_PRIVATE_KEY=your_private_key
CRE_ETH_PRIVATE_KEY=${SEPOLIA_PRIVATE_KEY}
SEPOLIA_RPC_URL=your_sepolia_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key
CONTRACT_ADDRESS=
SUBSCRIPTION_ID=your_vrf_subscription_id

# Fixed addresses (Sepolia)
FORWARDER_MOCK=0x15fC6ae953E024d975e77382eEeC56A9101f9F88
VRF_COORDINATOR=0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B

### 4. Compile & Test

```bash
cd contracts
source ../.env
forge build
forge test -vvv
```

### 5. Deploy to Sepolia and verify
```bash
forge script script/DeploySepolia.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $SEPOLIA_PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv
```

### After deployment:
```bash
cd my-workflow
```
Enter the contract address in the `config.staging.json` file under `consumerAddress`.
Create a subscription in the Chainlink VRF (Verifiable Random Function), fund the subscription, and add the SUBSCRIPTION_ID to your .env file.
Copy the new contract address into .env as CONTRACT_ADDRESS
Add the contract as a Consumer in your Chainlink VRF Subscription

To ensure that only the author can trigger the lottery draw, you can enter the author's address.
However, this does not work during simulation. For simulation, leave the address set to address(0).
```bash
cast send $CONTRACT_ADDRESS \
  "setExpectedAuthor(address)" AUTHOR_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $SEPOLIA_PRIVATE_KEY
```


### How to Play (Sepolia)
Enter the lottery with 0.01 ETH:

```bash
cast send $CONTRACT_ADDRESS \
  "enterRaffle()" \
  --value 0.01ether \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $SEPOLIA_PRIVATE_KEY
```

### Testing the CRE Workflow

```bash
cd CRELotto2
source .env
cre workflow simulate my-workflow --target staging-settings --broadcast
```

### Disclaimer

This project is an educational and experimental implementation of an automated blockchain lottery using Chainlink CRE and VRF.

Use testnet ETH and LINK when experimenting with the project!


