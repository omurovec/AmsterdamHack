import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { AAVE_POOL_ADDRESS, USDC_ADDRESS } from "./constants";

import { ICreditDelegationToken } from "../typechain";

export async function approveDelegation(
  token: string,
  amount: BigNumber,
  target: string
) {
  // get debt token address
  const pool = await ethers.getContractAt("IPool", AAVE_POOL_ADDRESS);

  const reserveData = await pool.getReserveData(token);

  const variableDebtTokenAddress = reserveData.variableDebtTokenAddress;

  // approve delegation
  const variableDebtToken = <ICreditDelegationToken>(
    await ethers.getContractAt(
      "ICreditDelegationToken",
      variableDebtTokenAddress
    )
  );

  await variableDebtToken.approveDelegation(target, amount);
}
