const { ethers, upgrades } = require("hardhat");
const { getAddress } = require("./saveaddress");
// const abi = require('../artifacts/contracts/RewardManager.sol/RewardManager.json');
require("dotenv").config();

const verificationType = 1;

const referrerAddress = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";

const timestamp = 100;


async function main() {

	const rewardManager = await ethers.getContractFactory("RewardManager");
	const rewardManagerAddr = await getAddress("rewardManager");
	const rewardManagerInstAddr = rewardManager.attach(rewardManagerAddr);
  // const provider = new ethers.JsonRpcProvider("http://localhost:8545");
  // const rewardManagerInstAddr = new ethers.Contract(await getAddress("rewardManager"), abi.abi, provider)
	// const wallet = new ethers.Wallet(process.env.APPROVER_KEY, provider);

  // Get the commitment from the contract
  const commitment = await rewardManagerInstAddr.makeUserRegistrationCommitment(
    verificationType,
    referrerAddress,
    timestamp
  );

  // Sign the commitment
  const signature = await wallet.signMessage(ethers.toBeArray(commitment));

  return getVRS(signature);
}

async function getVRS(signature) {
  // Manually split the signature
  const r = signature.slice(0, 66); // First 32 bytes (0x + 64 hex characters)
  const s = "0x" + signature.slice(66, 130); // Next 32 bytes (64 hex characters)
  const v = parseInt("0x" + signature.slice(130, 132), 16); // Last byte (2 hex characters)
  return { v, r, s };
}

main().then(console.log);
