#!/bin/bash
# 毎日0:00に実行

# =================================================================================================
# 定数設定
# =================================================================================================

# ディレクトリ、ファイル関係
## 【開発・本番共通】
TARGET_DIR='/home/eimuser/import/' 

# スクリプトログ関係
LOG_LEVEL='DEBUG'
LOG_FILE='import.log' # ログファイル名
script_name='eim_dir_delete.sh' # 実行スクリプト名

# =================================================================================================
# 変数設定
# =================================================================================================

current_time_1=$(date "+%Y%m%d%H%M%S") # 現在時刻
mid_host=$(hostname) # MIDサーバーのホスト名

# =================================================================================================
# 関数設定
# =================================================================================================

# ディレクトリ設定の関数
function dir_setting {

    # 検証環境MID1
    if [ $mid_host = 'st-ty1-snow-cmdb-mid01' ] ; then
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid1/' # 【開発】ログのディレクトリ

    # 検証環境MID2
    elif [ $mid_host = 'st-ty1-snow-cmdb-mid02' ] ; then
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid2/' # 【開発】ログのディレクトリ

    # 本番環境MID1
    elif [ $mid_host = 'ty1-snow-cmdb-mid01' ] ; then
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid1/' # 【本番】ログのディレクトリ

    # 本番環境MID2
    elif [ $mid_host = 'ty1-snow-cmdb-mid02' ] ; then
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid2/' # 【本番】ログのディレクトリ

    else
        echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$script_name] [ホスト名を判定できませんでした。${script_name}を終了します。]"
        exit 1
    fi

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

# =================================================================================================
# メイン処理
# =================================================================================================

# ディレクトリ設定
dir_setting
# ログのディレクトリが存在しているか
sc_log_dir_check

log_info "${script_name}を開始します。"

rm -f $TARGET_DIR*
log_debug "${TARGET_DIR}以下を削除しました。"

log_info "${script_name}を終了します。"