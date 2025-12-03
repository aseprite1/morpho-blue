# CustomMorpho - 커스텀 청산 조건 가이드

## 📋 개요

CustomMorpho는 기존 Morpho Blue를 확장하여 다음과 같은 커스텀 청산 조건을 추가한 컨트랙트입니다:

- **김치 프리미엄 기반 청산**: 김치 프리미엄이 설정된 %를 초과하면 청산 가능
- **커스텀 지표 기반 청산**: 변동성, 펀딩비 등 원하는 지표로 청산 조건 설정
- **마켓별 청산 인센티브**: 각 마켓마다 다른 청산 보너스 설정 가능

## 🚀 배포 방법

### 1. 환경 변수 설정

`.env` 파일에 다음 값들을 추가하세요:

```bash
# 기본 설정
GIWA_RPC_URL=https://your-giwa-rpc-url
PRIVATE_KEY=your_private_key_without_0x
OWNER_ADDRESS=0xYourOwnerAddress
CHAIN_ID=your_chain_id

# CustomMorpho 설정
KIMCHI_PREMIUM_THRESHOLD=30000000000000000  # 3% = 0.03e18
CUSTOM_METRIC_THRESHOLD=1000000000000000000  # 1 = 1e18
```

### 2. 컴파일

```bash
forge build
```

### 3. 배포

```bash
# Dry run (시뮬레이션)
forge script script/DeployCustomMorpho.s.sol:DeployCustomMorpho \
  --rpc-url $GIWA_RPC_URL

# 실제 배포
forge script script/DeployCustomMorpho.s.sol:DeployCustomMorpho \
  --rpc-url $GIWA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --chain-id $CHAIN_ID
```

## ⚙️ 초기 설정

배포 후 Owner가 다음 설정을 해야 합니다:

```solidity
// 1. 김치 프리미엄 청산 활성화
customMorpho.setKimchiPremiumEnabled(true);

// 2. 커스텀 지표 청산 활성화 (선택)
customMorpho.setCustomMetricEnabled(true);

// 3. IRM 활성화 (기존 Morpho와 동일)
customMorpho.enableIrm(irmAddress);

// 4. LLTV 활성화 (기존 Morpho와 동일)
customMorpho.enableLltv(0.8e18); // 80%

// 5. 특정 마켓에 커스텀 청산 보너스 설정 (선택)
customMorpho.setCustomLiquidationBonus(marketId, 1.2e18); // 20% 보너스
```

## 📊 청산 조건

CustomMorpho는 다음 조건 중 **하나라도 만족하면** 청산이 가능합니다:

### 1. 기존 건강도 체크 (Morpho Blue 기본)
```
담보가치 × LLTV < 빌린금액
```

### 2. 김치 프리미엄 청산 (새로운 기능!)
```
김치프리미엄 >= 설정된 임계값
```

예시:
- 임계값 설정: 3% (0.03e18)
- 현재 김치프리미엄: 4%
- 결과: ✅ 청산 가능!

### 3. 커스텀 지표 청산 (새로운 기능!)
```
커스텀지표 < 설정된 임계값
```

예시:
- 임계값 설정: 1.0 (1e18)
- 현재 지표: 0.8
- 결과: ✅ 청산 가능!

## 🔧 Owner 전용 함수들

### 임계값 설정

```solidity
// 김치 프리미엄 임계값 변경 (5%로 설정)
setKimchiPremiumThreshold(0.05e18)

// 커스텀 지표 임계값 변경
setCustomMetricThreshold(2e18)
```

### 청산 보너스 설정

```solidity
// 특정 마켓에 20% 청산 보너스 설정
setCustomLiquidationBonus(marketId, 1.2e18)

// 기본값으로 되돌리기 (0으로 설정)
setCustomLiquidationBonus(marketId, 0)
```

### 기능 활성화/비활성화

```solidity
// 김치 프리미엄 청산 활성화
setKimchiPremiumEnabled(true)

// 커스텀 지표 청산 비활성화
setCustomMetricEnabled(false)
```

## 🔍 조회 함수

### 청산 가능 여부 확인

```solidity
(bool canLiquidate, string memory reason) = customMorpho.canLiquidatePosition(
    marketParams,
    borrowerAddress
);

// 반환값:
// - canLiquidate: true/false
// - reason: "Unhealthy position" | "Kimchi premium exceeded" | "Custom metric below threshold" | "Position is healthy"
```

### 현재 설정 확인

```solidity
uint256 kimchiThreshold = customMorpho.kimchiPremiumThreshold();
uint256 customThreshold = customMorpho.customMetricThreshold();
bool kimchiEnabled = customMorpho.kimchiPremiumEnabled();
uint256 marketBonus = customMorpho.customLiquidationBonus(marketId);
```

## 🎯 오라클 구현 예시

CustomMorpho를 사용하려면 오라클이 `IAdvancedOracle` 인터페이스를 구현해야 합니다:

```solidity
contract GiwaOracle is IAdvancedOracle {
    // 기본 가격 (필수)
    function price() external view returns (uint256) {
        return getCollateralPrice(); // 1e36 스케일
    }

    // 김치 프리미엄 (선택)
    function kimchiPremium() external view returns (uint256) {
        uint256 koreaPrice = getKoreaExchangePrice();
        uint256 globalPrice = getBinancePrice();

        // 프리미엄 계산 (1e18 스케일)
        // 3% = 0.03e18
        return (koreaPrice - globalPrice) * 1e18 / globalPrice;
    }

    // 커스텀 지표 (선택)
    function customMetric() external view returns (uint256) {
        // 예: 변동성, 펀딩비, TVL 비율 등
        return calculateVolatility(); // 1e18 스케일
    }
}
```

**참고**: 기존 오라클 (IOracle만 구현)도 사용 가능합니다. 이 경우 김치 프리미엄/커스텀 지표 청산은 자동으로 스킵됩니다.

## 📈 청산 시나리오 예시

### 시나리오 1: 일반 청산
```
- 담보: 1 ETH ($2000)
- 빌린금액: $1700
- LLTV: 80%
- 최대 빌릴 수 있는 금액: $2000 × 0.8 = $1600
- 결과: $1700 > $1600 → ✅ 청산 가능 (건강도 미달)
```

### 시나리오 2: 김치 프리미엄 청산
```
- 담보: 1 ETH ($2000)
- 빌린금액: $1500
- LLTV: 80%
- 건강도: OK ($1500 < $1600)
- 김치 프리미엄: 5%
- 임계값: 3%
- 결과: 5% > 3% → ✅ 청산 가능 (김치 프리미엄 초과)
```

### 시나리오 3: 커스텀 지표 청산
```
- 담보: 1 ETH ($2000)
- 빌린금액: $1500
- 건강도: OK
- 김치 프리미엄: 2% (OK)
- 커스텀 지표 (변동성): 0.8
- 임계값: 1.0
- 결과: 0.8 < 1.0 → ✅ 청산 가능 (변동성 낮음)
```

## 🔒 보안 고려사항

1. **오라클 신뢰성**: 김치 프리미엄 데이터를 제공하는 오라클이 안전한지 확인
2. **초기 비활성화**: 배포 후 김치/커스텀 청산은 기본적으로 **비활성화**되어 있습니다
3. **점진적 활성화**: 충분한 테스트 후 Owner가 수동으로 활성화해야 합니다
4. **임계값 조정**: 시장 상황에 맞게 임계값을 조정하세요

## 🧪 테스트

Mock 오라클을 사용한 테스트:

```solidity
// 1. Mock 오라클 배포
AdvancedOracleMock oracle = new AdvancedOracleMock();

// 2. 초기 설정
oracle.setAll(
    1e36,      // price: 1:1
    0.05e18,   // kimchi premium: 5%
    0.8e18     // custom metric: 0.8
);

// 3. 마켓 생성 및 청산 테스트
// ... (테스트 코드)

// 4. 김치 프리미엄 변경 테스트
oracle.setKimchiPremium(0.02e18); // 2%로 하락
```

## 📝 이벤트

CustomMorpho는 다음 이벤트를 발생시킵니다:

```solidity
event SetKimchiPremiumThreshold(uint256 newThreshold);
event SetCustomMetricThreshold(uint256 newThreshold);
event SetCustomLiquidationBonus(Id indexed id, uint256 bonus);
event KimchiPremiumLiquidation(Id indexed id, address indexed borrower, uint256 premium);
event CustomMetricLiquidation(Id indexed id, address indexed borrower, uint256 metric);
```

## 💡 실전 팁

1. **임계값 시작은 보수적으로**: 처음엔 높은 임계값(5-10%)으로 시작하고 점차 조정
2. **모니터링**: 청산 이벤트를 모니터링하여 어떤 조건으로 청산되는지 추적
3. **백테스트**: 과거 데이터로 임계값 테스트
4. **긴급 중지**: 문제 발생 시 `setKimchiPremiumEnabled(false)`로 즉시 비활성화

## 📞 문의

이슈가 있거나 개선 제안이 있으시면 GitHub Issues에 올려주세요!
