# FnOS 飞牛OS dynv6 SSL 全自动续证一键脚本
解决飞牛OS原生不支持 dynv6 DDNS 自动SSL续期痛点｜开源可审计｜一次配置永久自动续签

仓库地址：https://github.com/jaxgj/fnOS-dynv6-ssl-autorenew
## 📖 项目前言
很多飞牛OS用户使用公网IP+DDNS远程访问NAS，未部署SSL证书会导致传输明文泄露账号密码、文件数据，浏览器持续标记不安全。
免费SSL证书（Let’s Encrypt）有效期仅90天，手动申请、上传、替换流程繁琐，极易遗忘过期导致远程无法访问。
飞牛系统内置证书自动续期仅兼容阿里云、腾讯云、华为云、Cloudflare等厂商，**dynv6 免费动态域名无官方适配方案**。

本脚本基于开源 acme.sh 深度适配FnOS，一条命令完成全套部署，到期前30天自动续签，自动同步系统证书、更新数据库、重启服务，全程无需人工干预。

## ✅ 核心功能
1. 自动安装/升级官方原版 acme.sh，无第三方篡改
2. 一键申请主域名 + 泛域名 `*.xxx.dynv6.net` ECC加密证书
3. 证书导出目录自定义，默认 `/vol1/1000/ssl_域名`，磁盘不存在则强制手动输入路径
4. 导出全套4份证书文件，清晰区分必传/可选/禁止上传文件
5. 自动检索飞牛网页上传生成的数字ID证书目录，无需手动查找路径
6. 续期后自动覆盖系统证书目录、更新PostgreSQL证书有效期时间戳
7. 自动重启 network_service / trim_nginx / webdav / smbftpd 服务，证书实时生效
8. root定时任务每日自动检测证书状态，剩余30天自动续签
9. 自动锁定密钥、配置文件权限，保护dynv6 Token与私钥安全

## 🧩 支持域名范围
- ✅ 完全支持：所有 dynv6 动态域名（xxxx.dynv6.net）

## 🚀 一键部署命令（国内CDN加速，无访问墙）
### 方式1：一键下载并直接运行（推荐小白）
SSH登录飞牛NAS，切换至 root(#) 权限后执行：
```bash
curl -fsSL https://cdn.jsdelivr.net/gh/jaxgj/fnOS-dynv6-ssl-autorenew@main/autorenew.sh | bash
