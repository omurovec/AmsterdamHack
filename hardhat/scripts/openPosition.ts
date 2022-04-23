import { ethers } from "hardhat";

import {
  UNI_POOL_ADDRESS,
  UNI_QUOTER_ADDRESS,
  USDC_ADDRESS,
  EURS_ADDRESS,
} from "./constants";

async function main() {
  const eurMode = await ethers.getContractAt("EurMode", "0x");
  const eurs = await ethers.getContractAt("IERC20Metadata", EURS_ADDRESS);
  const quoter = await ethers.getContractAt("IQuoter", UNI_QUOTER_ADDRESS);

  const decimals = await eurs.decimals();

  const collateral = ethers.utils.parseUnits("100", decimals);
  const isLong = true;
  const leverage = 5;

  const uniPool = await ethers.getContractAt(
    "IUniswapV3PoolImmutables",
    UNI_POOL_ADDRESS
  );

  const fees = await uniPool.fee();
  const token0 = await uniPool.token0();
  const token1 = await uniPool.token1();
  console.log({
    USDC_ADDRESS,
    token0,
    EURS_ADDRESS,
    token1,
    fees,
    collateral: collateral.mul(leverage - 1),
  });

  const borrowAmount = await quoter.callStatic.quoteExactOutputSingle(
    USDC_ADDRESS,
    EURS_ADDRESS,
    fees,
    collateral.mul(leverage - 1),
    0
  );

  await eurs.approve(eurMode.address, collateral);

  await eurMode.takeOutFlashLoan(borrowAmount, collateral, leverage, isLong);
}

main();
