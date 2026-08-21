const hre = require("hardhat");
async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying AuctionHouse with account:", deployer.address);
  const AH = await hre.ethers.getContractFactory("AuctionHouse");
  const ah = await AH.deploy();
  await ah.waitForDeployment();
  const addr = await ah.getAddress();
  console.log("AuctionHouse deployed to:", addr);
  console.log("View on explorer: https://scan.botchain.ai/address/" + addr);
}
main().catch((e) => { console.error(e); process.exitCode = 1; });
