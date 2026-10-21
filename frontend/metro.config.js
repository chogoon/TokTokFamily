// npm workspaces 모노레포 대응 (Expo 공식 가이드).
// 호이스팅된 루트 node_modules를 Metro가 인식하지 못하면 번들 URL에
// 상대경로(`../node_modules/...`)가 섞여 브라우저의 URL 정규화로 404가 난다.
const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, "..");

const config = getDefaultConfig(projectRoot);

config.watchFolders = [workspaceRoot];
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, "node_modules"),
  path.resolve(workspaceRoot, "node_modules"),
];

module.exports = config;
