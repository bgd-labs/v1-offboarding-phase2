#make download chain=1 address=0x1a7Dde6344d5F2888209DdB446756FE292e1325e #lm
#make download chain=1 address=0x89A943BAc327c9e217d70E57DCD57C7f2a8C3fA9 #lp

make git-diff before=etherscan/1_0x1a7Dde6344d5F2888209DdB446756FE292e1325e/LendingPoolLiquidationManager/src/contracts/UpdatedLendingPoolLiquidationManager.sol after=src/contracts/UpdatedLendingPoolLiquidationManager.sol out=LendingPoolLiquidationManager
make git-diff before=etherscan/1_0x89A943BAc327c9e217d70E57DCD57C7f2a8C3fA9/LendingPool/src/contracts/UpdatedLendingPool.sol after=src/contracts/UpdatedLendingPool.sol out=LendingPool