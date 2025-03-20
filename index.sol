// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PresaleToken is ERC20 {
    address public owner;
    address public initialWallet; // Changed from constant to configurable variable
    uint256 public constant MAX_SUPPLY = 10_000_000_000 * 10**18; // 10 billion tokens
    uint256 public constant INITIAL_ALLOCATION = 6_500_000_000 * 10**18; // 65%
    uint256 public constant PRESALE_ALLOCATION = 3_500_000_000 * 10**18; // 35%
    IERC20 public usdt;
    IERC20 public usdc;
    uint256 public ethUsdPrice; // ETH price in USD (e.g., 2100 * 10^18)
    uint256 public tokensPerUsd; // PST per USD (e.g., 1000 * 10^18)
    uint256 public tokensSold; // Track total sold
    bool public paused; // Pause mechanism
    uint256 public constant MAX_PURCHASE = 10_000_000 * 10**18; // e.g., 10M PST per tx

    event TokensPurchased(address buyer, uint256 amount, string currency);

    constructor(
        address _usdt,
        address _usdc,
        address _initialWallet // Added parameter for initial wallet
    ) ERC20("FundingMemeToken", "FM") {
        require(_initialWallet != address(0), "Invalid initial wallet address"); // Optional: prevent zero address
        owner = msg.sender;
        usdt = IERC20(_usdt);
        usdc = IERC20(_usdc);
        initialWallet = _initialWallet; // Set the initial wallet from constructor argument
        ethUsdPrice = 2100 * 10**18; // Initial ETH price: $2100
        tokensPerUsd = 1000 * 10**18; // 1 USD = 1000 PST

        _mint(initialWallet, INITIAL_ALLOCATION); // Use the configurable initialWallet
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

    // Buy with ETH
    function buyWithETH() external payable whenNotPaused {
        require(msg.value > 0, "Send some ETH");
        require(ethUsdPrice > 0, "ETH price not set");
        uint256 usdValue = (msg.value * ethUsdPrice) / 10**18;
        uint256 tokenAmount = (usdValue * tokensPerUsd) / 10**18;
        require(tokenAmount <= MAX_PURCHASE, "Exceeds max purchase");
        require(tokensSold + tokenAmount <= PRESALE_ALLOCATION, "Exceeds presale supply");
        require(balanceOf(address(this)) >= tokenAmount, "Not enough tokens");
        tokensSold += tokenAmount;
        _transfer(address(this), msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, tokenAmount, "ETH");
    }

    // Buy with USDT
    function buyWithUSDT(uint256 usdtAmount) external whenNotPaused {
        require(usdtAmount > 0, "Send some USDT");
        uint256 tokenAmount = (usdtAmount * tokensPerUsd) / 10**6;
        require(tokenAmount <= MAX_PURCHASE, "Exceeds max purchase");
        require(tokensSold + tokenAmount <= PRESALE_ALLOCATION, "Exceeds presale supply");
        require(balanceOf(address(this)) >= tokenAmount, "Not enough tokens");
        require(usdt.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");
        tokensSold += tokenAmount;
        _transfer(address(this), msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, tokenAmount, "USDT");
    }

    // Buy with USDC
    function buyWithUSDC(uint256 usdcAmount) external whenNotPaused {
        require(usdcAmount > 0, "Send some USDC");
        uint256 tokenAmount = (usdcAmount * tokensPerUsd) / 10**6;
        require(tokenAmount <= MAX_PURCHASE, "Exceeds max purchase");
        require(tokensSold + tokenAmount <= PRESALE_ALLOCATION, "Exceeds presale supply");
        require(balanceOf(address(this)) >= tokenAmount, "Not enough tokens");
        require(usdc.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");
        tokensSold += tokenAmount;
        _transfer(address(this), msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, tokenAmount, "USDC");
    }

    // Set ETH/USD price
    function setEthPrice(uint256 _ethUsdPrice) external onlyOwner {
        require(_ethUsdPrice > 0, "Invalid price");
        ethUsdPrice = _ethUsdPrice;
    }

    // Set tokens per USD
    function setTokensPerUsd(uint256 _tokensPerUsd) external onlyOwner {
        require(_tokensPerUsd > 0, "Invalid rate");
        tokensPerUsd = _tokensPerUsd;
    }

    // Pause or unpause presale
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    // Withdraw ETH
    function withdrawETH() external onlyOwner {
        payable(initialWallet).transfer(address(this).balance); // Updated to use initialWallet
    }

    // Withdraw USDT
    function withdrawUSDT() external onlyOwner {
        usdt.transfer(initialWallet, usdt.balanceOf(address(this))); // Updated to use initialWallet
    }

    // Withdraw USDC
    function withdrawUSDC() external onlyOwner {
        usdc.transfer(initialWallet, usdc.balanceOf(address(this))); // Updated to use initialWallet
    }
}