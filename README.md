### Download and install dependencies


git clone https://github.com/sahil-903/subscription.git
cd subscription-contracts
nvm use 20.17.0
npm i


### Compile


npx hardhat compile


### Set env variables
Create .evn file at the root of the project and fill below values. Refer to env_sample for reference

DEPLOYER_KEY=
NODE_ID=
NETWORK= polygon | amoy


### Prepare for Deployment

Custom `gas` value can be configured for different network in `hardhat.config.js`

e.g.

amoy: {
      url: `https://polygon-amoy.infura.io/v3/${process.env.NODE_ID}`,
      tags: ["test"],
      gas: 6_000_000,
      gasPrice: 35_000_000_000,
      timeout: 1200000,
      chainId: 80002,
      accounts: real_accounts,
    },




Visite below script to deploy contract.

deploy/deploy_subscriptionManager.js





Remove entries of deployment script from below file which you want to either deploy 


deployments/amoy/.migrations.json




To do fresh deployment, content of this file should look like this


{

}


### Deploy


# deploy on testnet
npx hardhat deploy --network amoy

# deploy on mainnet
npx hardhat deploy --network polygon
