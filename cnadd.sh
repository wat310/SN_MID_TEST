#!/bin/bash
# ディレクトリの監視にinotify-toolsを使用

# =================================================================================================
# 定数設定
# =================================================================================================

# スクリプトログ関係
LOG_LEVEL='DEBUG'
LOG_FILE='export.log' # ログファイル名
SCRIPT_NAME='cnadd.sh' # 実行スクリプト名
RG_TYPE='cn'
RG_STATUS='add'
RG_FILE_NAME='CnAdd_Snw.csv'

# =================================================================================================
# 変数設定
# =================================================================================================

mid_host=$(hostname) # MIDサーバーのホスト名

# =================================================================================================
# 関数設定
# =================================================================================================

# ディレクトリ設定の関数
function dir_setting() {

    # 検証環境MID1
    if [ $mid_host = 'st-ty1-snow-cmdb-mid01' ] ; then
        MAIN_EXPORT_DIR='/servicenow/st-ty1-snow-cmdb-mid01/agent/export/radius_guard/'
        MID_DIR="${MAIN_EXPORT_DIR}mid1/${RG_TYPE}${RG_STATUS}/" # 各MIDサーバ用ディレクトリ
        STANDBY_CONVERTED_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid02/home/rguser/'
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid1/' # 【開発】ログのディレクトリ

    # 検証環境MID2
    elif [ $mid_host = 'st-ty1-snow-cmdb-mid02' ] ; then
        MAIN_EXPORT_DIR='/servicenow/st-ty1-snow-cmdb-mid02/agent/export/radius_guard/'
        MID_DIR="${MAIN_EXPORT_DIR}mid2/${RG_TYPE}${RG_STATUS}/" # 各MIDサーバ用ディレクトリ
        STANDBY_CONVERTED_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid01/home/rguser/'
        LOG_DIR='/mnt/servicenow_cmdb02/st-ty1-snow-cmdb-mid/script_log/mid2/' # 【開発】ログのディレクトリ

    # 本番環境MID1
    elif [ $mid_host = 'ty1-snow-cmdb-mid01' ] ; then
        MAIN_EXPORT_DIR='/servicenow/ty1-snow-cmdb-mid01/agent/export/radius_guard/'
        MID_DIR="${MAIN_EXPORT_DIR}mid1/${RG_TYPE}${RG_STATUS}/" # 各MIDサーバ用ディレクトリ
        STANDBY_CONVERTED_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid02/home/rguser/'
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid1/' # 【本番】ログのディレクトリ

    # 本番環境MID2
    elif [ $mid_host = 'ty1-snow-cmdb-mid02' ] ; then
        MAIN_EXPORT_DIR='/servicenow/ty1-snow-cmdb-mid02/agent/export/radius_guard/'
        MID_DIR="${MAIN_EXPORT_DIR}mid2/${RG_TYPE}${RG_STATUS}/" # 各MIDサーバ用ディレクトリ
        STANDBY_CONVERTED_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid01/home/rguser/'
        LOG_DIR='/mnt/servicenow_cmdb01/ty1-snow-cmdb-mid/script_log/mid2/' # 【本番】ログのディレクトリ

    else
        echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$SCRIPT_NAME] [ホスト名を判定できませんでした。${SCRIPT_NAME}を終了します。]"
        exit 1
    fi

    EXPORT_DIR="${MAIN_EXPORT_DIR}${RG_TYPE}${RG_STATUS}/" # ファイルが配置されるディレクトリ
    CURRENT_CONVERTED_DIR='/home/rguser/'
    ARCHIVE_DIR="${MID_DIR}archive/" # RG登録後のファイル移動先(MIDサーバごと)
    EXPORTED_DIR="${MID_DIR}exportd/" # 整形前のcsvを配置するディレクトリ(MIDサーバごと)
    LIST_DIR="${EXPORT_DIR}list/" # nameとsys_idを保管するファイルを置くディレクトリ
    LIST_FILE="${EXPORT_DIR}list/${RG_TYPE}${RG_STATUS}_list.csv" # nameとsys_idのリスト
    CURRENT_CONVERTED_FILE="${CURRENT_CONVERTED_DIR}${RG_FILE_NAME}"
    STANDBY_CONVERTED_FILE="${STANDBY_CONVERTED_DIR}${RG_FILE_NAME}"

}

