#!/bin/bash
current_time=$(date)

#define mysql connect option
connect_support=" support -BNe "

# for testing on the copy of support/dev db on the local server:
# connect_support=" -uroot -pPassword1 support -ABNe "

# FUNCTIONS ===================================================================================

# function receives the source file,calculates the grade and updates temp files
function processFile(){
    echo "---" >> ${log_file}
    echo "Processing file $1" >> ${log_file}
    while IFS=',' read -r line || [[ -n "${line}" ]]; do
        while IFS=',' read company_id new_grade; do
            old_grade=$(cat ${company_files_folder}/${company_id})
            new_value=$((old_grade+new_grade))
            echo ${new_value} > ${company_files_folder}/${company_id}
            echo -e "---Company ID: \t$company_id \tOld grade: \t$old_grade \tNew grade: \t$new_grade \tNew calculated value: \t$new_value" >> ${log_file}
        done
    done < ${loc}/$1
    echo "Finished file $1" >> ${log_file}
}

# receive the file, go through lines, query the database,put result as HTML to the report
function processResultFile(){
    echo "Inside processResultFile " >> ${log_file}
    rm -rf ${resultSet}
    company_list=$(cat $1 | tr -s ' ' | cut -d ',' -f 1 | tr '\n' ',' | sed 's/,$//')
    echo "Company list for $1 : ${company_list}" >> ${log_file}
    echo "---" >> ${log_file}

    mysql ${connect_support} "select  c.company_id, c.company_name, a.title, DATE(c.expiration_time) AS 'Expiration', c.company_cust_total_prolong, c.company_cust_currency, cust.value_caption from  company c join agreement a on c.agreement=a.id join cust_values cust on c.company_cust_account_manager=cust.value_key and list_name='company_cust_account_manager' where  company_id in (${company_list}) into outfile '${resultSet}' fields terminated by ',';"

    while read line; do
        while IFS=',' read -a fields ; do
            if [ "$1" = "${loc}/result_HighRisk.txt" ]; then
                echo '<tr style="font-size:15px" bgcolor="#ffd2d2">'  >> ${loc}/ClientsAtRisk.htm

                elif [ "$1" = "${loc}/result_MediumRisk.txt" ];then
                    echo '<tr style="font-size:15px" bgcolor="#FFFF4C">' >> ${loc}/ClientsAtRisk.htm

                elif [ "$1" = "${loc}/result_LowRisk.txt" ];then
                    echo '<tr style="font-size:15px" bgcolor="#daffda">' >> ${loc}/ClientsAtRisk.htm
            fi

            echo "<td>&nbsp;${fields[0]}</td>" >> ${loc}/ClientsAtRisk.htm # company id
            echo "<td>&nbsp;${fields[1]}</td>" >> ${loc}/ClientsAtRisk.htm # name
            echo "<td>&nbsp;${fields[2]}</td>" >> ${loc}/ClientsAtRisk.htm # agreement
            echo "<td>&nbsp;${fields[3]}</td>" >> ${loc}/ClientsAtRisk.htm # Expiration
            echo "<td>&nbsp;${fields[4]}</td>" >> ${loc}/ClientsAtRisk.htm # Renewal
            echo "<td>&nbsp;${fields[5]}</td>" >> ${loc}/ClientsAtRisk.htm # currency
            echo "<td>&nbsp;${fields[6]}</td>" >> ${loc}/ClientsAtRisk.htm # Account manager
            grade=$(cat ${company_files_folder}/${fields[0]})
            echo "<td>&nbsp; ${grade}</td>" >> ${loc}/ClientsAtRisk.htm     # grade
            echo "</tr>" >> ${loc}/ClientsAtRisk.htm
        done
    done < ${resultSet}
}
# =============================================================================================





# create work directory and subdirectories
loc="/tmp/ClientsAtRisk"
rm -rf ${loc}

mkdir -p ${loc}
chmod -R 0777 ${loc}

# define log for dev update
log_file="$loc/progress.log"
> $log_file
echo "Starting..." > ${log_file}
echo "Log created at $current_time" >> ${log_file}
echo "---------------------------" >> ${log_file}

#company_files location
company_files_folder="${loc}/company_files"
echo "Creating company files folder" >> ${log_file}
mkdir -p ${company_files_folder}

resultSet=${loc}/resultSet.txt

# =================== Creating company files ===================================
echo "Running query to get companies and agreements." >> ${log_file}
resultFile="companies.txt"

mysql ${connect_support} "select company_id as id, case when agreement=1 then 2 when agreement=2 then 5 when agreement=3 then 10 when agreement=5 then 2 when agreement=6 then 12 else 0
end as agreement from company c where c.expiration_time>date_add(now(),interval -3 month) and c.agreement > 0 order by company_id into outfile '${loc}/${resultFile}' fields terminated by ','";

