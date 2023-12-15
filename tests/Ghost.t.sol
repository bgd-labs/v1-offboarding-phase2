// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';

interface ILendingPool {
  function liquidationCall(
    address _collateral,
    address _reserve,
    address _user,
    uint256 _purchaseAmount,
    bool _receiveAToken
  ) external payable;

  function offboardingLiquidationCall(
    address _collateral,
    address _reserve,
    address _user,
    uint256 _purchaseAmount
  ) external payable;

  function getUserAccountData(
    address _user
  )
    external
    view
    returns (
      uint256 totalLiquidityETH,
      uint256 totalCollateralETH,
      uint256 totalBorrowsETH,
      uint256 totalFeesETH,
      uint256 availableBorrowsETH,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    );
}

interface ILendingPoolAddressesProvider {
  function getLendingPoolCore() external view returns (address);

  function getLendingPool() external view returns (address);

  function setLendingPoolImpl(address _pool) external;

  function getLendingPoolLiquidationManager() external view returns (address);

  function setLendingPoolLiquidationManager(address _manager) external;
}

contract GhostTest is Test {
  ILendingPoolAddressesProvider public constant provider =
    ILendingPoolAddressesProvider(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8);

  address public manager; //= ILendingPoolLiquidationManager(0x31cceeb1fA3DbEAf7baaD25125b972A17624A40a);

  ILendingPool public pool = ILendingPool(0x398eC7346DcD622eDc5ae82352F02bE94C62d119);

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 18770009);
    // deploy liquidationManager
    bytes memory liquidationManagerBytecode = abi.encodePacked(
      vm.getCode('UpdatedLendingPoolLiquidationManager.sol:LendingPoolLiquidationManager')
    );
    address liquidationManager;
    assembly {
      liquidationManager := create(
        0,
        add(liquidationManagerBytecode, 0x20),
        mload(liquidationManagerBytecode)
      )
    }
    manager = liquidationManager;
    // deploy pool
    bytes memory lendingPoolBytecode = abi.encodePacked(
      vm.getCode('UpdatedLendingPool.sol:LendingPool')
    );
    address poolImpl;
    assembly {
      poolImpl := create(0, add(lendingPoolBytecode, 0x20), mload(lendingPoolBytecode))
    }
    vm.startPrank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    provider.setLendingPoolLiquidationManager(manager);
    provider.setLendingPoolImpl(poolImpl);
    vm.stopPrank();
  }

  struct V1User {
    address user;
    address collateral;
    address debt;
  }

  function test_liquidate() public {
    V1User[] memory users = new V1User[](1);
    users[0] = V1User(
      0x1F0aeAeE69468727BA258B0cf692E6bfecc2E286,
      0x514910771AF9Ca656af840dff83E8264EcF986CA, // LINK
      0x0000000000085d4780B73119b644AE5ecd22b376 // TUSD
    );
    for (uint256 i = 0; i < users.length; i++) {
      deal(users[i].debt, address(this), 26936742563757401924489);
      // as these are healthy users "default liquidation" should revert
      vm.expectRevert('Liquidation failed: Health factor is not below the threshold');
      pool.liquidationCall(users[i].collateral, users[i].debt, users[i].user, 1e6, false);

      // offboarding liquidations should provide a fixed 1% bonus
      (, uint256 totalCollateralETHBefore, uint256 totalBorrowsETHBefore, , , , , ) = pool
        .getUserAccountData(users[i].user);
      IERC20(users[i].debt).approve(provider.getLendingPoolCore(), type(uint256).max);
      pool.offboardingLiquidationCall(
        users[i].collateral,
        users[i].debt,
        users[i].user,
        type(uint256).max
      );
      (, uint256 totalCollateralETHAfter, uint256 totalBorrowsETHAfter, , , , , ) = pool
        .getUserAccountData(users[i].user);

      uint256 collateralDiff = totalCollateralETHBefore - totalCollateralETHAfter;
      uint256 borrowsDiff = totalBorrowsETHBefore - totalBorrowsETHAfter;
      assertGt(collateralDiff, borrowsDiff);
      assertApproxEqAbs((borrowsDiff * 1 ether) / collateralDiff, 0.99 ether, 0.001 ether); // should be ~1% + rounding
    }
  }
}
