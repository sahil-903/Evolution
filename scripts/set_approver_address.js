const { ethers, upgrades } = require("hardhat");
const { getAddress } = require("./saveaddress");
const { txOptions } = require("./evolution.config");

const approverAddress = process.env.REGISTRATION_APPROVER_ADDR;

async function main() {
  const rewardVault = await ethers.getContractFactory("RewardVault");
  const rewardManagerAddr = await getAddress("rewardVault");
  const rewardManagerInst = await rewardVault.attach(rewardManagerAddr);

  const tx = await rewardManagerInst.setApproverAddress(approverAddress);
  await tx.wait();

  console.log(
    `Approver Address set to : ${await rewardManagerInst.approver()}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
