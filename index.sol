// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // Import for reentrancy protection
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; // Chainlink price feed

contract FundingMemeToken is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    address public owner;
    address public initialWallet;
    uint256 public constant MAX_SUPPLY = 10_000_000_000 * 10**18;
    uint256 public constant INITIAL_ALLOCATION = 6_500_000_000 * 10**18;
    uint256 public constant PRESALE_ALLOCATION = 3_500_000_000 * 10**18;
    IERC20 public usdt;
    IERC20 public usdc;
    uint256 public tokensPerUsd;
    uint256 public tokensSold;
    bool public paused;
    uint256 public constant MAX_PURCHASE = 10_000_000 * 10**18;
    
    // Chainlink ETH/USD Price Feed
    AggregatorV3Interface public ethUsdPriceFeed;
    
    // Mapping to track decimal places for supported tokens
    mapping(address => uint8) public tokenDecimals;

    event TokensPurchased(address buyer, uint256 amount, string currency);
    event TokensRecovered(address token, uint256 amount);
    event EthPriceFeedUpdated(address newPriceFeed);

    constructor(
        address _initialWallet, 
        address _usdt, 
        address _usdc, 
        address _ethUsdPriceFeed
    ) ERC20("FundingMemeToken", "FM") {
        require(_initialWallet != address(0), "Invalid initial wallet");
        require(_ethUsdPriceFeed != address(0), "Invalid price feed address");
        
        owner = msg.sender;
        initialWallet = _initialWallet;
        usdt = IERC20(_usdt);
        usdc = IERC20(_usdc);
        
        // Set up decimals for supported tokens
        tokenDecimals[_usdt] = 6;  // USDT typically uses 6 decimals
        tokenDecimals[_usdc] = 6;  // USDC typically uses 6 decimals
        
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        tokensPerUsd = 1000 * 10**18; // 1 USD = 1000 FM (1 FM = $0.001)
        
        _mint(initialWallet, INITIAL_ALLOCATION);
        _mint(address(this), PRESALE_ALLOCATION);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Presale paused");
        _;
    }
    
    // Get latest ETH/USD price from Chainlink
    function getLatestEthPrice() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid price feed response");
        
        // Chainlink price feeds are typically 8 decimals, we convert to 18 decimals
        return uint256(price) * 10**10;
    }

    // Buy with ETH using Chainlink oracle price
    function buyWithETH() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Send some ETH");
        
        uint256 ethUsdPrice = getLatestEthPrice();
        uint256 usdValue = (msg.value * ethUsdPrice) / 10**18;
        uint256 tokenAmount = (usdValue * tokensPerUsd) / 10**18;

        require(tokenAmount <= MAX_PURCHASE, "Exceeds max purchase");
        require(tokensSold + tokenAmount <= PRESALE_ALLOCATION, "Exceeds presale supply");
        require(balanceOf(address(this)) >= tokenAmount, "Not enough tokens");

        tokensSold += tokenAmount;
        _transfer(address(this), msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, tokenAmount, "ETH");
    }

    // Buy with USDT with reentrancy protection
    function buyWithUSDT(uint256 usdtAmount) external nonReentrant whenNotPaused {
        require(usdtAmount > 0, "Send some USDT");
        
        uint8 decimals = tokenDecimals[address(usdt)];
        uint256 tokenAmount = (usdtAmount * tokensPerUsd) / (10**decimals);

        require(tokenAmount <= MAX_PURCHASE, "Exceeds max purchase");
        require(tokensSold + tokenAmount <= PRESALE_ALLOCATION, "Exceeds presale supply");
        require(balanceOf(address(this)) >= tokenAmount, "Not enough tokens");

        usdt.safeTransferFrom(msg.sender, address(this), usdtAmount);
        tokensSold += tokenAmount;
        _transfer(address(this), msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, tokenAmount, "USDT");
    }

    // Buy with USDC with reentrancy protection
    function buyWithUSDC(uint256 usdcAmount) external nonReentrant whenNotPaused {
        require(usdcAmount > 0, "Send some USDC");
        
        uint8 decimals = tokenDecimals[address(usdc)];
        uint256 tokenAmount = (usdcAmount * tokensPerUsd) / (10**decimals);

        require(tokenAmount <= MAX_PURCHASE, "Exceeds max purchase");
        require(tokensSold + tokenAmount <= PRESALE_ALLOCATION, "Exceeds presale supply");
        require(balanceOf(address(this)) >= tokenAmount, "Not enough tokens");

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        tokensSold += tokenAmount;
        _transfer(address(this), msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, tokenAmount, "USDC");
    }
    
    // Function to update the ETH/USD price feed address
    function updateEthUsdPriceFeed(address _ethUsdPriceFeed) external onlyOwner {
        require(_ethUsdPriceFeed != address(0), "Invalid price feed address");
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        emit EthPriceFeedUpdated(_ethUsdPriceFeed);
    }
    
    // Function to update token decimals if needed
    function updateTokenDecimals(address token, uint8 decimals) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(decimals > 0, "Decimals must be greater than 0");
        tokenDecimals[token] = decimals;
    }

    // Setter functions
    function setTokensPerUsd(uint256 _tokensPerUsd) external onlyOwner {
        require(_tokensPerUsd > 0, "Invalid rate");
        tokensPerUsd = _tokensPerUsd;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    // Withdraw functions
    function withdrawETH() external onlyOwner nonReentrant {
        payable(initialWallet).transfer(address(this).balance);
    }

    function withdrawUSDT() external onlyOwner nonReentrant {
        usdt.safeTransfer(initialWallet, usdt.balanceOf(address(this)));
    }

    function withdrawUSDC() external onlyOwner nonReentrant {
        usdc.safeTransfer(initialWallet, usdc.balanceOf(address(this)));
    }
    
    // Token recovery function for accidentally sent tokens
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner nonReentrant {
        require(tokenAddress != address(this), "Cannot recover presale token");
        require(
            tokenAddress != address(usdt) || tokenAddress != address(usdc), 
            "Use dedicated withdraw functions for USDT/USDC"
        );
        
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");
        
        token.safeTransfer(initialWallet, amount);
        emit TokensRecovered(tokenAddress, amount);
    }
}