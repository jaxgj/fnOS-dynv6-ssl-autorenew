#!/bin/bash
# FnOS dynv6 SSL全自动证书部署脚本
# 适配飞牛OS，dynv6域名专用，基于acme.sh开源工具
# 示例域名：xxxx.dynv6.net
# 运行要求：root(#)权限执行

# 校验root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m错误：必须切换为root(#)超级权限才能执行本脚本！\033[0m"
    exit 1
fi

clear
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m      FnOS dynv6 SSL全自动证书部署工具      \033[0m"
echo -e "\033[32m=============================================\033[0m"
echo ""

# 交互式录入基础信息
read -p "请输入你的dynv6完整域名（示例：xxxx.dynv6.net）: " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "域名不能为空，脚本退出"
    exit 1
fi

read -p "请输入dynv6后台API Token密钥: " DYNV6_TOKEN
if [ -z "$DYNV6_TOKEN" ]; then
    echo "dynv6 Token不能为空，脚本退出"
    exit 1
fi

read -p "请输入接收证书过期提醒的邮箱地址: " MAIL
if [ -z "$MAIL" ]; then
    echo "提醒邮箱不能为空，脚本退出"
    exit 1
fi

echo ""
# 证书导出存储路径交互逻辑
DEFAULT_BASE="/vol1/1000"
DEFAULT_FOLDER="ssl_${DOMAIN}"
DEFAULT_DOWNLOAD="${DEFAULT_BASE}/${DEFAULT_FOLDER}"

if [ -d "${DEFAULT_BASE}" ]; then
    read -p "请输入证书导出存放路径（默认：${DEFAULT_DOWNLOAD}，直接回车使用默认路径）: " INPUT_DOWNLOAD
    if [ -z "${INPUT_DOWNLOAD}" ]; then
        DOWNLOAD_CERT="${DEFAULT_DOWNLOAD}"
    else
        DOWNLOAD_CERT="${INPUT_DOWNLOAD}"
    fi
else
    echo -e "\033[33m警告：默认根目录 ${DEFAULT_BASE} 不存在，请手动输入可用的完整存储路径\033[0m"
    read -p "证书导出完整存放路径: " DOWNLOAD_CERT
    if [ -z "${DOWNLOAD_CERT}" ]; then
        echo "路径不能为空，脚本退出"
        exit 1
    fi
fi

echo ""
echo -e "\033[34m【1/8】安装/升级官方 acme.sh 证书工具\033[0m"
# 安装或升级acme.sh
if [ ! -f "/root/.acme.sh/acme.sh" ]; then
    curl https://get.acme.sh | sh -s email=$MAIL
else
    /root/.acme.sh/acme.sh --upgrade
fi
# 创建全局软链接，任意目录可直接调用acme.sh
ln -sf /root/.acme.sh/acme.sh /usr/local/bin/acme.sh

echo -e "\033[34m【2/8】配置Let's Encrypt证书机构、持久保存dynv6密钥\033[0m"
acme.sh --set-default-ca --server letsencrypt
acme.sh --register-account -m $MAIL
echo "DYNV6_TOKEN='$DYNV6_TOKEN'" >> /root/.acme.sh/account.conf
export DYNV6_TOKEN="$DYNV6_TOKEN"

echo -e "\033[34m【3/8】申请泛域名SSL证书（等待10分钟DNS解析生效）\033[0m"
acme.sh --issue \
--dns dns_dynv6 \
-d $DOMAIN \
-d *.$DOMAIN \
--dnssleep 600 \
--force

# 校验证书是否生成成功
SRC_CERT_PATH="/root/.acme.sh/${DOMAIN}_ecc"
if [ ! -f "${SRC_CERT_PATH}/fullchain.cer" ] || [ ! -f "${SRC_CERT_PATH}/${DOMAIN}.key" ]; then
    echo -e "\033[31m证书申请失败！请检查dynv6 Token、网络后重新运行脚本\033[0m"
    exit 1
fi

echo -e "\033[34m【4/8】导出全部证书文件到指定目录，用于飞牛网页上传\033[0m"
mkdir -p $DOWNLOAD_CERT
cp ${SRC_CERT_PATH}/fullchain.cer ${DOWNLOAD_CERT}/
cp ${SRC_CERT_PATH}/${DOMAIN}.key ${DOWNLOAD_CERT}/
cp ${SRC_CERT_PATH}/${DOMAIN}.crt ${DOWNLOAD_CERT}/
cp ${SRC_CERT_PATH}/ca.cer ${DOWNLOAD_CERT}/issuer_certificate.crt

echo "所有证书文件已导出至目录：$DOWNLOAD_CERT"
echo -e "\033[36m===== 目录内文件用途说明 =====\033[0m"
echo -e "① fullchain.cer        完整证书（域名+内置中间证书链，【必须上传】）"
echo -e "② ${DOMAIN}.key        私钥文件（【必须上传】）"
echo -e "③ ${DOMAIN}.crt        单域名裸证书（禁止上传，不含证书链）"
echo -e "④ issuer_certificate.crt 独立中间证书（可选上传）"
echo ""
echo -e "\033[0m网页上传操作路径：飞牛后台 → 系统设置 → 安全性 → SSL证书 → 新增证书"
echo -e "\033[32m推荐最简上传方案（新手首选）：\033[0m"
echo "证书文件选择 fullchain.cer，私钥文件选择 ${DOMAIN}.key，中间证书输入框留空，直接保存"
echo -e "\033[33m兼容老旧设备方案：\033[0m"
echo "证书+私钥同上，额外将 issuer_certificate.crt 填入中间证书栏后保存"
echo ""
echo -e "\033[33m==================== 等待手动上传证书 ====================\033[0m"
read -p "完成飞牛网页证书新增并保存后，按下回车继续自动部署流程"

echo -e "\033[34m【5/8】自动检索飞牛网页上传生成的数字ID证书目录\033[0m"
BASE_SSL_DIR="/usr/trim/var/trim_connect/ssls/${DOMAIN}"
FN_SSL_DIR=$(ls -d ${BASE_SSL_DIR}/[0-9]* 2>/dev/null | head -n1)
if [ -z "$FN_SSL_DIR" ]; then
    echo -e "\033[31m未检测到对应域名证书目录！确认已在网页后台保存证书条目\033[0m"
    exit 1
fi
echo "自动识别飞牛证书永久存储路径：$FN_SSL_DIR"
mkdir -p $FN_SSL_DIR

echo -e "\033[34m【6/8】绑定自动续期逻辑：自动替换证书+更新数据库+重启服务\033[0m"
acme.sh --install-cert -d $DOMAIN \
--fullchain-file ${FN_SSL_DIR}/fullchain.crt \
--key-file ${FN_SSL_DIR}/${DOMAIN}.key \
--cert-file ${FN_SSL_DIR}/${DOMAIN}.crt \
--ca-file ${FN_SSL_DIR}/issuer_certificate.crt \
--reloadcmd "
EXPIRE_TS=\$(date -d \"\$(openssl x509 -enddate -noout -in ${FN_SSL_DIR}/fullchain.crt | cut -d= -f2)\" +%s000)
NOW_TS=\$(date +%s000)
psql -U postgres -d trim_connect -c \"UPDATE cert SET valid_to=\$EXPIRE_TS, updated_time=\$NOW_TS WHERE domain='${DOMAIN}';\"
systemctl restart network_service trim_nginx webdav smbftpd
echo 续期完成：证书同步至飞牛系统目录、数据库有效期刷新、服务已重载
"

echo -e "\033[34m【7/8】安全加固：锁定证书、密钥配置文件权限\033[0m"
chmod -R 700 /root/.acme.sh
chmod 600 /root/.acme.sh/*.conf

echo -e "\033[34m【8/8】校验系统自动定时续期任务\033[0m"
crontab -l
echo ""
echo -e "\033[32m=============================================\033[0m"
echo -e "\033[32m            全部部署流程执行完成！            \033[0m"
echo -e "\033[32m=============================================\033[0m"
echo "1. 自动续期规则：证书剩余有效期 ≤30天自动发起续签"
echo "2. 每日凌晨0点以root账号自动检测证书状态"
echo "3. 续期后自动覆盖飞牛路径：$FN_SSL_DIR"
echo ""
echo "日常维护常用命令："
echo "  模拟每日自动检测任务：acme.sh --cron"
echo "  查看当前证书到期时间：openssl x509 -in ${FN_SSL_DIR}/fullchain.crt -dates -noout"
echo "  强制手动测试完整续证流程：acme.sh --renew -d $DOMAIN --force"
echo -e "\033[32m=============================================\033[0m"
