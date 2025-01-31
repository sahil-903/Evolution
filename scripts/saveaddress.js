const fs = require('fs');
const path = require('path');
require('dotenv').config({silent: true});
var prompt = require('prompt-sync')();

let filePath = null;
switch (process.env.NETWORK) {
    case "polygon":
        filePath = '../deployments/polygon/address.json';
        break;
    case "amoy":
        filePath = '../deployments/amoy/address.json';
        break;
    case "hardhat":
        filePath = '../deployments/hardhat/address.json';
        break;
    case "localhost":
        filePath = '../deployments/localhost/address.json';
        break;
    default:
        break;
}

var choise = prompt(`Using ${filePath} .  Continue? (y/n): `);

if(choise != "y") throw new Error("Aborted!");

const jsonFile = require(filePath);

module.exports.setAddress = async (key, value) => {
    jsonFile[key] = value;
    fs.writeFileSync(
        path.resolve(__dirname, filePath),
        JSON.stringify(jsonFile, null, 2) + '\n');
}

module.exports.getAddress = async (key) => {
    // const jsonFile = require(path);
    return jsonFile[key];
}