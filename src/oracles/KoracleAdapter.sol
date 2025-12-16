// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {IAdvancedOracle} from "../interfaces/IAdvancedOracle.sol";

/// @title IKoracle
/// @notice Interface for Koracle price feed
interface IKoracle {
    /// @notice Get price by feed ID
    /// @param feedId The feed identifier (e.g., "WEIGHTED.ETH.KRW")
    /// @return price Price scaled by 1e18
    /// @return timestamp Last update timestamp
    /// @return roundId Round ID
    /// @return feedIdOut Feed ID echo
    function getPriceByFeedId(string calldata feedId)
        external
        view
        returns (
            uint256 price,
            uint256 timestamp,
            uint256 roundId,
            string memory feedIdOut
        );
}

/// @title KoracleAdapter
/// @author KORACLE
/// @notice Adapter to make Koracle compatible with Morpho's IOracle interface
/// @dev Converts WEIGHTED.ETH.KRW price to Morpho's 1e36 scaled format
contract KoracleAdapter is IAdvancedOracle {

    /// @notice Koracle main oracle contract
    IKoracle public immutable koracle;

    /// @notice Feed ID for ETH/KRW price
    string public constant ETH_KRW_FEED = "WEIGHTED.ETH.KRW";

    /// @notice Feed ID for crypto FX rate (kimp included)
    string public constant CRYPTO_FX_FEED = "CRYPTOFX.USDT.KRW";

    /// @notice Feed ID for official USD/KRW rate
    string public constant USD_KRW_FEED = "USD.KRW.PRICE";

    /// @notice Maximum staleness for price data (1 hour)
    uint256 public constant MAX_STALENESS = 3600;

    /// @notice Morpho oracle price scale
    uint256 private constant ORACLE_PRICE_SCALE = 1e36;

    /// @notice Koracle price scale (1e18)
    uint256 private constant KORACLE_PRICE_SCALE = 1e18;

    error StalePrice();
    error InvalidPrice();

    constructor(address _koracle) {
        require(_koracle != address(0), "Invalid koracle address");
        koracle = IKoracle(_koracle);
    }

    /// @notice Returns the price of 1 UPKRW (collateral) in UPETH (loan), scaled by 1e36
    /// @dev Morpho expects: price of 1 collateral token in loan tokens * 1e36
    ///      UPKRW is collateral, UPETH is loan token
    ///      If ETH = 4,657,000 KRW, then 1 KRW = 1/4,657,000 ETH
    ///      price = (1 / 4,657,000) * 1e36
    function price() external view override returns (uint256) {
        (uint256 ethKrwPrice, uint256 timestamp,,) = koracle.getPriceByFeedId(ETH_KRW_FEED);

        // Check staleness
        if (block.timestamp - timestamp > MAX_STALENESS) revert StalePrice();
        if (ethKrwPrice == 0) revert InvalidPrice();

        // ethKrwPrice is in 1e18 scale (e.g., 4657000 * 1e18 for 4,657,000 KRW per ETH)
        // We need: (1 KRW in ETH) * 1e36 = (1e18 / ethKrwPrice) * 1e36 = 1e54 / ethKrwPrice
        // But ethKrwPrice already has 1e18 scale, so actual value = ethKrwPrice / 1e18
        // So: 1e36 / (ethKrwPrice / 1e18) = 1e36 * 1e18 / ethKrwPrice = 1e54 / ethKrwPrice

        return (ORACLE_PRICE_SCALE * KORACLE_PRICE_SCALE) / ethKrwPrice;
    }

    /// @notice Returns the kimchi premium as a percentage scaled by 1e18
    /// @dev Kimchi premium = (CRYPTOFX.USDT.KRW / USD.KRW.PRICE - 1) * 100
    ///      e.g., if crypto rate is 1488 and official is 1467, premium = (1488/1467 - 1) = 1.43%
    ///      Returns 0.0143e18 for 1.43%
    function kimchiPremium() external view override returns (uint256) {
        (uint256 cryptoFxRate, uint256 ts1,,) = koracle.getPriceByFeedId(CRYPTO_FX_FEED);
        (uint256 officialRate, uint256 ts2,,) = koracle.getPriceByFeedId(USD_KRW_FEED);

        // Check staleness (more lenient for FX rates)
        if (block.timestamp - ts1 > MAX_STALENESS * 2) revert StalePrice();
        if (block.timestamp - ts2 > MAX_STALENESS * 2) revert StalePrice();
        if (cryptoFxRate == 0 || officialRate == 0) revert InvalidPrice();

        // Both rates are in 1e18 scale
        // premium = (cryptoFxRate / officialRate - 1) * 1e18
        // = (cryptoFxRate - officialRate) * 1e18 / officialRate

        if (cryptoFxRate <= officialRate) {
            return 0; // No premium (or negative premium, treat as 0)
        }

        return ((cryptoFxRate - officialRate) * KORACLE_PRICE_SCALE) / officialRate;
    }

    /// @notice Custom metric (not used, returns 0)
    function customMetric() external pure override returns (uint256) {
        return 0;
    }

    /// @notice Get raw ETH/KRW price from Koracle
    /// @return ethKrwPrice ETH price in KRW (scaled by 1e18)
    /// @return timestamp Last update timestamp
    function getEthKrwPrice() external view returns (uint256 ethKrwPrice, uint256 timestamp) {
        (ethKrwPrice, timestamp,,) = koracle.getPriceByFeedId(ETH_KRW_FEED);
    }

    /// @notice Get raw FX rates for kimchi premium calculation
    /// @return cryptoFxRate Crypto market USD/KRW rate
    /// @return officialRate Official USD/KRW rate
    function getFxRates() external view returns (uint256 cryptoFxRate, uint256 officialRate) {
        (cryptoFxRate,,,) = koracle.getPriceByFeedId(CRYPTO_FX_FEED);
        (officialRate,,,) = koracle.getPriceByFeedId(USD_KRW_FEED);
    }
}
