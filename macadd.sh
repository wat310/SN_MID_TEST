#!/bin/bash
# ディレクトリの監視にinotify-toolsを使用

# =================================================================================================
# 定数設定
# =================================================================================================

# ディレクトリ、ファイル関係
MACADD1='macadd1' # ファイル名(macadd1)
MACADD2='macadd2' # ファイル名(macadd2)

# スクリプトログ関係
LOG_LEVEL='DEBUG'
LOG_FILE='export.log'   # ログファイル名
SCRIPT_NAME='macadd.sh' # 実行スクリプト名
RG_TYPE='mac'
RG_STATUS='add'
RG_FILE_NAME='MacAdd_Snw.csv'

# =================================================================================================
# 変数設定
# =================================================================================================

mid_host=$(hostname)                # MIDサーバーのホスト名

# =================================================================================================
# 関数設定
# =================================================================================================

# ディレクトリ設定の関数
function dir_setting() {

  # 検証環境MID1
  if [ $mid_host = 'st-ty1-snow-cmdb-mid01' ]; then
    MAIN_EXPORT_DIR='/servicenow/st-ty1-snow-cmdb-mid01/agent/export/radius_guard/'
    MID_DIR="${MAIN_EXPORT_DIR}mid1/${RG_TYPE}${RG_STATUS}/" # 各MIDサーバ用ディレクトリ
    STANDBY_CONVERTED_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid02/home/rguser/'
    LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid1/'            # 【開発】ログのディレクトリ

  # 検証環境MID2
  elif [ $mid_host = 'st-ty1-snow-cmdb-mid02' ]; then
    MAIN_EXPORT_DIR='/servicenow/st-ty1-snow-cmdb-mid02/agent/export/radius_guard/'
    MID_DIR="${MAIN_EXPORT_DIR}mid2/${RG_TYPE}${RG_STATUS}/" # 各MIDサーバ用ディレクトリ
    STANDBY_CONVERTED_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid01/home/rguser/'
    LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid2/'            # 【開発】ログのディレクトリ

  # 本番環境MID1
  elif [ $mid_host = 'ty1-snow-cmdb-mid01' ]; then
    MAIN_EXPORT_DIR='/servicenow/ty1-snow-cmdb-mid01/agent/export/radius_guard/'
    MID_DIR="${MAIN_EXPORT_DIR}mid1/${RG_TYPE}${RG_STATUS}/" # 各MIDサーバ用ディレクトリ
    STANDBY_CONVERTED_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid02/home/rguser/'
    LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid1/'            # 【本番】ログのディレクトリ

  # 本番環境MID2
  elif [ $mid_host = 'ty1-snow-cmdb-mid02' ]; then
    MAIN_EXPORT_DIR='/servicenow/ty1-snow-cmdb-mid02/agent/export/radius_guard/'
    MID_DIR="${MAIN_EXPORT_DIR}mid2/${RG_TYPE}${RG_STATUS}/" # 各MIDサーバ用ディレクトリ
    STANDBY_CONVERTED_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid01/home/rguser/'
    LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid2/'            # 【本番】ログのディレクトリ

  else
    echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$SCRIPT_NAME] [ホスト名を判定できませんでした。${SCRIPT_NAME}を終了します。]"
    exit 1
  fi

  EXPORT_DIR="${MAIN_EXPORT_DIR}${RG_TYPE}${RG_STATUS}/" # ファイルが配置されるディレクトリ
  CURRENT_CONVERTED_DIR='/home/rguser/'
  ARCHIVE_DIR="${MID_DIR}archive/"           # RG登録後のファイル移動先(MIDサーバごと)
  EXPORTED_DIR="${MID_DIR}exportd/"          # 整形前のcsvを配置するディレクトリ(MIDサーバごと)
  LIST_DIR="${EXPORT_DIR}list/"                 # nameとsys_idを保管するファイルを置くディレクトリ
  LIST_FILE="${EXPORT_DIR}list/${RG_TYPE}${RG_STATUS}_list.csv" # nameとsys_idのリスト
  CURRENT_CONVERTED_FILE="${CURRENT_CONVERTED_DIR}${RG_FILE_NAME}"
  STANDBY_CONVERTED_FILE="${STANDBY_CONVERTED_DIR}${RG_FILE_NAME}"

}

# ログを出力する関数
# infoのログ
function log_info() {
  echo "$(date "+%Y%m%d%H%M%S") [INFO] [$SCRIPT_NAME] [${1}]" >>$LOG_DIR$LOG_FILE
}
# debugのログ
function log_debug() {
  if [ $LOG_LEVEL = 'DEBUG' ]; then
    echo "$(date "+%Y%m%d%H%M%S") [DEBUG] [$SCRIPT_NAME] [${1}]" >>$LOG_DIR$LOG_FILE
  fi
}
# errorのログ
function log_error() {
  echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$SCRIPT_NAME] [${1}]" >>$LOG_DIR$LOG_FILE
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
function remove_files() {
  cd ${1}
  if [[ -n $(ls -r | grep "${2}_" | tail -n +15) ]] ; then # 15件目以降が存在したら実行
    log_debug "${1}のファイルをローテートします。"
    rm $(ls -r | grep "${2}_" | tail -n +15) # 15件目以降を削除
  fi
}

