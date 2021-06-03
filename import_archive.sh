#!/bin/bash
# cronで00:00に実行
# 前日分のファイルをアーカイブ・圧縮

# =================================================================================================
# 定数定義
# =================================================================================================

# ログレベル
LOG_LEVEL='DEBUG'

# ログファイル名
LOG_FILE='import.log'

# 実行スクリプト名
script_name='import_archive.sh'

# =================================================================================================
# 変数定義
# =================================================================================================

# 削除の目安(1週間)
time_limit=$(date "+%Y%m%d" --date "7 day ago")

# 前日
previous_day=$(date "+%Y%m%d" --date "1 day ago")

# ホスト判別
mid_host=$(hostname) # MIDサーバーのホスト名

# =================================================================================================
# 関数設定
# =================================================================================================

# ディレクトリ設定の関数
function dir_setting() {

    # 検証環境MID1
    if [ $mid_host = 'st-ty1-snow-cmdb-mid01' ]; then
        IMPORT_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid' # 【開発】インポートデータのディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid1/' # 【開発】ログのディレクトリ

    # 検証環境MID2
    elif [ $mid_host = 'st-ty1-snow-cmdb-mid02' ]; then
        IMPORT_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid' # 【開発】インポートデータのディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid2/' # 【開発】ログのディレクトリ

    # 本番環境MID1
    elif [ $mid_host = 'ty1-snow-cmdb-mid01' ]; then
        IMPORT_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid' # 【本番】インポートデータのディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid1/' # 【本番】ログのディレクトリ

    # 本番環境MID2
    elif [ $mid_host = 'ty1-snow-cmdb-mid02' ]; then
        IMPORT_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid' # 【本番】インポートデータのディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid2/' # 【本番】ログのディレクトリ

    else
        echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$script_name] [ホスト名を判定できませんでした。${script_name}を終了します。]"
        exit 1
    fi

    # ディレクトリ
    ## インポートデータのディレクトリ
    PF_ORIGIN_DIR="${IMPORT_DIR}/pfuser/import/job/origin/" # MIDに配置されたPFファイル(=ServiceNowへ送るファイル)の移動先ディレクトリ
    EIM_ORIGIN_DIR="${IMPORT_DIR}/eimuser/import/job/origin/" # MIDに配置されたEIMファイルの移動先ディレクトリ
    EIM_ARCHIVE_DIR="${IMPORT_DIR}/eimuser/import/servicenow/archive/" # ServiceNowへ送信したEIMファイルの移動先ディレクトリ

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

# アーカイブ作成用の関数
# $1:ディレクトリ $2:ファイル種別
function create_archive() {
    cd $1

    # csvファイルの存在確認
    # 配置された日時が1日以内のファイルを検索
    file_count=$(find -ctime -1 | grep ".csv" | wc -l)
    if [ $file_count -ge 1 ];then
        log_debug "${1}のcsvファイル(${2})のアーカイブを作成します。"
        # ファイルを圧縮
        find -ctime -1 | grep ".csv" | sed "s/\.\/\(.*csv.*$\)/\1/g" | xargs tar --remove-files -z -cf ${2}_${previous_day}.tar.gz
    fi
}

# 1週間を過ぎているアーカイブを削除する関数
# $1:ディレクトリ、$2:ファイル種別
function delete_archive() {
    cd $1

    ls | grep $2 | grep -E "[0-9]{8}" | grep -q ".tar.gz"
    if [ $? = "0" ];then
        archives=$(ls | grep $2 | grep -E "[0-9]{8}" | grep ".tar.gz")
        # 1週間を経過しているアーカイブは削除
        for archive in $archives ; do
            archive_created=$(echo $archive | sed "s/.*_\([0-9]\{8\}\)\.tar\.gz$/\1/g")
            if [ $archive_created -lt $time_limit ]; then
                log_debug "保持期間を超過しているため、${1}${archive}を削除します。"
                rm $archive
            fi
        done
    fi
}

# =================================================================================================
# メイン処理
# =================================================================================================

# ディレクトリ設定
dir_setting
# ログのディレクトリが存在しているか
sc_log_dir_check

# ディレクトリ存在確認
[[ -e $IMPORT_DIR ]] || error_dir $IMPORT_DIR 

[[ -e $PF_ORIGIN_DIR ]] || error_dir $PF_ORIGIN_DIR
[[ -e $EIM_ORIGIN_DIR ]] || error_dir $EIM_ORIGIN_DIR 
[[ -e $EIM_ARCHIVE_DIR ]] || error_dir $EIM_ARCHIVE_DIR 

log_info "${script_name}を開始します。"

# インポートディレクトリのアーカイブ処理
create_archive $PF_ORIGIN_DIR "pf"
create_archive $EIM_ORIGIN_DIR "eim_origin"
create_archive $EIM_ARCHIVE_DIR "eim_archive"

delete_archive $PF_ORIGIN_DIR "pf"
delete_archive $EIM_ORIGIN_DIR "eim_origin"
delete_archive $EIM_ARCHIVE_DIR "eim_archive"

log_info "${script_name}を終了します。"
