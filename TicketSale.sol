// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TicketSale is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _eventIdCounter;

    struct TicketInfo {
        string eventName;
        string eventOrganizer;
        string posterCid;
        string ticketImageUrl;
        uint128 price;
        uint64 expiryTimestamp;
        uint64 eventDate;
        address seller;
    }

    struct TicketStatus {
        address buyer;
        bool sold;
        bool downloaded;
        bool active;
    }

    struct Ticket {
        uint256 ticketId; 
        TicketInfo info;   
        TicketStatus status; 
    }

    struct TransactionHistory {
        address buyer;
        uint256 ticketId; 
        uint128 price;
        string eventName;
        uint64 purchaseDate;
    }

    mapping(uint256 => Ticket) public tickets;
    mapping(uint256 => uint256) public escrowBalances;
    mapping(uint256 => mapping(address => bool)) public hasPurchased;

    TransactionHistory[] public transactionHistories;

    uint256 public ticketCreationFee = 0.02 ether;
    address payable public admin;

    event TicketCreated(uint256 indexed ticketId, string eventName, string ticketImageUrl, string posterCid, bool active);
    event TicketBought(uint256 indexed ticketId, address buyer, uint256 price);
    event TicketDownloaded(uint256 indexed ticketId, address owner);
    event TicketRefunded(uint256 indexed ticketId, address buyer, uint256 refundAmount);
    event TicketStatusUpdated(uint256 indexed ticketId, bool active);
    event TransactionRecorded(address indexed buyer, uint256 indexed ticketId, uint128 price, string eventName, uint64 purchaseDate);

    constructor() ERC721("ConcertTicket", "CTIX") Ownable() {
        admin = payable(0xD55B57a32ffc78885F6A5F96016b5Dc87cb7BA06);
        _tokenIdCounter.increment(); 
    }

    modifier onlyActiveTicket(uint256 _ticketId) {
        require(tickets[_ticketId].status.active, "Ticket is inactive");
        _;
    }

    function createMultipleTickets(
        string memory _eventName,
        string memory _eventOrganizer,
        string memory _posterCid,
        string memory _ticketImageUrl,
        uint128 _price,
        uint64 _expiryTimestamp,
        uint64 _eventDate
    ) public payable {
        uint8 totalTickets = 5; 
        require(msg.value == 0.02 ether, "Payment of 0.02 ETH required");
        require(_expiryTimestamp > block.timestamp, "Expiry must be future");
        require(_expiryTimestamp < _eventDate, "Expiry must be before event date");
        require(bytes(_posterCid).length > 0, "Poster CID cannot be empty");

        for (uint8 i = 0; i < totalTickets; i++) {
            uint256 ticketId = _tokenIdCounter.current();
            _tokenIdCounter.increment(); 

            tickets[ticketId] = Ticket({
                ticketId: ticketId,
                info: TicketInfo({
                    eventName: _eventName,
                    eventOrganizer: _eventOrganizer,
                    posterCid: _posterCid,
                    ticketImageUrl: _ticketImageUrl,
                    price: _price,
                    expiryTimestamp: _expiryTimestamp,
                    eventDate: _eventDate,
                    seller: msg.sender
                }),
                status: TicketStatus({
                    buyer: address(0), 
                    sold: false,
                    downloaded: false,
                    active: true
                })
            });

            emit TicketCreated(ticketId, _eventName, _ticketImageUrl, _posterCid, true);
        }

        (bool sent, ) = admin.call{value: msg.value}("");
        require(sent, "Failed to transfer creation fee to admin");
    }

    function buyTicket(uint256 _ticketId) public payable {
        Ticket storage ticket = tickets[_ticketId];

        require(!ticket.status.sold, "Ticket already sold");
        require(msg.value == ticket.info.price, "Incorrect payment amount");
        require(!hasPurchased[_ticketId][msg.sender], "Already purchased this ticket");

        hasPurchased[_ticketId][msg.sender] = true;
        escrowBalances[_ticketId] = msg.value;

        ticket.status.buyer = msg.sender;
        ticket.status.sold = true;

        transactionHistories.push(TransactionHistory({
            buyer: msg.sender,
            ticketId: _ticketId,
            price: ticket.info.price,
            eventName: ticket.info.eventName,
            purchaseDate: uint64(block.timestamp)
        }));

        emit TransactionRecorded(msg.sender, _ticketId, ticket.info.price, ticket.info.eventName, uint64(block.timestamp));
        emit TicketBought(_ticketId, msg.sender, msg.value);
    }

    function markAsDownloaded(uint256 _ticketId) public {
        Ticket storage ticket = tickets[_ticketId];
        require(ticket.status.sold, "Ticket must be sold first");
        require(!ticket.status.downloaded, "Ticket already downloaded");
        require(ticket.status.buyer == msg.sender, "Only the buyer can mark the ticket as downloaded");

        uint256 escrowAmount = escrowBalances[_ticketId];
        require(escrowAmount > 0, "No funds in escrow");

        ticket.status.downloaded = true;

        escrowBalances[_ticketId] = 0;  

        address seller = ticket.info.seller;

        (bool sent, ) = seller.call{value: escrowAmount}("");
        require(sent, "Failed to transfer funds to seller");

        _mint(msg.sender, _ticketId); 

        emit TicketDownloaded(_ticketId, msg.sender);
    }

    function updateExpiredTickets() public {
        for (uint256 i = 1; i < getTicketCount(); i++) {
            if (tickets[i].ticketId == i) {
                Ticket storage ticket = tickets[i];
                if (ticket.status.active && ticket.info.expiryTimestamp < block.timestamp) {
                    if (ticket.status.sold && !ticket.status.downloaded) {
                        uint256 refundAmount = escrowBalances[i];
                        escrowBalances[i] = 0;
                        address buyer = ticket.status.buyer;

                        (bool refunded, ) = buyer.call{value: refundAmount}("");
                        require(refunded, "Refund failed");

                        emit TicketRefunded(i, buyer, refundAmount);
                    }
                    ticket.status.active = false;
                    emit TicketStatusUpdated(i, false);
                }
            }
        }
    }

    function setAdmin(address payable _admin) public onlyOwner {
        admin = _admin;
    }

    function getTransactionHistory() public view returns (TransactionHistory[] memory) {
        return transactionHistories;
    }

    function getTicketDetails(uint256 _ticketId) public view returns (
        string memory eventName,
        address owner,
        address buyer,
        bool active
    ) {
        Ticket memory ticket = tickets[_ticketId];
        return (ticket.info.eventName, ownerOf(_ticketId), ticket.status.buyer, ticket.status.active);
    }

    function getTicketCount() public view returns (uint256) {
        uint256 validTickets = 0;
        for (uint256 i = 1; i <= _tokenIdCounter.current(); i++) {
            if (tickets[i].status.active) {  
                validTickets++;
            }
        }
        return validTickets;
    }

    function getTicketStatus(uint _ticketId) public view returns (
        address buyer,
        bool sold,
        bool downloaded,
        bool active
    ) {
        TicketStatus memory status = tickets[_ticketId].status;
        return (status.buyer, status.sold, status.downloaded, status.active);
    }
}
