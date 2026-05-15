#!/bin/bash
mkdir -p test_dir
for i in {1..2000}; do
  touch test_dir/file_$i.sh
done

echo "Benchmarking old command..."
time find test_dir -type f -name "*.sh" -exec chmod +x {} \;

for i in {1..2000}; do
  chmod -x test_dir/file_$i.sh
done

echo "Benchmarking new command..."
time find test_dir -type f -name "*.sh" -exec chmod +x {} +

rm -rf test_dir
