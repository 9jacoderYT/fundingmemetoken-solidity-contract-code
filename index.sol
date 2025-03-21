// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FundingMemeToken is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Contract owner and recipient of funds
    address public owner;
    
    // Hardcoded token addresses (Ethereum mainnet)
    address public constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    // Token supply configuration
    uint256 public constant MAX_SUPPLY = 10_000_000_000 * 10**18;
    uint256 public constant INITIAL_ALLOCATION = 6_500_000_000 * 10**18;
    uint256 public constant PRESALE_ALLOCATION = 3_500_000_000 * 10**18;
    
    // Token interfaces
    IERC20 public usdt;
    IERC20 public usdc;
    
    // Pricing and sales tracking
    uint256 public tokensPerUsd;
    uint256 public tokensSold;
    bool public paused;
    
    // Fixed ETH/USD Price (with 18 decimals)
    uint256 public ethUsdPrice;
    
    // Mapping to track decimal places for supported tokens
    mapping(address => uint8) public tokenDecimals;

    // Events
    event TokensPurchased(address buyer, uint256 amount, string currency);
    event TokensRecovered(address token, uint256 amount);
    event EthPriceUpdated(uint256 newPrice);

    constructor() ERC20("FundingMemeToken", "FM") {
        owner = msg.sender;
        
        // Initialize token interfaces
        usdt = IERC20(USDT_ADDRESS);
        usdc = IERC20(USDC_ADDRESS);
        
        // Set token decimals
        tokenDecimals[USDT_ADDRESS] = 6;  // USDT uses 6 decimals
        tokenDecimals[USDC_ADDRESS] = 6;  // USDC uses 6 decimals
        
        // Set initial prices
        ethUsdPrice = 2100 * 10**18; // Initial ETH price: $2100
        tokensPerUsd = 1000 * 10**18; // 1 USD = 1000 FM (1 FM = $0.001)
        
        // Mint initial token supply
        _mint(owner, INITIAL_ALLOCATION);
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
    
    // Buy with ETH using fixed price set by owner
    function buyWithETH() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Send some ETH");
        require(ethUsdPrice > 0, "ETH price not set");
        
        uint256 usdValue = (msg.value * ethUsdPrice) / 10**18;
        uint256 tokenAmount = (usdValue * tokensPerUsd) / 10**18;

        require(tokensSold + tokenAmount <= PRESALE_ALLOCATION, "Exceeds presale supply");
        require(balanceOf(address(this)) >= tokenAmount, "Not enough tokens");

        tokensSold += tokenAmount;
        _transfer(address(this), msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, tokenAmount, "ETH");
    }

    // Buy with USDT with reentrancy protection
    function buyWithUSDT(uint256 usdtAmount) external nonReentrant whenNotPaused {
        require(usdtAmount > 0, "Send some USDT");
        
        uint8 decimals = tokenDecimals[USDT_ADDRESS];
        uint256 tokenAmount = (usdtAmount * tokensPerUsd) / (10**decimals);

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
        
        uint8 decimals = tokenDecimals[USDC_ADDRESS];
        uint256 tokenAmount = (usdcAmount * tokensPerUsd) / (10**decimals);

        require(tokensSold + tokenAmount <= PRESALE_ALLOCATION, "Exceeds presale supply");
        require(balanceOf(address(this)) >= tokenAmount, "Not enough tokens");

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);
        tokensSold += tokenAmount;
        _transfer(address(this), msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, tokenAmount, "USDC");
    }
    
    // Function to update the ETH/USD price
    function setEthPrice(uint256 _ethUsdPrice) external onlyOwner {
        require(_ethUsdPrice > 0, "Invalid price");
        ethUsdPrice = _ethUsdPrice;
        emit EthPriceUpdated(_ethUsdPrice);
    }
    
    // Function to update token decimals if needed
    function updateTokenDecimals(address token, uint8 decimals) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(decimals > 0, "Decimals must be greater than 0");
        tokenDecimals[token] = decimals;
    }

    // Update token price
    function setTokensPerUsd(uint256 _tokensPerUsd) external onlyOwner {
        require(_tokensPerUsd > 0, "Invalid rate");
        tokensPerUsd = _tokensPerUsd;
    }

    // Pause/unpause presale
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    // Withdraw functions
    function withdrawETH() external onlyOwner nonReentrant {
        payable(owner).transfer(address(this).balance);
    }

    function withdrawUSDT() external onlyOwner nonReentrant {
        usdt.safeTransfer(owner, usdt.balanceOf(address(this)));
    }

    function withdrawUSDC() external onlyOwner nonReentrant {
        usdc.safeTransfer(owner, usdc.balanceOf(address(this)));
    }
    
    // Token recovery function for accidentally sent tokens
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner nonReentrant {
        require(tokenAddress != address(this), "Cannot recover presale token");
        require(
            tokenAddress != USDT_ADDRESS && tokenAddress != USDC_ADDRESS, 
            "Use dedicated withdraw functions for USDT/USDC"
        );
        
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");
        
        token.safeTransfer(owner, amount);
        emit TokensRecovered(tokenAddress, amount);
    }
}