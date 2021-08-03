import { formatEther } from 'ethers/lib/utils'
import { task } from 'hardhat/config'
import { deployContract } from './utils'

task('deployERC20Vault', 'Deploy')
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

    // deploy contracts
    const ERC20Vault = await deployContract(
      'ERC20Vault',
      await ethers.getContractFactory('ERC20Vault'),
      signer
    )

    // verify source
    if (args.verify) {
      console.log('Verifying source on etherscan')
      await ERC20Vault.deployTransaction.wait(5)
      await run('verify:verify', {
        address: ERC20Vault.address,
        contract: "contracts/ERC20Vault.sol:ERC20Vault",
      })
    }
  })