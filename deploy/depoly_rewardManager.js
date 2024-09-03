const { ethers, upgrades } = require("hardhat");
const {getAddress, setAddress} = require('../scripts/saveaddress.js');


module.exports = async ({getNamedAccounts, deployments, network}) => {

    // Define the constructor parameters
    const totallevels = 5; 
    const evolutionTokenAddr = await getAddress("Evolution");

    const rewardManager = await ethers.getContractFactory("RewardManager");
    
    // deploy rewardManager
    const worldId = process.env.WORLDID
    const appId = "app_staging_24d45b0940a55b20d154053fc56ee64f"
    const registerActionId = "registration"
    const upgradeActionId = "upgradation"

    const rewardManagerInst = await rewardManager.deploy(evolutionTokenAddr, totallevels, worldId, appId, registerActionId, upgradeActionId);
    const approverAddress = process.env.REGISTRATION_APPROVER_ADDR;
    await rewardManagerInst.waitForDeployment();
    console.log(`### rewardManager deployed at ${rewardManagerInst.target}`);
    await setAddress("rewardManager", rewardManagerInst.target);


    // Configure reward Manager contract (mul each value with 100)
    // [0.1, 10, 100, 1000, 10000] -> ["10", "1000", "10000", "100000", "1000000"]
    const evolutionRewardPercenatgePerLevel = ["10", "1000", "10000", "100000", "1000000"]
    const levels = ["0", "1", "2", "3"];
    const evolutionCriteriaPerLevel = [["10", "0", "10000"], ["100", "1", "100000"], ["1000", "10", "1000000"], ["10000", "100", "10000000"]]

    // setEvolutionRewardPercentagePerLevel
    await rewardManagerInst.setEvolutionRewardPercentagePerLevel(evolutionRewardPercenatgePerLevel);
    console.log("EvolutionReward set in rewardManager");

    // setminOrbReferralsPerLevelToEvolve
    await rewardManagerInst.setEvolutionCriteria(levels, evolutionCriteriaPerLevel);
    console.log("Evolution Criteria for each level is set in rewardManager");

    //add approver address
    await rewardManagerInst.setApproverAddress(approverAddress);
    console.log(`Approver Address set to : ${await rewardManagerInst.approver()}`)

    // Setting reward manager address in Evolution token.
    const evolutionToken = await ethers.getContractFactory("Evolution");
    const evolutionTokenInst = evolutionToken.attach(evolutionTokenAddr);
    await evolutionTokenInst.setRewardManager(rewardManagerInst.target);
    console.log("Reward Manager address set in evolutionToken")
    return true;
};
module.exports.tags = ["RewardManager"];
module.exports.id = "RewardManager";
module.exports.dependencies = ["Evolution"];
