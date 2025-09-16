// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EcommerceStore {
    enum ProductStatus { Open, Sold, Unsold }
    enum ProductCondition { New, Used }

    struct Bid {
        address bidder;
        uint productId;
        uint value;
        bool revealed;
    }

    struct Product {
        uint id;
        string name;
        string category;
        string imageLink;
        string descLink;
        uint auctionStartTime;
        uint auctionEndTime;
        uint startPrice;
        address highestBidder;
        uint highestBid;
        uint secondHighestBid;
        uint totalBids;
        ProductStatus status;
        ProductCondition condition;
        mapping(address => mapping(bytes32 => Bid)) bids;
    }

    uint public productIndex;
    mapping(address => mapping(uint => Product)) private stores;
    mapping(uint => address) private productIdInStore;

    function addProductToStore(
        string memory _name,
        string memory _category,
        string memory _imageLink,
        string memory _descLink,
        uint _auctionStartTime,
        uint _auctionEndTime,
        uint _startPrice,
        uint _productCondition
    ) public {
        require(_auctionStartTime < _auctionEndTime, "Invalid auction time");
        productIndex++;
        Product storage newProduct = stores[msg.sender][productIndex];
        newProduct.id = productIndex;
        newProduct.name = _name;
        newProduct.category = _category;
        newProduct.imageLink = _imageLink;
        newProduct.descLink = _descLink;
        newProduct.auctionStartTime = _auctionStartTime;
        newProduct.auctionEndTime = _auctionEndTime;
        newProduct.startPrice = _startPrice;
        newProduct.status = ProductStatus.Open;
        newProduct.condition = ProductCondition(_productCondition);

        productIdInStore[productIndex] = msg.sender;
    }

    function getProduct(uint _productId) public view returns (
        uint, string memory, string memory, string memory, string memory,
        uint, uint, uint, ProductStatus, ProductCondition
    ) {
        Product storage product = stores[productIdInStore[_productId]][_productId];
        return (
            product.id, product.name, product.category, product.imageLink, product.descLink,
            product.auctionStartTime, product.auctionEndTime, product.startPrice,
            product.status, product.condition
        );
    }

    function bid(uint _productId, bytes32 _bid) public payable returns(bool) {
        Product storage product = stores[productIdInStore[_productId]][_productId];
        require(block.timestamp >= product.auctionStartTime, "Auction not started");
        require(block.timestamp <= product.auctionEndTime, "Auction ended");
        require(msg.value > product.startPrice, "Bid too low");
        require(product.bids[msg.sender][_bid].bidder == address(0), "Bid already exists");

        product.bids[msg.sender][_bid] = Bid(msg.sender, _productId, msg.value, false);
        product.totalBids++;
        return true;
    }

    function revealBid(uint _productId, uint _amount, string memory _secret) public {
        Product storage product = stores[productIdInStore[_productId]][_productId];
        require(block.timestamp > product.auctionEndTime, "Auction not ended");

        bytes32 sealedBid = keccak256(abi.encodePacked(_amount, _secret));
        Bid storage bidInfo = product.bids[msg.sender][sealedBid];

        require(bidInfo.bidder != address(0), "Invalid bid");
        require(!bidInfo.revealed, "Bid already revealed");

        uint refund = 0;
        if (bidInfo.value >= _amount) {
            if (product.highestBidder == address(0)) {
                product.highestBidder = msg.sender;
                product.highestBid = _amount;
                product.secondHighestBid = product.startPrice;
                refund = bidInfo.value - _amount;
            } else if (_amount > product.highestBid) {
                product.secondHighestBid = product.highestBid;
                payable(product.highestBidder).transfer(product.highestBid);
                product.highestBidder = msg.sender;
                product.highestBid = _amount;
                refund = bidInfo.value - _amount;
            } else if (_amount > product.secondHighestBid) {
                product.secondHighestBid = _amount;
                refund = _amount;
            } else {
                refund = _amount;
            }
        }

        if (refund > 0) {
            payable(msg.sender).transfer(refund);
            bidInfo.revealed = true;
        }
    }

    function highestBidderInfo(uint _productId) public view returns(address, uint, uint) {
        Product storage product = stores[productIdInStore[_productId]][_productId];
        return (product.highestBidder, product.highestBid, product.secondHighestBid);
    }

    function totalBids(uint _productId) public view returns(uint) {
        Product storage product = stores[productIdInStore[_productId]][_productId];
        return product.totalBids;
    }
}
