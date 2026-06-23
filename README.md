# 文件名：README.md

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
- ❌ 不支持：FreeDNS 共享二级域名（bot.nu / mooo.com）服务商API限制，无法全自动TXT验证
- 其他域名（Cloudflare/阿里云DNSPod/华为云）如需兼容，可提Issue获取多服务商改造版本

## 🚀 一键部署命令（国内CDN加速，无访问墙）
### 方式1：一键下载并直接运行（推荐小白）
SSH登录飞牛NAS，切换至 root(#) 权限后执行：
```bash
curl -fsSL https://cdn.jsdelivr.net/gh/jaxgj/fnOS-dynv6-ssl-autorenew@main/fn_ssl_auto.sh | bash
```

### 方式2：下载到本地，查看源码后手动执行（安全审计推荐）
```bash
# 下载脚本到本地
curl -fsSL https://cdn.jsdelivr.net/gh/jaxgj/fnOS-dynv6-ssl-autorenew@main/fn_ssl_auto.sh -o fn_ssl_auto.sh
# 查看完整源码，确认无后门
cat fn_ssl_auto.sh
# 添加执行权限并运行
chmod +x fn_ssl_auto.sh
./fn_ssl_auto.sh
```

## 📝 完整部署步骤
1. SSH切换root账号，复制上方一键命令执行脚本
2. 根据交互提示依次输入：dynv6完整域名、dynv6后台API Token、证书过期提醒邮箱
3. 证书导出路径直接回车使用默认，或自定义本地存储路径
4. 脚本自动执行DNS验证，等待10分钟生成全套证书文件
5. 进入飞牛后台：系统设置 → 安全性 → SSL证书 → 新增证书
6. 按照脚本提示上传对应证书文件，保存完成后回车继续脚本
7. 脚本自动匹配系统证书目录，绑定自动续期重载逻辑，流程全部结束

## 📂 飞牛后台证书上传规范（新手必看）
脚本导出目录内4个文件，严格区分用途：
1. `fullchain.cer` 【必传证书文件】内置域名证书+完整中间证书链
2. `xxxx.dynv6.net.key` 【必传私钥文件】
3. `xxxx.dynv6.net.crt` 【禁止上传】裸单域名证书，不含证书链，浏览器会报不安全
4. `issuer_certificate.crt` 【可选中间证书】兼容老旧设备，普通用户留空即可

### 最简上传方案（99%用户适用）
证书文件：fullchain.cer
私钥文件：域名.key
中间证书输入框：留空，直接保存

## 🔄 自动续期运行机制
1. root定时任务每日凌晨0点自动执行证书检测
2. 证书剩余有效期 ≤30天，自动发起DNS验证续签90天新证书
3. 签发完成自动覆盖飞牛系统证书存储目录
4. 更新数据库内证书过期时间，后台页面同步刷新有效期
5. 重启系统网关、反向代理、WebDAV服务，无缝切换新证书，无长时间断连

## 🧷 日常维护常用命令
```bash
# 模拟每日定时检测，排查续期故障
acme.sh --cron
```
```bash
# 查看当前系统证书到期时间
openssl x509 -in /usr/trim/var/trim_connect/ssls/你的域名/*/fullchain.crt -dates -noout
```
```bash
# 强制手动完整测试续证流程
acme.sh --renew -d 你的域名 --force
```

## 🔒 安全说明
1. 脚本完全开源托管GitHub，所有人可查看完整源码，无隐藏后门、无数据上传逻辑
2. 证书工具拉取 acme.sh 官方安装地址，不使用第三方修改版本
3. dynv6 Token、域名私钥仅本地存储于 `/root/.acme.sh`，不会上传至任何外部服务器
4. 脚本执行结束自动设置目录权限700、配置文件600，禁止普通用户读取密钥信息

## ❓ 常见问题 FAQ
### Q：普通用户($)执行提示 acme.sh: command not found
A：属于正常现象。自动续期由root定时任务后台运行，不影响全自动续签功能；仅root可完整操作证书工具。

### Q：脚本提示未找到飞牛证书目录，部署中断
A：必须提前在飞牛网页后台「新增证书并点击保存」，系统才会生成带数字ID的证书存储文件夹。

### Q：证书申请超时、验证失败
A：检查dynv6 Token权限、NAS网络能否访问外网，确认域名解析正常后重新运行脚本。

### Q：为什么不支持FreeDNS免费二级域名？
A：FreeDNS官方API限制共享二级域名无法自动创建TXT验证记录，属于服务商硬性限制，无法通过脚本解决。

