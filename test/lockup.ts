contract('TokenValueTest', ([property, sender1, sender2, sender3]) => {
	const TokenValueContract = artifacts.require('TokenValue')
	describe('TokenValue; set and get', () => {
		it('Set the amount that locking-up tokens', async () => {
			const tokenValue = await TokenValueContract.new()
			await tokenValue.set(property, sender1, 10)
			const result = await tokenValue.get(property, sender1)
			expect(result.toNumber()).to.be.equal(10)
		})
		it('Add tokens amount to already added amount', async () => {
			const tokenValue = await TokenValueContract.new()
			await tokenValue.set(property, sender1, 10)
			const first = await tokenValue.get(property, sender1)
			expect(first.toNumber()).to.be.equal(10)
			await tokenValue.set(property, sender1, 90)
			const second = await tokenValue.get(property, sender1)
			expect(second.toNumber()).to.be.equal(100)
		})
		it('Returns 0 when not locked-up', async () => {
			const tokenValue = await TokenValueContract.new()
			const result = await tokenValue.get(property, sender1)
			expect(result.toNumber()).to.be.equal(0)
		})
	})
	describe('TokenValue; getByProperty', () => {
		it('Get the amount of total locked-up tokens to the Property', async () => {
			const tokenValue = await TokenValueContract.new()
			await tokenValue.set(property, sender1, 7356)
			await tokenValue.set(property, sender2, 6457)
			await tokenValue.set(property, sender3, 7568)
			const result = await tokenValue.getByProperty(property)
			expect(result.toNumber()).to.be.equal(7356 + 6457 + 7568)
		})
	})
	describe('TokenValue; hasTokenByProperty', () => {
		it('Check if an account is locking-up to a Property', async () => {
			const tokenValue = await TokenValueContract.new()
			await tokenValue.set(property, sender1, 10)
			let result = await tokenValue.hasTokenByProperty(property, sender1)
			expect(result).to.be.equal(true)
			result = await tokenValue.hasTokenByProperty(property, sender2)
			expect(result).to.be.equal(false)
		})
	})
})

contract('CanceledLockupFlgTest', ([property, sender1, sender2]) => {
	const CanceledLockUpFlgContract = artifacts.require('CanceledLockupFlg')
	describe('CanceledLockupFlg; isCanceled', () => {
		it('Check if an account canceled lock-up to a Property', async () => {
			const canceled = await CanceledLockUpFlgContract.new()
			await canceled.setCancelFlg(property, sender1, true)
			let result = await canceled.isCanceled(property, sender1)
			expect(result).to.be.equal(true)
			result = await canceled.isCanceled(property, sender2)
			expect(result).to.be.equal(false)
		})
	})
})

contract('ReleasedBlockNumberTest', ([property, sender1, sender2]) => {
	const ReleasedBlockNumberContract = artifacts.require('ReleasedBlockNumber')
	describe('ReleasedBlockNumber; setBlockNumber', () => {
		let canceled: any
		beforeEach(async () => {
			canceled = await ReleasedBlockNumberContract.new()
			await canceled.setBlockNumber(property, sender1, 10)
		})
		it('Check if a block has passed a withdrawable block number', async () => {
			let result = await canceled.canRlease(property, sender1)
			expect(result).to.be.equal(false)
			for (let i = 0; i < 20; i++) {
				// eslint-disable-next-line no-await-in-loop
				await new Promise(function(resolve) {
					// eslint-disable-next-line no-undef
					web3.currentProvider.send(
						{
							jsonrpc: '2.0',
							method: 'evm_mine',
							params: [],
							id: 0
						},
						resolve
					)
				})
			}

			result = await canceled.canRlease(property, sender1)
			expect(result).to.be.equal(true)
		})
		it('Returns false when not canceled', async () => {
			const result = await canceled.canRlease(property, sender2)
			expect(result).to.be.equal(false)
		})
	})
	describe('ReleasedBlockNumber; clear', () => {
		it('Reset block number of withdrawable', async () => {
			const canceled = await ReleasedBlockNumberContract.new()
			await canceled.setBlockNumber(property, sender1, 10)
			let result = await canceled.canRlease(property, sender1)
			expect(result).to.be.equal(false)
			for (let i = 0; i < 20; i++) {
				// eslint-disable-next-line no-await-in-loop
				await new Promise(function(resolve) {
					// eslint-disable-next-line no-undef
					web3.currentProvider.send(
						{
							jsonrpc: '2.0',
							method: 'evm_mine',
							params: [],
							id: 0
						},
						resolve
					)
				})
			}

			result = await canceled.canRlease(property, sender1)
			expect(result).to.be.equal(true)
			await canceled.clear(property, sender1)
			result = await canceled.canRlease(property, sender1)
			expect(result).to.be.equal(false)
		})
	})
})

contract('LockupTest', ([deployer, property, sender1]) => {
	const lockupContract = artifacts.require('Lockup')
	const addressConfigContract = artifacts.require('common/config/AddressConfig')
	const propertyGroupContract = artifacts.require('property/PropertyGroup')

	describe('Lockup; getTokenValue', () => {
		it('Returns 0 when not locked-up accunt', async () => {
			const addressConfig = await addressConfigContract.new({from: deployer})
			const lockup = await lockupContract.new(addressConfig.address)
			const result = await lockup.getTokenValue(property, sender1)
			expect(result.toNumber()).to.be.equal(0)
		})
	})
	describe('Lockup; cancel', () => {
		it('Returns an error when runs cancel to address that not Property as a target', async () => {
			const addressConfig = await addressConfigContract.new({from: deployer})
			const propertyGroup = await propertyGroupContract.new(
				addressConfig.address,
				{from: deployer}
			)
			await addressConfig.setPropertyGroup(propertyGroup.address)
			const lockup = await lockupContract.new(addressConfig.address)
			const result = await lockup
				.cancel('0x2d6ab242bc13445954ac46e4eaa7bfa6c7aca167')
				.catch((err: Error) => err)
			expect((result as Error).message).to.be.equal(
				'Returned error: VM Exception while processing transaction: revert this address is not property contract -- Reason given: this address is not property contract.'
			)
		})
	})
	describe('Lockup; lockup', () => {
		it('address is not property contract', async () => {})
		it('lockup is already canceled', async () => {})
		it('insufficient balance', async () => {})
		it('transfer was failed', async () => {})
		it('success', async () => {})
	})
	describe('Lockup; withdraw', () => {
		it('address is not property contract', async () => {})
		it('lockup is not canceled', async () => {})
		it('waiting for release', async () => {})
		it('dev token is not locked', async () => {})
		it('success', async () => {})
	})
})
