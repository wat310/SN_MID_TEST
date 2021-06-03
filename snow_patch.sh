#!/bin/bash
# =================================================================================================
# 定数定義
# =================================================================================================

# ログレベル
LOG_LEVEL='DEBUG'

# ログファイル名
LOG_FILE='export.log'
# 実行スクリプト名
script_name='snow_patch.sh' 

# curl設定
snow_table_api_path='/api/now/table/'
table_name='x_ritsc_a200002101_integrated_asset_management'
snow_account_user='dev_auth'
snow_account_pass='dev_auth'
macdel_table_name='x_ritsc_a200002101_delete_previous_macaddress_list'
cnadd_data="{'cert_sync_status':'Added'}"
cndel_data="{'cert_sync_status':'Deleted'}"
mac1add_data="{'mac1_sync_status':'Added'}"
mac2add_data="{'mac2_sync_status':'Added'}"
mac1del_data="{'mac1_sync_status':'Deleted'}"
mac2del_data="{'mac2_sync_status':'Deleted'}"
mac_changed_del_data="{'status':'Deleted'}"

cnadd_fail_data="{'cert_sync_status':'add failed'}"
cndel_fail_data="{'cert_sync_status':'delete failed'}"
mac1add_fail_data="{'mac1_sync_status':'add failed'}"
mac2add_fail_data="{'mac2_sync_status':'add failed'}"
mac1del_fail_data="{'mac1_sync_status':'delete failed'}"
mac2del_fail_data="{'mac2_sync_status':'delete failed'}"
mac_changed_fail_del_data="{'status':'delete failed'}"

# curl_失敗理由送信関係
# Messageは関数の中で定義する
# サーバー情報は「変数定義」で設定
application_info='A200002102' # メッセージに含めるアプリケーション情報
ecclog_table='ecc_agent_log' # 送信先テーブル
ecclog_level="'type':'Info'" # Level
# applog_scope="{'sys_scope':'A200002102 Device Authentication Develop'}" # App Scope
# applog_script="{'script_artifact':'MIDサーバー_${script_name}'}" # Source Script

# メール関係
MAIL_FROM='notification@now.staff.ricoh.com'     # メールの送信元
MAIL_TO='zjp_deviceauth_snow_admin@jp.ricoh.com rfgricohdev01@service-now.com' # メールの送信先

# =================================================================================================
# 変数定義
# =================================================================================================

# 現在時刻
current_time=$(date "+%Y%m%d%H%M%S")

# メール設定
mid_host=$(hostname) # MIDサーバーのホスト名

# curl_失敗理由送信関係
ecclog_server="'ecc_agent':'${mid_host}'" # MID server

# =================================================================================================
# 関数設定
# =================================================================================================