echo "Results file ${resultFile} created." >> ${log_file}

echo "  Processing  ${resultFile}" >> ${log_file}
while IFS=',' read -r line || [[ -n "${line}" ]]; do
    while IFS=',' read f1 f2; do
        echo $f2 > ${company_files_folder}/${f1}
    done
done < ${loc}/${resultFile}

echo -e "Company files created.\n\n" >> ${log_file}
# ==============================================================================

resultFile="openSupportTickets.txt"
mysql $connect_support "select c.company_id, case  when count(r.id)=3 then 1 when count(r.id)>3 then count(r.id)+1 else 0 end as grade from service_req r join sysaid_user u on r.request_user=u.user_name join company c on u.company=c.company_id where c.expiration_time>date_add(now(),interval -3 month) and c.agreement > 0 and  r.status in (1,2,12,15,32) and r.problem_type='Support Request' group by c.company_id having grade > 0 into outfile '${loc}/${resultFile}' fields terminated by ','";
processFile $resultFile

resultFile="openCriticalIssues.txt"
mysql $connect_support "select c.company_id, case when count(r.id)>0 then 16 else 0 end as grade from service_req r join sysaid_user u on r.request_user=u.user_name join company c on u.company=c.company_id where c.expiration_time>date_add(now(),interval -3 month) and c.agreement > 0 and r.status in (1,2,12,15,32) and r.problem_type='Support Request' and r.priority=1 group by c.company_id having grade>0 into outfile '${loc}/${resultFile}' fields terminated by ','";
processFile $resultFile

resultFile="ongoingP1Issues.txt"
mysql $connect_support "select c.company_id, case  when count(r.id)=1 then 1  when count(r.id)=2 then 2  when count(r.id)=3 then 6  when count(r.id) in (4,5) then count(r.id)*3 when count(r.id) >5 then 25 else 0 end as grade from service_req r join sysaid_user u on r.request_user=u.user_name join company c on u.company=c.company_id where c.expiration_time>date_add(now(),interval -3 month) and c.agreement > 0 and r.status in (1,2,12,15,32) and r.problem_type='Support Request' and r.priority=1 group by c.company_id having grade>0 into outfile '${loc}/${resultFile}' fields terminated by ','"
processFile $resultFile

resultFile="moreThan3criticalP1in3Months.txt"
mysql $connect_support "select c.company_id, case when count(r.id)>3 then 46 else 0 end as grade from service_req r join sysaid_user u on r.request_user=u.user_name join company c on u.company=c.company_id where c.expiration_time>date_add(now(),interval -3 month) and c.agreement > 0 and r.status not in (7,93) and r.insert_time>date_add(now(),interval -3 month) and r.problem_type='Support Request' and r.priority=1 group by c.company_id having grade>0 into outfile '${loc}/${resultFile}' fields terminated by ','"
processFile $resultFile

resultFile="moreThan5SupportInLast3Months.txt"
mysql $connect_support "select c.company_id, case when count(r.id)>5 then 25 else 0 end as grade from service_req r join sysaid_user u on r.request_user=u.user_name join company c on u.company=c.company_id where c.expiration_time>date_add(now(),interval -3 month) and c.agreement > 0 and r.status not in (7,93) and r.insert_time>date_add(now(),interval -3 month) and r.problem_type='Support Request' group by c.company_id having grade>0 into outfile '${loc}/${resultFile}' fields terminated by ','";
processFile $resultFile

resultFile="CustomerUpToAYear.txt"
mysql $connect_support "select c.company_id, case when c.company_cust_purchase_date >date_add(now(),interval -1 year) then 5 else 0 end as grade from company c  where c.expiration_time>date_add(now(),interval -3 month) and c.agreement > 0 having grade>0 into outfile '${loc}/${resultFile}' fields terminated by ','"
processFile $resultFile

resultFile="CustomerComplained.txt"
mysql $connect_support "select c.company_id,case when c.company_cust_clientatrisk>1 then 16 else 0 end as grade from company c  where c.expiration_time>date_add(now(),interval -3 month) and c.agreement > 0 having grade>0 into outfile '${loc}/${resultFile}' fields terminated by ','"
processFile $resultFile

resultFile="SupportActiveSRsOpenMoreThan7Days.txt"
mysql $connect_support "select c.company_id, case  when count(r.id)>0 and count(r.id)<9 then count(r.id)  when count(r.id)in (9,10) then count(r.id)*2 when count(r.id)=11 then count(r.id)*3 when count(r.id)>11 then 50 else 0 end as grade from service_req r join sysaid_user u on r.request_user=u.user_name join company c on u.company=c.company_id where c.expiration_time>date_add(now(),interval -3 month) and c.agreement > 0 and r.status in (1,2,12,15,32) and r.problem_type='Support Request' group by c.company_id having count(*)>0 into outfile '${loc}/${resultFile}' fields terminated by ','"
processFile $resultFile
echo "=====================================================================" >> ${log_file}


