#!/bin/bash
# 手動での動作を想定する

# =================================================================================================
# 定数設定
# =================================================================================================

# ServiceNow関係
## 【開発・本番共通】
snow_account_user='dev_auth' # ユーザー
snow_account_pass='dev_auth' # パスワード
table_name='x_ritsc_a200002102_import_full_eim' # テーブル名

update_table_name='x_ritsc_a200002102_import_eim_update' # updateテーブル名
delete_table_name='x_ritsc_a200002102_import_eim_delete' # updateテーブル名

# ディレクトリ、ファイル関係
## 【開発・本番共通】
IMPORT_DIR='/home/eimuser/import/' # ファイルが配置されるディレクトリ
CURL_FILE_NAME='eim_import.csv' # ServiceNowへ取り込むファイル名

# スクリプトログ関係
LOG_LEVEL='DEBUG'
LOG_FILE='import.log' # ログファイル名
script_name='eim_full.sh' # 実行スクリプト名

# メール関係
MAIL_FROM='notification@now.staff.ricoh.com' # メールの送信元
MAIL_TO='zjp_deviceauth_snow_admin@jp.ricoh.com rfgricohdev01@service-now.com' # メールの送信先

# =================================================================================================
# 変数設定
# =================================================================================================

# ファイル識別用正規表現
file_check=^eim.*\.csv$ # 監視ディレクトリに配置されたファイルの識別
file_pattern_diff_update=^eim_diff_update_[0-9]{14}\.csv$ # eim_diff_update
file_pattern_diff_delete=^eim_diff_delete_[0-9]{14}\.csv$ # eim_diff_delete
file_pattern_full_update=^eim_full_update_[0-9]{14}\.csv$ # eim_full_update
file_pattern_full_delete=^eim_full_delete_[0-9]{14}\.csv$ # eim_full_delete

# メール設定
mid_host=$(hostname) # MIDサーバーのホスト名

# =================================================================================================
# 関数設定
# =================================================================================================