# ディレクトリ設定の関数
function dir_setting() {

    # 検証環境MID1
    if [ $mid_host = 'st-ty1-snow-cmdb-mid01' ]; then
        snow_url='https://rfgricohdev01.service-now.com'
        EXPORT_DIR="/servicenow/st-ty1-snow-cmdb-mid01/agent/export/radius_guard"
        MID_DIR='/servicenow/st-ty1-snow-cmdb-mid01/agent/export/radius_guard/mid1' # 【開発】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid1/' # 【開発】ログのディレクトリ

    # 検証環境MID2
    elif [ $mid_host = 'st-ty1-snow-cmdb-mid02' ]; then
        snow_url='https://rfgricohdev01.service-now.com'
        EXPORT_DIR="/servicenow/st-ty1-snow-cmdb-mid02/agent/export/radius_guard"
        MID_DIR='/servicenow/st-ty1-snow-cmdb-mid02/agent/export/radius_guard/mid2' # 【開発】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid2/' # 【開発】ログのディレクトリ

    # 本番環境MID1
    elif [ $mid_host = 'ty1-snow-cmdb-mid01' ]; then
        snow_url='https://rfgricoh.service-now.com'
        EXPORT_DIR="/servicenow/ty1-snow-cmdb-mid01/agent/export/radius_guard"
        MID_DIR='/servicenow/ty1-snow-cmdb-mid01/agent/export/radius_guard/mid1' # 【本番】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid1/' # 【本番】ログのディレクトリ

    # 本番環境MID2
    elif [ $mid_host = 'ty1-snow-cmdb-mid02' ]; then
        snow_url='https://rfgricoh.service-now.com'
        EXPORT_DIR="/servicenow/ty1-snow-cmdb-mid02/agent/export/radius_guard"
        MID_DIR='/servicenow/ty1-snow-cmdb-mid02/agent/export/radius_guard/mid2' # 【本番】各MIDサーバ用ディレクトリ
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid2/' # 【本番】ログのディレクトリ

    else
        echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$script_name] [ホスト名を判定できませんでした。${script_name}を終了します。]"
        exit 1
    fi

    # ディレクトリ
    CNADD_LOG_DIR="$MID_DIR/cnadd/log"
    CNDEL_LOG_DIR="$MID_DIR/cndel/log"
    MACADD_LOG_DIR="$MID_DIR/macadd/log"
    MACDEL_LOG_DIR="$MID_DIR/macdel/log"

    CNADD_LIST_DIR="$EXPORT_DIR/cnadd/list"
    CNDEL_LIST_DIR="$EXPORT_DIR/cndel/list"
    MACADD_LIST_DIR="$EXPORT_DIR/macadd/list"
    MACDEL_LIST_DIR="$EXPORT_DIR/macdel/list"

    CNADD_JOB_DIR="$MID_DIR/cnadd/job"
    CNDEL_JOB_DIR="$MID_DIR/cndel/job"
    MACADD_JOB_DIR="$MID_DIR/macadd/job"
    MACDEL_JOB_DIR="$MID_DIR/macdel/job"

    # RGからの抽出ログファイル
    CNADD_LOG="$CNADD_LOG_DIR/cnadd.log"
    CNDEL_LOG="$CNDEL_LOG_DIR/cndel.log"
    MACADD_LOG="$MACADD_LOG_DIR/macadd.log"
    MACDEL_LOG="$MACDEL_LOG_DIR/macdel.log"
    CNADDFAIL_LOG="$CNADD_LOG_DIR/cnadd_failed.log"
    CNDELFAIL_LOG="$CNDEL_LOG_DIR/cndel_failed.log"
    MACADDFAIL_LOG="$MACADD_LOG_DIR/macadd_failed.log"
    MACDELFAIL_LOG="$MACDEL_LOG_DIR/macdel_failed.log"

    # 各エクスポートスクリプトで作成したsys_id含め2パラメータのリスト
    CNADD_LIST="$CNADD_LIST_DIR/cnadd_list.csv"    # nameとsys_idのリスト
    CNDEL_LIST="$CNDEL_LIST_DIR/cndel_list.csv"    # nameとsys_idのリスト
    MACADD_LIST="$MACADD_LIST_DIR/macadd_list.csv" # mac_addressとsys_idのリスト
    MACDEL_LIST="$MACDEL_LIST_DIR/macdel_list.csv" # mac_addressとsys_idのリスト

    # 作業用ログファイル名
    JOB_CNADD_LOG="$CNADD_JOB_DIR/add_cn.csv"
    JOB_CNDEL_LOG="$CNDEL_JOB_DIR/del_cn.csv"
    JOB_MACADD_LOG="$MACADD_JOB_DIR/add_mac.csv"
    JOB_MACDEL_LOG="$MACDEL_JOB_DIR/del_mac.csv"
    JOB_CNADDFAIL_LOG="$CNADD_JOB_DIR/add_cn_failed.csv"
    JOB_CNDELFAIL_LOG="$CNDEL_JOB_DIR/del_cn_failed.csv"
    JOB_MACADDFAIL_LOG="$MACADD_JOB_DIR/add_mac_failed.csv"
    JOB_MACDELFAIL_LOG="$MACDEL_JOB_DIR/del_mac_failed.csv"

    # 作業用一時ファイル名
    JOB_CNADD_LOG_TEMP="$CNADD_JOB_DIR/add_cn_temp.csv"
    JOB_CNDEL_LOG_TEMP="$CNDEL_JOB_DIR/del_cn_temp.csv"
    JOB_MACADD_LOG_TEMP="$MACADD_JOB_DIR/add_mac_temp.csv"
    JOB_MACDEL_LOG_TEMP="$MACDEL_JOB_DIR/del_mac_temp.csv"
    JOB_CNADDFAIL_LOG_TEMP="$CNADD_JOB_DIR/add_cn_failed_temp.csv"
    JOB_CNDELFAIL_LOG_TEMP="$CNDEL_JOB_DIR/del_cn_failed_temp.csv"
    JOB_MACADDFAIL_LOG_TEMP="$MACADD_JOB_DIR/add_mac_failed_temp.csv"
    JOB_MACDELFAIL_LOG_TEMP="$MACDEL_JOB_DIR/del_mac_failed_temp.csv"

    # 失敗理由通知作業用一時ファイル
    CURL_CNADDFAIL_TEMP="$CNADD_JOB_DIR/curl_add_cn_failed_temp.csv"
    CURL_CNDELFAIL_TEMP="$CNDEL_JOB_DIR/curl_del_cn_failed_temp.csv"
    CURL_MACADDFAIL_TEMP="$MACADD_JOB_DIR/curl_add_mac_failed_temp.csv"
    CURL_MACDELFAIL_TEMP="$MACDEL_JOB_DIR/curl_del_mac_failed_temp.csv"
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

# ローテート用の関数
# $1:**_JOB_DIR $2:ローテート対象ファイル $3:ログ出力テキスト(ファイル種別)
# 【$2が**_temp.csvのときのみ】$4:success
function remove_files() {
    cd $1
    # 対象ファイル名に"temp"が含まれるか
    echo $2 | grep -q "temp"
    rf_result=$?
    # "temp"が含まれるかどうかで処理を分ける
    # "temp_**_success"はこの関数で処理するが、"temp_**_failed"はこの関数では処理しないため
    if [ $rf_result = "0" ] ; then
        if [[ -n $(ls -r | grep "${2}_" | grep -E "_${4}$" | tail -n +15) ]]; then
            log_debug "${3}_${4}ファイルをローテートします。"
            rm $(ls -r | grep "${2}_" | grep -E "_${4}$" | tail -n +15) # 15件目以降を削除
        fi
    else
        if [[ -n $(ls -r | grep "${2}_" | tail -n +15) ]]; then # importログ15件目以降が存在したら実行
            log_debug "${3}ファイルをローテートします。"
            rm $(ls -r | grep "${2}_" | tail -n +15) # 15件目以降を削除
        fi
    fi
}

