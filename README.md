# BOT Auction House

A decentralized auction platform on BOT Chain. Create auctions, place bids, highest bidder wins.

## Features
- Create timed auctions with minimum bid
- Place BOT bids (outbid to become highest)
- Automatic refunds for outbid participants
- Seller receives payment minus 2.5% fee on auction end
- Cancel auctions with no bids
- Demo Mode for testing without blockchain

## Quick Start
```bash
npm install && npx hardhat compile && npx hardhat test
npx hardhat run scripts/deploy.js --network botchain_testnet
```
