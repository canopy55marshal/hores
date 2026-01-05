# 赛马游戏部署到 GitHub Pages

## 快速部署
1. 在 GitHub 新建一个公开仓库（例如 horses-game）
2. 在本地执行：
   - `git init`
   - `git add .`
   - `git commit -m "deploy to GitHub Pages"`
   - `git branch -M main`
   - `git remote add origin https://github.com/<YOUR_USERNAME>/<YOUR_REPO>.git`
   - `git push -u origin main`
3. Pages 会通过工作流自动发布，几分钟后即可访问：
   - `https://<YOUR_USERNAME>.github.io/<YOUR_REPO>/` （首页跳转到 preview.html）

## 说明
- 本仓库已包含：
  - `index.html`：跳转到 `preview.html`
  - `.nojekyll`：禁用 Jekyll 处理，确保 assets 资源路径正常
  - `.github/workflows/pages.yml`：GitHub Actions 自动部署到 Pages

## 可选
- 自定义域名：在仓库 Settings → Pages 绑定域名，并在 DNS 配置 CNAME。
