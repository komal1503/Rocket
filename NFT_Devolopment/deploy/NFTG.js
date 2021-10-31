let {
  networkConfig,
  getNetworkIdFromName,
} = require("../helper-hardhat-config");
const fs = require("fs");

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  log("----------------------------------------------------");
  const NFTG = await deploy("NFTG", {
    from: deployer,
    log: true,
  });

  log(`You have deployed an NFT contract to ${NFTG.address}`);
  const nftGameContract = await ethers.getContractFactory("NFTG");
  const accounts = await hre.ethers.getSigners();
  const signer = accounts[0];
  const nftGame = new ethers.Contract(
    NFTG.address,
    nftGameContract.interface,
    signer
  );
  const networkName = networkConfig[chainId]["name"];

  log(
    `Verify with:\n npx hardhat verify --network ${networkName} ${nftGame.address}`
  );

  log("Let's create an NFT now!");

  let creation_tx = await nftGame.mintNFT();
  let receipt = await creation_tx.wait(1);
  let tokenId = receipt.events[3].topics[2];
  log(`You've made your NFT! This is number ${tokenId}`);
  await new Promise((r) => setTimeout(r, 180000));
  log(`Now let's finish the mint...`);
  tx = await nftGame.finishMint(tokenId, { gasLimit: 2000000 });
  await tx.wait(1);
  log(`You can view the tokenURI here ${await nftGame.tokenURI(1)}`);
};

module.exports.tags = ["all", "nftg"];
