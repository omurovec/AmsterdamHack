// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import env = require("hardhat");

import { ethers } from "hardhat";
import {
  AAVE_POOL_ADDRESS,
  AAVE_POOL_ADDRESSES_PROVIDER,
  EURS_ADDRESS,
  UNI_POOL_ADDRESS,
  USDC_ADDRESS,
} from "./constants";

export async function deployContract() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  console.log("network is", env.network.name);

  // We get the contract to deploy
  const EurMode = await ethers.getContractFactory("EurMode");
  const eurMode = await EurMode.deploy(
    AAVE_POOL_ADDRESS,
    AAVE_POOL_ADDRESSES_PROVIDER,
    EURS_ADDRESS,
    USDC_ADDRESS,
    UNI_POOL_ADDRESS
  );

  /* 
  IPool _pool
  IPoolAddressesProvider _addressesProvider 
  address _base 
  address _quote 
  address _uniPool 
  */

  await eurMode.deployed();

  // await env.tenderly.verify({
  //   name: "EurMode",
  //   address: eurMode.address,
  // });
  // console.log("EURMode deployed to:", eurMode.address);

  // await env.tenderly.persistArtifacts({
  //   name: "EurMode",
  //   address: eurMode.address,
  // });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deployContract().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
