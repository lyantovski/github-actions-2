const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const port = process.env.PORT || 80;
const dist = path.join(__dirname, '..', 'dist');

if (fs.existsSync(dist) && fs.statSync(dist).isDirectory()) {
  console.log(`Serving ./dist on port ${port}`);
  execSync(`npx http-server ${dist} -p ${port}`, { stdio: 'inherit' });
} else {
  console.log(`./dist not found, serving project root on port ${port}`);
  execSync(`npx http-server . -p ${port}`, { stdio: 'inherit' });
}
