#!/usr/bin/env node

/**
 * GraphQL Codegen Wrapper Script
 * 
 * SKIP_CODEGEN=true 환경 변수가 설정되면 codegen을 스킵합니다.
 * 이는 Docker 빌드 타임에 Backend API가 없을 때 사용됩니다.
 */

if (process.env.SKIP_CODEGEN === 'true') {
  console.log('✓ Skipping GraphQL Codegen (SKIP_CODEGEN=true)');
  console.log('  Using existing generated types from source code');
  process.exit(0);
}

const { execSync } = require('child_process');
const path = require('path');

try {
  console.log('→ Running GraphQL Codegen...');
  
  // codegen.ts가 있는 디렉토리로 이동
  const codegenDir = path.join(__dirname, '..');
  
  execSync('graphql-codegen --config ./codegen.ts --project saleor', {
    stdio: 'inherit',
    cwd: codegenDir,
    env: process.env
  });
  
  console.log('✓ Codegen completed successfully');
} catch (error) {
  console.error('✗ Codegen failed:', error.message);
  process.exit(1);
}

