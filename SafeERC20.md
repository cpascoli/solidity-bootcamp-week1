# Why does the SafeERC20 program exist and when should it be used?

- [SafeERC20](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol) provides a utility that wraps around ERC20 operations that throw on failure (when the token contract returns false). 

- Tokens that return no value (and instead revert or throw on failure) are also supported, non-reverting calls are assumed to be successful. 

- SafeERC20 should be used when the caller requires a uniform behaviour, across different ERC20 implementations, and make sure to revert on failed transfers and approvals.