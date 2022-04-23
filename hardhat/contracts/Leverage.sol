pragma solidity ^0.8.10;

import "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolImmutables.sol";

import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";

contract Leverage is IFlashLoanSimpleReceiver, IUniswapV3SwapCallback {
    // aave flash loan
    IPool public immutable override POOL;
    IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;

    // uniswap
    IUniswapV3PoolActions public immutable uniswap;

    // tokens
    IERC20 public immutable base;
    IERC20 public immutable quote;

    // parameters
    uint8 public immutable baseDecimals;
    uint8 public immutable quoteDecimals;
    uint8 internal constant oracleDecimals = 8;
    bool internal immutable quoteIsZeroSlot;

    uint256 internal constant WAD = 1e18;

    constructor(
        IPool _pool,
        IPoolAddressesProvider _addressesProvider,
        address _base,
        address _quote,
        address _uniPool
    ) {
        POOL = _pool;
        ADDRESSES_PROVIDER = _addressesProvider;

        uniswap = IUniswapV3PoolActions(_uniPool);

        base = IERC20(_base);
        quote = IERC20(_quote);

        baseDecimals = IERC20Metadata(_base).decimals();
        quoteDecimals = IERC20Metadata(_quote).decimals();

        quoteIsZeroSlot = IUniswapV3PoolImmutables(_uniPool).token0() == _quote;

        // approve all future actions
        IERC20(_base).approve(address(_pool), type(uint256).max);
        IERC20(_quote).approve(address(_pool), type(uint256).max);
        IERC20(_base).approve(address(_uniPool), type(uint256).max);
        IERC20(_quote).approve(address(_uniPool), type(uint256).max);
    }

    /// @notice Open a leveraged long position on Aave V3
    /// @param borrowAmount Amount of base token to borrow from Aave V3 (has to cover the flash loan + fees and slippage)
    /// @param collateral Amount of collateral available
    /// @param leverage Desired leverage factor
    /// @param isLong Long (EUR/USD) or short

    function takeOutFlashLoan(
        uint256 borrowAmount,
        uint256 collateral,
        uint8 leverage,
        bool isLong
    ) external {
        IERC20 flashLoanToken = isLong ? base : quote;
        flashLoanToken.transferFrom(msg.sender, address(this), collateral);

        uint256 flashLoanAmount = collateral * (leverage - 1);

        POOL.flashLoanSimple(
            address(this),
            address(flashLoanToken),
            flashLoanAmount,
            abi.encode(msg.sender, isLong, collateral, borrowAmount),
            0
        );
    }

    // callback by aave flash loan
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        (
            address user,
            bool isLong,
            uint256 collateral,
            uint256 borrowAmount
        ) = abi.decode(params, (address, bool, uint256, uint256));

        borrowOnAaveAndSwapOnUni(
            user,
            isLong,
            collateral,
            borrowAmount,
            amount,
            premium
        );
    }

    // borrow collateral and swap on uni
    function borrowOnAaveAndSwapOnUni(
        address user,
        bool isLong,
        uint256 collateral,
        uint256 borrowAmount,
        uint256 flashLoanAmount,
        uint256 premium
    ) internal {
        // Total amount borrowed in flash loans
        uint256 supplyAmount = collateral + flashLoanAmount;
        POOL.supply(
            address(isLong ? base : quote),
            supplyAmount,
            msg.sender,
            0
        );

        // User might have to give credit allocation to the contract
        POOL.borrow(
            address(isLong ? quote : base),
            borrowAmount,
            2,
            0,
            msg.sender
        );

        // Swap the tokens

        // zeroForOne should be
        // if       long  & quote is token0 than swap token0 for token1 => true
        // else if  long  & base  is token0 than swap token1 for token0 => false
        // else if  short & quote is token0 than swap token1 for token0 => false
        // else if  long  & base  is token0 than swap token0 for token1 => true

        uniswap.swap(
            address(this),
            isLong ? quoteIsZeroSlot : !quoteIsZeroSlot, /* zeroForOne*/
            int256(borrowAmount),
            0,
            abi.encode(user, isLong, flashLoanAmount + premium)
        );
    }

    // callback by uniswap
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        (address user, bool isLong, uint256 targetAmount) = abi.decode(
            data,
            (address, bool, uint256)
        );

        // check return values
    }
}
