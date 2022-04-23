import { parseEther } from "ethers/lib/utils";
import env, { ethers } from "hardhat";

import {
  UNI_POOL_ADDRESS,
  UNI_QUOTER_ADDRESS,
  USDC_ADDRESS,
  EURS_ADDRESS,
  EURS_HOLDER,
} from "./constants";
import { approveDelegation } from "./utils";

async function main() {
  const eurMode = await ethers.getContractAt(
    "EurMode",
    "0xb56b55b1e36bdf01e016c30b0a62f9ff745155f4"
  );
  const eurs = await ethers.getContractAt("IERC20Metadata", EURS_ADDRESS);
  const quoter = await ethers.getContractAt("IQuoter", UNI_QUOTER_ADDRESS);

  await env.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [EURS_HOLDER],
  });
  await env.network.provider.send("hardhat_setBalance", [
    EURS_HOLDER,
    "0x100000000000000000000000000000",
  ]);

  const eursHolder = await ethers.getSigner(EURS_HOLDER);

  const decimals = await eurs.decimals();

  const collateral = ethers.utils.parseUnits("100", decimals);
  const isLong = true;
  const leverage = 5;

  await approveDelegation(
    USDC_ADDRESS,
    ethers.constants.MaxUint256,
    eurMode.address
  );
  await approveDelegation(
    EURS_ADDRESS,
    ethers.constants.MaxUint256,
    eurMode.address
  );

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

  await eurs.connect(eursHolder).approve(eurMode.address, collateral);

  console.log("TEST");

  await eurMode
    .connect(eursHolder)
    .takeOutFlashLoan(borrowAmount, collateral, leverage, isLong);
}

main();
