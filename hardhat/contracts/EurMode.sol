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



import "hardhat/console.sol";

contract EurMode is IFlashLoanSimpleReceiver, IUniswapV3SwapCallback {
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

    // from uniswap - used for min prices
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;



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

        console.log("get base decimals");
        baseDecimals = IERC20Metadata(_base).decimals();
        console.log("get quote decimals");
        quoteDecimals = IERC20Metadata(_quote).decimals();

        console.log("check token0");
        quoteIsZeroSlot = IUniswapV3PoolImmutables(_uniPool).token0() == _quote;

        // approve all future actions
        console.log("approve shit");
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

        console.log("transfer tokens");
        flashLoanToken.transferFrom(msg.sender, address(this), collateral);

        uint256 flashLoanAmount = collateral * (leverage - 1);

        console.log("flashloan simple");
        POOL.flashLoanSimple(
            address(this),  
            address(flashLoanToken),
            flashLoanAmount,
            abi.encode(msg.sender, isLong, collateral, borrowAmount, address(flashLoanToken)),
            0
        );
    }

    // callback by aave flash loan
    function executeOperation(
        address, /* asset */
        uint256 amount,
        uint256 premium,
        address, /* initiator */
        bytes calldata params
    ) external override returns (bool) {
        (
            address user,
            bool isLong,
            uint256 collateral,
            uint256 borrowAmount,
            address flashLoanToken
        ) = abi.decode(params, (address, bool, uint256, uint256, address));

        console.log("borrow on aave an swap on uni");
        borrowOnAaveAndSwapOnUni(
            user,
            isLong,
            collateral,
            borrowAmount,
            amount,
            premium
        );

        require(IERC20(flashLoanToken).balanceOf(address(this)) > amount + premium, "Contract balances are not sufficient");
        console.log("owns so much token");
        console.log("tries to pay", amount+ premium);
        
        IERC20(flashLoanToken).transfer(address(POOL), amount+ premium);
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

        console.log("supply assets");

        POOL.supply(address(isLong ? base : quote), supplyAmount, user, 0);

        // User might have to give credit allocation to the contract via `approveDelegation()`
        // see: https://docs.aave.com/developers/core-contracts/pool#borrow for reference

        console.log("borrow assets");

        POOL.borrow(address(isLong ? quote : base), borrowAmount, 2, 0, user);

        // Swap the tokens

        // zeroForOne should be
        // if       long  & quote is token0 than swap token0 for token1 => true
        // else if  long  & base  is token0 than swap token1 for token0 => false
        // else if  short & quote is token0 than swap token1 for token0 => false
        // else if  long  & base  is token0 than swap token0 for token1 => true

        console.log("swap with uniswap");

        bool zeroForOne = isLongToken0(isLong);

        uniswap.swap(
            address(this),
            zeroForOne, /* zeroForOne*/
            int256(borrowAmount),
            zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1, /* minRatio */
            abi.encode(isLong, borrowAmount, flashLoanAmount + premium)
        );
    }

    // callback by uniswap
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        console.log("catch callback");

        (bool isLong, uint256 borrowAmount, uint256 targetAmount) = abi.decode(
            data,
            (bool, uint256, uint256)
        );

        bool token0Direction = !isLongToken0(isLong);

        // check return values
        require(amount0Delta != 0 && amount1Delta != 0, "No swap");


        console.log("amount0Delta");
        console.logInt(amount0Delta);
        
        console.log("amount1Delta");
        console.logInt(amount1Delta);

        require(
            token0Direction ? amount1Delta > 0 : amount0Delta > 0,
            "Wrong balance received"
        );

        require(
            token0Direction
                ? uint256(amount1Delta) > targetAmount
                : uint256(amount0Delta) > targetAmount,
            "Not enough received"
        );

        console.log("sacrifice to uni gods");

        // sacrifice to the gods of uniswap so that they will be merciful to us.
        IERC20(isLong ? quote : base).transfer(address(uniswap), borrowAmount);
    }

    function isLongToken0(bool isLong) internal view returns (bool) {
        return isLong ? quoteIsZeroSlot : !quoteIsZeroSlot;
    }
}
