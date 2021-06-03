#!/bin/bash
# 毎日1回実行

# =================================================================================================
# 定数設定
# =================================================================================================

# スクリプトログ関係
LOG_LEVEL='DEBUG'
IMPORT_LOG_FILE='import.log' # インポートのログファイル名
EXPORT_LOG_FILE='export.log' # エクスポートのログファイル名
script_name='script_log_rotate.sh' # 実行スクリプト名

# =================================================================================================
# 変数設定
# =================================================================================================

current_time=$(date "+%Y%m%d") # 現在時刻
yesterday=$(date "+%Y%m%d" --date "1 day ago") # 昨日の日付
mid_host=$(hostname) # MIDサーバーのホスト名

# =================================================================================================
# 関数設定
# =================================================================================================

# ディレクトリ設定の関数
function dir_setting {

    # 検証環境MID1
    if [ $mid_host = 'st-ty1-snow-cmdb-mid01' ] ; then
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid1/' # 【開発】ログのディレクトリ
        EXPORT_DIR='/servicenow/st-ty1-snow-cmdb-mid01/agent/export/radius_guard/'

    # 検証環境MID2
    elif [ $mid_host = 'st-ty1-snow-cmdb-mid02' ] ; then
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid2/' # 【開発】ログのディレクトリ
        EXPORT_DIR='/servicenow/st-ty1-snow-cmdb-mid02/agent/export/radius_guard/'

    # 本番環境MID1
    elif [ $mid_host = 'ty1-snow-cmdb-mid01' ] ; then
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid1/' # 【本番】ログのディレクトリ
        EXPORT_DIR='/servicenow/ty1-snow-cmdb-mid01/agent/export/radius_guard/'

    # 本番環境MID2
    elif [ $mid_host = 'ty1-snow-cmdb-mid02' ] ; then
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid2/' # 【本番】ログのディレクトリ
        EXPORT_DIR='/servicenow/ty1-snow-cmdb-mid02/agent/export/radius_guard/'

    else
        echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$script_name] [ホスト名を判定できませんでした。${script_name}を終了します。]"
        exit 1
    fi

    CNADD_DIR="${EXPORT_DIR}cnadd"
    CNDEL_DIR="${EXPORT_DIR}cndel"
    MACADD_DIR="${EXPORT_DIR}macadd"
    MACDEL_DIR="${EXPORT_DIR}macdel"

}

# ログを出力する関数
# infoのログ
function log_info {
  echo "$(date "+%Y%m%d%H%M%S") [DEBUG] [$script_name] [${1}]" >> $LOG_DIR$IMPORT_LOG_FILE
  echo "$(date "+%Y%m%d%H%M%S") [DEBUG] [$script_name] [${1}]" >> $LOG_DIR$EXPORT_LOG_FILE
}
# debugのログ
function log_debug {
  if [ $LOG_LEVEL = 'DEBUG' ] ; then
  echo "$(date "+%Y%m%d%H%M%S") [DEBUG] [$script_name] [${1}]" >> $LOG_DIR$IMPORT_LOG_FILE
  echo "$(date "+%Y%m%d%H%M%S") [DEBUG] [$script_name] [${1}]" >> $LOG_DIR$EXPORT_LOG_FILE
  fi
}
# errorのログ
function log_error {
  echo "$(date "+%Y%m%d%H%M%S") [DEBUG] [$script_name] [${1}]" >> $LOG_DIR$IMPORT_LOG_FILE
  echo "$(date "+%Y%m%d%H%M%S") [DEBUG] [$script_name] [${1}]" >> $LOG_DIR$EXPORT_LOG_FILE
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
# スクリプトログのローテート
if [ -f ${LOG_DIR}${IMPORT_LOG_FILE} ] || [ -f ${LOG_DIR}${EXPORT_LOG_FILE} ] ; then
  log_debug "スクリプトログファイルのファイル名を変更しました。"

  # log1/import.log
  if [ -f ${LOG_DIR}${IMPORT_LOG_FILE} ] ; then
    cd $LOG_DIR
    mv $IMPORT_LOG_FILE "import_${yesterday}.log"
    if [[ -n $(ls -r | grep "import_" | tail -n +15) ]]; then # importログ15件目以降が存在したら実行
      log_debug "importログファイルをローテートします。"
      rm $(ls -r | grep "import_" | tail -n +15) # 15件目以降を削除
    fi
  fi
  # log1/export.log
  if [ -f ${LOG_DIR}${EXPORT_LOG_FILE} ] ; then
    cd $LOG_DIR
    mv $EXPORT_LOG_FILE "export_${yesterday}.log"
    if [[ -n $(ls -r | grep "export_" | tail -n +15) ]]; then # 15件目以降が存在したら実行
      log_debug "exportログファイルをローテートします。"
      rm $(ls -r | grep "export_" | tail -n +15) # 15件目以降を削除
    fi
  fi
fi