# ファイルを1か月保持して、ローテートする関数
# $1:**_JOB_DIR $2:**_LOG_TEMP $3:**用tmp $4:failed
function keep_files() {
    border_date=$(date "+%Y%m%d" -d "1 month ago") # ファイル保持の期限日(YYYYmmdd)

    cd $1
    # **temp.csv_#{timestamp}_failedの検索
    file_list=$(ls | grep $2 | grep -E "[0-9]{14}" | grep -E "${4}$")

    # 該当するファイルが存在するか判定
    ls | grep $2 | grep -E "[0-9]{14}" | grep -qE "${4}$"
    kf_result=$? # 終了ステータスを変数に格納(そうしないと正常に動作しない)
    if [ $kf_result = "0" ] ; then
        log_debug "${3}_${4}ファイルの内、1か月の保存期間を過ぎているものは削除します。"
        # 検索でヒットしたファイルから1つずつタイムスタンプの比較をする
        for file in $file_list; do
            # ファイル名の中の日付を抽出(YYYYmmddまで)
            file_date=$(basename $file | sed "s/.*\([0-9]\{14\}\).*/\1/g" | cut -c 1-8)

            # ファイルの日付が期限日を過ぎていたら削除
            if [ $file_date -lt $border_date ] ; then
                rm $file
            fi
        done
    fi
}

# メール通知
function send_mail() {
    echo "${1}" | mail -s "${2}" -r $MAIL_FROM $MAIL_TO
}

# rsyslog_check.shで作成したログファイルを名前を変更して保存
# $1:**_LOG
# **_LOG → **_LOG_currenttime
function rename_rglog(){
    log_debug "${1}の名前を変更します。"
    mv $1 "${1}_${current_time}"
}

# [cn]名前を変更したログファイルから、nameを作業用ファイルに出力
# $1:**_LOG $2:JOB_**_LOG{current_time}
# JOB_**_LOG が「"name",」の形
# **_LOG_currenttime → JOB_**_LOG_currenttime
function get_rglog_cn_value(){
    log_debug "${1}_${current_time}を整形して${2}_${current_time}に出力します。"
    # 「cn=」の後に1文字は確実に存在すること
    #  小文字は大文字に変換する
    cat "${1}_${current_time}" | grep -E 'cn=.' | sed 's/.*cn=//g' | sed 's/, reason=.*$//g' | sed "s/\(^.*\)$/\"\1\",/g" | sed "s/\(.*\)/\U\1/" >>"${2}_${current_time}"
}

# [mac]名前を変更したログファイルから、macを作業用ファイルに出力
# $1:**_LOG $2:JOB_**_LOG_{current_time}
# JOB_**_LOG が「,"mac",」 の形
# **_LOG_currenttime → JOB_**_LOG_currenttime
function get_rglog_mac_value(){
    log_debug "${1}_${current_time}を整形して${2}_${current_time}に出力します。"
    # 「uid=」の後に1文字は確実に存在すること
    #  小文字は大文字に変換する
    cat "${1}_${current_time}" | grep -E 'uid=.' | sed 's/.*uid=//g' | sed 's/, reason=.*$//g' | sed "s/\(^.*\)$/\"\1\",/g" | sed "s/\(.*\)/\U\1/" >>"${2}_${current_time}"
}

# 失敗理由をServiceNowに送信する関数
# $1:**_LOG $2:cn/macの値 $3:sys_id $4:CN/mac*** $5:CURL_**FAIL_TEMP
function send_failed_log() {
    log_debug "FailのログをApplication LogにPOSTします。"
    # **_LOGから該当のcn/macを含む行を一時ファイルに抽出
    cat "${1}_${current_time}" | grep "${2}" >> $5

    # 抽出した一時ファイルを一行ずつ処理
    while read line; do
        # curl用に編集
        curl_message="[${application_info}_sys_id:${3}_${4}]${line}"
        ecclog_message="'log':'${curl_message}'" # ecclogのMessage
        retry_count=0
        # レコード作成なのでHTTPステータスコードは201 Created
        # until curl -f -i "$snow_url$snow_table_api_path$ecclog_table" --request POST --header "Accept:application/json" --header "Content-Type:application/json" --data "${ecclog_level}" --data "${ecclog_server}" --data "${ecclog_message}" --user $snow_account_user:$snow_account_pass | grep "201 Created" >>$LOG_DIR$LOG_FILE; do
        until curl -f -i "$snow_url$snow_table_api_path$ecclog_table" --request POST --header "Accept:application/json" --header "Content-Type:application/json" --data "{${ecclog_level},${ecclog_server},${ecclog_message}}" --user $snow_account_user:$snow_account_pass | grep "201 Created" >>$LOG_DIR$LOG_FILE; do
            sleep 10
            retry_count=$((retry_count + 1))
            if [[ retry_count -eq 3 ]]; then
                log_error "${4}:${2},SYS_ID:${3}についてServiceNowへcurlコマンドを実行できませんでした。(Failed通知)"
                # メール通知
                send_mail "${4}:${2},SYS_ID:${3}についてServiceNowへcurlコマンドを実行できませんでした。(Failed通知)" "【CURLエラー】デバイス認証 ${mid_host} ${script_name}"
                break
            fi
        done

        if [[ retry_count -ne 3 ]]; then
            log_debug "${4}:${2},SYS_ID:${3}についてcurlコマンドが成功しました。(Failed通知)"
        fi
    done <$5

    # 処理後は一時ファイルを削除
    rm $5
}

# 作業用ファイル内重複の削除
# $1:JOB_**_LOG $2:JOB_**_LOG_TEMP
function delete_duplicate(){
    if [ -s $1 ];then
        touch $2
        log_debug "${1}のファイル内の重複を削除します。"
        sort $1 | uniq >$2
        cat $2 >$1
        rm $2
    fi
}

