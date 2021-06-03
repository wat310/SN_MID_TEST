#!/bin/bash
# 前回のファイルが存在した場合、差分ファイルを作成する

# =================================================================================================
# 定数設定
# =================================================================================================

# ServiceNow関係
snow_account_user='dev_auth' # 【開発・本番】ユーザー
snow_account_pass='dev_auth' # 【開発・本番】パスワード
table_name='x_ritsc_a200002102_import_perfect_finder' # 【開発・本番】テーブル名

# ディレクトリ、ファイル関係
IMPORT_DIR='/home/pfuser/import/' # 【開発・本番】移動元のディレクトリ
ORIGIN_FILE='pf_update.csv' # 【開発・本番】送信元のファイル

# スクリプトログ関係
LOG_LEVEL='DEBUG'
LOG_FILE='import.log' # ログファイル名
script_name='pf_diff.sh' # 実行スクリプト名

# メール関係
MAIL_FROM='notification@now.staff.ricoh.com' # メールの送信元
MAIL_TO='zjp_deviceauth_snow_admin@jp.ricoh.com rfgricohdev01@service-now.com' # メールの送信先

# =================================================================================================
# 変数設定
# =================================================================================================

current_time=$(date "+%Y%m%d%H%M%S") # 現在時刻
SNOW_FILE="pf_diff_$current_time.csv" # 出力ファイル名

# ファイル識別用正規表現
file_pattern_edit=^origin_edit_[0-9]{14}\.csv$ # origin_edit

# メール設定
mid_host=$(hostname) # MIDサーバーのホスト名

# =================================================================================================
# 関数設定
# =================================================================================================

# ディレクトリ設定の関数
function dir_setting {

    # 検証環境MID1
    if [ $mid_host = 'st-ty1-snow-cmdb-mid01' ] ; then
        # ServiceNow関係
        snow_url='https://rfgricohdev01.service-now.com' # 【開発】ServiceNowのURL
        upload_path='@/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/pfuser/import/servicenow/' # 【開発】アップロードファイルのパス
        # ディレクトリ、ファイル関係
        EXPORT_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/pfuser/import' 
        # スクリプトログ関係
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid1/' # 【開発】ログのディレクトリ

    # 検証環境MID2
    elif [ $mid_host = 'st-ty1-snow-cmdb-mid02' ] ; then
        # ServiceNow関係
        snow_url='https://rfgricohdev01.service-now.com' # 【開発】ServiceNowのURL
        upload_path='@/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/pfuser/import/servicenow/' # 【開発】アップロードファイルのパス
        # ディレクトリ、ファイル関係
        EXPORT_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/pfuser/import' 
        # スクリプトログ関係
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid2/' # 【開発】ログのディレクトリ

    # 本番環境MID1
    elif [ $mid_host = 'ty1-snow-cmdb-mid01' ] ; then
        # ServiceNow関係
        snow_url='https://rfgricoh.service-now.com' # 【本番】ServiceNowのURL
        upload_path='@/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/pfuser/import/servicenow/' # 【本番】アップロードファイルのパス
        # ディレクトリ、ファイル関係
        EXPORT_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/pfuser/import' 
        # スクリプトログ関係
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid1/' # 【本番】ログのディレクトリ

    # 本番環境MID2
    elif [ $mid_host = 'ty1-snow-cmdb-mid02' ] ; then
        # ServiceNow関係
        snow_url='https://rfgricoh.service-now.com' # 【本番】ServiceNowのURL
        upload_path='@/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/pfuser/import/servicenow/' # 【本番】アップロードファイルのパス
        # ディレクトリ、ファイル関係
        EXPORT_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/pfuser/import' 
        # スクリプトログ関係
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid2/' # 【本番】ログのディレクトリ

    else
        echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$script_name] [ホスト名を判定できませんでした。${script_name}を終了します。]"
        exit 1
    fi

    DATA_DIR="${EXPORT_DIR}/job/" # 作業用ディレクトリ
    ORIGIN_DIR="${EXPORT_DIR}/job/origin/" # IMPORT_DIRに配置されたファイルの移動先
    DIFF_DIR="${EXPORT_DIR}/servicenow/" # diffファイルのディレクトリ(ServiceNowへ送るファイルの配置先)
}

