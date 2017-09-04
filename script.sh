#!/bin/bash
#
# create a list of tickets which don't have a value
# go through the list
# for each ticket:
#       read the value of custom text field
#       search for the key in the list
#       log old value and new value
#       update the list with a new value key
#
# connect option needs to be updated according to the client's environment
connect=" -uroot -pPassword1 onsemiconductor -BNqe "

# some MySQL installatons do not allow to save files in /tmp, we need to query the safe location for the files:
# SHOW VARIABLES LIKE "secure_file_priv";
# and then update the variable below:
file_location="/tmp"
rm -rf ${file_location}/*
echo "Initializing logs...."
log_file="${file_location}/main.log"
> ${log_file}

missing_values="${file_location}/missing_values.log"
>${missing_values}

functionLog="${file_location}/function_log.txt"
> ${functionLog}

update_queries="${file_location}/update_queries.sql"
> ${update_queries}


echo "Creating cust values file..."
ticket_list="${file_location}/ticket_list.txt"

# cust_values_location="${file_location}/custvalues"
# mkdir -p ${cust_values_location}
# rm -rf ${cust_values_location}/*

field_list="${file_location}/field_list.txt"

# create a map of sr_cust_apps list
#mysql ${connect} "select value_key,value_caption from cust_values where list_name='sr_cust_apps' INTO OUTFILE '${field_list}' FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';"
mysql ${connect} "select value_key,value_caption from cust_values where list_name='sr_cust_apps';" > ${field_list}

# while read -r line
#do
#        key=`echo $line | cut -d '|' -f1`
#        value=`echo $line | cut -d '|' -f2`
         # echo "Adding key: ${key} \tValue: ${value} \tto files" >> ${log_file}
#        touch ${cust_values_location}/${key}
#        echo ${value} >> ${cust_values_location}/${key}
#done < ${field_list}
echo "Custvalues files created."
# read -n1 -r -p "Press any key to continue..." key


# ---------- DEFINE FUNCTIONS ------------------------
function findkey(){
	datafile=${field_list}
	while read -r line2
	do
	IFS=$'\t'
	list_key=0
		while read p1 p2;do
			temp_valuekey=$p1
			temp_valuecaption=$p2
			# echo "Troubleshooting - looking for: '$1'  value key: '${temp_valuekey}'  value caption : '${temp_valuecaption}' "
			if [[ "${temp_valuecaption}" == "$1" ]]; then
				# echo "  Key found - ${temp_valuekey}" >> ${functionLog}
				list_key=${temp_valuekey}
				return ${list_key}
				break
			fi
		done 
	done < ${datafile}	
}


# ---------- MAIN -----------------------------------

current_time=$(date)
echo "Log createad at ${current_time}"  >> ${log_file}

# ------create a list of tickets------------------
echo "Creating a ticket list.."
#mysql ${connect} "select id,sr_cust_applicationlist from service_req where (sr_cust_apps=0 or sr_cust_apps is NULL) and sr_cust_applicationlist!='' and sr_cust_applicationlist!='0' and sr_type in (1,4,6,10) INTO OUTFILE '${ticket_list}' FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';"

mysql ${connect} "select id,sr_cust_applicationlist from service_req where sr_cust_applicationlist!='' and sr_cust_applicationlist!='0' and sr_type in (1,4,6,10);" > ${ticket_list}

echo "Ticket list created."
while read -r line
do	
	sr_id=""
	text_caption=""
	
	sr_id=`echo "${line}" | cut -d $'\t' -f1`
	text_caption=`echo "${line}" | cut -d $'\t' -f2`
	echo "Reading line ${line}..Text caption: ${text_caption}">> ${log_file}

	# search for the text caption in files
	# echo "Working on SR ${sr_id}"
	findkey ${text_caption}

	# list_key=$(mysql ${connect} "select value_key from cust_values where list_name='sr_cust_apps' and value_caption='${text_caption}'")

	if ! [ -z "${list_key}" ]; then
			echo "          List key ${list_key} for ${sr_id} found, adding the record to the queries"
			echo "update service_req set sr_cust_apps=${list_key} where id = ${sr_id}; " >> ${update_queries}
	else
			echo "SR: ${sr_id} ______ ${text_caption} ______ was not found in list." >> ${missing_values}
	fi

done < ${ticket_list}

echo ""
echo ""
echo "-----------------------------------"
echo "Please check the following files:"
echo "-----------------------------------"
echo "    less ${log_file}"

file_length=$(wc -l < ${missing_values})
if [ $file_length -gt 0 ];then
        echo "    less ${missing_values}"
fi

echo "-----------------------------------"
echo ""
echo ""
echo "And run the following file to update tickets: "
echo "-----------------------------------"
echo "   less ${update_queries}"
echo "-----------------------------------"

echo "OnSemi update" | mutt -a "${log_file}" -a "${missing_values}" -a "${functionLog}" -a "${update_queries}"  -s "OnSemi update " -- slava.safronov@sysaid.com
