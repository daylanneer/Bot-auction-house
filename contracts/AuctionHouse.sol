// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract AuctionHouse is ReentrancyGuard, Ownable, Pausable {
    enum AuctionStatus { Active, Ended, Cancelled }

    struct Auction {
        address seller;
        string title;
        string description;
        uint256 minBid;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        AuctionStatus status;
        uint256 createdAt;
    }

    Auction[] public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    mapping(address => uint256[]) public sellerAuctions;

    uint256 public platformFee = 250; // 2.5%
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public totalAuctions;
    uint256 public totalVolume;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, string title, uint256 minBid, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 amount);
    event AuctionCancelled(uint256 indexed auctionId);
    event BidWithdrawn(uint256 indexed auctionId, address indexed bidder, uint256 amount);

    constructor() Ownable() {}

    function createAuction(string calldata _title, string calldata _desc, uint256 _minBid, uint256 _duration) external whenNotPaused {
        require(bytes(_title).length > 0, "Title required");
        require(_minBid > 0, "Min bid required");
        require(_duration >= 1 hours && _duration <= 30 days, "Invalid duration");

        uint256 id = auctions.length;
        auctions.push(Auction({
            seller: msg.sender,
            title: _title,
            description: _desc,
            minBid: _minBid,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + _duration,
            status: AuctionStatus.Active,
            createdAt: block.timestamp
        }));
        sellerAuctions[msg.sender].push(id);
        totalAuctions++;
        emit AuctionCreated(id, msg.sender, _title, _minBid, block.timestamp + _duration);
    }

    function placeBid(uint256 _auctionId) external payable nonReentrant whenNotPaused {
        Auction storage a = auctions[_auctionId];
        require(a.status == AuctionStatus.Active, "Not active");
        require(block.timestamp < a.endTime, "Auction ended");
        require(msg.sender != a.seller, "Seller cannot bid");
        require(msg.value >= a.minBid, "Below min bid");
        require(msg.value > a.highestBid, "Bid too low");

        if (a.highestBidder != address(0)) {
            pendingReturns[_auctionId][a.highestBidder] += a.highestBid;
        }
        a.highestBid = msg.value;
        a.highestBidder = msg.sender;
        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 _auctionId) external nonReentrant {
        Auction storage a = auctions[_auctionId];
        require(a.status == AuctionStatus.Active, "Not active");
        require(block.timestamp >= a.endTime, "Not ended yet");

        a.status = AuctionStatus.Ended;
        if (a.highestBidder != address(0)) {
            uint256 fee = (a.highestBid * platformFee) / FEE_DENOMINATOR;
            uint256 payout = a.highestBid - fee;
            totalVolume += a.highestBid;
            (bool sent,) = a.seller.call{value: payout}("");
            require(sent, "Payment failed");
        }
        emit AuctionEnded(_auctionId, a.highestBidder, a.highestBid);
    }

    function withdrawBid(uint256 _auctionId) external nonReentrant {
        uint256 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0, "Nothing to withdraw");
        pendingReturns[_auctionId][msg.sender] = 0;
        (bool sent,) = msg.sender.call{value: amount}("");
        require(sent, "Withdraw failed");
        emit BidWithdrawn(_auctionId, msg.sender, amount);
    }

    function cancelAuction(uint256 _auctionId) external {
        Auction storage a = auctions[_auctionId];
        require(msg.sender == a.seller || msg.sender == owner(), "Not authorized");
        require(a.status == AuctionStatus.Active, "Not active");
        require(a.highestBidder == address(0), "Has bids");
        a.status = AuctionStatus.Cancelled;
        emit AuctionCancelled(_auctionId);
    }

    function getAuction(uint256 _id) external view returns (Auction memory) { return auctions[_id]; }
    function getAuctionCount() external view returns (uint256) { return auctions.length; }
    function getSellerAuctions(address _s) external view returns (uint256[] memory) { return sellerAuctions[_s]; }
    function setPlatformFee(uint256 _fee) external onlyOwner { require(_fee <= 1000); platformFee = _fee; }
    function withdrawFees() external onlyOwner { (bool s,) = owner().call{value: address(this).balance}(""); require(s); }
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