#Processing results
echo "Processing Results" >> ${log_file}
# No risk		0-15
# Low risk	    16-30
# Medium risk	31-45
# High risk	    46 +

# empty result files
touch ${loc}/result_HighRisk.txt
touch ${loc}/result_MediumRisk.txt
touch ${loc}/result_LowRisk.txt
touch ${loc}/result_NoRisk.txt
touch ${loc}/highRisk.tmp
touch ${loc}/mediumRisk.tmp
touch ${loc}/lowRisk.tmp


# read value from each file, add record to relevant result file
cd ${company_files_folder}
FILES=*
echo "Files variable created. Reading..." >> ${log_file}
    for file in ${FILES}; do

        grade=$(cat ${file})
        company_id=${file}

        if [ "${grade}" -ge 45 ]; then
            echo "${company_id},${grade}" >> ${loc}/result_HighRisk.txt
            echo -e  "File \t${file} \tGrade: \t${grade} \tRisk: \tHigh Risk " >> ${log_file}

            elif [ $grade -ge 31 ] && [ $grade -le 44 ]; then
                echo "${company_id},${grade}" >> ${loc}/result_MediumRisk.txt
                echo -e  "File \t${file} \tGrade: \t${grade} \tRisk: \tMedium Risk " >> ${log_file}
                echo "${company_id}" >> ${loc}/mediumRisk.tmp

            elif [ $grade -ge 16 ] && [ $grade -le 30 ]; then
                echo "${company_id},${grade}" >> ${loc}/result_LowRisk.txt
                echo -e  "File \t${file} \tGrade: \t${grade} \tRisk: \tLow Risk " >> ${log_file}
                echo "${company_id}" >> ${loc}/lowRisk.tmp

            else
                echo "${company_id},${grade}" >> ${loc}/result_NoRisk.txt
                echo -e  "File \t${file} \tGrade: \t${grade} \tRisk: \tNo Risk " >> ${log_file}
        fi
    done


# process result files into HTML report

echo "Creating HTML file " >> ${log_file}

touch ${loc}/ClientsAtRisk.htm
echo "<html>" > ${loc}ClientsAtRisk.htm
echo "<head></head>" >> ${loc}/ClientsAtRisk.htm
echo "<body>" >> ${loc}/ClientsAtRisk.htm
echo " Updated: $(date)" >> ${loc}/ClientsAtRisk.htm
echo "<strong><H1><B><center> Clients at Risk :</center></H1></B></strong><BR/>" >> ${loc}/ClientsAtRisk.htm
echo "<table cellpadding="0" cellspacing="0" width="100%" border="1" >" >> ${loc}/ClientsAtRisk.htm
echo "<tr>"  >> ${loc}/ClientsAtRisk.htm
echo "<th style="font-size:20px">ID</th>" >> ${loc}/ClientsAtRisk.htm
echo "<th style="font-size:20px">Name</th>" >> ${loc}/ClientsAtRisk.htm
echo "<th style="font-size:20px">Agreement</th>" >> ${loc}/ClientsAtRisk.htm
echo "<th style="font-size:20px">Expiration</th>" >> ${loc}/ClientsAtRisk.htm
echo "<th style="font-size:20px">Renewal</th>" >> ${loc}/ClientsAtRisk.htm
echo "<th style="font-size:20px">Currency</th>" >> ${loc}/ClientsAtRisk.htm
echo "<th style="font-size:20px">Account manager</th>" >> ${loc}/ClientsAtRisk.htm
echo "<th style="font-size:20px">Grade</th>" >> ${loc}/ClientsAtRisk.htm
echo "</tr>"  >> ${loc}/ClientsAtRisk.htm


echo "Processing HighRisk tickets .." >> ${log_file}
processResultFile ${loc}/result_HighRisk.txt

echo "Processing MediumRisk tickets .." >> ${log_file}
processResultFile ${loc}/result_MediumRisk.txt

echo "Processing LowRisk tickets .." >> ${log_file}
processResultFile ${loc}/result_LowRisk.txt

# close html tags
echo "</table>" >> ${loc}/ClientsAtRisk.htm
echo "</body>" >> ${loc}/ClientsAtRisk.htm
echo "</html>" >> ${loc}/ClientsAtRisk.htm

echo "Finished the script at $(date)" >> ${log_file}

# send report and log to email
echo "Clients at Risk report" | mutt -a "${log_file}" -a "${loc}/ClientsAtRisk.htm" -s "Clients at Risk Report generated on  ${current_time}" -- slava.safronov@sysaid.com