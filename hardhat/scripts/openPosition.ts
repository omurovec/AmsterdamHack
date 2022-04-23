import { ethers } from "hardhat";
import { IQuoter } from "@uniswap/v3-periphery/contracts/interfaces";

import {
  AAVE_POOL_ADDRESS,
  UNI_POOL_ADDRESS,
  UNI_QUOTER_ADDRESS,
  AAVE_POOL_ADDRESSES_PROVIDER,
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
  const leverage = "5";

  const borrowAmount = await quoter.q;

  await eurs.approve(eurMode.address, collateral);

  await eurMode.takeOutFlashLoan(borrowAmount, collateral, leverage, isLong);
}

main();
