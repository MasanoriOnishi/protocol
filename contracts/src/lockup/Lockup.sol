pragma solidity 0.5.17;

// prettier-ignore
import {ERC20Mintable} from "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Decimals} from "contracts/src/common/libs/Decimals.sol";
import {UsingConfig} from "contracts/src/common/config/UsingConfig.sol";
import {LockupStorage} from "contracts/src/lockup/LockupStorage.sol";
import {IProperty} from "contracts/interface/IProperty.sol";
import {IPolicy} from "contracts/interface/IPolicy.sol";
import {IAllocator} from "contracts/interface/IAllocator.sol";
import {ILockup} from "contracts/interface/ILockup.sol";
import {IMetricsGroup} from "contracts/interface/IMetricsGroup.sol";

/**
 * A contract that manages the staking of DEV tokens and calculates rewards.
 * Staking and the following mechanism determines that reward calculation.
 *
 * Variables:
 * -`M`: Maximum mint amount per block determined by Allocator contract
 * -`B`: Number of blocks during staking
 * -`P`: Total number of staking locked up in a Property contract
 * -`S`: Total number of staking locked up in all Property contracts
 * -`U`: Number of staking per account locked up in a Property contract
 *
 * Formula:
 * Staking Rewards = M * B * (P / S) * (U / P)
 *
 * Note:
 * -`M`, `P` and `S` vary from block to block, and the variation cannot be predicted.
 * -`B` is added every time the Ethereum block is created.
 * - Only `U` and `B` are predictable variables.
 * - As `M`, `P` and `S` cannot be observed from a staker, the "cumulative sum" is often used to calculate ratio variation with history.
 * - Reward withdrawal always withdraws the total withdrawable amount.
 *
 * Scenario:
 * - Assume `M` is fixed at 500
 * - Alice stakes 100 DEV on Property-A (Alice's staking state on Property-A: `M`=500, `B`=0, `P`=100, `S`=100, `U`=100)
 * - After 10 blocks, Bob stakes 60 DEV on Property-B (Alice's staking state on Property-A: `M`=500, `B`=10, `P`=100, `S`=160, `U`=100)
 * - After 10 blocks, Carol stakes 40 DEV on Property-A (Alice's staking state on Property-A: `M`=500, `B`=20, `P`=140, `S`=200, `U`=100)
 * - After 10 blocks, Alice withdraws Property-A staking reward. The reward at this time is 5000 DEV (10 blocks * 500 DEV) + 3125 DEV (10 blocks * 62.5% * 500 DEV) + 2500 DEV (10 blocks * 50% * 500 DEV).
 */