# ログを出力する関数
# infoのログ
function log_info() {
  echo "$(date "+%Y%m%d%H%M%S") [INFO] [$SCRIPT_NAME] [${1}]" >> $LOG_DIR$LOG_FILE
}
# debugのログ
function log_debug() {
  if [ $LOG_LEVEL = 'DEBUG' ] ; then
    echo "$(date "+%Y%m%d%H%M%S") [DEBUG] [$SCRIPT_NAME] [${1}]" >> $LOG_DIR$LOG_FILE
  fi
}
# errorのログ
function log_error() {
  echo "$(date "+%Y%m%d%H%M%S") [ERROR] [$SCRIPT_NAME] [${1}]" >> $LOG_DIR$LOG_FILE
}

# ディレクトリのエラー発生時
function dir_log() {
  log_error "${1}が存在しません。"
  log_debug "${1}を作成します。"
}

# スクリプトログのディレクトリの存在確認
function sc_log_dir_check() {
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

# ディレクトリの監視
inotifywait -m -q -e create $EXPORT_DIR | while read line; do
  current_time_2=$(date "+%Y%m%d%H%M%S") # 現在時刻(while文内)
  set $line
  file_name=${3} # 監視出力の3番目がファイル名

  # CSVでない場合はcontinue
  [[ $file_name =~ .*\.csv ]] || continue
  log_info "${EXPORT_DIR}に${file_name}が配置されました。"

  # 元ファイルをEXPORTED_DIRに移動
  log_debug "${EXPORT_DIR}${file_name}を${EXPORTED_DIR}に移動します。"
  if [ -f ${EXPORT_DIR}${file_name} ]; then
    mv $EXPORT_DIR$file_name $EXPORTED_DIR$file_name
  else
    log_debug "${EXPORT_DIR}${file_name}が存在しません。${file_name}について処理を終了します。監視を継続します。"
    continue
  fi

  if [[ -z ${EXPORTED_DIR}${file_name} ]]; then 
    log_debug "${EXPORTED_DIR}${file_name}が存在しません。${file_name}について処理を終了します。監視を継続します。"
    continue
  fi

    # csv整形(ヘッダー削除、ファイル作成、/home/rguser/(CONVERTED)に配置)
    log_debug "csvファイルを整形して${CURRENT_CONVERTED_FILE}に配置します。"
    FILE=${EXPORTED_DIR}${file_name}
    # LISTFILE用tmpファイルを作成
    touch "${LIST_FILE}_${current_time_2}"
    # RG出力用tmpファイルを作成
    touch "${ARCHIVE_DIR}rg_${current_time_2}.csv"

    # 不自然に改行されている行を修正(行末が"ではない部分)
    # Business_PhoneなどServiceNow内ですでに改行ありで入力されている部分が対象
    cat $FILE | sed -i -e ':loop; N; $!b loop; s/[^\"]\n//g' $FILE

    # nameが「-」の場合は「'-」になっているので、最初の「'」を取り除く 
    sed -i -e "s/\"'/\"/g" $FILE

    # RG出力用データ作成
    # r3_contract_number,asset_tag,assined_to,vlan,sys_id,asset_class,cert_sync_status が飛んでくる想定

    # ヘッダー削除
    sed -i -e '1d' $FILE
    while read line
    do
        # ","が多い場合はerrorを出力してcontinue
        if [ $(echo -n $line | sed -e 's@[^,]@@g' | wc -c) != 6 ];then
            log_error "「,」の数にエラーが発生しました。${line}の処理をスキップします。"
            continue
        fi

        # cnが次のループに引き継がれないようにリセット
        cn="";

        assined_to=$(echo $line | cut -d ',' -f 3 | sed -e "s/\"//g")
        vlan=$(echo $line | cut -d ',' -f 4 | sed -e "s/\"//g")
        sys_id=$(echo $line | cut -d ',' -f 5 | sed -e "s/\"//g")
        sync_status=$(echo $line | cut -d ',' -f 7 | sed -e "s/\"//g")
        # "Original"(独自)の場合はCN名をasset_tagとする
        # "RⅢ"の場合はCN名をr3_contract_number(RⅢ契約番号)の先頭10桁とする
        #  小文字は大文字に変換する
        asset_class=$(echo $line | cut -d ',' -f 6 | sed -e "s/\"//g")
        if [ "$asset_class" = "Original" ]; then
            cn=$(echo $line | cut -d ',' -f 2 | sed -e "s/\"//g" | sed "s/\(.*\)/\U\1/")
        elif [ "$asset_class" = "RⅢ" ] ; then
            cn=$(echo $line | cut -d ',' -f 1 | sed -e "s/\"//g" | sed "s/\(.*\)/\U\1/" | cut -c 1-10)
        fi
        if [ -z "$cn" ]; then
            continue
        fi
        # requestingで来た場合(=Adding以外)はリストに記載しない
        if [ "$sync_status" == "Adding" ]; then
            # リスト用データ(再度""を付ける)
            echo "\"${cn}\",\"${sys_id}\"" >>"${LIST_FILE}_${current_time_2}"
        fi
        # RG出力用データ
        echo "${cn},,,,,,,,,${assined_to},,,,,,,,,,,,,,,,,,1,,,,,,,,,,,,,,,,,,証明書申請,,,,,13,6,${vlan},,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,," >>"${ARCHIVE_DIR}rg_${current_time_2}.csv"

    done <$FILE

    # 同じ値がリストに存在する場合は書き込みを行わない
    log_debug "nameとsys_idを${LIST_FILE}に出力します。"
    if [ -e ${LIST_FILE} ] ; then
      while read line
      do
        # 同じnameがあれば追記しない(重複は次回へ持ち越し)
        # name=$(echo $line | cut -d ',' -f 1)
        name=$(echo $line | cut -d ',' -f 1 | sed -e "s/\"//g")
        grep -sq -E "^\"${name}\"" $LIST_FILE && continue
        # 完全重複でなければ追記を行う
        grep -sq $line $LIST_FILE || echo $line >> $LIST_FILE

      done <"${LIST_FILE}_${current_time_2}"
    else
        log_debug "${LIST_FILE}が存在しません。"
    fi

    # 文字コードを変更して/home/rguser/に配置
    # US-ASCIIの場合は日本語が入っていないのでそのまま
    touch "${ARCHIVE_DIR}${RG_FILE_NAME}_${current_time_2}.csv"
    iconv -f UTF-8 -t MS932 -c -o "${ARCHIVE_DIR}${RG_FILE_NAME}_${current_time_2}.csv" "${ARCHIVE_DIR}rg_${current_time_2}.csv"
    rm "${ARCHIVE_DIR}rg_${current_time_2}.csv"

    # currentの/home/rguser/の移動、コピー
    if [ -f ${CURRENT_CONVERTED_FILE} ]; then
        # log_debug "${CURRENT_CONVERTED_FILE}を${ARCHIVE_DIR}${RG_TYPE}_${RG_STATUS}_${current_time_2}.csvに移動します。"
        log_debug "${CURRENT_CONVERTED_FILE}を削除します。"
        # mv $CURRENT_CONVERTED_FILE "${ARCHIVE_DIR}${RG_TYPE}_${RG_STATUS}_${current_time_2}.csv"
        rm $CURRENT_CONVERTED_FILE
    fi
    log_debug "${ARCHIVE_DIR}${RG_FILE_NAME}_${current_time_2}.csvを$CURRENT_CONVERTED_FILEにコピーします。"
    cp -p "${ARCHIVE_DIR}${RG_FILE_NAME}_${current_time_2}.csv" $CURRENT_CONVERTED_FILE

    # standbyの/home/rguser/の削除、コピー
    if [ -f ${STANDBY_CONVERTED_FILE} ]; then
        log_debug "${STANDBY_CONVERTED_FILE}を削除します。"
        rm $STANDBY_CONVERTED_FILE
    fi
    cp -p "${ARCHIVE_DIR}${RG_FILE_NAME}_${current_time_2}.csv" $STANDBY_CONVERTED_FILE

    # tmpLISTファイルのローテート
    remove_files $LIST_DIR "${RG_TYPE}${RG_STATUS}_list.csv"

    log_info "${file_name}について処理を終了します。監視を継続します。"  
done

log_info "${SCRIPT_NAME}を終了します。"