import { expect } from "chai";
import { ethers } from "hardhat";

import { deployContract } from "../scripts/deploy";
import { openPosition } from "../scripts/openPosition";
import { checkPosition } from "../scripts/checkPosition";

describe("Contract", function () {
  it("Should work", async function () {
    await deployContract();
    await openPosition();
    await checkPosition();
  });
});