# [cn]sys_id検索
# (検索元は各エクスポートスクリプトで作成したリスト)
# 作業用ファイルを読み込み、中間ファイルから最終的に作業用ファイルにsys_idを含めたデータを出力
# $1:JOB_**_LOG $2:JOB_**_LOG_TEMP $3:**_LIST
# JOB_**_LOG → JOB_**_LOG_currenttime
# **_LIST → JOB_**_LOG_currenttime
function search_cn_sys_id(){
    log_debug "${1}_${current_time}のnameに対応するsys_idを検索します。"
    #JOB_**_LOGをコピー
    less $1 >> "${1}_${current_time}"
    touch "${2}_${current_time}"
    # ソート
    delete_duplicate "${1}_${current_time}" "${2}_${current_time}"

    touch "${2}_${current_time}"
    while read line; do
        #LISTファイルからsys_idを検索
        
        # sys_idが入っていない場合
        if echo $line | grep ",$" > /dev/null ;then
            #LISTファイルにnameがなければ終了
            grep -sq $line $3 || ( echo $line >> "${2}_${current_time}" && continue )
            # あれば、sys_idを追記する
            sys_id=$(grep $line $3 | cut -d ',' -f 2)
            echo $line$sys_id >> "${2}_${current_time}"
            
        # sys_idが入っている場合
        else
            #LISTファイルとsys_idが同じであれば終了
            grep -sq $line $3 && ( echo $line >> "${2}_${current_time}" && continue )
            # 違えば、書き換える
            target=$(echo $line | cut -d ',' -f 1)
            sys_id=$(echo $line | cut -d ',' -f 2)
            list_sys_id=$(grep $target $3 | cut -d ',' -f 2)
            sed -e $line "/${sys_id}/${list_sys_id}/" >> "${2}_${current_time}"
        fi

    done <"${1}_${current_time}"
    cat "${2}_${current_time}">"${1}_${current_time}"
    rm "${2}_${current_time}"

    touch "${2}_${current_time}"
    # POST前に再度ソート
    delete_duplicate "${1}_${current_time}" "${2}_${current_time}"
}

