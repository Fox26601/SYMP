package chain

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"os"
	"strings"
	"sync"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

type Client struct {
	EC       *ethclient.Client
	ChainID  *big.Int
	Key      *ecdsa.PrivateKey
	From     common.Address
	USDC     common.Address
	SYMP     common.Address
	Router   common.Address
	Quoter   common.Address
	PoolFee  uint32
	mu       sync.Mutex
}

func NewFromEnv() (*Client, error) {
	rpc := strings.TrimSpace(os.Getenv("ONCHAIN_RPC_URL"))
	if rpc == "" {
		return nil, fmt.Errorf("ONCHAIN_RPC_URL required")
	}
	ec, err := ethclient.Dial(rpc)
	if err != nil {
		return nil, err
	}
	pkHex := strings.TrimPrefix(strings.TrimSpace(os.Getenv("PAYOUT_PRIVATE_KEY")), "0x")
	if pkHex == "" {
		return nil, fmt.Errorf("PAYOUT_PRIVATE_KEY required")
	}
	key, err := crypto.HexToECDSA(pkHex)
	if err != nil {
		return nil, err
	}
	from := crypto.PubkeyToAddress(key.PublicKey)
	chainID, err := ec.ChainID(context.Background())
	if err != nil {
		return nil, err
	}
	fee := uint32(3000)
	return &Client{
		EC: ec, ChainID: chainID, Key: key, From: from,
		USDC:   common.HexToAddress(os.Getenv("USDC_TOKEN")),
		SYMP:   common.HexToAddress(os.Getenv("SYMP_TOKEN")),
		Router: common.HexToAddress(os.Getenv("UNISWAP_SWAP_ROUTER")),
		Quoter: common.HexToAddress(os.Getenv("UNISWAP_QUOTER_V2")),
		PoolFee: fee,
	}, nil
}

var erc20ABI = mustABI(`[{"name":"balanceOf","type":"function","stateMutability":"view","inputs":[{"name":"a","type":"address"}],"outputs":[{"type":"uint256"}]},{"name":"approve","type":"function","stateMutability":"nonpayable","inputs":[{"name":"s","type":"address"},{"name":"v","type":"uint256"}],"outputs":[{"type":"bool"}]},{"name":"allowance","type":"function","stateMutability":"view","inputs":[{"name":"o","type":"address"},{"name":"s","type":"address"}],"outputs":[{"type":"uint256"}]},{"name":"decimals","type":"function","stateMutability":"view","inputs":[],"outputs":[{"type":"uint8"}]}]`)

// SwapRouter02 exactInputSingle
var routerABI = mustABI(`[{"name":"exactInputSingle","type":"function","stateMutability":"payable","inputs":[{"components":[{"name":"tokenIn","type":"address"},{"name":"tokenOut","type":"address"},{"name":"fee","type":"uint24"},{"name":"recipient","type":"address"},{"name":"amountIn","type":"uint256"},{"name":"amountOutMinimum","type":"uint256"},{"name":"sqrtPriceLimitX96","type":"uint160"}],"name":"params","type":"tuple"}],"outputs":[{"name":"amountOut","type":"uint256"}]}]`)

var quoterABI = mustABI(`[{"name":"quoteExactInputSingle","type":"function","stateMutability":"nonpayable","inputs":[{"components":[{"name":"tokenIn","type":"address"},{"name":"tokenOut","type":"address"},{"name":"amountIn","type":"uint256"},{"name":"fee","type":"uint24"},{"name":"sqrtPriceLimitX96","type":"uint160"}],"name":"params","type":"tuple"}],"outputs":[{"name":"amountOut","type":"uint256"},{"name":"sqrtPriceX96After","type":"uint160"},{"name":"initializedTicksCrossed","type":"uint32"},{"name":"gasEstimate","type":"uint256"}]}]`)

func mustABI(json string) abi.ABI {
	a, err := abi.JSON(strings.NewReader(json))
	if err != nil {
		panic(err)
	}
	return a
}

func (c *Client) BalanceUSDC(ctx context.Context) (*big.Int, error) {
	return c.balanceOf(ctx, c.USDC, c.From)
}

func (c *Client) BalanceETH(ctx context.Context) (*big.Int, error) {
	return c.EC.BalanceAt(ctx, c.From, nil)
}

