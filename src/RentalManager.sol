// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Escrow.sol";
import "./ListingManager.sol";
import "./Rentable721.sol";

contract RentalManager is ReentrancyGuard, Ownable {
    Escrow public escrow;
    ListingManager public listingManager;
    address public feeRecipient;
    uint256 public protocolFeeBps;
    uint256 public nextRentalId = 1;

    struct Rental {
        uint256 id;
        address nft;
        uint256 tokenId;
        address renter;
        uint256 start;
        uint256 end;
        uint256 amount;
        uint256 deposit;
        bool finalized;
    }

    // O(1) lookup for rentals by ID
    mapping(uint256 => Rental) public rentalById;
    
    // Track the end time of the last scheduled rental to enforce append-only scheduling (Conflict Prevention)
    mapping(address => mapping(uint256 => uint256)) public lastRentalEnd;

    event Rented(
        uint256 indexed rentalId,
        address indexed nft,
        uint256 indexed tokenId,
        address renter,
        uint256 start,
        uint256 end,
        uint256 amount,
        uint256 deposit
    );
    event CheckedIn(uint256 indexed rentalId, uint256 timestamp);
    event RentalFinalized(uint256 indexed rentalId, address indexed nft, uint256 indexed tokenId);
    event PayoutReleased(uint256 indexed rentalId, address indexed to, uint256 amount);
    event DepositRefunded(uint256 indexed rentalId, address indexed renter, uint256 amount);
    event ProtocolFeeUpdated(uint256 newFeeBps);
    event FeeRecipientUpdated(address newRecipient);

    constructor(address _listingManager, address _feeRecipient, uint256 _protocolFeeBps) Ownable(msg.sender) {
        listingManager = ListingManager(_listingManager);
        feeRecipient = _feeRecipient;
        protocolFeeBps = _protocolFeeBps;
        escrow = new Escrow(address(this));
    }

    function setProtocolFee(uint256 _protocolFeeBps) external onlyOwner {
        require(_protocolFeeBps <= 10000, "RentalManager: invalid bps");
        protocolFeeBps = _protocolFeeBps;
        emit ProtocolFeeUpdated(_protocolFeeBps);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "RentalManager: invalid address");
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function rent(address nft, uint256 tokenId, uint256 start, uint256 end) external payable nonReentrant {
        require(start < end, "RentalManager: invalid times");
        require(start >= block.timestamp, "RentalManager: start in past");
        
        ListingManager.Listing memory listing = listingManager.getListing(nft, tokenId);
        require(listing.active, "RentalManager: not listed");
        require(listing.owner == IERC721(nft).ownerOf(tokenId), "RentalManager: ownership changed");
        
        uint256 duration = end - start;
        require(
            duration >= listing.minDuration && duration <= listing.maxDuration, "RentalManager: duration out of range"
        );
        
        // Conflict Check: Append-only strategy for O(1) complexity
        // New rental must start after the last scheduled rental ends
        require(start >= lastRentalEnd[nft][tokenId], "RentalManager: time conflict - must book after last rental");

        uint256 cost = duration * listing.pricePerSecond;
        uint256 total = cost + listing.deposit;
        require(msg.value >= total, "RentalManager: insufficient payment");

        // Update schedule
        lastRentalEnd[nft][tokenId] = end;

        // Deposit funds
        escrow.deposit{value: total}(nextRentalId);

        // Store Rental
        rentalById[nextRentalId] = Rental({
            id: nextRentalId,
            nft: nft,
            tokenId: tokenId,
            renter: msg.sender,
            start: start,
            end: end,
            amount: cost,
            deposit: listing.deposit,
            finalized: false
        });

        emit Rented(nextRentalId, nft, tokenId, msg.sender, start, end, cost, listing.deposit);

        // If rental starts immediately (or close enough), auto-checkin
        if (start <= block.timestamp + 1 hours && start <= lastRentalEnd[nft][tokenId]) {
             // We can try to set user properly.
             // Note: If this is a future rental appended to the end, we can only set user if it's the CURRENT usage time.
             // But we just checked `start >= block.timestamp`.
             // If `start` is NOW, we set user.
             if (start <= block.timestamp) {
                 _checkIn(nextRentalId);
             }
        }

        nextRentalId++;

        // Refund excess
        if (msg.value > total) {
            (bool refundSuccess,) = payable(msg.sender).call{value: msg.value - total}("");
            require(refundSuccess, "RentalManager: refund failed");
        }
    }

    // New function: Check-in to active the rental on the NFT
    // This allows future rentals to be booked without overwriting the current user immediately
    function checkIn(uint256 rentalId) external nonReentrant {
        _checkIn(rentalId);
    }

    function _checkIn(uint256 rentalId) internal {
        Rental memory rental = rentalById[rentalId];
        require(msg.sender == rental.renter, "RentalManager: not renter");
        require(block.timestamp >= rental.start, "RentalManager: too early");
        require(block.timestamp < rental.end, "RentalManager: expired");
        
        // This fails if someone else is currently the user? 
        // ERC4907 `setUser` ensures `user` is set. It overwrites. 
        // We trust our `lastRentalEnd` logic to ensure no overlaps in *paid* time.
        // So safe to overwrite (previous rental should be over).
        
        Rentable721(rental.nft).setUser(rental.tokenId, rental.renter, uint64(rental.end));
        emit CheckedIn(rentalId, block.timestamp);
    }

    function finalize(uint256 rentalId) external nonReentrant {
        Rental storage rental = rentalById[rentalId];
        require(rental.id != 0, "RentalManager: does not exist");
        require(!rental.finalized, "RentalManager: already finalized");
        require(block.timestamp >= rental.end, "RentalManager: not expired");

        ListingManager.Listing memory listing = listingManager.getListing(rental.nft, rental.tokenId);
        
        uint256 fee = rental.amount * protocolFeeBps / 10000;
        uint256 toOwner = rental.amount - fee;

        if (toOwner > 0) {
            escrow.release(rentalId, listing.owner, toOwner);
            emit PayoutReleased(rentalId, listing.owner, toOwner);
        }
        if (fee > 0) escrow.release(rentalId, feeRecipient, fee);
        if (rental.deposit > 0) {
            escrow.release(rentalId, rental.renter, rental.deposit);
            emit DepositRefunded(rentalId, rental.renter, rental.deposit);
        }

        rental.finalized = true;
        emit RentalFinalized(rentalId, rental.nft, rental.tokenId);
    }
}
