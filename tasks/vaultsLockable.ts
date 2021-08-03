import { expect } from 'chai'
import { Wallet } from 'ethers'
import { formatEther, parseUnits, randomBytes } from 'ethers/lib/utils'
import { task } from 'hardhat/config'
import { signPermission, signPermissionERC721 } from './utils'

require('dotenv').config()

const localPrivKey = process.env.ETH_HARDHAT_LOCAL_PRIV_KEY || ''

task('lockERC20Tokens', 'Lock tokens in a given vault')
  .addParam('vault', 'Vault address')
  .addParam('token', 'Address of the token to lock')
  .addParam('amount', 'Amount of tokens to lock with decimals')
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
    const signerWallet = new Wallet(localPrivKey)
    expect(signer.address).to.be.eq(signerWallet.address)

    // fetch contract
    const vault = await ethers.getContractAt('ERC20VaultLockable', args.vault, signer)
    const nonce = await vault.getNonce()
    // declare config
    const token = await ethers.getContractAt('MockERC20', args.token, signer)
    const amount = parseUnits(args.amount, await token.decimals())
    // validate balances
    expect(await token.balanceOf(signer.address)).to.be.gte(amount)

    // craft permission
    console.log('Locking tokens to vault')
    const permission = await signPermission(
      'Lock',
      vault,
      signerWallet,
      signerWallet.address,
      token.address,
      amount,
      nonce
    )
    
    console.log('Locking ' + amount + ' ' + token.address + ' with permission: ' + permission)
    const tx = await vault.lock(token.address, amount, permission)
    console.log('  in', tx.hash)
  })

  task('unlockERC20Tokens', 'Unlock tokens from a given vault')
  .addParam('vault', 'Vault address')
  .addParam('token', 'Address of the token to unlock')
  .addParam('amount', 'Amount of tokens to unlock with decimals')
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
    const signerWallet = new Wallet(localPrivKey)
    expect(signer.address).to.be.eq(signerWallet.address)

    // fetch contract
    const vault = await ethers.getContractAt('ERC20VaultLockable', args.vault, signer)
    const nonce = await vault.getNonce()

    // declare config
    const token = await ethers.getContractAt('MockERC20', args.token, signer)
    const amount = parseUnits(args.amount, await token.decimals())

    // craft permission
    console.log('Unlocking tokens from vault')
    const permission = await signPermission(
      'Unlock',
      vault,
      signerWallet,
      signerWallet.address,
      token.address,
      amount,
      nonce
    )
    
    console.log('Unlocking ' + amount + ' ' + token.address + ' with permission: ' + permission)
    const tx = await vault.unlock(token.address, amount, permission)
    console.log('  in', tx.hash)
  })

  task('lockERC721', 'Lock tokens in a given vault')
  .addParam('vault', 'Vault address')
  .addParam('token', 'Address of the token to lock')
  .addParam('tokenid', '')
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
    const signerWallet = new Wallet(localPrivKey)
    expect(signer.address).to.be.eq(signerWallet.address)

    // fetch contract
    const vault = await ethers.getContractAt('ERC721VaultLockable', args.vault, signer)
    const nonce = await vault.getNonce()

    // craft permission
    console.log('Locking token to vault')
    const permission = await signPermissionERC721(
      'LockERC721',
      vault,
      signerWallet,
      signerWallet.address,
      args.token,
      args.tokenid,
      nonce
    )
    
    console.log('Locking ' + args.tokenid + ' with permission: ' + permission)
    const tx = await vault.lockERC721(args.token, args.tokenid, permission)
    console.log('  in', tx.hash)
  })

  task('unlockERC721', 'Unlock tokens in a given vault')
  .addParam('vault', 'Vault address')
  .addParam('token', 'Address of the token to lock')
  .addParam('tokenid', '')
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
    const signerWallet = new Wallet(localPrivKey)
    expect(signer.address).to.be.eq(signerWallet.address)

    // fetch contract
    const vault = await ethers.getContractAt('ERC721VaultLockable', args.vault, signer)
    const nonce = await vault.getNonce()

    // craft permission
    console.log('Unlocking tokens from vault')
    const permission = await signPermissionERC721(
      'UnlockERC721',
      vault,
      signerWallet,
      signerWallet.address,
      args.token,
      args.tokenid,
      nonce
    )
    
    console.log('Unlocking ' + args.tokenid + ' with permission: ' + permission)
    const tx = await vault.unlockERC721(args.token, args.tokenid, permission)
    console.log('  in', tx.hash)
  })


task('rageQuit', 'Ragequits by unlocking delegated tokens from a given vault')
  .addParam('vault', 'Vault address')
  .addParam('delegate', 'Address of the delegator who locked the tokens')
  .addParam('token', 'Address of the token to unlock')
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
    const signerWallet = new Wallet(localPrivKey)
    expect(signer.address).to.be.eq(signerWallet.address)

    // fetch contract
    const vault = await ethers.getContractAt('ERC20VaultLockable', args.vault, signer)
    
    console.log('Ragequitting from vault ' + vault.address + ' for the token ' + args.token + ' delegated by ' + args.delegate)
    const tx = await vault.rageQuit(args.delegate, args.token)
    console.log('  in', tx.hash)
  })