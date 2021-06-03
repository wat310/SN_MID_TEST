#!/bin/bash

# バックグラウンド実行を前提とする
# =================================================================================================
# 定数定義 
# =================================================================================================

# inputファイル
## 【開発・本番共通】
TARGET_LOG="/var/log/RG.log" # 本番搭載時に使用

# outputファイル
# ログGrep検索対象
grep_cnadd='add cert success'
grep_cndel='delete cert success'
grep_macadd='add mac success'
grep_macdel='delete mac success'

grep_cnadd_failed='add cert fail'
grep_cndel_failed='delete cert fail'
grep_macadd_failed='add mac fail'
grep_macdel_failed='delete mac fail'

# スクリプトログ関係
LOG_LEVEL='DEBUG'
LOG_FILE='export.log' # ログファイル名
script_name='rsyslog_check.sh' # 実行スクリプト名

# ログ形式 例
# Oct 26 13:42:12 rgwl-auth-01 aad[23868]: unknown(): AccountLumpProcess: add cert success: cn={name}
# Jan 11 14:12:02 rgwl-auth-test01 aad[14316]: unknown(): >AccountLumpProcess: add cert fail: cn=A047534244, reason=paramater error

# =================================================================================================
# 変数設定
# =================================================================================================

current_time_1=$(date "+%Y%m%d%H%M%S") # 現在時刻
mid_host=$(hostname) # MIDサーバーのホスト名

# =================================================================================================
# 関数 
# =================================================================================================

# ディレクトリ設定の関数
function dir_setting {

    # 検証環境MID1
    if [ $mid_host = 'st-ty1-snow-cmdb-mid01' ] ; then
        MID_DIR='/servicenow/st-ty1-snow-cmdb-mid01/agent/export/radius_guard/mid1' # 【開発】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid1/' # 【開発】ログのディレクトリ

    # 検証環境MID2
    elif [ $mid_host = 'st-ty1-snow-cmdb-mid02' ] ; then
        MID_DIR='/servicenow/st-ty1-snow-cmdb-mid02/agent/export/radius_guard/mid2' # 【開発】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid2/' # 【開発】ログのディレクトリ

    # 本番環境MID1
    elif [ $mid_host = 'ty1-snow-cmdb-mid01' ] ; then
        MID_DIR='/servicenow/ty1-snow-cmdb-mid01/agent/export/radius_guard/mid1' # 【本番】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid1/' # 【本番】ログのディレクトリ

    # 本番環境MID2
    elif [ $mid_host = 'ty1-snow-cmdb-mid02' ] ; then
        MID_DIR='/servicenow/ty1-snow-cmdb-mid02/agent/export/radius_guard/mid2' # 【本番】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid2/' # 【本番】ログのディレクトリ

    else
        echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$script_name] [ホスト名を判定できませんでした。${script_name}を終了します。]"
        exit 1
    fi

    # RGからの抽出ログファイル
    CNADD_LOG="$MID_DIR/cnadd/log/cnadd.log"
    CNDEL_LOG="$MID_DIR/cndel/log/cndel.log"
    MACADD_LOG="$MID_DIR/macadd/log/macadd.log"
    MACDEL_LOG="$MID_DIR/macdel/log/macdel.log"
    CNADDFAIL_LOG="$MID_DIR/cnadd/log/cnadd_failed.log"
    CNDELFAIL_LOG="$MID_DIR/cndel/log/cndel_failed.log"
    MACADDFAIL_LOG="$MID_DIR/macadd/log/macadd_failed.log"
    MACDELFAIL_LOG="$MID_DIR/macdel/log/macdel_failed.log"

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

# 該当する文字れるがあるか出力する関数
# $1=$i $2=CNADD_LOG $3=grep_cnadd
function grep_string() {
    [[ -d $(dirname $2) ]] || error_dir $(dirname $2)
    log_debug "${2}に出力します。"
    echo $1 | grep "${3}" >> $2
}

# ログファイルを監視する関数
hit_action() {
    while read i
    do
        # cnadd
        echo $i | grep -q "${grep_cnadd}"
        if [ $? = "0" ];then
            grep_string "${i}" $CNADD_LOG "${grep_cnadd}"
            log_debug "処理が終了しました。監視を継続します。"
        fi
        # cndel
        echo $i | grep -q "${grep_cndel}"
        if [ $? = "0" ];then
            grep_string "${i}" $CNDEL_LOG "${grep_cndel}"
            log_debug "処理が終了しました。監視を継続します。"
        fi
        # macadd
        echo $i | grep -q "${grep_macadd}"
        if [ $? = "0" ];then
            grep_string "${i}" $MACADD_LOG "${grep_macadd}"
            log_debug "処理が終了しました。監視を継続します。"
        fi
        # macdel
        echo $i | grep -q "${grep_macdel}"
        if [ $? = "0" ];then
            grep_string "${i}" $MACDEL_LOG "${grep_macdel}"
            log_debug "処理が終了しました。監視を継続します。"
        fi
        # cnadd_fail
        echo $i | grep -q "${grep_cnadd_failed}"
        if [ $? = "0" ];then
            grep_string "${i}" $CNADDFAIL_LOG "${grep_cnadd_failed}"
            log_debug "処理が終了しました。監視を継続します。"
        fi
        # cndel_fail
        echo $i | grep -q "${grep_cndel_failed}"
        if [ $? = "0" ];then
            grep_string "${i}" $CNDELFAIL_LOG "${grep_cndel_failed}"
            log_debug "処理が終了しました。監視を継続します。"
        fi
        # macadd_fail
        echo $i | grep -q "${grep_macadd_failed}"
        if [ $? = "0" ];then
            grep_string "${i}" $MACADDFAIL_LOG "${grep_macadd_failed}"
            log_debug "処理が終了しました。監視を継続します。"
        fi
        # macdel_fail
        echo $i | grep -q "${grep_macdel_failed}"
        if [ $? = "0" ];then
            grep_string "${i}" $MACDELFAIL_LOG "${grep_macdel_failed}"
            log_debug "処理が終了しました。監視を継続します。"
        fi
    done
}

# =================================================================================================
# メイン処理 
# =================================================================================================

# ディレクトリ設定
dir_setting
# ログのディレクトリが存在しているか
sc_log_dir_check

log_info "${script_name}を開始します。"

if [ ! -f ${TARGET_LOG} ]; then
    log_debug "${TARGET_LOG}を作成します。"
    [[ -d $(dirname $TARGET_LOG) ]] || error_dir $(dirname $TARGET_LOG)
    touch ${TARGET_LOG}
fi

tail -n 0 --follow=name --retry $TARGET_LOG 2>/dev/null | hit_action

log_info "${script_name}を終了します。"