# =================================================================================================
# メイン処理
# =================================================================================================

# ディレクトリ設定
dir_setting
# ログのディレクトリが存在しているか
sc_log_dir_check

log_info "${SCRIPT_NAME}を開始します。"

# ディレクトリ存在確認
[[ -e $EXPORT_DIR ]] || error_dir $EXPORT_DIR
[[ -e $CURRENT_CONVERTED_DIR ]] || error_dir $CURRENT_CONVERTED_DIR
[[ -e $EXPORTED_DIR ]] || error_dir $EXPORTED_DIR
[[ -e $LIST_DIR ]] || error_dir $LIST_DIR
[[ -e $ARCHIVE_DIR ]] || error_dir $ARCHIVE_DIR
[[ -e $LIST_FILE ]] || touch $LIST_FILE

log_debug "${EXPORT_DIR}を監視します。"

macadd1_file='' # ファイル名保持用変数
macadd2_file='' # ファイル名保持用変数

# ディレクトリの監視
inotifywait -m -q -e create $EXPORT_DIR | while read line; do
    set $line
    file_name=${3}                       # 監視出力の3番目がファイル名
    current_time=$(date "+%Y%m%d%H%M%S") # 現在時刻(while文内)
    [[ $file_name =~ .*\.csv ]] && log_info "${EXPORT_DIR}に${file_name}が配置されました。"

    if [[ $file_name =~ $MACADD1 ]]; then   # ファイル名がmacadd1の場合
        macadd1_file=$file_name               # ファイル名を保持（既に保持済みの場合、新しい方に更新）
    elif [[ $file_name =~ $MACADD2 ]]; then # ファイル名がmacadd2の場合
        macadd2_file=$file_name               # ファイル名を保持（既に保持済みの場合、新しい方に更新）
    else
        continue
    fi

    # macadd1、macadd2の両方のファイルが揃った場合に処理を行う
    if [[ $macadd1_file = "" ]] || [[ $macadd2_file = "" ]];then
        continue
    fi

    # 元ファイルをEXPORTED_DIRに移動
    log_debug "${EXPORT_DIR}${macadd1_file}を${EXPORTED_DIR}に移動します。"
    if [ -f ${EXPORT_DIR}${macadd1_file} ]; then
        mv $EXPORT_DIR$macadd1_file $EXPORTED_DIR$macadd1_file
    else
        log_debug "${EXPORT_DIR}${macadd1_file}が存在しません。${macadd1_file}について処理を終了します。監視を継続します。"
        macadd1_file=''
        continue
    fi
    log_debug "${EXPORT_DIR}${macadd2_file}を${EXPORTED_DIR}に移動します。"
    if [ -f ${EXPORT_DIR}${macadd2_file} ]; then
        mv $EXPORT_DIR$macadd2_file $EXPORTED_DIR$macadd2_file
    else
        log_debug "${EXPORT_DIR}${macadd2_file}が存在しません。${macadd2_file}について処理を終了します。監視を継続します。"
        macadd2_file=''
        continue
    fi
    if [[ -z ${EXPORTED_DIR}${macadd1_file} ]]; then 
        log_debug "${EXPORTED_DIR}${macadd1_file}が存在しません。${macadd1_file}について処理を終了します。監視を継続します。"
        macadd1_file=''
        continue
    fi
    if [[ -z ${EXPORTED_DIR}${macadd2_file} ]]; then 
        log_debug "${EXPORTED_DIR}${macadd2_file}が存在しません。${macadd2_file}について処理を終了します。監視を継続します。"
        macadd2_file=''
        continue
    fi

    # csv整形(ヘッダー削除、ファイル作成、/home/rguser/(CONVERTED)に配置)
    log_debug "${macadd1_file}と${macadd2_file}を変換・結合して${CURRENT_CONVERTED_FILE}に配置します。"
    # LISTFILE用tmpファイルを作成
    touch "${LIST_FILE}_${current_time}"
    # RG出力用tmpファイルを作成
    touch "${ARCHIVE_DIR}rg_${current_time}.csv"

    cd $EXPORTED_DIR
    for file in $macadd1_file $macadd2_file; do
        # 不自然に改行されている行を修正(行末が"ではない部分)
        # Business_PhoneなどServiceNow内ですでに改行ありで入力されている部分が対象
        cd $EXPORTED_DIR
        cat $file | sed -i -e ':loop; N; $!b loop; s/[^\"]\n//g' $file

        # RG出力用データ作成
        # mac_address1or2,assined_to,vlan,sys_id,mac_sync_status1or2 が飛んでくる想定

        # ヘッダー削除して行ごとの処理
        sed -i -e '1d' $file
        while read line
        do
            # ","が多い場合はerrorを出力してcontinue
            if [ $(echo -n $line | sed -e 's@[^,]@@g' | wc -c) != 4 ];then
                log_error "「,」の数にエラーが発生しました。${line}の処理をスキップします。"
                continue
            fi

            # macアドレス
            mac=$(echo ${line} | sed -e s/\"//g | cut -d ',' -f 1)
            # macアドレス(コロン、ハイフンなし)
            macl=$(echo ${line} | sed -e s/\"//g | sed -e s/://g -e s/-//g | cut -d ',' -f 1)
            # ruid
            ruid=$(echo ${line} | sed -e s/\"//g | cut -d ',' -f 2)
            # vlan
            vlan=$(echo ${line} | sed -e s/\"//g | cut -d ',' -f 3)
            # sys_id
            sys_id=$(echo ${line} | sed -e s/\"//g | cut -d ',' -f 4)
            sync_status=$(echo ${line} | sed -e s/\"//g | cut -d ',' -f 5)

            if [ -z "$macl" ]; then
                continue
            fi
            # 整形したcsv行の出力
            echo "${macl},,,${ruid},,,,,,,,,,,,,,,,,,,,,,,,,,,,,13,6,${vlan},,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,," >>"${ARCHIVE_DIR}rg_${current_time}.csv"
            # コロンありのmac addressをリストに登録

            # requestingで来た場合(=Adding以外)はリストに記載しない
            if [ "$sync_status" == "Adding" ]; then
                ## mac1とmac2の識別が必要
                if [[ $file =~ $MACADD1 ]]; then # ファイル名がmacadd1の場合
                    echo "\"mac1\",\"${macl}\",\"${sys_id}\"" >>"${LIST_FILE}_${current_time}"
                elif [[ $file =~ $MACADD2 ]]; then # ファイル名がmacadd2の場合
                    echo "\"mac2\",\"${macl}\",\"${sys_id}\"" >>"${LIST_FILE}_${current_time}"
                else
                    continue
                fi
            fi

        done <$file

        # 同じ値がリストに存在する場合は書き込みを行わない
        log_debug "mac_addressとsys_idを${LIST_FILE}に出力します。"
        if [ -e ${LIST_FILE} ]; then
            while read line
            do
                # 同じmacaddressがあれば追記しない(重複は次回へ持ち越し)
                # mac_type=$(echo $line | cut -d ',' -f 1)
                # mac=$(echo $line | cut -d ',' -f 2)
                mac_type=$(echo $line | cut -d ',' -f 1 | sed -e s/\"//g)
                mac=$(echo $line | cut -d ',' -f 2 | sed -e s/\"//g)
                grep -sq -E "^\"${mac_type}\",\"${mac}\"" $LIST_FILE && continue
                # 完全重複でなければ追記を行う
                grep -sq $line $LIST_FILE || echo $line >> $LIST_FILE

            done <"${LIST_FILE}_${current_time}"
        else
            log_debug "${LIST_FILE}が存在しません。"
        fi
    done

    # 文字コードを変更して/home/rguser/に配置
    # US-ASCIIの場合は日本語が入っていないのでそのまま
    touch "${ARCHIVE_DIR}${RG_FILE_NAME}_${current_time}.csv"
    iconv -f UTF-8 -t MS932 -c -o "${ARCHIVE_DIR}${RG_FILE_NAME}_${current_time}.csv" "${ARCHIVE_DIR}rg_${current_time}.csv"
    rm "${ARCHIVE_DIR}rg_${current_time}.csv"

    # currentの/home/rguser/の移動、コピー
    if [ -f ${CURRENT_CONVERTED_FILE} ]; then
        # log_debug "${CURRENT_CONVERTED_FILE}を${ARCHIVE_DIR}${RG_TYPE}_${RG_STATUS}_${current_time}.csvに移動します。"
        log_debug "${CURRENT_CONVERTED_FILE}を削除します。"
        # mv $CURRENT_CONVERTED_FILE "${ARCHIVE_DIR}${RG_TYPE}_${RG_STATUS}_${current_time}.csv"
        rm $CURRENT_CONVERTED_FILE
    fi
    log_debug "${ARCHIVE_DIR}${RG_FILE_NAME}_${current_time}.csvを$CURRENT_CONVERTED_FILEにコピーします。"
    cp -p "${ARCHIVE_DIR}${RG_FILE_NAME}_${current_time}.csv" $CURRENT_CONVERTED_FILE

    # standbyの/home/rguser/の削除、コピー
    if [ -f ${STANDBY_CONVERTED_FILE} ]; then
        log_debug "${STANDBY_CONVERTED_FILE}を削除します。"
        rm $STANDBY_CONVERTED_FILE
    fi
    cp -p "${ARCHIVE_DIR}${RG_FILE_NAME}_${current_time}.csv" $STANDBY_CONVERTED_FILE

    # tmpLISTファイルのローテート
    remove_files $LIST_DIR "${RG_TYPE}${RG_STATUS}_list.csv"

    log_info "監視を継続します。"  

    # 結合処理終了後、ファイル名を保持していた変数を初期化
    macadd1_file=''
    macadd2_file=''
done

log_info "${SCRIPT_NAME}を終了します。"
