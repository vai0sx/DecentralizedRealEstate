// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BlockHomie is ERC721 {
    using SafeMath for uint256;

    struct Property {
        uint256 id;
        address owner;
        uint256 price;
        uint256 tokenId;
        bool isForSale;
        bool isForRent;
        uint256 rentPrice;
        string metaData;
    }

    struct RentalAgreement {
        uint256 propertyId;
        address tenant;
        uint256 startDate;
        uint256 endDate;
        uint256 rentAmount;
    }

    IERC20 public etherToken;
    IERC20 public usdtToken;
    address public PropertyCreator;
    uint256 private propertyIdCounter;
    uint256 private rentalAgreementCounter;

    uint256 private constant COMMISSION_RATE = 100; // 1% commission

    mapping(uint256 => Property) public properties;
    mapping(uint256 => RentalAgreement) public rentalAgreements;

    event PropertyListed(uint256 indexed propertyId, address indexed owner, uint256 price, string metaData);
    event PropertySold(uint256 indexed propertyId, address indexed newOwner, uint256 price);
    event PropertyRented(uint256 indexed propertyId, address indexed tenant, uint256 startDate, uint256 endDate, uint256 rentAmount);
    event RentalAgreementSigned(uint256 indexed propertyId, uint256 indexed rentalAgreementId);

    constructor(IERC20 _etherToken, IERC20 _usdtToken, address _PropertyCreator) ERC721("Real Estate Market", "REMARKET") {
        etherToken = _etherToken;
        usdtToken = _usdtToken;
        PropertyCreator = _PropertyCreator;
        propertyIdCounter = 1;
        rentalAgreementCounter = 1;
    }

    function listProperty(uint256 price, string memory metaData) public {
        uint256 propertyId = propertyIdCounter;
        _mint(msg.sender, propertyId);
        properties[propertyId] = Property(propertyId, msg.sender, price, propertyId, true, false, 0, metaData);
        emit PropertyListed(propertyId, msg.sender, price, metaData);
        propertyIdCounter++;
    }

    function buyProperty(uint256 propertyId, bool useEther) public {
        Property storage property = properties[propertyId];
        require(property.isForSale, "Property not for sale");

        uint256 commission = property.price.div(COMMISSION_RATE);
        uint256 sellerAmount = property.price.sub(commission);

        if (useEther) {
            require(etherToken.transferFrom(msg.sender, property.owner, sellerAmount), "Payment to seller failed");
            require(etherToken.transferFrom(msg.sender, PropertyCreator, commission), "Payment to platform failed");
        } else {
            require(usdtToken.transferFrom(msg.sender, property.owner, sellerAmount), "Payment to seller failed");
            require(usdtToken.transferFrom(msg.sender, PropertyCreator, commission), "Payment to platform failed");
        }

        _transfer(property.owner, msg.sender, property.tokenId);
        property.owner = msg.sender;
        property.isForSale = false;
        emit PropertySold(propertyId, msg.sender, property.price);
    }

    function rentProperty(uint256 propertyId, uint256 startDate, uint256 endDate, uint256 rentAmount, bool useEther) public {
        Property storage property = properties[propertyId];
        require(property.isForRent, "Property not for rent");
                require(rentAmount >= property.rentPrice, "Rent amount insufficient");

        uint256 rentalAgreementId = rentalAgreementCounter;
        rentalAgreements[rentalAgreementId] = RentalAgreement(propertyId, msg.sender, startDate, endDate, rentAmount);
        emit RentalAgreementSigned(propertyId, rentalAgreementId);
        rentalAgreementCounter++;

        uint256 commission = rentAmount.div(COMMISSION_RATE);
        uint256 sellerAmount = rentAmount.sub(commission);

        if (useEther) {
            require(etherToken.transferFrom(msg.sender, property.owner, sellerAmount), "Payment to seller failed");
            require(etherToken.transferFrom(msg.sender, PropertyCreator, commission), "Payment to platform failed");
        } else {
            require(usdtToken.transferFrom(msg.sender, property.owner, sellerAmount), "Payment to seller failed");
            require(usdtToken.transferFrom(msg.sender, PropertyCreator, commission), "Payment to platform failed");
        }

        emit PropertyRented(propertyId, msg.sender, startDate, endDate, rentAmount);
    }

    function setForSale(uint256 propertyId, bool isForSale, uint256 newPrice) public {
        Property storage property = properties[propertyId];
        require(msg.sender == property.owner, "Only the property owner can change the sale status");

        property.isForSale = isForSale;

        if (newPrice > 0) {
            property.price = newPrice;
        }
    }
}
