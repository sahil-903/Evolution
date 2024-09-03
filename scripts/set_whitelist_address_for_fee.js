const { ethers, upgrades } = require("hardhat");
const { getAddress } = require('./saveaddress');
const { txOptions } = require("./evolution.config");

// list of address for which whitelist entry should be updated
// e.g. ["0x00..001", "0x00..002"]
const addresses = [];

/*
  new value of whitelist
    true - whitelisted
    false - not whitelisted
  e.g. [true, false]
*/
// lenght of both array has to be same
const values = [];

async function main() {

  const evolutionToken = await ethers.getContractFactory("Evolution");
  const evolutionTokenAddr = await getAddress("Evolution");
  const evolutionTokenInstAddr = await evolutionToken.attach(evolutionTokenAddr);

  const tx = await evolutionTokenInstAddr.setWhitelistAddressForFeeBatch(addresses, values, txOptions);
  await tx.wait();

  console.log(`Tx completed`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });