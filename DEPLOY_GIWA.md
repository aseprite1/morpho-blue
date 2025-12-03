# Morpho Blue - 기와체인 배포 가이드

## 사전 준비

### 1. Foundry 설치
```bash
# Windows PowerShell
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 의존성 설치
```bash
cd morpho-blue
forge install
yarn install  # 또는 npm install
```

### 3. 환경 변수 설정
`.env.example` 파일을 복사하여 `.env` 파일을 생성하고 실제 값으로 채웁니다:

```bash
cp .env.example .env
```

`.env` 파일에서 다음 값들을 설정하세요:
- `GIWA_RPC_URL`: 기와체인 RPC 엔드포인트
- `PRIVATE_KEY`: 배포자 계정의 프라이빗 키 (0x 접두사 없이)
- `OWNER_ADDRESS`: Morpho Blue 컨트랙트의 오너 주소
- `CHAIN_ID`: 기와체인의 체인 ID

## 배포 전 확인사항

### 1. 컴파일 테스트
```bash
forge build
```

### 2. 테스트 실행 (선택사항)
```bash
yarn test:forge
```

### 3. 배포자 계정 잔액 확인
배포자 계정에 충분한 가스비(네이티브 토큰)가 있는지 확인하세요.

## 배포 방법

### 방법 1: Forge Script 사용 (권장)

```bash
# Dry run (시뮬레이션)
forge script script/DeployMorpho.s.sol:DeployMorpho \
  --rpc-url $GIWA_RPC_URL \
  --private-key $PRIVATE_KEY

# 실제 배포
forge script script/DeployMorpho.s.sol:DeployMorpho \
  --rpc-url $GIWA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --chain-id $CHAIN_ID

# 검증 없이 배포 (블록 익스플로러가 없는 경우)
forge script script/DeployMorpho.s.sol:DeployMorpho \
  --rpc-url $GIWA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --chain-id $CHAIN_ID
```

### 방법 2: Forge Create 사용

```bash
forge create \
  --rpc-url $GIWA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args $OWNER_ADDRESS \
  src/Morpho.sol:Morpho
```

### 방법 3: .env 파일 자동 로드

```bash
# .env 파일을 자동으로 로드하여 배포
source .env
forge script script/DeployMorpho.s.sol:DeployMorpho \
  --rpc-url $GIWA_RPC_URL \
  --broadcast
```

## 배포 후 확인

### 1. 배포된 컨트랙트 주소 확인
배포 후 터미널에 출력된 컨트랙트 주소를 기록하세요.

### 2. 컨트랙트 검증 (블록 익스플로러가 있는 경우)
```bash
forge verify-contract \
  --chain-id $CHAIN_ID \
  --compiler-version v0.8.19 \
  --optimizer-runs 999999 \
  <DEPLOYED_ADDRESS> \
  src/Morpho.sol:Morpho \
  --constructor-args $(cast abi-encode "constructor(address)" $OWNER_ADDRESS)
```

### 3. 컨트랙트 상태 확인
```bash
# Owner 주소 확인
cast call <DEPLOYED_ADDRESS> "owner()(address)" --rpc-url $GIWA_RPC_URL
```

## 트러블슈팅

### Gas 부족 에러
- 배포자 계정에 충분한 네이티브 토큰이 있는지 확인
- Gas price를 수동으로 설정: `--gas-price <price>`

### RPC 연결 실패
- RPC URL이 올바른지 확인
- 네트워크 연결 상태 확인
- 방화벽 설정 확인

### Nonce 에러
- 이전 트랜잭션이 완료될 때까지 대기
- 또는 nonce를 수동으로 설정: `--nonce <nonce>`

### 컴파일 에러
```bash
# 캐시 정리 후 재빌드
forge clean
forge build
```

## 보안 주의사항

⚠️ **중요**:
- `.env` 파일을 절대 Git에 커밋하지 마세요
- 프라이빗 키를 안전하게 보관하세요
- 가능하면 하드웨어 지갑이나 Ledger를 사용하세요
- 메인넷 배포 전 테스트넷에서 충분히 테스트하세요

## 추가 리소스

- Foundry Book: https://book.getfoundry.sh/
- Morpho Blue Docs: https://docs.morpho.org/
