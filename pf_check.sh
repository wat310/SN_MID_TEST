#!/bin/bash
# 該当ディレクトリにcsvが存在するか確認する

# =================================================================================================
# 定数設定
# =================================================================================================

# ディレクトリ、ファイル関係
IMPORT_DIR='/home/pfuser/import/' # 【開発・本番】csvを配置するディレクトリ
SCRIPT_DIR='/servicenow/script/' # 【開発・本番】pfのスクリプトを配置するディレクトリ
TARGET_FILE='pf_update.csv'       # 【開発・本番】配置されるファイル

# スクリプトログ関係
LOG_LEVEL='DEBUG'
LOG_FILE='import.log'     # ログファイル名
script_name='pf_check.sh' # 実行スクリプト名

# =================================================================================================
# 変数設定
# =================================================================================================

UPDATE_FILE="$IMPORT_DIR$TARGET_FILE" # ディレクトリパス/ファイル名の形式にする
current_time=$(date "+%Y%m%d%H%M%S")  # 現在時刻
mid_host=$(hostname)                  # MIDサーバーのホスト名

# =================================================================================================
# 関数設定
# =================================================================================================

# ディレクトリ設定の関数
function dir_setting() {

  # 検証環境MID1
  if [ $mid_host = 'st-ty1-snow-cmdb-mid01' ]; then
    LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid1/' # 【開発】ログのディレクトリ

  # 検証環境MID2
  elif [ $mid_host = 'st-ty1-snow-cmdb-mid02' ]; then
    LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid2/' # 【開発】ログのディレクトリ

  # 本番環境MID1
  elif [ $mid_host = 'ty1-snow-cmdb-mid01' ]; then
    LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid1/' # 【本番】ログのディレクトリ

  # 本番環境MID2
  elif [ $mid_host = 'ty1-snow-cmdb-mid02' ]; then
    LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid2/' # 【本番】ログのディレクトリ

  else
    echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$script_name] [ホスト名を判定できませんでした。${script_name}を終了します。]"
    exit 1
  fi

}

# ログを出力する関数
# infoのログ
function log_info() {
  echo "$(date "+%Y%m%d%H%M%S") [INFO] [$script_name] [${1}]" >>$LOG_DIR$LOG_FILE
}
# debugのログ
function log_debug() {
  if [ $LOG_LEVEL = 'DEBUG' ]; then
    echo "$(date "+%Y%m%d%H%M%S") [DEBUG] [$script_name] [${1}]" >>$LOG_DIR$LOG_FILE
  fi
}
# errorのログ
function log_error() {
  echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$script_name] [${1}]" >>$LOG_DIR$LOG_FILE
}

# ディレクトリのエラー発生時
function dir_log() {
  log_error "${1}が存在しません。"
  log_debug "${1}を作成します。"
}

# スクリプトログのディレクトリの存在確認
function sc_log_dir_check() {
  log_message=""
  if [ ! -d $LOG_DIR ]; then
    mkdir -p $LOG_DIR
    log_message=$LOG_DIR
  fi
  if [ -n "$log_message" ]; then
    dir_log $log_message
  fi
}

# ディレクトリが存在しないときの関数
function error_dir() {
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

# importディレクトリが存在しているか
[[ -e $IMPORT_DIR ]] || error_dir $IMPORT_DIR

# ディレクトリの監視(-m:監視を継続、-q:イベント検出以外は出力しない、-e:監視するイベントを限定)
inotifywait -m -q -e create,moved_to $IMPORT_DIR | while read line; do
  log_debug "ファイルの配置を検知しました。1分待機します。" && sleep 1m

  set $line
  file_name=${3} # 監視出力の3番目がファイル名
  log_debug "${IMPORT_DIR}に${file_name}が配置されました。"

  # ファイル名がマッチしたら処理
  if [[ $file_name = $TARGET_FILE ]]; then
    log_debug "${UPDATE_FILE}が配置されたので、pf_diff.shを実行します。"
    cd $SCRIPT_DIR
    ./pf_diff.sh # シェルスクリプトの実行
  fi

  log_info "${file_name}について処理を終了します。監視を継続します。"  

done

log_info "${script_name}を終了します。"
