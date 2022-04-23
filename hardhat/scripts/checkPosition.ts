import { ethers } from "hardhat";
import {
  AAVE_POOL_ADDRESS,
  EURS_ADDRESS,
  EURS_HOLDER,
  USDC_ADDRESS,
} from "./constants";

export async function checkPosition() {
  const pool = await ethers.getContractAt("IPool", AAVE_POOL_ADDRESS);
  const usdcReserveData = await pool.getReserveData(USDC_ADDRESS);

  const eursReserveData = await pool.getReserveData(EURS_ADDRESS);

  const eursATokenAddress = eursReserveData.aTokenAddress;
  const usdcATokenAddress = eursReserveData.aTokenAddress;

  const usdcVariableDebtTokenAddress = usdcReserveData.variableDebtTokenAddress;
  const usdcDebtToken = await ethers.getContractAt(
    "IERC20",
    usdcVariableDebtTokenAddress
  );

  const usdcAToken = await ethers.getContractAt("IERC20", usdcATokenAddress);
  const eursAToken = await ethers.getContractAt("IERC20", eursATokenAddress);

  const eursVariableDebtTokenAddress = eursReserveData.variableDebtTokenAddress;
  const eursDebtToken = await ethers.getContractAt(
    "IERC20",
    eursVariableDebtTokenAddress
  );

  const usdcDebtBalance = await usdcDebtToken.balanceOf(EURS_HOLDER);
  const eursDebtBalance = await eursDebtToken.balanceOf(EURS_HOLDER);
  const eursATokenBalance = await eursAToken.balanceOf(EURS_HOLDER);
  const usdcATokenBalance = await usdcAToken.balanceOf(EURS_HOLDER);

  console.log({
    usdcDebtBalance,
    eursDebtBalance,
    usdcATokenBalance,
    eursATokenBalance,
  });
}

checkPosition().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
