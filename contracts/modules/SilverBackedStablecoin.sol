// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "../utils/AccessControl.sol";
// import "../token/ERC20/ERC20.sol";
// import "../token/ERC20/IERC20.sol";
// import {ERC20Burnable} from "./ERC20/extensions/ERC20Burnable.sol";
// import {ERC20Permit} from "./ERC20/extensions/ERC20Permit.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// /**
//  * @title SilverBackedStablecoin
//  * @dev Chainlink Oracle ile gümüş fiyatı güncellenen gümüş destekli stablecoin.
//  */
// contract SilverBackedStablecoin is 
//     AccessControl,
//     ERC20,
//     ERC20Burnable,
//     ERC20Permit {


//     bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

//     uint256 public silverReserve; // Gram cinsinden toplam gümüş rezervi
//     AggregatorV3Interface internal priceFeed; // Chainlink Price Feed

//     // Olaylar (Events)
//     event Minted(address indexed to, uint256 amount, uint256 newReserve);
//     event Burned(address indexed from, uint256 amount, uint256 newReserve);
//     event ReserveUpdated(uint256 oldReserve, uint256 newReserve);
//     event SilverPriceUpdated(uint256 price);

//     /**
//      * @dev Kontratın başlatılması. Chainlink XAG/USD fiyat feed adresi girilmeli.
//      * Ethereum Mainnet için XAG/USD fiyat feed: 0x379589227b15F1a12195D3f2d90bBc9F31f95235
//      */
//     constructor(address _priceFeed) ERC20("Silver Backed Stablecoin", "SILV") ERC20Permit("Silver Backed Stablecoin"){

//         _mint(msg.sender, 11000000 * 10 ** decimals());
//         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         _grantRole(ADMIN_ROLE, msg.sender);
//         priceFeed = AggregatorV3Interface(_priceFeed);
//     }

//     /**
//      * @dev Güncel gümüş fiyatını Chainlink Oracle'dan alır.
//      */
//     function getSilverPrice() public view returns (uint256) {
//         (, int256 price, , , ) = priceFeed.latestRoundData();
//         require(price > 0, "Invalid price feed response");
//         return uint256(price); // Fiyat, 8 ondalık basamağa sahiptir (1 XAG = price * 10^8 USD)
//     }

//     /**
//      * @dev Yeni token basma işlemi. 
//      * Yalnızca admin tarafından çağrılabilir.
//      */
//     function mint(address to, uint256 silverAmount) external onlyRole(ADMIN_ROLE) {
//         require(silverAmount > 0, "Mint amount must be greater than zero");
//         _mint(to, silverAmount);
//         silverReserve += silverAmount;
//         emit Minted(to, silverAmount, silverReserve);
//     }

//     /**
//      * @dev Token yakma işlemi. Kullanıcılar tokenlerini fiziksel gümüş karşılığında yakabilir.
//      */
//     function burn(uint256 amount) external {
//         require(balanceOf(msg.sender) >= amount, "Insufficient balance");
//         _burn(msg.sender, amount);
//         silverReserve -= amount;
//         emit Burned(msg.sender, amount, silverReserve);
//     }

//     /**
//      * @dev Rezerv güncellendiğinde, eklenen rezerv kadar token basılır.
//      */
//     function updateReserve(uint256 newReserve) external onlyRole(ADMIN_ROLE) {
//         require(newReserve > silverReserve, "New reserve must be greater than current reserve");

//         uint256 addedAmount = newReserve - silverReserve;
//         _mint(owner(), addedAmount);  // Yeni eklenen rezerv kadar token mint edilir

//         uint256 oldReserve = silverReserve;
//         silverReserve = newReserve;

//         emit ReserveUpdated(oldReserve, newReserve);
//     }

//     /**
//      * @dev Kullanıcıya güncel SILV fiyatını verir (1 gram SILV kaç USD ediyor).
//      */
//     function getSILVPriceInUSD() public view returns (uint256) {
//         uint256 silverPrice = getSilverPrice();
//         return silverPrice / 100000000; // 8 ondalık basamaktan tam sayıya dönüştür
//     }
// }