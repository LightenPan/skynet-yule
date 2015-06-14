
¸
profilesvr.protoprofilesvr_protos"F
UserInfo
user_id (
nick (
level (
edge ("!
GetUserInfoReq
user_id ("`
GetUserInfoRsp
result (
errmsg (.
	user_info (2.profilesvr_protos.UserInfo"³

PlayerInfo
user_id (
score (
	video_url (
pic_url (
video_start_time (
video_file_size (
video_times (
video_upload_time ("z
	MatchInfo
match_id (
win_user_id (

match_time (2
player_info (2.profilesvr_protos.PlayerInfo"M
GetUserMatchInfoListReq
user_id (
page_id (
per_page ("k
GetUserMatchInfoListRsp
result (
errmsg (0

match_info (2.profilesvr_protos.MatchInfo"#
GetMatchInfoReq
match_id ("c
GetMatchInfoRsp
result (
errmsg (0

match_info (2.profilesvr_protos.MatchInfo"=
ManiContent
type (
	voice_url (
words ("N
SendMatchManifestoReq
uuid (
	mani_type (
mani_content ("E
SendMatchManifestoRsp
result (
errmsg (
uuid ("9
QueryMatchManifestoReq
uuid (
	mani_type ("\
QueryMatchManifestoRsp
result (
errmsg (
uuid (
mani_content ("’
PKUserGameInfo
user_id (
game_id (
	user_name (
nick (
level (
btval (
edge (
	game_name ("8
GetPKUserGameInfoReq
user_id (
game_id ("g
GetPKUserGameInfoRsp
result (
errmsg (/
info (2!.profilesvr_protos.PKUserGameInfo*
CMD_DEF
CMD_PROFILESVR„*Î

SUBCMD_DEF
SUBCMD_GET_USER_INFO#
SUBCMD_GET_USER_MATCH_INFO_LIST
SUBCMD_GET_MATCH_INFO
SUBCMD_SEND_MATCH_MANIFESTO 
SUBCMD_QUERY_MATCH_MANIFESTO#
SUBCMD_PK_SELECT_USER_GAME_INFOB4
 com.shoushi.yld.base.protocol.pbBProfileSvrProtos