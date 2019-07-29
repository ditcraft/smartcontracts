#!/bin/bash

cd contracts
abigen --sol KNWToken.sol --pkg KNWToken --out KNWToken.go
abigen --sol KNWVoting.sol --pkg KNWVoting --out KNWVoting.go
abigen --sol ditCoordinator.sol --pkg ditCoordinator --out ditCoordinator.go
cp libraries/SafeMath.sol demo_contracts/SafeMath.sol
cd demo_contracts
cp ditDemoCoordinator.sol ditDemoCoordinator_abigen.sol
cp ditToken.sol ditToken_abigen.sol
sed -i '' 's/..\/libraries\/SafeMath.sol/.\/SafeMath.sol/g' *_abigen.sol
abigen --sol ditDemoCoordinator_abigen.sol --pkg ditDemoCoordinator --out ditDemoCoordinator.go
abigen --sol ditToken_abigen.sol --pkg ditToken --out ditToken.go
rm *_abigen.sol SafeMath.sol
mv *.go ../../contracts
cd ../..
mkdir abigen_out
mv contracts/*.go abigen_out