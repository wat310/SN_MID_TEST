#!/bin/bash
# cronで00:00に実行
# 前日分のファイルをアーカイブ・圧縮

# =================================================================================================
# 定数定義
# =================================================================================================

# ログレベル
LOG_LEVEL='DEBUG'

# ログファイル名
LOG_FILE='export.log'

# 実行スクリプト名
script_name='export_archive.sh'

# ファイル種別
cnadd_types=("cnadd")
cndel_types=("cndel")
macadd_types=("macadd1" "macadd2")
macdel_types=("macdel1" "macdel2" "mac_changed_del")

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
        MID_DIR='/servicenow/st-ty1-snow-cmdb-mid01/agent/export/radius_guard/mid1' # 【開発】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid1/' # 【開発】ログのディレクトリ

    # 検証環境MID2
    elif [ $mid_host = 'st-ty1-snow-cmdb-mid02' ]; then
        MID_DIR='/servicenow/st-ty1-snow-cmdb-mid02/agent/export/radius_guard/mid2' # 【開発】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid2/' # 【開発】ログのディレクトリ

    # 本番環境MID1
    elif [ $mid_host = 'ty1-snow-cmdb-mid01' ]; then
        MID_DIR='/servicenow/ty1-snow-cmdb-mid01/agent/export/radius_guard/mid1' # 【本番】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid1/' # 【本番】ログのディレクトリ

    # 本番環境MID2
    elif [ $mid_host = 'ty1-snow-cmdb-mid02' ]; then
        MID_DIR='/servicenow/ty1-snow-cmdb-mid02/agent/export/radius_guard/mid2' # 【本番】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid2/' # 【本番】ログのディレクトリ

    else
        echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$script_name] [ホスト名を判定できませんでした。${script_name}を終了します。]"
        exit 1
    fi

    # ディレクトリ
    ## 整形前のエクスポートされたcsvが移動されるディレクトリ
    CNADD_EXPORTED_DIR="${MID_DIR}/cnadd/exportd/"
    CNDEL_EXPORTED_DIR="${MID_DIR}/cndel/exportd/"
    MACADD_EXPORTED_DIR="${MID_DIR}/macadd/exportd/"
    MACDEL_EXPORTED_DIR="${MID_DIR}/macdel/exportd/"

    ## Radius Guardが取得するファイルの元データを配置するディレクトリ
    CNADD_ARCHIVE_DIR="${MID_DIR}/cnadd/archive/"
    CNDEL_ARCHIVE_DIR="${MID_DIR}/cndel/archive/"
    MACADD_ARCHIVE_DIR="${MID_DIR}/macadd/archive/"
    MACDEL_ARCHIVE_DIR="${MID_DIR}/macdel/archive/"

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

# exportedディレクトリ内のアーカイブ作成用の関数
# $1:exportdディレクトリ、$2:ファイル種別(配列)
function create_exported_archive() {
    cd $1

    for type in $2; do
        # csvファイルの存在確認
        # 更新日時が1日以内のファイルを検索
        file_count=$(find ./ -name \*.csv -mtime -1 | grep $type | wc -l)
        if [ $file_count -ge 1 ];then
            log_debug "${1}のcsvファイル(${type})のアーカイブを作成します。"
            # ファイルを圧縮
            find ./ -name \*.csv -mtime -1 | grep $type | sed "s/\.\/\(.*csv\)$/\1/g" | xargs tar --remove-files -z -cf ${type}_${previous_day}.tar.gz
        fi
    done
}

# exportedディレクトリ内で1週間を過ぎているアーカイブを削除する関数
# $1:exportdディレクトリ、$2:ファイル種別(配列)
function delete_exported_archive() {
    cd $1

    for type in $2; do
        # アーカイブの存在確認
        ls | grep $type | grep -E "[0-9]{8}" | grep -q ".tar.gz"
        if [ $? = "0" ];then
            archives=$(ls | grep $type | grep -E "[0-9]{8}" | grep ".tar.gz")
            # 1週間を経過しているアーカイブは削除
            for archive in $archives ; do
                archive_created=$(echo $archive | sed "s/.*_\([0-9]\{8\}\)\.tar\.gz$/\1/g")
                if [ $archive_created -lt $time_limit ]; then
                    log_debug "保持期間を超過しているため、${1}${archive}を削除します。"
                    rm $archive
                fi
            done
        fi
    done
}

# exportedディレクトリ以外のアーカイブ作成用の関数
# $1:ディレクトリ $2:ファイル種別
function create_archive() {
    cd $1

    # csvファイルの存在確認
    # 配置された日時が1日以内のファイルを検索
    file_count=$(find -ctime -1 | grep ".csv" | wc -l)
    if [ $file_count -ge 1 ];then
        log_debug "${1}のcsvファイル(${2})のアーカイブを作成します。"
        # ファイルを圧縮
        find -ctime -1 | grep ".csv" | sed "s/\.\/\(.*csv\)$/\1/g" | xargs tar --remove-files -z -cf ${2}_${previous_day}.tar.gz
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
[[ -e $MID_DIR ]] || error_dir $MID_DIR 

[[ -e $CNADD_EXPORTED_DIR ]] || error_dir $CNADD_EXPORTED_DIR 
[[ -e $CNDEL_EXPORTED_DIR ]] || error_dir $CNDEL_EXPORTED_DIR 
[[ -e $MACADD_EXPORTED_DIR ]] || error_dir $MACADD_EXPORTED_DIR 
[[ -e $MACDEL_EXPORTED_DIR ]] || error_dir $MACDEL_EXPORTED_DIR 

[[ -e $CNADD_ARCHIVE_DIR ]] || error_dir $CNADD_ARCHIVE_DIR 
[[ -e $CNDEL_ARCHIVE_DIR ]] || error_dir $CNDEL_ARCHIVE_DIR 
[[ -e $MACADD_ARCHIVE_DIR ]] || error_dir $MACADD_ARCHIVE_DIR 
[[ -e $MACDEL_ARCHIVE_DIR ]] || error_dir $MACDEL_ARCHIVE_DIR 

log_info "${script_name}を開始します。"

# exportedディレクトリのアーカイブ処理
create_exported_archive $CNADD_EXPORTED_DIR "${cnadd_types[*]}"
create_exported_archive $CNDEL_EXPORTED_DIR "${cndel_types[*]}"
create_exported_archive $MACADD_EXPORTED_DIR "${macadd_types[*]}"
create_exported_archive $MACDEL_EXPORTED_DIR "${macdel_types[*]}"

delete_exported_archive $CNADD_EXPORTED_DIR "${cnadd_types[*]}"
delete_exported_archive $CNDEL_EXPORTED_DIR "${cndel_types[*]}"
delete_exported_archive $MACADD_EXPORTED_DIR "${macadd_types[*]}"
delete_exported_archive $MACDEL_EXPORTED_DIR "${macdel_types[*]}"

# エクスポートのarchiveディレクトリのアーカイブ処理
create_archive $CNADD_ARCHIVE_DIR "cnadd"
create_archive $CNDEL_ARCHIVE_DIR "cndel"
create_archive $MACADD_ARCHIVE_DIR "macadd"
create_archive $MACDEL_ARCHIVE_DIR "macdel"

delete_archive $CNADD_ARCHIVE_DIR "cnadd"
delete_archive $CNDEL_ARCHIVE_DIR "cndel"
delete_archive $MACADD_ARCHIVE_DIR "macadd"
delete_archive $MACDEL_ARCHIVE_DIR "macdel"

log_info "${script_name}を終了します。"