func (c *Client) balanceOf(ctx context.Context, token, holder common.Address) (*big.Int, error) {
	data, err := erc20ABI.Pack("balanceOf", holder)
	if err != nil {
		return nil, err
	}
	out, err := c.EC.CallContract(ctx, ethereum.CallMsg{To: &token, Data: data}, nil)
	if err != nil {
		return nil, err
	}
	return new(big.Int).SetBytes(out), nil
}

func (c *Client) QuoteExactIn(ctx context.Context, amountIn *big.Int) (*big.Int, error) {
	data, err := quoterABI.Pack("quoteExactInputSingle", struct {
		TokenIn           common.Address
		TokenOut          common.Address
		AmountIn          *big.Int
		Fee               *big.Int
		SqrtPriceLimitX96 *big.Int
	}{c.USDC, c.SYMP, amountIn, big.NewInt(int64(c.PoolFee)), big.NewInt(0)})
	if err != nil {
		return nil, err
	}
	out, err := c.EC.CallContract(ctx, ethereum.CallMsg{To: &c.Quoter, Data: data, From: c.From}, nil)
	if err != nil {
		return nil, err
	}
	vals, err := quoterABI.Unpack("quoteExactInputSingle", out)
	if err != nil {
		return nil, err
	}
	return vals[0].(*big.Int), nil
}

func (c *Client) EnsureApprove(ctx context.Context, amount *big.Int) error {
	data, _ := erc20ABI.Pack("allowance", c.From, c.Router)
	out, err := c.EC.CallContract(ctx, ethereum.CallMsg{To: &c.USDC, Data: data}, nil)
	if err != nil {
		return err
	}
	allow := new(big.Int).SetBytes(out)
	if allow.Cmp(amount) >= 0 {
		return nil
	}
	adata, err := erc20ABI.Pack("approve", c.Router, new(big.Int).Mul(amount, big.NewInt(10)))
	if err != nil {
		return err
	}
	_, err = c.send(ctx, c.USDC, adata, big.NewInt(0))
	return err
}

func (c *Client) SwapUSDCForSYMP(ctx context.Context, amountIn, minOut *big.Int, recipient common.Address) (common.Hash, error) {
	if err := c.EnsureApprove(ctx, amountIn); err != nil {
		return common.Hash{}, err
	}
	data, err := routerABI.Pack("exactInputSingle", struct {
		TokenIn           common.Address
		TokenOut          common.Address
		Fee               *big.Int
		Recipient         common.Address
		AmountIn          *big.Int
		AmountOutMinimum  *big.Int
		SqrtPriceLimitX96 *big.Int
	}{c.USDC, c.SYMP, big.NewInt(int64(c.PoolFee)), recipient, amountIn, minOut, big.NewInt(0)})
	if err != nil {
		return common.Hash{}, err
	}
	return c.send(ctx, c.Router, data, big.NewInt(0))
}

func (c *Client) WaitMined(ctx context.Context, hash common.Hash) (*types.Receipt, error) {
	for {
		r, err := c.EC.TransactionReceipt(ctx, hash)
		if err == nil && r != nil {
			return r, nil
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		default:
		}
	}
}

func (c *Client) send(ctx context.Context, to common.Address, data []byte, value *big.Int) (common.Hash, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	nonce, err := c.EC.PendingNonceAt(ctx, c.From)
	if err != nil {
		return common.Hash{}, err
	}
	gasPrice, err := c.EC.SuggestGasPrice(ctx)
	if err != nil {
		return common.Hash{}, err
	}
	msg := ethereum.CallMsg{From: c.From, To: &to, Data: data, Value: value}
	gas, err := c.EC.EstimateGas(ctx, msg)
	if err != nil {
		gas = 500000
	}
	tx := types.NewTransaction(nonce, to, value, gas+gas/10, gasPrice, data)
	signed, err := types.SignTx(tx, types.LatestSignerForChainID(c.ChainID), c.Key)
	if err != nil {
		return common.Hash{}, err
	}
	if err := c.EC.SendTransaction(ctx, signed); err != nil {
		return common.Hash{}, err
	}
	return signed.Hash(), nil
}

func USDMinorToUSDC(minor int64) *big.Int {
	// USD minor (cents) → USDC 6 decimals: $1.00 = 100 minor = 1e6 USDC units
	return big.NewInt(minor * 10_000)
}

func IsETHAddress(s string) bool {
	return common.IsHexAddress(s)
}
