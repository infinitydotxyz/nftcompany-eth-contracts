import { formatEther } from 'ethers/lib/utils'
import { task } from 'hardhat/config'
import { deployContract } from './utils'

task('stringToBytes', '')
  .addParam('string', 'String literal')
  .setAction(async (args, { ethers, run, network }) => {
    // log config
    console.log('Network')
    console.log('  ', network.name)
    console.log('Task Args')
    console.log(args)

    // compile
    await run('compile')
    // get signer
    const signer = (await ethers.getSigners())[0]
    console.log('Signer')
    console.log('  at', signer.address)
    console.log('  ETH', formatEther(await signer.getBalance()))

    const bytes = ethers.utils.formatBytes32String(args.string)
    console.log(bytes)

  })

task('deployNFTCompanyFactory', 'Deploy')
  .addFlag('verify', 'verify contracts on etherscan')
  .setAction(async (args, { ethers, run, network }) => {
    // log config
    console.log('Network')
    console.log('  ', network.name)
    console.log('Task Args')
    console.log(args)

    // compile
    await run('compile')
    // get signer
    const signer = (await ethers.getSigners())[0]
    console.log('Signer')
    console.log('  at', signer.address)
    console.log('  ETH', formatEther(await signer.getBalance()))

    const nftCompanyFactory = await deployContract(
      'NFTCompanyFactory',
      await ethers.getContractFactory('NFTCompanyFactory'),
      signer
    )

    // verify source
    if (args.verify) {
      console.log('Verifying source on etherscan')
      await nftCompanyFactory.deployTransaction.wait(1)
      await run('verify:verify', {
        address: nftCompanyFactory.address,
        contract: "contracts/NFTCompanyFactory.sol:NFTCompanyFactory",
      })
    }
  })