# [mac]sys_id検索
# (検索元は各エクスポートスクリプトで作成したリスト)
# 作業用ファイルを読み込み、中間ファイルから最終的に作業用ファイルにsys_idを含めたデータを出力
# macaddとmacdelは、mac addressの種類も記載する必要あり
# $1:JOB_**_LOG $2:JOB_**_LOG_TEMP $3:**_LIST
# JOB_**_LOG → JOB_**_LOG_currenttime
# **_LIST → JOB_**_LOG_currenttime
function search_mac_sys_id(){
    log_debug "${1}_${current_time}のmac_addressに対応するsys_idを検索します。"

    #JOB_**_LOGをコピー
    less $1 >> "${1}_${current_time}"
    touch "${2}_${current_time}"

    # ソート
    delete_duplicate "${1}_${current_time}" "${2}_${current_time}"
    touch "${2}_${current_time}"

    while read line; do
        #LISTファイルからsys_idを検索
        # 検索対象ファイルにsys_idが入っている場合
        if [[ -n $(echo $line | cut -d ',' -f 3) ]]; then
            #LISTファイルとsys_idの全文が同じであれば終了
            grep -sq $line $3 && ( echo $line >> "${2}_${current_time}" && continue )
            # 違えば、書き換える
            # 検索対象(mac種別)
            mac_type=$(echo $line | cut -d ',' -f 1 | sed -e s/\"//g)
            # 検索対象(mac address)
            target=$(echo $line | cut -d ',' -f 2)
            # LISTファイルから検索したmac_addressに対応するsys_idを抽出(1つのみ)
            list_sys_id=$(grep -m1 ",${target}," $3 | cut -d ',' -f 3)
            list_mac_type=$(grep -m1 ",${target}," $3 | cut -d ',' -f 1)

            echo "${list_mac_type},${target},${list_sys_id}" >> "${2}_${current_time}"
        # 検索対象ファイルにsys_idがない場合
        else
            #LISTファイルにmacaddressがなければ終了
            grep -sq $line $3 || ( echo $line >> "${2}_${current_time}" && continue )
            # 検索対象(mac address)
            target=$(echo $line | cut -d ',' -f 1) # sys_idが存在しないときはカラムの構成数が異なる
            # あれば、sys_idを追記する

            list_sys_id=$(grep -m1 ",${target}," $3 | cut -d ',' -f 3)
            list_mac_type=$(grep -m1 ",${target}," $3 | cut -d ',' -f 1)

            echo "${list_mac_type},${target},${list_sys_id}" >> "${2}_${current_time}"

        fi

    done <"${1}_${current_time}"
    cat "${2}_${current_time}">"${1}_${current_time}"
    rm "${2}_${current_time}"

    touch "${2}_${current_time}"
    # POST前に再度ソート
    delete_duplicate "${1}_${current_time}" "${2}_${current_time}"
}

# [cn]sys_idをPOST
# $1:JOB_**_LOG $2:JOB_**_LOG_TEMP $3:**_LIST $4:**_data $5:"**" $6:**_LOG(failの時のみ使用) $7:CURL_**FAIL_TEMP(failの時のみ使用)
# **_LIST → JOB_**_LOG_currenttime
# JOB_**_LOG_currenttime → JOB_**_LOG_TEMP(失敗) JOB_**_LOG_TEMP_currenttime(成功)
# JOB_**_LOG_TEMP(失敗) → JOB_**_LOG
function post_cn_sys_id(){
    log_debug "${5}のsys_idをPOSTします。"
    log_debug "${3}に同じsys_idを含む行があれば削除します。"

    touch "${2}_${current_time}_failed"
    touch "${2}_${current_time}_success"
    while read line; do
        # 空行の場合continue
        if [[ -z "$line" ]]; then
            continue
        fi

        # sys_idが空の場合continue
        if [[ -z $(echo $line | cut -d ',' -f 2) ]]; then
            echo $line >>"${2}_${current_time}_failed"
            continue
        fi
        name=$(echo $line | cut -d ',' -f 1 | sed -e "s/\"//g")
        sys_id=$(echo $line | cut -d ',' -f 2 | sed -e "s/\"//g")
        retry_count=0
        log_debug "NAME:${name},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行します。(${5})"
        until curl -f -i "$snow_url$snow_table_api_path$table_name/$sys_id" --request PATCH --header "Accept:application/json" --header "Content-Type:application/json" --data "${4}" --user $snow_account_user:$snow_account_pass | grep "200 OK" >>$LOG_DIR$LOG_FILE; do
            sleep 10
            retry_count=$((retry_count + 1))
            if [[ retry_count -eq 3 ]]; then
                log_error "NAME:${name},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行できませんでした。"
                # メール通知
                send_mail "NAME:${name},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行できませんでした。" "【CURLエラー】デバイス認証 ${mid_host} ${script_name}"
                break
            fi
        done
        #成功
        if [[ retry_count -ne 3 ]]; then
            # LISTファイルの同じsys_idの行を削除
            log_debug "NAME:${name},SYS_ID:${sys_id}についてcurlコマンドが成功しました。(${5})"
            sed -i "/$sys_id/d" $3
            echo $line >>"${2}_${current_time}_success"

        # 失敗
        else
            echo $line >>"${2}_${current_time}_failed"
        fi

        # failの場合は失敗理由も送信
        # 引数が7個存在した場合に処理
        if [[ $# -eq 7 ]]; then
            send_failed_log $6 $name $sys_id "CN" $7
        fi

    done <"${1}_${current_time}"

    # 成功の場合、ログ本体の値を削除
    while read line; do
        # 同じ値がなければ終了
        grep -sq $line $1 || continue
        # あれば削除
        sed -i "/${line}/d" $1

    done <"${2}_${current_time}_success"

    # 失敗の場合(成功と同じ処理)
    while read line; do
        # 同じ値がなければ終了
        grep -sq $line $1 || continue
        # あれば削除
        sed -i "/${line}/d" $1

    done <"${2}_${current_time}_failed"
}

# [mac]sys_idをPOST
# $1:JOB_**_LOG $2:JOB_**_LOG_TEMP $3:**_LIST $4:**_data $5:**_data $6:**_data $7:"**" $8:**_LOG(failの時のみ使用) $9:CURL_**FAIL_TEMP(failの時のみ使用)
# **_LIST → JOB_**_LOG_currenttime
# JOB_**_LOG_currenttime → JOB_**_LOG_TEMP(失敗) JOB_**_LOG_TEMP_currenttime(成功)
# JOB_**_LOG_TEMP(失敗) → JOB_**_LOG
function post_mac_sys_id(){
    # macaddとmacdelはmac_typeによって出力先のデータを変更
    log_debug "${7}のsys_idをPOSTします。"
    log_debug "${3}に同じsys_idを含む行があれば削除します。"

    touch "${2}_${current_time}_failed"
    touch "${2}_${current_time}_success"

    while read line; do
        # 空行の場合continue
        if [[ -z "$line" ]]; then
            continue
        fi

        # sys_idが空の場合continue
        if [[ -z $(echo $line | cut -d ',' -f 3) ]]; then
            echo $line >>"${2}_${current_time}_failed"
            continue
        fi
        sys_id=$(echo $line | cut -d ',' -f 3 | sed -e "s/\"//g")
        mac_type=$(echo $line | cut -d ',' -f 1 | sed -e "s/\"//g")
        mac_address=$(echo $line | cut -d ',' -f 2 | sed -e "s/\"//g")
        retry_count=0
        if [ "$mac_type" = "mac1" ]; then
            log_debug "MAC_ADDRESS:${mac_address},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行します。(${7})"
            until curl -f -i "$snow_url$snow_table_api_path$table_name/$sys_id" --request PATCH --header "Accept:application/json" --header "Content-Type:application/json" --data "${4}" --user $snow_account_user:$snow_account_pass | grep "200 OK" >>$LOG_DIR$LOG_FILE; do
                sleep 60
                retry_count=$((retry_count + 1))
                if [[ retry_count -eq 3 ]]; then
                    log_error "MAC_ADDRESS:${mac_address},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行できませんでした。"
                    # メール通知
                    send_mail "MAC_ADDRESS:${mac_address},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行できませんでした。" "【CURLエラー】デバイス認証 ${mid_host} ${script_name}"
                    break
                fi
            done
        elif [ "$mac_type" = "mac2" ]; then
            log_debug "MAC_ADDRESS:${mac_address},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行します。(${7})"
            until curl -f -i "$snow_url$snow_table_api_path$table_name/$sys_id" --request PATCH --header "Accept:application/json" --header "Content-Type:application/json" --data "${5}" --user $snow_account_user:$snow_account_pass | grep "200 OK" >>$LOG_DIR$LOG_FILE; do
                sleep 60
                retry_count=$((retry_count + 1))
                if [[ retry_count -eq 3 ]]; then
                    log_error "MAC_ADDRESS:${mac_address},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行できませんでした。"
                    # メール通知
                    send_mail "MAC_ADDRESS:${mac_address},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行できませんでした。" "【CURLエラー】デバイス認証 ${mid_host} ${script_name}"
                    break
                fi
            done
        elif [ "$mac_type" = "mac_changed_del" ]; then
            log_debug "MAC_ADDRESS:${mac_address},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行します。(${7})"
            until curl -f -i "$snow_url$snow_table_api_path$macdel_table_name/$sys_id" --request PATCH --header "Accept:application/json" --header "Content-Type:application/json" --data "${6}" --user $snow_account_user:$snow_account_pass | grep "200 OK" >>$LOG_DIR$LOG_FILE; do
                sleep 60
                retry_count=$((retry_count + 1))
                if [[ retry_count -eq 3 ]]; then
                    log_error "MAC_ADDRESS:${mac_address},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行できませんでした。"
                    # メール通知
                    send_mail "MAC_ADDRESS:${mac_address},SYS_ID:${sys_id}についてServiceNowへcurlコマンドを実行できませんでした。" "【CURLエラー】デバイス認証 ${mid_host} ${script_name}"
                    break
                fi
            done
        fi
        # 成功
        if [[ retry_count -ne 3 ]]; then
            # LISTファイルの同じmac種別、mac addressの行を削除
            log_debug "MAC_ADDRESS:${mac_address},SYS_ID:${sys_id}についてcurlコマンドが成功しました。(${7})"
            sed -i "/\"$mac_type\",\"$mac_address\"/d" $3
            echo $line >>"${2}_${current_time}_success"

        # 失敗
        else
            echo $line >>"${2}_${current_time}_failed"
        fi

        # failの場合は失敗理由も送信
        # 引数が9個存在した場合に処理
        if [[ $# -eq 9 ]]; then
            send_failed_log $8 $mac_address $sys_id $mac_type $9
        fi

    done <"${1}_${current_time}"

    # 成功の場合、ログ本体の値を削除
    while read line; do
        # 同じ値がなければ終了
        grep -sq $line $1 || continue
        # あれば削除
        sed -i "/${line}/d" $1

    done <"${2}_${current_time}_success"

    # 失敗の場合(成功と同じ処理)
    while read line; do
        # 同じ値がなければ終了
        grep -sq $line $1 || continue
        # あれば削除
        sed -i "/${line}/d" $1

    done <"${2}_${current_time}_failed"

}

# =================================================================================================
# メイン処理
# =================================================================================================

# ディレクトリ設定
dir_setting
# ログのディレクトリが存在しているか
sc_log_dir_check

# ディレクトリ存在確認
[[ -e $EXPORT_DIR ]] || error_dir $EXPORT_DIR 
[[ -e $MID_DIR ]] || error_dir $MID_DIR 

[[ -e $CNADD_LOG_DIR ]] || error_dir $CNADD_LOG_DIR 
[[ -e $CNDEL_LOG_DIR ]] || error_dir $CNDEL_LOG_DIR 
[[ -e $MACADD_LOG_DIR ]] || error_dir $MACADD_LOG_DIR 
[[ -e $MACDEL_LOG_DIR ]] || error_dir $MACDEL_LOG_DIR 

[[ -e $CNADD_LIST_DIR ]] || error_dir $CNADD_LIST_DIR 
[[ -e $CNDEL_LIST_DIR ]] || error_dir $CNDEL_LIST_DIR 
[[ -e $MACADD_LIST_DIR ]] || error_dir $MACADD_LIST_DIR 
[[ -e $MACDEL_LIST_DIR ]] || error_dir $MACDEL_LIST_DIR 

[[ -e $CNADD_JOB_DIR ]] || error_dir $CNADD_JOB_DIR 
[[ -e $CNDEL_JOB_DIR ]] || error_dir $CNDEL_JOB_DIR 
[[ -e $MACADD_JOB_DIR ]] || error_dir $MACADD_JOB_DIR 
[[ -e $MACDEL_JOB_DIR ]] || error_dir $MACDEL_JOB_DIR 

# ファイル存在確認
[[ -e $CNADD_LOG ]] || touch $CNADD_LOG 
[[ -e $CNDEL_LOG ]] || touch $CNDEL_LOG 
[[ -e $MACADD_LOG ]] || touch $MACADD_LOG 
[[ -e $MACDEL_LOG ]] || touch $MACDEL_LOG 
[[ -e $CNADDFAIL_LOG ]] || touch $CNADDFAIL_LOG
[[ -e $CNDELFAIL_LOG ]] || touch $CNDELFAIL_LOG
[[ -e $MACADDFAIL_LOG ]] || touch $MACADDFAIL_LOG
[[ -e $MACDELFAIL_LOG ]] || touch $MACDELFAIL_LOG

[[ -e $JOB_CNADD_LOG ]] || touch $JOB_CNADD_LOG
[[ -e $JOB_CNDEL_LOG ]] || touch $JOB_CNDEL_LOG
[[ -e $JOB_MACADD_LOG ]] || touch $JOB_MACADD_LOG
[[ -e $JOB_MACDEL_LOG ]] || touch $JOB_MACDEL_LOG
[[ -e $JOB_CNADDFAIL_LOG ]] || touch $JOB_CNADDFAIL_LOG
[[ -e $JOB_CNDELFAIL_LOG ]] || touch $JOB_CNDELFAIL_LOG
[[ -e $JOB_MACADDFAIL_LOG ]] || touch $JOB_MACADDFAIL_LOG
[[ -e $JOB_MACDELFAIL_LOG ]] || touch $JOB_MACDELFAIL_LOG

[[ -e $CNADD_LIST ]] || touch $CNADD_LIST 
[[ -e $CNDEL_LIST ]] || touch $CNDEL_LIST 
[[ -e $MACADD_LIST ]] || touch $MACADD_LIST 
[[ -e $MACDEL_LIST ]] || touch $MACDEL_LIST 

log_info "${script_name}を開始します。"

# cnadd
if [ -s $CNADD_LOG ]; then
    rename_rglog $CNADD_LOG 
    get_rglog_cn_value $CNADD_LOG $JOB_CNADD_LOG
    if [ -s "${JOB_CNADD_LOG}_${current_time}" ]; then
        # delete_duplicate $JOB_CNADD_LOG $JOB_CNADD_LOG_TEMP
        search_cn_sys_id $JOB_CNADD_LOG $JOB_CNADD_LOG_TEMP $CNADD_LIST
        post_cn_sys_id $JOB_CNADD_LOG $JOB_CNADD_LOG_TEMP $CNADD_LIST "${cnadd_data}" "cnadd"
    else
        log_debug "パターンにマッチするログが存在しませんでした。(cnadd)"
    fi
    remove_files $CNADD_LOG_DIR "cnadd.log" "cnadd用RGログ"
    remove_files $CNADD_JOB_DIR "add_cn.csv" "cnadd用ログ抽出"
    remove_files $CNADD_JOB_DIR "add_cn_temp.csv" "cnadd用tmp" "success"
    keep_files $CNADD_JOB_DIR "add_cn_temp.csv" "cnadd用tmp" "failed"
else
    log_debug "${CNADD_LOG}にログが存在しないため終了します。(cnadd)"
fi

# cnaddfail
if [ -s $CNADDFAIL_LOG ]; then
    rename_rglog $CNADDFAIL_LOG 
    get_rglog_cn_value $CNADDFAIL_LOG $JOB_CNADDFAIL_LOG
    # get_fail_reason $CNADDFAIL_LOG
    if [ -s "${JOB_CNADDFAIL_LOG}_${current_time}" ]; then
        # delete_duplicate $JOB_CNADD_LOG $JOB_CNADD_LOG_TEMP
        search_cn_sys_id $JOB_CNADDFAIL_LOG $JOB_CNADDFAIL_LOG_TEMP $CNADD_LIST
        post_cn_sys_id $JOB_CNADDFAIL_LOG $JOB_CNADDFAIL_LOG_TEMP $CNADD_LIST "${cnadd_fail_data}" "cnadd_fail" $CNADDFAIL_LOG $CURL_CNADDFAIL_TEMP
    else
        log_debug "パターンにマッチするログが存在しませんでした。(cnadd_fail)"
    fi
    remove_files $CNADD_LOG_DIR "cnadd_failed.log" "cnadd_failed用RGログ"
    remove_files $CNADD_JOB_DIR "add_cn_failed.csv" "cnadd_failed用ログ抽出"
    remove_files $CNADD_JOB_DIR "add_cn_failed_temp.csv" "cnadd_failed用tmp" "success"
    keep_files $CNADD_JOB_DIR "add_cn_failed_temp.csv" "cnadd_failed用tmp" "failed"
else
    log_debug "${CNADDFAIL_LOG}にログが存在しないため終了します。(cnadd_fail)"
fi

# cndel
if [ -s $CNDEL_LOG ]; then
    rename_rglog $CNDEL_LOG 
    get_rglog_cn_value $CNDEL_LOG $JOB_CNDEL_LOG
    if [ -s "${JOB_CNDEL_LOG}_${current_time}" ]; then
        # delete_duplicate $JOB_CNDEL_LOG $JOB_CNDEL_LOG_TEMP
        search_cn_sys_id $JOB_CNDEL_LOG $JOB_CNDEL_LOG_TEMP $CNDEL_LIST
        post_cn_sys_id $JOB_CNDEL_LOG $JOB_CNDEL_LOG_TEMP $CNDEL_LIST "${cndel_data}" "cndel"
    else
        log_debug "パターンにマッチするログが存在しませんでした。(cndel)"
    fi
    remove_files $CNDEL_LOG_DIR "cndel.log" "cndel用RGログ"
    remove_files $CNDEL_JOB_DIR "del_cn.csv" "cndel用ログ抽出"
    remove_files $CNDEL_JOB_DIR "del_cn_temp.csv" "cndel用tmp" "success"
    keep_files $CNDEL_JOB_DIR "del_cn_temp.csv" "cndel用tmp" "failed"
else
    log_debug "${CNDEL_LOG}にログが存在しないため終了します。(cndel)"
fi

# cndelfail
if [ -s $CNDELFAIL_LOG ]; then
    rename_rglog $CNDELFAIL_LOG 
    get_rglog_cn_value $CNDELFAIL_LOG $JOB_CNDELFAIL_LOG
    if [ -s "${JOB_CNDELFAIL_LOG}_${current_time}" ]; then
        # delete_duplicate $JOB_CNDEL_LOG $JOB_CNDEL_LOG_TEMP
        search_cn_sys_id $JOB_CNDELFAIL_LOG $JOB_CNDELFAIL_LOG_TEMP $CNDEL_LIST
        post_cn_sys_id $JOB_CNDELFAIL_LOG $JOB_CNDELFAIL_LOG_TEMP $CNDEL_LIST "${cndel_fail_data}" "cndel_fail" $CNDELFAIL_LOG $CURL_CNDELFAIL_TEMP
    else
        log_debug "パターンにマッチするログが存在しませんでした。(cndel_fail)"
    fi
    remove_files $CNDEL_LOG_DIR "cndel_failed.log" "cndel_failed用RGログ"
    remove_files $CNDEL_JOB_DIR "del_cn_failed.csv" "cndel_failed用ログ抽出"
    remove_files $CNDEL_JOB_DIR "del_cn_failed_temp.csv" "cndel_failed用tmp" "success"
    keep_files $CNDEL_JOB_DIR "del_cn_failed_temp.csv" "cndel_failed用tmp" "failed"
else
    log_debug "${CNDELFAIL_LOG}にログが存在しないため終了します。(cndel_fail)"
fi

# macadd
if [ -s $MACADD_LOG ]; then
    rename_rglog $MACADD_LOG 
    get_rglog_mac_value $MACADD_LOG $JOB_MACADD_LOG
    if [ -s "${JOB_MACADD_LOG}_${current_time}" ]; then
        # delete_duplicate $JOB_MACADD_LOG $JOB_MACADD_LOG_TEMP
        search_mac_sys_id $JOB_MACADD_LOG $JOB_MACADD_LOG_TEMP $MACADD_LIST
        post_mac_sys_id $JOB_MACADD_LOG $JOB_MACADD_LOG_TEMP $MACADD_LIST "${mac1add_data}" "${mac2add_data}" "${mac_changed_del_data}" "macadd"
    else
        log_debug "パターンにマッチするログが存在しませんでした。(macadd)"
    fi
    remove_files $MACADD_LOG_DIR "macadd.log" "macadd用RGログ"
    remove_files $MACADD_JOB_DIR "add_mac.csv" "macadd用ログ抽出"
    remove_files $MACADD_JOB_DIR "add_mac_temp.csv" "macadd用tmp" "success"
    keep_files $MACADD_JOB_DIR "add_mac_temp.csv" "macadd用tmp" "failed"
else
    log_debug "${MACADD_LOG}にログが存在しないため終了します。(macadd)"
fi

# macaddfail
if [ -s $MACADDFAIL_LOG ]; then
    rename_rglog $MACADDFAIL_LOG 
    get_rglog_mac_value $MACADDFAIL_LOG $JOB_MACADDFAIL_LOG
    if [ -s "${JOB_MACADDFAIL_LOG}_${current_time}" ]; then
        # delete_duplicate $JOB_MACADD_LOG $JOB_MACADD_LOG_TEMP
        search_mac_sys_id $JOB_MACADDFAIL_LOG $JOB_MACADDFAIL_LOG_TEMP $MACADD_LIST
        post_mac_sys_id $JOB_MACADDFAIL_LOG $JOB_MACADDFAIL_LOG_TEMP $MACADD_LIST "${mac1add_fail_data}" "${mac2add_fail_data}" "${mac_changed_fail_del_data}" "macadd_fail" $MACADDFAIL_LOG $CURL_MACADDFAIL_TEMP
    else
        log_debug "パターンにマッチするログが存在しませんでした。(macadd_fail)"
    fi
    remove_files $MACADD_LOG_DIR "macadd_failed.log" "macadd_failed用RGログ"
    remove_files $MACADD_JOB_DIR "add_mac_failed.csv" "macadd_failed用ログ抽出"
    remove_files $MACADD_JOB_DIR "add_mac_failed_temp.csv" "macadd_failed用tmp" "success"
    keep_files $MACADD_JOB_DIR "add_mac_failed_temp.csv" "macadd_failed用tmp" "failed"
else
    log_debug "${MACADDFAIL_LOG}にログが存在しないため終了します。(macadd_fail)"
fi

# macdel
if [ -s $MACDEL_LOG ]; then
    rename_rglog $MACDEL_LOG 
    get_rglog_mac_value $MACDEL_LOG $JOB_MACDEL_LOG
    if [ -s "${JOB_MACDEL_LOG}_${current_time}" ]; then
        # delete_duplicate $JOB_MACDEL_LOG $JOB_MACDEL_LOG_TEMP
        search_mac_sys_id $JOB_MACDEL_LOG $JOB_MACDEL_LOG_TEMP $MACDEL_LIST
        post_mac_sys_id $JOB_MACDEL_LOG $JOB_MACDEL_LOG_TEMP $MACDEL_LIST "${mac1del_data}" "${mac2del_data}" "${mac_changed_del_data}" "macdel"
    else
        log_debug "パターンにマッチするログが存在しませんでした。(macdel)"
    fi
    remove_files $MACDEL_LOG_DIR "macdel.log" "macdel用RGログ"
    remove_files $MACDEL_JOB_DIR "del_mac.csv" "macdel用ログ抽出"
    remove_files $MACDEL_JOB_DIR "del_mac_temp.csv" "macdel用tmp" "success"
    keep_files $MACDEL_JOB_DIR "del_mac_temp.csv" "macdel用tmp" "failed"
else
    log_debug "${MACDEL_LOG}にログが存在しないため終了します。(macdel)"
fi

# macdelfail
if [ -s $MACDELFAIL_LOG ]; then
    rename_rglog $MACDELFAIL_LOG 
    get_rglog_mac_value $MACDELFAIL_LOG $JOB_MACDELFAIL_LOG
    if [ -s "${JOB_MACDELFAIL_LOG}_${current_time}" ]; then
        # delete_duplicate $JOB_MACDEL_LOG $JOB_MACDEL_LOG_TEMP
        search_mac_sys_id $JOB_MACDELFAIL_LOG $JOB_MACDELFAIL_LOG_TEMP $MACDEL_LIST
        post_mac_sys_id $JOB_MACDELFAIL_LOG $JOB_MACDELFAIL_LOG_TEMP $MACDEL_LIST "${mac1del_fail_data}" "${mac2del_fail_data}" "${mac_changed_fail_del_data}" "macdel_fail" $MACDELFAIL_LOG $CURL_MACDELFAIL_TEMP
    else
        log_debug "パターンにマッチするログが存在しませんでした。(macdel_fail)"
    fi
    remove_files $MACDEL_LOG_DIR "macdel_failed.log" "macdel_failed用RGログ"
    remove_files $MACDEL_JOB_DIR "del_mac_failed.csv" "macdel_failed用ログ抽出"
    remove_files $MACDEL_JOB_DIR "del_mac_failed_temp.csv" "macdel_failed用tmp" "success"
    keep_files $MACDEL_JOB_DIR "del_mac_failed_temp.csv" "macdel_failed用tmp" "failed"
else
    log_debug "${MACDELFAIL_LOG}にログが存在しないため終了します。(macdel_fail)"
fi

log_info "${script_name}を終了します。"
