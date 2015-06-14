
à	
Account.protoyldapp_protos"S
RegiestAccountReq
account_type (
account_name (

passwd_md5 ("O
RegiestAccountRsp
result (
errmsg (
uuid (
flag ("Z
AuthData
account_type (
account_name (
	timestamp (
md5_pwd ("`
GetTokenReq
account_type (
account_name (
	auth_data (

is_tourist ("\
GetTokenRsp
result (
uuid (
errmsg (
auth_key (
token ("t
ResetPasswordReq
account_type (
account_name (
pwd_md5 (
	auth_data (
sms_code ("2
ResetPasswordRsp
result (
errmsg ("L
AllocSsidReq
clientip (
machine_type (
machine_code ("<
AllocSsidRsp
result (
errmsg (
ssid (*
ACCOUNT_CMD
CMD_ACCOUNT€*t
ACCOUNT_SUBCMD
SUBCMD_REGIEST_ACCOUNT
SUBCMD_GET_TOKEN
SUBCMD_RESET_PASSWARD
SUBCMD_ALLOC_SSID*—
AccountType
AccountType_SSID
AccountType_SsName
AccountType_QQ
AccountType_WeXin
AccountType_WeiBo
AccountType_PhoneNum*i
MachineType
MachineType_Android
MachineType_iOS
MachineType_Web
MachineType_WindowsB,
com.shoushi.net.protocol.pbBAccountProtos