pragma solidity 0.5.17;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {UsingStorage} from "contracts/src/common/storage/UsingStorage.sol";

contract LockupStorage is UsingStorage {
	using SafeMath for uint256;

	uint256 private constant BASIS = 100000000000000000000000000000000;

	//AllValue
	function setStorageAllValue(uint256 _value) internal {
		bytes32 key = getStorageAllValueKey();
		eternalStorage().setUint(key, _value);
	}

	function getStorageAllValue() public view returns (uint256) {
		bytes32 key = getStorageAllValueKey();
		return eternalStorage().getUint(key);
	}

	function getStorageAllValueKey() private pure returns (bytes32) {
		return keccak256(abi.encodePacked("_allValue"));
	}

	//Value
	function setStorageValue(
		address _property,
		address _sender,
		uint256 _value
	) internal {
		bytes32 key = getStorageValueKey(_property, _sender);
		eternalStorage().setUint(key, _value);
	}

	function getStorageValue(address _property, address _sender)
		public
		view
		returns (uint256)
	{
		bytes32 key = getStorageValueKey(_property, _sender);
		return eternalStorage().getUint(key);
	}

	function getStorageValueKey(address _property, address _sender)
		private
		pure
		returns (bytes32)
	{
		return keccak256(abi.encodePacked("_value", _property, _sender));
	}

	//PropertyValue
	function setStoragePropertyValue(address _property, uint256 _value)
		internal
	{
		bytes32 key = getStoragePropertyValueKey(_property);
		eternalStorage().setUint(key, _value);
	}

	function getStoragePropertyValue(address _property)
		public
		view
		returns (uint256)
	{
		bytes32 key = getStoragePropertyValueKey(_property);
		return eternalStorage().getUint(key);
	}

	function getStoragePropertyValueKey(address _property)
		private
		pure
		returns (bytes32)
	{
		return keccak256(abi.encodePacked("_propertyValue", _property));
	}

	//InterestPrice
	function setStorageInterestPrice(address _property, uint256 _value)
		internal
	{
		// The previously used function
		// This function is only used in testing
		eternalStorage().setUint(getStorageInterestPriceKey(_property), _value);
	}

	function getStorageInterestPrice(address _property)
		public
		view
		returns (uint256)
	{
		return eternalStorage().getUint(getStorageInterestPriceKey(_property));
	}

	function getStorageInterestPriceKey(address _property)
		private
		pure
		returns (bytes32)
	{
		return keccak256(abi.encodePacked("_interestTotals", _property));
	}

	//LastInterestPrice
	function setStorageLastInterestPrice(
		address _property,
		address _user,
		uint256 _value
	) internal {
		eternalStorage().setUint(
			getStorageLastInterestPriceKey(_property, _user),
			_value
		);
	}

	function getStorageLastInterestPrice(address _property, address _user)
		public
		view
		returns (uint256)
	{
		return
			eternalStorage().getUint(
				getStorageLastInterestPriceKey(_property, _user)
			);
	}

	function getStorageLastInterestPriceKey(address _property, address _user)
		private
		pure
		returns (bytes32)
	{
		return
			keccak256(
				abi.encodePacked("_lastLastInterestPrice", _property, _user)
			);
	}

	//LastSameRewardsAmountAndBlock
	function setStorageLastSameRewardsAmountAndBlock(
		uint256 _amount,
		uint256 _block
	) internal {
		uint256 record = _amount.mul(BASIS).add(_block);
		eternalStorage().setUint(
			getStorageLastSameRewardsAmountAndBlockKey(),
			record
		);
	}

	function getStorageLastSameRewardsAmountAndBlock()
		public
		view
		returns (uint256 _amount, uint256 _block)
	{
		uint256 record =
			eternalStorage().getUint(
				getStorageLastSameRewardsAmountAndBlockKey()
			);
		uint256 amount = record.div(BASIS);
		uint256 blockNumber = record.sub(amount.mul(BASIS));
		return (amount, blockNumber);
	}

	function getStorageLastSameRewardsAmountAndBlockKey()
		private
		pure
		returns (bytes32)
	{
		return keccak256(abi.encodePacked("_LastSameRewardsAmountAndBlock"));
	}

	//LastSameGMRewardsAmountAndBlock
	function setStorageLastSameGMRewardsAmountAndBlock(
		uint256 _amount,
		uint256 _block
	) internal {
		uint256 record = _amount.mul(BASIS).add(_block);
		eternalStorage().setUint(
			getStorageLastSameGMRewardsAmountAndBlockKey(),
			record
		);
	}

	function getStorageLastSameGMRewardsAmountAndBlock()
		public
		view
		returns (uint256 _amount, uint256 _block)
	{
		uint256 record =
			eternalStorage().getUint(
				getStorageLastSameGMRewardsAmountAndBlockKey()
			);
		uint256 amount = record.div(BASIS);
		uint256 blockNumber = record.sub(amount.mul(BASIS));
		return (amount, blockNumber);
	}

	function getStorageLastSameGMRewardsAmountAndBlockKey()
		private
		pure
		returns (bytes32)
	{
		return keccak256(abi.encodePacked("_LastSameGMRewardsAmountAndBlock"));
	}

	//CumulativeGlobalRewards
	function setStorageCumulativeGlobalRewards(uint256 _value) internal {
		eternalStorage().setUint(
			getStorageCumulativeGlobalRewardsKey(),
			_value
		);
	}

	function getStorageCumulativeGlobalRewards() public view returns (uint256) {
		return eternalStorage().getUint(getStorageCumulativeGlobalRewardsKey());
	}

	function getStorageCumulativeGlobalRewardsKey()
		private
		pure
		returns (bytes32)
	{
		return keccak256(abi.encodePacked("_cumulativeGlobalRewards"));
	}

	//CumulativeGlobalGMRewards
	function setStorageCumulativeGlobalGMRewards(uint256 _value) internal {
		eternalStorage().setUint(
			getStorageCumulativeGlobalGMRewardsKey(),
			_value
		);
	}

	function getStorageCumulativeGlobalGMRewards()
		public
		view
		returns (uint256)
	{
		return
			eternalStorage().getUint(getStorageCumulativeGlobalGMRewardsKey());
	}

	function getStorageCumulativeGlobalGMRewardsKey()
		private
		pure
		returns (bytes32)
	{
		return keccak256(abi.encodePacked("_cumulativeGlobalGMRewards"));
	}

	//PendingWithdrawal
	function setStoragePendingInterestWithdrawal(
		address _property,
		address _user,
		uint256 _value
	) internal {
		eternalStorage().setUint(
			getStoragePendingInterestWithdrawalKey(_property, _user),
			_value
		);
	}

	function getStoragePendingInterestWithdrawal(
		address _property,
		address _user
	) public view returns (uint256) {
		return
			eternalStorage().getUint(
				getStoragePendingInterestWithdrawalKey(_property, _user)
			);
	}

	function getStoragePendingInterestWithdrawalKey(
		address _property,
		address _user
	) private pure returns (bytes32) {
		return
			keccak256(
				abi.encodePacked("_pendingInterestWithdrawal", _property, _user)
			);
	}

	//DIP4GenesisBlock
	function setStorageDIP4GenesisBlock(uint256 _block) internal {
		eternalStorage().setUint(getStorageDIP4GenesisBlockKey(), _block);
	}

	function getStorageDIP4GenesisBlock() public view returns (uint256) {
		return eternalStorage().getUint(getStorageDIP4GenesisBlockKey());
	}

	function getStorageDIP4GenesisBlockKey() private pure returns (bytes32) {
		return keccak256(abi.encodePacked("_dip4GenesisBlock"));
	}

	//lastStakedInterestPrice
	function setStorageLastStakedInterestPrice(
		address _property,
		address _user,
		uint256 _value
	) internal {
		eternalStorage().setUint(
			getStorageLastStakedInterestPriceKey(_property, _user),
			_value
		);
	}

	function getStorageLastStakedInterestPrice(address _property, address _user)
		public
		view
		returns (uint256)
	{
		return
			eternalStorage().getUint(
				getStorageLastStakedInterestPriceKey(_property, _user)
			);
	}

	function getStorageLastStakedInterestPriceKey(
		address _property,
		address _user
	) private pure returns (bytes32) {
		return
			keccak256(
				abi.encodePacked("_lastStakedInterestPrice", _property, _user)
			);
	}

	//lastStakesChangedCumulativeReward
	function setStorageLastStakesChangedCumulativeReward(uint256 _value)
		internal
	{
		eternalStorage().setUint(
			getStorageLastStakesChangedCumulativeRewardKey(),
			_value
		);
	}

	function getStorageLastStakesChangedCumulativeReward()
		public
		view
		returns (uint256)
	{
		return
			eternalStorage().getUint(
				getStorageLastStakesChangedCumulativeRewardKey()
			);
	}

	function getStorageLastStakesChangedCumulativeRewardKey()
		private
		pure
		returns (bytes32)
	{
		return
			keccak256(abi.encodePacked("_lastStakesChangedCumulativeReward"));
	}

	//LastCumulativeHoldersRewardPrice
	function setStorageLastCumulativeHoldersRewardPrice(uint256 _holders)
		internal
	{
		eternalStorage().setUint(
			getStorageLastCumulativeHoldersRewardPriceKey(),
			_holders
		);
	}

	function getStorageLastCumulativeHoldersRewardPrice()
		public
		view
		returns (uint256)
	{
		return
			eternalStorage().getUint(
				getStorageLastCumulativeHoldersRewardPriceKey()
			);
	}

	function getStorageLastCumulativeHoldersRewardPriceKey()
		private
		pure
		returns (bytes32)
	{
		return keccak256(abi.encodePacked("0lastCumulativeHoldersRewardPrice"));
	}

	//LastCumulativeInterestPrice
	function setStorageLastCumulativeInterestPrice(uint256 _interest) internal {
		eternalStorage().setUint(
			getStorageLastCumulativeInterestPriceKey(),
			_interest
		);
	}

	function getStorageLastCumulativeInterestPrice()
		public
		view
		returns (uint256)
	{
		return
			eternalStorage().getUint(
				getStorageLastCumulativeInterestPriceKey()
			);
	}

	function getStorageLastCumulativeInterestPriceKey()
		private
		pure
		returns (bytes32)
	{
		return keccak256(abi.encodePacked("0lastCumulativeInterestPrice"));
	}

	//LastCumulativeHoldersRewardAmountPerProperty
	function setStorageLastCumulativeHoldersRewardAmountPerProperty(
		address _property,
		uint256 _value
	) internal {
		eternalStorage().setUint(
			getStorageLastCumulativeHoldersRewardAmountPerPropertyKey(
				_property
			),
			_value
		);
	}

	function getStorageLastCumulativeHoldersRewardAmountPerProperty(
		address _property
	) public view returns (uint256) {
		return
			eternalStorage().getUint(
				getStorageLastCumulativeHoldersRewardAmountPerPropertyKey(
					_property
				)
			);
	}

	function getStorageLastCumulativeHoldersRewardAmountPerPropertyKey(
		address _property
	) private pure returns (bytes32) {
		return
			keccak256(
				abi.encodePacked(
					"0lastCumulativeHoldersRewardAmountPerProperty",
					_property
				)
			);
	}

	//LastCumulativeHoldersRewardPricePerProperty
	function setStorageLastCumulativeHoldersRewardPricePerProperty(
		address _property,
		uint256 _price
	) internal {
		eternalStorage().setUint(
			getStorageLastCumulativeHoldersRewardPricePerPropertyKey(_property),
			_price
		);
	}

	function getStorageLastCumulativeHoldersRewardPricePerProperty(
		address _property
	) public view returns (uint256) {
		return
			eternalStorage().getUint(
				getStorageLastCumulativeHoldersRewardPricePerPropertyKey(
					_property
				)
			);
	}

	function getStorageLastCumulativeHoldersRewardPricePerPropertyKey(
		address _property
	) private pure returns (bytes32) {
		return
			keccak256(
				abi.encodePacked(
					"0lastCumulativeHoldersRewardPricePerProperty",
					_property
				)
			);
	}

	//GeometricMeanLockedUp
	function setStorageGeometricMeanLockedUp(uint256 _geometricMean) internal {
		eternalStorage().setUint(
			getStorageGeometricMeanLockedUpKey(),
			_geometricMean
		);
	}

	function getStorageGeometricMeanLockedUp() public view returns (uint256) {
		return eternalStorage().getUint(getStorageGeometricMeanLockedUpKey());
	}

	function getStorageGeometricMeanLockedUpKey()
		private
		pure
		returns (bytes32)
	{
		return keccak256(abi.encodePacked("_geometricMeanLockedUp"));
	}

	//DisabledLockedups
	function setStorageDisabledLockedups(address _property, uint256 _value)
		internal
	{
		eternalStorage().setUint(
			getStorageDisabledLockedupsKey(_property),
			_value
		);
	}

	function getStorageDisabledLockedups(address _property)
		public
		view
		returns (uint256)
	{
		return
			eternalStorage().getUint(getStorageDisabledLockedupsKey(_property));
	}

	function getStorageDisabledLockedupsKey(address _property)
		private
		pure
		returns (bytes32)
	{
		return keccak256(abi.encodePacked("_disabledLockedups", _property));
	}

	//lastStakesChangedCumulativeGMReward
	function setStorageLastStakesChangedCumulativeGMReward(uint256 _value)
		internal
	{
		eternalStorage().setUint(
			getStorageLastStakesChangedCumulativeGMRewardKey(),
			_value
		);
	}

	function getStorageLastStakesChangedCumulativeGMReward()
		public
		view
		returns (uint256)
	{
		return
			eternalStorage().getUint(
				getStorageLastStakesChangedCumulativeGMRewardKey()
			);
	}

	function getStorageLastStakesChangedCumulativeGMRewardKey()
		private
		pure
		returns (bytes32)
	{
		return
			keccak256(abi.encodePacked("1lastStakesChangedCumulativeGMReward"));
	}

	//LastCumulativeHoldersGMRewardAmountPerProperty
	function setStorageLastCumulativeHoldersGMRewardAmountPerProperty(
		address _property,
		uint256 _value
	) internal {
		eternalStorage().setUint(
			getStorageLastCumulativeHoldersGMRewardAmountPerPropertyKey(
				_property
			),
			_value
		);
	}

	function getStorageLastCumulativeHoldersGMRewardAmountPerProperty(
		address _property
	) public view returns (uint256) {
		return
			eternalStorage().getUint(
				getStorageLastCumulativeHoldersGMRewardAmountPerPropertyKey(
					_property
				)
			);
	}

	function getStorageLastCumulativeHoldersGMRewardAmountPerPropertyKey(
		address _property
	) private pure returns (bytes32) {
		return
			keccak256(
				abi.encodePacked(
					"1LastCumulativeHoldersGMRewardAmountPerProperty",
					_property
				)
			);
	}

	//LastCumulativeHoldersGMRewardPricePerProperty
	function setStorageLastCumulativeHoldersGMRewardPricePerProperty(
		address _property,
		uint256 _price
	) internal {
		eternalStorage().setUint(
			getStorageLastCumulativeHoldersGMRewardPricePerPropertyKey(
				_property
			),
			_price
		);
	}

	function getStorageLastCumulativeHoldersGMRewardPricePerProperty(
		address _property
	) public view returns (uint256) {
		return
			eternalStorage().getUint(
				getStorageLastCumulativeHoldersGMRewardPricePerPropertyKey(
					_property
				)
			);
	}

	function getStorageLastCumulativeHoldersGMRewardPricePerPropertyKey(
		address _property
	) private pure returns (bytes32) {
		return
			keccak256(
				abi.encodePacked(
					"1LastCumulativeHoldersGMRewardPricePerProperty",
					_property
				)
			);
	}

	//LastCumulativeHoldersGMRewardPrice
	function setStorageLastCumulativeHoldersGMRewardPrice(uint256 _holders)
		internal
	{
		eternalStorage().setUint(
			getStorageLastCumulativeHoldersGMRewardPriceKey(),
			_holders
		);
	}

	function getStorageLastCumulativeHoldersGMRewardPrice()
		public
		view
		returns (uint256)
	{
		return
			eternalStorage().getUint(
				getStorageLastCumulativeHoldersGMRewardPriceKey()
			);
	}

	function getStorageLastCumulativeHoldersGMRewardPriceKey()
		private
		pure
		returns (bytes32)
	{
		return
			keccak256(abi.encodePacked("1lastCumulativeHoldersGMRewardPrice"));
	}
}
