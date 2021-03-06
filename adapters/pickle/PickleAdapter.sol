// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../libraries/UniswapV2Library.sol";
import "../../IVampireAdapter.sol";
import "../../IDrainController.sol";
import "./IMasterChef.sol";

contract PickleAdapter is IVampireAdapter {
    IDrainController constant drainController = IDrainController(0x2e813f2e524dB699d279E631B0F2117856eb902C);
    IMasterChef constant pickleMasterChef = IMasterChef(0xbD17B1ce622d73bD438b9E658acA5996dc394b0d);
    IERC20 constant pickle = IERC20(0x429881672B9AE42b8EbA0E26cD9C73711b891Ca5);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant pickleWethPair = IUniswapV2Pair(0xdc98556Ce24f007A5eF6dC1CE96322d65832A819);
    // token 0 - pickle
    // token 1 - weth

    constructor() public {
    }

    // Victim info
    function rewardToken() external view override returns (IERC20) {
        return pickle;
    }

    function poolCount() external view override returns (uint256) {
        return pickleMasterChef.poolLength();
    }

    function sellableRewardAmount() external view override returns (uint256) {
        return uint256(-1);
    }
    
    // Victim actions, requires impersonation via delegatecall
    function sellRewardForWeth(address, uint256 rewardAmount, address to) external override returns(uint256) {
        require(drainController.priceIsUnderRejectionTreshold(), "Possible price manipulation, drain rejected");
        pickle.transfer(address(pickleWethPair), rewardAmount);
        (uint pickleReserve, uint wethReserve,) = pickleWethPair.getReserves();
        uint amountOutput = UniswapV2Library.getAmountOut(rewardAmount, pickleReserve, wethReserve);
        pickleWethPair.swap(uint(0), amountOutput, to, new bytes(0));
        return amountOutput;
    }
    
    // Pool info
    function lockableToken(uint256 poolId) external view override returns (IERC20) {
        (IERC20 lpToken,,,) = pickleMasterChef.poolInfo(poolId);
        return lpToken;
    }

    function lockedAmount(address user, uint256 poolId) external view override returns (uint256) {
        (uint256 amount,) = pickleMasterChef.userInfo(poolId, user);
        return amount;
    }
    
    // Pool actions, requires impersonation via delegatecall
    function deposit(address _adapter, uint256 poolId, uint256 amount) external override {
        IVampireAdapter adapter = IVampireAdapter(_adapter);
        adapter.lockableToken(poolId).approve(address(pickleMasterChef), uint256(-1));
        pickleMasterChef.deposit( poolId, amount);
    }

    function withdraw(address, uint256 poolId, uint256 amount) external override {
        pickleMasterChef.withdraw( poolId, amount);
    }

    function claimReward(address, uint256 poolId) external override {
        pickleMasterChef.deposit( poolId, 0);
    }
    
    function emergencyWithdraw(address, uint256 poolId) external override {
        pickleMasterChef.emergencyWithdraw(poolId);
    }
    
    // Service methods
    function poolAddress(uint256) external view override returns (address) {
        return address(pickleMasterChef);
    }

    function rewardToWethPool() external view override returns (address) {
        return address(pickleWethPair);
    }
    
    function lockedValue(address, uint256) external override view returns (uint256) {
        require(false, "not implemented");
    }    

    function totalLockedValue(uint256) external override view returns (uint256) {
        require(false, "not implemented"); 
    }

    function normalizedAPY(uint256) external override view returns (uint256) {
        require(false, "not implemented");
    }
}