# ディレクトリ設定の関数
function dir_setting {

    # 検証環境MID1
    if [ $mid_host = 'st-ty1-snow-cmdb-mid01' ] ; then
        snow_url='https://rfgricohdev01.service-now.com' # 【開発】ServiceNowのURL
        upload_path='@/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/eimuser/import/servicenow/' # 【開発】アップロードファイルのパス
        EXPORT_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/eimuser/import' # 【開発】ファイルの移動先ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid1/' # 【開発】ログのディレクトリ

    # 検証環境MID2
    elif [ $mid_host = 'st-ty1-snow-cmdb-mid02' ] ; then
        snow_url='https://rfgricohdev01.service-now.com' # 【開発】ServiceNowのURL
        upload_path='@/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/eimuser/import/servicenow/' # 【開発】アップロードファイルのパス
        EXPORT_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/eimuser/import' # 【開発】ファイルの移動先ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid2/' # 【開発】ログのディレクトリ

    # 本番環境MID1
    elif [ $mid_host = 'ty1-snow-cmdb-mid01' ] ; then
        snow_url='https://rfgricoh.service-now.com' # 【本番】ServiceNowのURL
        upload_path='@/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/eimuser/import/servicenow/' # 【本番】アップロードファイルのパス
        EXPORT_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/eimuser/import' # 【本番】ファイルの移動先ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid1/' # 【本番】ログのディレクトリ

    # 本番環境MID2
    elif [ $mid_host = 'ty1-snow-cmdb-mid02' ] ; then
        snow_url='https://rfgricoh.service-now.com' # 【本番】ServiceNowのURL
        upload_path='@/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/eimuser/import/servicenow/' # 【本番】アップロードファイルのパス
        EXPORT_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/eimuser/import' # 【本番】ファイルの移動先ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid2/' # 【本番】ログのディレクトリ

    else
        echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$script_name] [ホスト名を判定できませんでした。${script_name}を終了します。]"
        exit 1
    fi

    DATA_DIR="${EXPORT_DIR}/job/" # 元ファイルにフラグを追記したものを配置するディレクトリ
    ORIGIN_DIR="${EXPORT_DIR}/job/origin/" # 元ファイルを配置するディレクトリ
    CURL_DIR="${EXPORT_DIR}/servicenow/" # curl用ディレクトリ
    ARCHIVE_DIR="${EXPORT_DIR}/servicenow/archive/" # インポート済みファイルのディレクトリ

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
function remove_files() {
    cd $1
    if [[ -n $(ls -r | grep "${2}_" | tail -n +15) ]]; then # importログ15件目以降が存在したら実行
      log_debug "${3}ファイルをローテートします。"
      rm $(ls -r | grep "${2}_" | tail -n +15) # 15件目以降を削除
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
# ログのディレクトリが存在しているか
sc_log_dir_check
log_info "${script_name}を開始します。"

[[ -e $IMPORT_DIR ]] || error_dir $IMPORT_DIR
[[ -e $DATA_DIR ]] || error_dir $DATA_DIR
[[ -e $ORIGIN_DIR ]] || error_dir $ORIGIN_DIR
[[ -e $CURL_DIR ]] || error_dir $CURL_DIR
[[ -e $ARCHIVE_DIR ]] || error_dir $ARCHIVE_DIR

#while import/eim内
dirs=`find ${IMPORT_DIR}/* -maxdepth 0 -type f -name "*.csv"`
# ls $IMPORT_DIR | grep "eim_full" | while read line
for line in $dirs;
do
    current_time=$(date "+%Y%m%d%H%M%S") # 現在時刻
    file_name=$(echo $line | sed -e "s:${IMPORT_DIR}/::g")

    # full_update
    if [[ $file_name =~ $file_pattern_full_update ]] ; then
        # 移動してあれば処理済みなので処理終了
        if [[ -f "${ORIGIN_DIR}${file_name}" ]] ; then
            log_info "${file_name}は処理済みのため、処理を終了し、監視を継続します。"
            continue
        fi

        # timestampを抽出
        timestamp=`echo "$file_name" | sed -e "s/^eim_full_update_//g" | sed -e "s/.csv$//g"`

        # もう一方のfile_name
        other_file_name="eim_full_delete_${timestamp}.csv"

        # 追加するフラグ
        flag="update"
        other_flag="delete"

        # 大きめのファイルが配置された時に読み込み途中のファイルを勝手に処理しないように1分待つ
        log_debug "${file_name}の配置を検知しました。1分待機します。" && sleep 1m

        # ファイルをORIGIN_DIRにコピーする
        log_debug "${file_name}を${ORIGIN_DIR}にコピーします。"
        cp -p $IMPORT_DIR$file_name $ORIGIN_DIR

    # full_delete
    elif [[ $file_name =~ $file_pattern_full_delete ]] ; then
        # 移動してあれば処理済みなので処理終了
        if [[ -f "${ORIGIN_DIR}${file_name}" ]] ; then
            log_info "${file_name}は処理済みのため、処理を終了し、監視を継続します。"
            continue
        fi
        # timestampを抽出
        timestamp=`echo "$file_name" | sed -e "s/^eim_full_delete_//g" | sed -e "s/.csv$//g"`

        # もう一方のfile_name
        other_file_name="eim_full_update_${timestamp}.csv"

        # 追加するフラグ
        flag="delete"
        other_flag="update"

        # 大きめのファイルが配置された時に読み込み途中のファイルを勝手に処理しないように1分待つ
        log_debug "${file_name}の配置を検知しました。1分待機します。" && sleep 1m

        # ファイルをORIGIN_DIRにコピーする
        log_debug "${file_name}を${ORIGIN_DIR}にコピーします。"
        cp -p $IMPORT_DIR$file_name $ORIGIN_DIR

    else
        continue
    fi

    # もう一方の存在確認
    # 存在しなければ、1分待つ
    [[ -f $IMPORT_DIR$other_file_name ]] || log_debug "もう一方のファイルの確認のために1分待機します。" && sleep 1m

    # 存在していれば、処理を行う
    if [[ -f $IMPORT_DIR$other_file_name ]] ; then
        # 大きめのファイルが配置された時に読み込み途中のファイルを勝手に処理しないように1分待つ
        log_debug "${other_file_name}の配置を検知しました。1分待機します。" && sleep 1m

        # otherファイルをORIGIN_DIRにコピーする
        log_debug "${other_file_name}を${ORIGIN_DIR}にコピーします。"
        cp -p $IMPORT_DIR$other_file_name $ORIGIN_DIR
        
        log_debug "${file_name}について、flagの追記をします。"
        # フラグを追記
        cp -p $ORIGIN_DIR$file_name $DATA_DIR

        sed -i -e "1s/$/,flag/g" $DATA_DIR$file_name
        sed -i -e "2,\$s/$/,${flag}/g" $DATA_DIR$file_name
        # データ内改行(改行コードが\r\n)の行は元に戻す
        sed -i -e "2,\$s/\r,${flag}/\r/g" $DATA_DIR$file_name
        # 行末の改行コードが異なっていると正常に処理できない
        sed -i -e 's/\r//g' $DATA_DIR$file_name

        log_debug "${other_file_name}について、flagの追記をします。"
        cp -p $ORIGIN_DIR$other_file_name $DATA_DIR
        # otherファイルのヘッダーを削除(ファイル結合時に不要)
        sed -i -e '1d' $DATA_DIR$other_file_name
        # otherファイルのヘッダーは削除されてるので、1行目から
        sed -i -e "s/$/,${other_flag}/g" $DATA_DIR$other_file_name
        # データ内改行(改行コードが\r\n)の行は元に戻す
        sed -i -e "s/\r,${other_flag}/\r/g" $DATA_DIR$other_file_name
        # 行末の改行コードが異なっていると正常に処理できない
        sed -i -e 's/\r//g' $DATA_DIR$other_file_name

        # 既に存在する場合は待機してみる
        [[ -f $CURL_DIR$CURL_FILE_NAME ]] && log_debug "${CURL_FILE_NAME}が存在するため、5分待ちます。" && sleep 5m

        # まだ存在する場合は更に待機してみる
        [[ -f $CURL_DIR$CURL_FILE_NAME ]] && log_debug "${CURL_FILE_NAME}が存在するため、さらに5分待ちます。" && sleep 5m

        # まだ存在する場合はエラーとして終了
        [[ -f $CURL_DIR$CURL_FILE_NAME ]] && log_error "curl用ファイル${CURL_FILE_NAME}が存在するため、処理を継続できません。処理を終了します。" && log_info "監視を継続します。" && continue

        # 結合,curl用に配置
        cat $DATA_DIR$file_name $DATA_DIR$other_file_name > $CURL_DIR$CURL_FILE_NAME


    # 存在しなければ、単体で処理を行う
    else
        log_debug "もう片方のファイルが確認出来ませんでした。単独で処理を実行します。"
        log_debug "${file_name}について、flagの追記をします。"
        # フラグを追記
        cp -p $ORIGIN_DIR$file_name $DATA_DIR

        sed -i -e "1s/$/,flag/g" $DATA_DIR$file_name
        sed -i -e "2,\$s/$/,${flag}/g" $DATA_DIR$file_name
        # データ内改行(改行コードが\r\n)の行は元に戻す
        sed -i -e "2,\$s/\r,${flag}/\r/g" $DATA_DIR$file_name
        # 行末の改行コードが異なっていると正常に処理できない
        sed -i -e 's/\r//g' $DATA_DIR$file_name

        # 既に存在する場合は待機してみる
        [[ -f $CURL_DIR$CURL_FILE_NAME ]] && log_debug "${CURL_FILE_NAME}が存在するため、5分待ちます。" && sleep 5m

        # まだ存在する場合は更に待機してみる
        [[ -f $CURL_DIR$CURL_FILE_NAME ]] && log_debug "${CURL_FILE_NAME}が存在するため、さらに5分待ちます。" && sleep 5m

        # まだ存在する場合はエラーとして終了
        [[ -f $CURL_DIR$CURL_FILE_NAME ]] && log_error "curl用ファイル${CURL_FILE_NAME}が存在するため、処理を継続できません。処理を終了します。" && log_info "監視を継続します。" && continue

        # curl用に配置
        log_debug "${file_name}をコピーして${CURL_DIR}に配置します。"
        cp -p $DATA_DIR$file_name $CURL_DIR$CURL_FILE_NAME

    fi

    snow_update_file=$CURL_FILE_NAME

    log_debug "${file_name}をServiceNowへインポートします。"
    # csvファイルをServiceNowへインポート
    retry_count=0
    until curl -f -i --request POST --header "Accept:application/json" --user $snow_account_user:$snow_account_pass -F "upload=$upload_path$snow_update_file" $snow_url/sys_import.do?sysparm_import_set_tablename=$table_name\&sysparm_transform_after_load=true | grep "200 OK" >> $LOG_DIR$LOG_FILE ; do
        sleep 60
        retry_count=$((retry_count + 1))
        if [[ retry_count -eq 3 ]] ; then
            log_error "${file_name}についてServiceNowへcurlコマンドを実行できませんでした。アーカイブファイル名：${CURL_FILE_NAME}_${current_time}"
            # ★メール通知
            send_mail "${file_name}についてServiceNowへcurlコマンドを実行できませんでした。" "【CURLエラー】デバイス認証 ${mid_host} ${script_name}"
            break
        fi
    done
    # 成功
    if [[ retry_count -ne 3 ]]; then
        log_debug "${file_name}についてcurlコマンドが成功しました。"
    fi

    # curl用ファイルを移動(archiveディレクトリへ)
    if [[ -f $CURL_DIR$CURL_FILE_NAME ]]; then
        mv $CURL_DIR$CURL_FILE_NAME "${ARCHIVE_DIR}${CURL_FILE_NAME}_${current_time}"
    fi


done

log_debug "${DATA_DIR}の中間ファイルを削除します。"
cd $DATA_DIR
ls | grep "eim_" | grep ".csv" | xargs rm

log_info "${script_name}を終了します。"