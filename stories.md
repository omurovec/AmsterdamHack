Throughout the examples we assume:

EUR/USD = 1

### Open a position

Start: 100 EURS

1. take out EURS flash loan of 400 EURS on aave
2. deposit 500 EURS into Aave
3. borrow 500 USDC
4. swap 500 USDC for 400 EURS on Uniswap
5. pay back 400 EURS flash loan

End: 500 aEURS & 500 USDC borrowed | Leverage factor is 5x

### Close a position

Start: 500 aEURS & 500 USDC borrowed

1. take out a USDC flash loan of 500 USDC on aave
2. pay back your 500 USDC borrowed
3. withdraw 500 EURS from Aave
4. swap 400 EURS for 500 USDC on Uniswap
5. pay back 500 USDC flash loan

End: 100 EURS

## Short EUR/USD strategy

### Open a position

Start: 100 USDC, .2

1. take out USDC flash loan of 400 USDC on aave
2. deposit 500 USDC into Aave
3. borrow 333 EURS
4. swap 333 EURS for 400 USDC on Uniswap
5. pay back 333 EURS flash loan

End: 500 aUSDC && 333 EURS borrowed | Leverage factor is 5x

### Close a position

Start: 500 aUSDC & 333 EURS borrowed

1. take out a EURS flash loan of 333 USDC on aave
2. pay back your 333 EURS borrowed
3. withdraw 500 USDC from Aave
4. swap 400 USDC for 333 EURS on Uniswap
5. pay back 500 USDC flash loan

End: 100 EURS
