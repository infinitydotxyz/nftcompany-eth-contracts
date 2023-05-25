import { formatEther } from 'ethers/lib/utils'
import { task } from 'hardhat/config'
import { deployContract } from './utils'

task('deployCompoundNFT', 'Deploy')
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

    const compoundNFT = await deployContract(
      'CompoundNFT',
      await ethers.getContractFactory('CompoundNFT'),
      signer
    )

    // verify source
    if (args.verify) {
      console.log('Verifying source on etherscan')
      await compoundNFT.deployTransaction.wait(1)
      await run('verify:verify', {
        address: compoundNFT.address,
        contract: "contracts/nfts/CompoundNFT.sol:CompoundNFT",
      })
    }
  })