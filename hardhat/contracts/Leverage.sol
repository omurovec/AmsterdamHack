pragma solidity ^0.8.10;

import "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol";

contract Leverage is IFlashLoanSimpleReceiver {
    enum Direction {
        Long,
        Short
    }

    IPool public immutable override POOL;
    IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
    IUniswapV3PoolActions public immutable override UNI_POOL;
    IAaveOracle public immutable AAVE_ORACLE;
    IERC20 public immutable BASE;
    IERC20 public immutable QUOTE;

    uint8 public immutable BASE_DECIMALS;
    uint8 public immutable QUOTE_DECIMALS;
    uint8 internal constant immutable ORACLE_DECIMALS = 8;

    bool internal immutable baseIsZeroSlot;

    uint256 internal constant WAD = 1e18;

    constructor(
        IPool _pool,
        IPoolAddressesProvider _addressesProvider,
        address _base,
        address _quote,
        IAaveOracle _aave_oracle,
        address _uniPool
    ) {
        POOL = _pool;
        ADDRESSES_PROVIDER = _addressesProvider;
        UNI_POOL = IUniswapV3PoolActions(_uniPool);
        BASE = IERC20(_base);
        QUOTE = IERC20(_quote);
        AAVE_ORACLE = _aave_oracle;

        BASE_DECIMALS = IERC20Metadata(_base).decimals();
        QUOTE_DECIMALS = IERC20Metadata(_quote).decimals();
        baseIsZeroSlot = IUniswapV3PoolImmutables(_uniPool).token0() == _base;

        IERC20(_base).approve(address(_pool), type(uint256).max);
        IERC20(_quote).approve(address(_pool), type(uint256).max);
        IERC20(_base).approve(address(_uniPool), type(uint256).max);
        IERC20(_quote).approve(address(_uniPool), type(uint256).max);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        (bool isLong, uint256 collateral) = abi.decode(params, (bool, uint256));
        setupPosition(isLong, collateral, amount);
    }

    function openPosition(
        bool isLong,
        uint256 collateral,
        uint8 leverage
    ) external returns (bool) {
        IERC20 flashLoanToken = isLong ? BASE : QUOTE;
        flashLoanToken.transferFrom(msg.sender, address(this), collateral);

        uint256 flashLoanAmount = collateral * leverage - collateral;

        POOL.flashLoanSimple(
            address(this),
            address(flashLoanToken),
            flashLoanAmount,
            abi.encode(isLong, collateral),
            0
        );
    }

    function setupPosition(
        bool isLong,
        uint256 collateral,
        uint256 loanAmount
    ) internal returns (bool) {
        address supplyToken = address(isLong ? BASE : QUOTE);
        address borrowToken = address(isLong ? QUOTE : BASE);

        // Total amount borrowed in flash loan
        // 400
        uint256 loanAmountWei = isLong
            ? _toWad(loanAmount, BASE_DECIMALS)
            : _toWad(loanAmount, QUOTE_DECIMALS);

        // 500
        uint256 supplyAmount = collateral + loanAmount;

        POOL.supply(supplyToken, supplyAmount, msg.sender, 0);

        uint256 basePrice = _getBasePrice();

        uint256 borrowAmount = isLong
            ? (loanAmountWei * basePrice) / WAD
            : (loanAmountWei * WAD) / basePrice;

        // User might have to give credit allocation to the contract
        POOL.borrow(borrowToken, borrowAmount, 2, 0, msg.sender);
    }

    function _getBasePrice() internal returns (uint256) {
        return
            _toWad(AAVE_ORACLE.getAssetPrice(address(BASE)), ORACLE_DECIMALS);
    }

    function _toWad(uint256 amount, uint8 decimals) internal returns (uint256) {
        return amount * 10**(18 - decimals);
    }
}