contract Lockup is ILockup, UsingConfig, LockupStorage {
	using SafeMath for uint256;
	using Decimals for uint256;
	struct RewardPrices {
		uint256 reward;
		uint256 holders;
		uint256 interest;
		uint256 gMReward;
		uint256 gMHolders;
	}
	struct Rewards {
		uint256 nextReward;
		uint256 rewardAmount;
		uint256 nextGMReward;
		uint256 gMRewardAmount;
	}
	event Lockedup(address _from, address _property, uint256 _value);

	/**
	 * Initialize the passed address as AddressConfig address.
	 */
	constructor(address _config) public UsingConfig(_config) {}

	/**
	 * Adds staking.
	 * Only the Dev contract can execute this function.
	 */
	function lockup(
		address _from,
		address _property,
		uint256 _value
	) external {
		/**
		 * Validates the sender is Dev contract.
		 */
		require(msg.sender == config().token(), "this is illegal address");

		/**
		 * Validates _value is not 0.
		 */
		require(_value != 0, "illegal lockup value");

		/**
		 * Validates the passed Property has greater than 1 asset.
		 */
		require(
			IMetricsGroup(config().metricsGroup()).hasAssets(_property),
			"unable to stake to unauthenticated property"
		);

		/**
		 * Since the reward per block that can be withdrawn will change with the addition of staking,
		 * saves the undrawn withdrawable reward before addition it.
		 */
		RewardPrices memory prices =
			updatePendingInterestWithdrawal(_property, _from);

		/**
		 * Saves variables that should change due to the addition of staking.
		 */
		updateValues(true, _from, _property, _value, prices);

		/**
		 * Saves disabled lockedups value
		 */
		addDisabledLockedups(_from, _property, _value);

		emit Lockedup(_from, _property, _value);
	}

	/**
	 * Disable staking if property token is held.
	 */
	function addDisabledLockedups(
		address _from,
		address _property,
		uint256 _amount
	) private {
		IERC20 property = IERC20(_property);
		uint256 balance = property.balanceOf(_from);
		if (balance == 0) {
			return;
		}
		uint256 tmp = getStorageDisabledLockedups(_property);
		setStorageDisabledLockedups(_property, tmp.add(_amount));
	}

	/**
	 * Withdraw staking.
	 * Releases staking, withdraw rewards, and transfer the staked and withdraw rewards amount to the sender.
	 */
	function withdraw(address _property, uint256 _amount) external {
		/**
		 * Validates the sender is staking to the target Property.
		 */
		require(
			hasValue(_property, msg.sender, _amount),
			"insufficient tokens staked"
		);

		/**
		 * Withdraws the staking reward
		 */
		RewardPrices memory prices = _withdrawInterest(_property);

		/**
		 * Transfer the staked amount to the sender.
		 */
		if (_amount != 0) {
			IProperty(_property).withdraw(msg.sender, _amount);
		}

		/**
		 * Saves disabled lockedups value
		 */
		subDisabledLockedups(_property, _amount);

		/**
		 * Saves variables that should change due to the canceling staking..
		 */
		updateValues(false, msg.sender, _property, _amount, prices);
	}

	/**
	 * Remove disabled staking.
	 */
	function subDisabledLockedups(address _property, uint256 _amount) private {
		uint256 disabledLockedups = getStorageDisabledLockedups(_property);
		if (disabledLockedups < _amount) {
			return;
		}
		uint256 stakingAmount = getStoragePropertyValue(_property);
		uint256 tmp =
			disabledLockedups.sub(_amount) <= stakingAmount.sub(_amount)
				? disabledLockedups
				: disabledLockedups - _amount;
		if (disabledLockedups == tmp) {
			return;
		}
		setStorageDisabledLockedups(_property, tmp);
	}

	/**
	 * get geometric average
	 */
	function geometricMeanLockedUp() external view returns (uint256) {
		return getStorageGeometricMeanLockedUp();
	}

	/**
	 * set geometric average
	 */
	function setGeometricMean(uint256 _geometricMean) external {
		address setter = IPolicy(config().policy()).geometricMeanSetter();
		require(setter == msg.sender, "illegal access");
		setStorageGeometricMeanLockedUp(_geometricMean);
	}

	/**
	 * Store staking states as a snapshot.
	 */
	function beforeStakesChanged(
		address _property,
		address _user,
		RewardPrices memory _prices
	) private {
		/**
		 * Gets latest cumulative holders reward for the passed Property.
		 */
		(uint256 cHoldersReward, uint256 cHoldersGMReward) =
			_calculateCumulativeHoldersRewardAmount(
				_prices.holders,
				_prices.gMHolders,
				_property
			);

		/**
		 * Store each value.
		 */
		setStorageLastStakedInterestPrice(_property, _user, _prices.interest);
		setStorageLastStakesChangedCumulativeReward(_prices.reward);
		setStorageLastStakesChangedCumulativeGMReward(_prices.gMReward);
		setStorageLastCumulativeHoldersRewardPrice(_prices.holders);
		setStorageLastCumulativeHoldersGMRewardPrice(_prices.gMHolders);
		setStorageLastCumulativeInterestPrice(_prices.interest);
		setStorageLastCumulativeHoldersRewardAmountPerProperty(
			_property,
			cHoldersReward
		);
		setStorageLastCumulativeHoldersRewardPricePerProperty(
			_property,
			_prices.holders
		);
		setStorageLastCumulativeHoldersGMRewardAmountPerProperty(
			_property,
			cHoldersGMReward
		);
		setStorageLastCumulativeHoldersGMRewardPricePerProperty(
			_property,
			_prices.gMHolders
		);
	}

	/**
	 * Gets latest value of cumulative sum of the reward amount, cumulative sum of the holders reward per stake, and cumulative sum of the stakers reward per stake.
	 */
	function calculateCumulativeRewardPrices(Rewards memory _rewards)
		private
		view
		returns (
			uint256 _reward,
			uint256 _holders,
			uint256 _interest
		)
	{
		uint256 lastReward = getStorageLastStakesChangedCumulativeReward();
		uint256 lastHoldersPrice = getStorageLastCumulativeHoldersRewardPrice();
		uint256 lastInterestPrice = getStorageLastCumulativeInterestPrice();
		uint256 allStakes = getStorageAllValue();

		/**
		 * Gets latest cumulative sum of the reward amount.
		 */
		uint256 mReward = _rewards.nextReward.mulBasis();

		/**
		 * Calculates reward unit price per staking.
		 * Later, the last cumulative sum of the reward amount is subtracted because to add the last recorded holder/staking reward.
		 */
		uint256 price =
			allStakes > 0 ? mReward.sub(lastReward).div(allStakes) : 0;

		/**
		 * Calculates the holders reward out of the total reward amount.
		 */
		uint256 holdersShare =
			IPolicy(config().policy()).holdersShare(price, allStakes);

		/**
		 * Calculates and returns each reward.
		 */
		uint256 holdersPrice = holdersShare.add(lastHoldersPrice);
		uint256 interestPrice = price.sub(holdersShare).add(lastInterestPrice);
		return (mReward, holdersPrice, interestPrice);
	}

	/**
	 * Gets latest value of cumulative sum of the reward amount for geometric mean, cumulative sum of the holders reward per stake, and cumulative sum of the stakers reward per stake.
	 */
	function calculateCumulativeGMRewardPrices(Rewards memory _rewards)
		private
		view
		returns (uint256 _gMReward, uint256 _gMHolders)
	{
		uint256 lastGMReward = getStorageLastStakesChangedCumulativeGMReward();
		uint256 lastHoldersGMPrice =
			getStorageLastCumulativeHoldersGMRewardPrice();
		uint256 allStakes = getStorageAllValue();

		/**
		 * Gets latest cumulative sum of the reward amount.
		 */
		uint256 mGMReward = _rewards.nextGMReward.mulBasis();

		/**
		 * Calculates reward unit price per staking.
		 * Later, the last cumulative sum of the reward amount is subtracted because to add the last recorded holder/staking reward.
		 */
		uint256 gMPrice =
			allStakes > 0 ? mGMReward.sub(lastGMReward).div(allStakes) : 0;

		/**
		 * Calculates the holders reward out of the total reward amount.
		 */
		uint256 gMHoldersShare =
			IPolicy(config().policy()).holdersShare(gMPrice, allStakes);

		/**
		 * Calculates and returns each reward.
		 */
		uint256 geometricMeanHoldersPrice =
			gMHoldersShare.add(lastHoldersGMPrice);
		return (mGMReward, geometricMeanHoldersPrice);
	}

	/**
	 * Calculates cumulative sum of the holders reward per Property.
	 * To save computing resources, it receives the latest holder rewards from a caller.
	 */
	function _calculateCumulativeHoldersRewardAmount(
		uint256 _reward,
		uint256 _geometric,
		address _property
	) private view returns (uint256, uint256) {
		(uint256 cHoldersReward, uint256 lastRewardPrice) =
			(
				getStorageLastCumulativeHoldersRewardAmountPerProperty(
					_property
				),
				getStorageLastCumulativeHoldersRewardPricePerProperty(_property)
			);
		(uint256 cHoldersGMReward, uint256 lastGMRewardPrice) =
			(
				getStorageLastCumulativeHoldersGMRewardAmountPerProperty(
					_property
				),
				getStorageLastCumulativeHoldersGMRewardPricePerProperty(
					_property
				)
			);

		/**
		 * culculate enabled staking value
		 */
		uint256 stakingValue = getStoragePropertyValue(_property);
		uint256 enabledStakingValue =
			stakingValue.sub(getStorageDisabledLockedups(_property));

		/**
		 * `_reward` contains the calculation of `lastRewardPrice`, so subtract it here.
		 */
		uint256 additionalHoldersReward =
			_reward.sub(lastRewardPrice).mul(enabledStakingValue);

		/**
		 * `_geometric` contains the calculation of `lastGMRewardPrice`, so subtract it here.
		 */
		uint256 additionalGMHoldersReward =
			_geometric.sub(lastGMRewardPrice).mul(enabledStakingValue);

		/**
		 * Calculates and returns the cumulative sum of the holder reward by adds the last recorded holder reward and the latest holder reward.
		 */
		return (
			cHoldersReward.add(additionalHoldersReward),
			cHoldersGMReward.add(additionalGMHoldersReward)
		);
	}

	/**
	 * Calculates cumulative sum of the holders reward per Property.
	 * caution!!!this function is deprecated!!!
	 * use calculateRewardAmount
	 */
	function calculateCumulativeHoldersRewardAmount(address _property)
		external
		view
		returns (uint256)
	{
		Rewards memory rewards = dry();
		(, uint256 holders, ) = calculateCumulativeRewardPrices(rewards);
		(, uint256 gMHolders) = calculateCumulativeGMRewardPrices(rewards);
		(uint256 reward, ) =
			_calculateCumulativeHoldersRewardAmount(
				holders,
				gMHolders,
				_property
			);
		return reward;
	}

	/**
	 * Calculates holders reward and geometric mean per Property.
	 */
	function calculateRewardAmount(address _property)
		external
		view
		returns (uint256, uint256)
	{
		Rewards memory rewards = dry();
		(, uint256 holders, ) = calculateCumulativeRewardPrices(rewards);
		(, uint256 gMHolders) = calculateCumulativeGMRewardPrices(rewards);
		return
			_calculateCumulativeHoldersRewardAmount(
				holders,
				gMHolders,
				_property
			);
	}

	/**
	 * Updates cumulative sum of the maximum mint amount calculated by Allocator contract, the latest maximum mint amount per block,
	 * and the last recorded block number.
	 * The cumulative sum of the maximum mint amount is always added.
	 * By recording that value when the staker last stakes, the difference from the when the staker stakes can be calculated.
	 */
	function update() public {
		/**
		 * Gets the cumulative sum of the maximum mint amount and the maximum mint number per block.
		 */
		Rewards memory rewards = dry();

		/**
		 * Records each value and the latest block number.
		 */
		setStorageCumulativeGlobalRewards(rewards.nextReward);
		setStorageLastSameRewardsAmountAndBlock(
			rewards.rewardAmount,
			block.number
		);
		setStorageCumulativeGlobalGMRewards(rewards.nextGMReward);
		setStorageLastSameGMRewardsAmountAndBlock(
			rewards.gMRewardAmount,
			block.number
		);
	}

	/**
	 * Referring to the values recorded in each storage to returns the latest cumulative sum of the maximum mint amount and the latest maximum mint amount per block.
	 */
	function dry() private view returns (Rewards memory _rewards) {
		uint256 gM = getStorageGeometricMeanLockedUp();

		/**
		 * Gets the latest mint amount per block from Allocator contract.
		 */
		uint256 rewardsAmount =
			IAllocator(config().allocator()).calculateMaxRewardsPerBlock();

		/**
		 * Gets the latest mint amount when geometric mean per block from Allocator contract.
		 */
		uint256 gMRewardsAmount =
			IAllocator(config().allocator())
				.calculateMaxRewardsPerBlockWhenLockedIs(gM);

		/**
		 * Gets the maximum mint amount per block, and the last recorded block number from `LastSameRewardsAmountAndBlock` storage.
		 */
		(uint256 lastAmount, uint256 lastBlock) =
			getStorageLastSameRewardsAmountAndBlock();

		/**
		 * Gets the maximum mint amount per block for geometric mean, and the last recorded block number from `LastSameGMRewardsAmountAndBlock` storage.
		 */
		(uint256 lastGMAmount, uint256 lastGMBlock) =
			getStorageLastSameGMRewardsAmountAndBlock();

		/**
		 * If the recorded maximum mint amount per block and the result of the Allocator contract are different,
		 * the result of the Allocator contract takes precedence as a maximum mint amount per block.
		 */
		uint256 lastMaxRewards =
			lastAmount == rewardsAmount ? rewardsAmount : lastAmount;
		uint256 lastMaxGMRewards =
			lastGMAmount == gMRewardsAmount ? gMRewardsAmount : lastGMAmount;

		/**
		 * Calculates the difference between the latest block number and the last recorded block number.
		 */
		uint256 blocks = lastBlock > 0 ? block.number.sub(lastBlock) : 0;
		uint256 gMBlocks = lastGMBlock > 0 ? block.number.sub(lastGMBlock) : 0;

		/**
		 * Adds the calculated new cumulative maximum mint amount to the recorded cumulative maximum mint amount.
		 */
		uint256 additionalRewards = lastMaxRewards.mul(blocks);
		uint256 additionalGMRewards = lastMaxGMRewards.mul(gMBlocks);
		uint256 nextRewards =
			getStorageCumulativeGlobalRewards().add(additionalRewards);
		uint256 nextGMRewards =
			getStorageCumulativeGlobalGMRewards().add(additionalGMRewards);

		/**
		 * Returns the latest theoretical cumulative sum of maximum mint amount and maximum mint amount per block.
		 */
		return
			Rewards(nextRewards, rewardsAmount, nextGMRewards, gMRewardsAmount);
	}

	/**
	 * Returns the staker reward as interest.
	 */
	function _calculateInterestAmount(address _property, address _user)
		private
		view
		returns (
			uint256 _amount,
			uint256 _interestPrice,
			RewardPrices memory _prices
		)
	{
		/**
		 * Get the amount the user is staking for the Property.
		 */
		uint256 lockedUpPerAccount = getStorageValue(_property, _user);

		/**
		 * Gets the cumulative sum of the interest price recorded the last time you withdrew.
		 */
		uint256 lastInterest =
			getStorageLastStakedInterestPrice(_property, _user);

		/**
		 * Gets the latest cumulative sum of the interest price.
		 */
		Rewards memory rewards = dry();
		(uint256 reward, uint256 holders, uint256 interest) =
			calculateCumulativeRewardPrices(rewards);
		(uint256 gMReward, uint256 gMHolders) =
			calculateCumulativeGMRewardPrices(rewards);

		/**
		 * Calculates and returns the latest withdrawable reward amount from the difference.
		 */
		uint256 result =
			interest >= lastInterest
				? interest.sub(lastInterest).mul(lockedUpPerAccount).divBasis()
				: 0;
		return (
			result,
			interest,
			RewardPrices(reward, holders, interest, gMReward, gMHolders)
		);
	}

	/**
	 * Returns the total rewards currently available for withdrawal. (For calling from inside the contract)
	 */
	function _calculateWithdrawableInterestAmount(
		address _property,
		address _user
	) private view returns (uint256 _amount, RewardPrices memory _prices) {
		/**
		 * If the passed Property has not authenticated, returns always 0.
		 */
		if (
			IMetricsGroup(config().metricsGroup()).hasAssets(_property) == false
		) {
			return (0, RewardPrices(0, 0, 0, 0, 0));
		}

		/**
		 * Gets the reward amount in saved without withdrawal.
		 */
		uint256 pending = getStoragePendingInterestWithdrawal(_property, _user);

		/**
		 * Gets the reward amount of before DIP4.
		 */
		uint256 legacy = __legacyWithdrawableInterestAmount(_property, _user);

		/**
		 * Gets the latest withdrawal reward amount.
		 */
		(uint256 amount, , RewardPrices memory prices) =
			_calculateInterestAmount(_property, _user);

		/**
		 * Returns the sum of all values.
		 */
		uint256 withdrawableAmount = amount.add(pending).add(legacy);
		return (withdrawableAmount, prices);
	}

	/**
	 * Returns the total rewards currently available for withdrawal. (For calling from external of the contract)
	 */
	function calculateWithdrawableInterestAmount(
		address _property,
		address _user
	) public view returns (uint256) {
		(uint256 amount, ) =
			_calculateWithdrawableInterestAmount(_property, _user);
		return amount;
	}

	/**
	 * Withdraws staking reward as an interest.
	 */
	function _withdrawInterest(address _property)
		private
		returns (RewardPrices memory _prices)
	{
		/**
		 * Gets the withdrawable amount.
		 */
		(uint256 value, RewardPrices memory prices) =
			_calculateWithdrawableInterestAmount(_property, msg.sender);

		/**
		 * Sets the unwithdrawn reward amount to 0.
		 */
		setStoragePendingInterestWithdrawal(_property, msg.sender, 0);

		/**
		 * Creates a Dev token instance.
		 */
		ERC20Mintable erc20 = ERC20Mintable(config().token());

		/**
		 * Updates the staking status to avoid double rewards.
		 */
		setStorageLastStakedInterestPrice(
			_property,
			msg.sender,
			prices.interest
		);
		__updateLegacyWithdrawableInterestAmount(_property, msg.sender);

		/**
		 * Mints the reward.
		 */
		require(erc20.mint(msg.sender, value), "dev mint failed");

		/**
		 * Since the total supply of tokens has changed, updates the latest maximum mint amount.
		 */
		update();

		return prices;
	}

	/**
	 * Status updates with the addition or release of staking.
	 */
	function updateValues(
		bool _addition,
		address _account,
		address _property,
		uint256 _value,
		RewardPrices memory _prices
	) private {
		beforeStakesChanged(_property, _account, _prices);
		/**
		 * If added staking:
		 */
		if (_addition) {
			/**
			 * Updates the current staking amount of the protocol total.
			 */
			addAllValue(_value);

			/**
			 * Updates the current staking amount of the Property.
			 */
			addPropertyValue(_property, _value);

			/**
			 * Updates the user's current staking amount in the Property.
			 */
			addValue(_property, _account, _value);

			/**
			 * If released staking:
			 */
		} else {
			/**
			 * Updates the current staking amount of the protocol total.
			 */
			subAllValue(_value);

			/**
			 * Updates the current staking amount of the Property.
			 */
			subPropertyValue(_property, _value);

			/**
			 * Updates the current staking amount of the Property.
			 */
			subValue(_property, _account, _value);
		}

		/**
		 * Since each staking amount has changed, updates the latest maximum mint amount.
		 */
		update();
	}

	/**
	 * Returns the staking amount of the protocol total.
	 */
	function getAllValue() external view returns (uint256) {
		return getStorageAllValue();
	}

	/**
	 * Adds the staking amount of the protocol total.
	 */
	function addAllValue(uint256 _value) private {
		uint256 value = getStorageAllValue();
		value = value.add(_value);
		setStorageAllValue(value);
	}

	/**
	 * Subtracts the staking amount of the protocol total.
	 */
	function subAllValue(uint256 _value) private {
		uint256 value = getStorageAllValue();
		value = value.sub(_value);
		setStorageAllValue(value);
	}

	/**
	 * Returns the user's staking amount in the Property.
	 */
	function getValue(address _property, address _sender)
		external
		view
		returns (uint256)
	{
		return getStorageValue(_property, _sender);
	}

	/**
	 * Adds the user's staking amount in the Property.
	 */
	function addValue(
		address _property,
		address _sender,
		uint256 _value
	) private {
		uint256 value = getStorageValue(_property, _sender);
		value = value.add(_value);
		setStorageValue(_property, _sender, value);
	}

	/**
	 * Subtracts the user's staking amount in the Property.
	 */
	function subValue(
		address _property,
		address _sender,
		uint256 _value
	) private {
		uint256 value = getStorageValue(_property, _sender);
		value = value.sub(_value);
		setStorageValue(_property, _sender, value);
	}

	/**
	 * Returns whether the user is staking in the Property.
	 */
	function hasValue(
		address _property,
		address _sender,
		uint256 _amount
	) private view returns (bool) {
		uint256 value = getStorageValue(_property, _sender);
		return value >= _amount;
	}

	/**
	 * Returns the staking amount of the Property.
	 */
	function getPropertyValue(address _property)
		external
		view
		returns (uint256)
	{
		return getStoragePropertyValue(_property);
	}

	/**
	 * Adds the staking amount of the Property.
	 */
	function addPropertyValue(address _property, uint256 _value) private {
		uint256 value = getStoragePropertyValue(_property);
		value = value.add(_value);
		setStoragePropertyValue(_property, value);
	}

	/**
	 * Subtracts the staking amount of the Property.
	 */
	function subPropertyValue(address _property, uint256 _value) private {
		uint256 value = getStoragePropertyValue(_property);
		uint256 nextValue = value.sub(_value);
		setStoragePropertyValue(_property, nextValue);
	}

	/**
	 * Saves the latest reward amount as an undrawn amount.
	 */
	function updatePendingInterestWithdrawal(address _property, address _user)
		private
		returns (RewardPrices memory _prices)
	{
		/**
		 * Gets the latest reward amount.
		 */
		(uint256 withdrawableAmount, RewardPrices memory prices) =
			_calculateWithdrawableInterestAmount(_property, _user);

		/**
		 * Saves the amount to `PendingInterestWithdrawal` storage.
		 */
		setStoragePendingInterestWithdrawal(
			_property,
			_user,
			withdrawableAmount
		);

		/**
		 * Updates the reward amount of before DIP4 to prevent further addition it.
		 */
		__updateLegacyWithdrawableInterestAmount(_property, _user);

		return prices;
	}

	/**
	 * Returns the reward amount of the calculation model before DIP4.
	 * It can be calculated by subtracting "the last cumulative sum of reward unit price" from
	 * "the current cumulative sum of reward unit price," and multiplying by the staking amount.
	 */
	function __legacyWithdrawableInterestAmount(
		address _property,
		address _user
	) private view returns (uint256) {
		uint256 _last = getStorageLastInterestPrice(_property, _user);
		uint256 price = getStorageInterestPrice(_property);
		uint256 priceGap = price.sub(_last);
		uint256 lockedUpValue = getStorageValue(_property, _user);
		uint256 value = priceGap.mul(lockedUpValue);
		return value.divBasis();
	}

	/**
	 * Updates and treats the reward of before DIP4 as already received.
	 */
	function __updateLegacyWithdrawableInterestAmount(
		address _property,
		address _user
	) private {
		uint256 interestPrice = getStorageInterestPrice(_property);
		if (getStorageLastInterestPrice(_property, _user) != interestPrice) {
			setStorageLastInterestPrice(_property, _user, interestPrice);
		}
	}

	/**
	 * Updates the block number of the time of DIP4 release.
	 */
	function setDIP4GenesisBlock(uint256 _block) external onlyOwner {
		/**
		 * Validates the value is not set.
		 */
		require(getStorageDIP4GenesisBlock() == 0, "already set the value");

		/**
		 * Sets the value.
		 */
		setStorageDIP4GenesisBlock(_block);
	}
}