# ログを出力する関数
# infoのログ
function log_info {
  echo "$(date "+%Y%m%d%H%M%S") [INFO] [$script_name] [${1}]" >> $LOG_DIR$LOG_FILE
}
# debugのログ
function log_debug {
  if [ $LOG_LEVEL = 'DEBUG' ] ; then
    echo "$(date "+%Y%m%d%H%M%S") [DEBUG] [$script_name] [${1}]" >> $LOG_DIR$LOG_FILE
  fi
}
# errorのログ
function log_error {
  echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$script_name] [${1}]" >> $LOG_DIR$LOG_FILE
}

# ディレクトリのエラー発生時
function dir_log {
  log_error "${1}が存在しません。"
  log_debug "${1}を作成します。"
}

# スクリプトログのディレクトリの存在確認
function sc_log_dir_check {
  log_message=""
  if [ ! -d $LOG_DIR ] ; then
    mkdir -p $LOG_DIR
    log_message=$LOG_DIR
  fi
  if [ -n "$log_message" ] ; then
    dir_log $log_message
  fi
}

# ディレクトリが存在しないときの関数
function error_dir {
  dir_log ${1}
  mkdir -p ${1}
}

# ローテート用の関数
function remove_files () {
  if [[ -n $(ls -1F -r | grep -v / | tail -n +4) ]] ; then # 4件目以降が存在したら実行
    log_debug "${1}の${2}ファイルをローテートします。"
    rm $(ls -1F -r | grep -v / | tail -n +4) # 4件目以降を削除
  fi
}

# メール通知
function send_mail {
  echo "${1}" | mail -s "${2}" -r $MAIL_FROM $MAIL_TO
}

# =================================================================================================
# メイン処理
# =================================================================================================

# ディレクトリ設定
dir_setting
# # ログのディレクトリが存在しているか
sc_log_dir_check

log_info "${script_name}を開始します。"

[[ -e $ORIGIN_DIR ]] || error_dir $ORIGIN_DIR
[[ -e $DATA_DIR ]] || error_dir $DATA_DIR
[[ -e $DIFF_DIR ]] || error_dir $DIFF_DIR

# importディレクトリのファイルをoriginディレクトリに移動
log_debug "${IMPORT_DIR}の${ORIGIN_FILE}を${ORIGIN_DIR}pf_update_${current_time}.csvにコピーします。"
if [ -f ${IMPORT_DIR}${ORIGIN_FILE} ];then
    mv $IMPORT_DIR$ORIGIN_FILE "${ORIGIN_DIR}pf_update_${current_time}.csv"
else
    log_debug "${IMPORT_DIR}${ORIGIN_FILE}が存在しません。スクリプトを終了します。"
    exit 1
fi

cp -p "${ORIGIN_DIR}pf_update_${current_time}.csv" $DIFF_DIR$SNOW_FILE

# 差分ファイルをServiceNowへインポート
log_debug "差分ファイルをServiceNowへインポートします。"
retry_count=0
# スクリプトを置いたMIDのログに飛ばす
until curl -f -i --request POST --header "Accept:application/json" --user $snow_account_user:$snow_account_pass -F "upload=$upload_path$SNOW_FILE" $snow_url/sys_import.do?sysparm_import_set_tablename=$table_name\&sysparm_transform_after_load=true | grep "200 OK" >> $LOG_DIR$LOG_FILE ; do
    sleep 60
    retry_count=$(( retry_count + 1 ))
    if [[ retry_count -eq 3 ]] ; then
        log_error "ServiceNowへcurlコマンドを実行できませんでした。"
        # メール通知
        send_mail "ServiceNowへcurlコマンドを実行できませんでした。" "【CURLエラー】デバイス認証 ${mid_host} ${script_name}"
        break
    fi
done

# インポートした差分ファイルを削除(ORIGIN_DIRのファイルと中身は同じ)
cd $DIFF_DIR

log_debug "インポート済みの差分ファイルを削除します。"
ls | grep "pf_diff_" | grep ".csv" | xargs rm

log_info "${script_name}を終了します。"