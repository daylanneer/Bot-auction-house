const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("AuctionHouse", function () {
  let ah, owner, seller, bidder1, bidder2;
  const ONE_DAY = 86400;
  const MIN_BID = ethers.parseEther("0.1");
  beforeEach(async () => {
    [owner, seller, bidder1, bidder2] = await ethers.getSigners();
    const F = await ethers.getContractFactory("AuctionHouse");
    ah = await F.deploy();
  });

  it("should create an auction", async () => {
    await ah.connect(seller).createAuction("Rare NFT", "A unique item", MIN_BID, ONE_DAY);
    const a = await ah.getAuction(0);
    expect(a.title).to.equal("Rare NFT");
    expect(a.seller).to.equal(seller.address);
  });

  it("should reject empty title", async () => {
    await expect(ah.connect(seller).createAuction("", "Desc", MIN_BID, ONE_DAY)).to.be.revertedWith("Title required");
  });

  it("should place a bid", async () => {
    await ah.connect(seller).createAuction("Item", "Desc", MIN_BID, ONE_DAY);
    await ah.connect(bidder1).placeBid(0, { value: ethers.parseEther("0.5") });
    const a = await ah.getAuction(0);
    expect(a.highestBid).to.equal(ethers.parseEther("0.5"));
    expect(a.highestBidder).to.equal(bidder1.address);
  });

  it("should reject bid below minimum", async () => {
    await ah.connect(seller).createAuction("Item", "Desc", MIN_BID, ONE_DAY);
    await expect(ah.connect(bidder1).placeBid(0, { value: ethers.parseEther("0.01") })).to.be.revertedWith("Below min bid");
  });

  it("should outbid previous bidder", async () => {
    await ah.connect(seller).createAuction("Item", "Desc", MIN_BID, ONE_DAY);
    await ah.connect(bidder1).placeBid(0, { value: ethers.parseEther("1") });
    await ah.connect(bidder2).placeBid(0, { value: ethers.parseEther("2") });
    const a = await ah.getAuction(0);
    expect(a.highestBidder).to.equal(bidder2.address);
  });

  it("should allow previous bidder to withdraw", async () => {
    await ah.connect(seller).createAuction("Item", "Desc", MIN_BID, ONE_DAY);
    await ah.connect(bidder1).placeBid(0, { value: ethers.parseEther("1") });
    await ah.connect(bidder2).placeBid(0, { value: ethers.parseEther("2") });
    await ah.connect(bidder1).withdrawBid(0);
  });

  it("should end auction and pay seller", async () => {
    await ah.connect(seller).createAuction("Item", "Desc", MIN_BID, ONE_DAY);
    await ah.connect(bidder1).placeBid(0, { value: ethers.parseEther("1") });
    await time.increase(ONE_DAY + 1);
    const before = await ethers.provider.getBalance(seller.address);
    await ah.endAuction(0);
    const after = await ethers.provider.getBalance(seller.address);
    expect(after).to.be.gt(before);
  });

  it("should not end auction early", async () => {
    await ah.connect(seller).createAuction("Item", "Desc", MIN_BID, ONE_DAY);
    await expect(ah.endAuction(0)).to.be.revertedWith("Not ended yet");
  });

  it("should cancel auction with no bids", async () => {
    await ah.connect(seller).createAuction("Item", "Desc", MIN_BID, ONE_DAY);
    await ah.connect(seller).cancelAuction(0);
    const a = await ah.getAuction(0);
    expect(a.status).to.equal(2);
  });

  it("should not cancel auction with bids", async () => {
    await ah.connect(seller).createAuction("Item", "Desc", MIN_BID, ONE_DAY);
    await ah.connect(bidder1).placeBid(0, { value: ethers.parseEther("1") });
    await expect(ah.connect(seller).cancelAuction(0)).to.be.revertedWith("Has bids");
  });

  it("should prevent seller from bidding", async () => {
    await ah.connect(seller).createAuction("Item", "Desc", MIN_BID, ONE_DAY);
    await expect(ah.connect(seller).placeBid(0, { value: ethers.parseEther("1") })).to.be.revertedWith("Seller cannot bid");
  });

  it("should pause and unpause", async () => {
    await ah.pause();
    await expect(ah.connect(seller).createAuction("I", "D", MIN_BID, ONE_DAY)).to.be.reverted;
    await ah.unpause();
    await ah.connect(seller).createAuction("I", "D", MIN_BID, ONE_DAY);
  });
});
