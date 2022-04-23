import { ReserveDataUpdated } from "../generated/Pool/Pool";
import { Market, Pool, Rate } from "../generated/schema";
import { EURS_ADDRESS, USDC_ADDRESS } from "./constants";

export function ensurePool(event: ReserveDataUpdated): void {
  const poolAddress = event.address.toString();

  let pool = new Pool(poolAddress);

  pool.baseMarket = EURS_ADDRESS.toString();
  pool.quoteMarket = USDC_ADDRESS.toString();

  pool.save();
}

export function ensureMarket(event: ReserveDataUpdated): void {
  const marketAddress = event.address.toString();

  let pool = Pool.load(marketAddress);

  let market = Market.load(pool.baseMarket);

  market.rate = [event.block.timestamp.toString()];

  market.save();
}

export function updateRate(event: ReserveDataUpdated): Rate {
  // 1) get pool
  // 2) get pool.baseMarket
  // 3) load baseMarket from Market

  let rate = new Rate(event.block.timestamp.toString());

  rate.supplyRate = event.params.liquidityRate;
  rate.borrowRate = event.params.variableBorrowRate;

  rate.borrowIndex = event.params.liquidityIndex;
  rate.supplyIndex = event.params.variableBorrowIndex;

  rate.save();
  return rate;
}
