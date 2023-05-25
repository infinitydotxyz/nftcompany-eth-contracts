const ethers = hre.ethers;
// run the command below from the terminal to call this script
// npx hardhat run --network localhost scripts/deploy.js
async function main() {

  const NFTCompanyFactory = await ethers.getContractFactory('NFTCompanyFactory.sol')
  const nftCompanyFactoryInstance = await NFTCompanyFactory.deploy()

  console.log('NFT Company Factory deployed to:', nftCompanyFactoryInstance.address)

}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
