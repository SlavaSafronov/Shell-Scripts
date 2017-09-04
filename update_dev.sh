#!/bin/bash

# update 31-Jan-2017
# 	- added check for manually placed account value  
#	- created a log to list tickets that can be closed since the bug has been resolved. 
# --------------------------------------------------------------------------------------



# The script is designed to collect the tickets affected by bugs, get a company price for each ticket,
# and update the bug value and the number of affected tickets in dev.
# -----------------------Steps-----------------------------------
    # get all ticket numbers
    # store them in one file tickets.txt
    #
    # For each ticket
        # get from db and save to variables company value $company_value, license_type (for proper calculation of company value), bug number $bug_id
        # check if the bug is still active
        # check if the file exists with the same bug number $bug_id
            # create a file if it does not exist
        # read the number of affected tickets $affected
        # add +1 to the number of affected tickets $affected +1
        # read bug value $bug_value
        # calculate and add $company_value to $bug_value
        # save the file with updated $affected and $bug_value
    #
    # For each bug in bug files
        # form a query to update the bug in dev
        # add query to the query_file
# ----------------------------------------------------------


current_time=$(date)

#define mysql connect option
connect_support=" support -BNe "
connect_dev=" dev -BNe "

#for testing on the copy of support/dev db on the local server: 
#connect_support=" -uroot -pPassword1 support -BNe "
#connect_dev=" -uroot -pPassword1 dev -BNe "


join_user=" join sysaid_user u on r.request_user=u.user_name "
join_company=" join company c on u.company=c.company_id "



# create work directory and subdirectories

loc="/tmp/update_dev"
mkdir -p $loc
chmod -R 0777 $loc

# define log for dev update
log_file="$loc/update_dev.log"
> ${log_file}

# define log for SR's that can be closed
sr_to_close="$loc/sr_to_close.log"
> ${sr_to_close}
echo "Log created at $current_time" >> ${sr_to_close}
echo "These SRs can be closed since the bug they contain is already fixed:" >> ${sr_to_close}
echo "" >> ${sr_to_close}

account_managers="$loc/account_managers"
mkdir -p $account_managers
rm -rf $account_managers/*

# reset tickets file
tickets="$loc/tickets.txt"
rm -rf $tickets

# conversion rates to USD on 02-Oct-2016 - need for renewal calculation
EUR=1.12
GBP=1.30
ILS=0.27
AUD=0.77
BRL=0.31

#set bugs folder
bug_folder="$loc/bugs"
mkdir -p $bug_folder
rm -rf $bug_folder/*

sql_update="$loc/sql_update.sql"
> $sql_update


# create empty files for active bugs
mysql $connect_dev "select id as ticket from service_req where status in (1,2,8,9,10,11,40,72,90,958) and sr_type=1 order by id;" | while read ticket; do
	touch $bug_folder/$ticket
        echo -e "0\n0" >> $bug_folder/$ticket
done

# get all support ticket numbers - id,bug number,value,currency,notes
mysql $connect_support "select r.id,r.cust_int2,c.company_cust_total_prolong,c.company_cust_currency,c.notes,r.sr_cust_accountvalue,cust.value_caption from service_req r $join_user $join_company join cust_values cust on (c.company_cust_account_manager=cust.value_key and list_name='company_cust_account_manager') where r.cust_int2>0 and r.parent_link=0 and r.sr_type=1 and r.status not in (7,45,47,56,92,140) and r.insert_time>'2015-01-01' and c.expiration_time > curdate()-INTERVAL 90 DAY order by r.id INTO OUTFILE '$loc/tickets.txt' FIELDS TERMINATED BY '|' LINES TERMINATED BY '\n';"

total_tickets=$(wc -l < $tickets)
echo "" >> ${log_file}
echo "Script ran at: $current_time" >> ${log_file}
echo "" >> ${log_file}
echo "Total number of tickets to work on is $total_tickets" >> ${log_file}
count=0
while read -r line
do
    fields="$line"
	let count=count+1
	echo -ne "(${count} / ${total_tickets})\r"
    echo "------------------------------------">> ${log_file}
    sr_id=`echo $fields | cut -d '|' -f1`
    echo "Working on SR $sr_id " >> ${log_file}

    bug_id=`echo $fields | cut -d '|' -f2`
    echo "Bug: $bug_id" >> ${log_file}

    #if the bug exists in the file list
    # echo "Checking if bug $bug_id exists in $bug_folder " >>${log_file}
    if [[ -f "$bug_folder/$bug_id" ]]; then
        echo "File found...." >> ${log_file}

        # read the bug file
        eval $(awk '{print "var"NR"="$1}' $bug_folder/$bug_id)

        # get number of affected tickets, then add +1 to it
        affected=$((var1+1))
	    echo "Number of tickets affected by bug: $affected " >> ${log_file}
        old_bug_value=${var2}
            echo "Old bug value: $old_bug_value " >> ${log_file}
        
        # get license type
        # the factor will be used to divide the company value in case of Perpetual license (get 20%)
        lic_type=$(echo $fields | cut -d '|' -f5)
        echo "License type: $lic_type" >> ${log_file}

        if [[ -z "$lic_type" ]]; then
           lic_type=""
        fi

        if [[ $lic_type =~ .*erpetual.* ]]; then
            license_type=5
         else
            license_type=1
        fi
        echo "License factor: $license_type" >>${log_file}
    
		


        # get renewal price
        prolong=0

        check_prolong=`echo $fields | cut -d '|' -f3`
	
		re='^[0-9]+$'
		if ! [[ $check_prolong =~ $re ]] ; then
			prolong=0
		else 
			prolong=${check_prolong}
		fi
			
		#prolong=${check_prolong:='0'}
        echo "Renewal:  $prolong " >>${log_file}

        # get currency
        curr=`echo $fields | cut -d '|' -f4`
        echo "Currency: $curr " >>${log_file}
        
        if [[ $prolong -ge 0 ]]; then
                if [[ $curr == "EUR" ]]; then
                        value=$(expr $prolong*$EUR/$license_type | bc )
                    elif [[ $curr == "GBP" ]]; then
                        value=$(expr $prolong*$GBP/$license_type | bc )
                    elif [[ $curr == "ILS" ]]; then
                        value=$(expr $prolong*$ILS/$license_type | bc )
                    elif [[ $curr == "AUD" ]]; then
                        value=$(expr $prolong*$AUD/$license_type | bc )
                    elif [[ $curr == "BRL" ]]; then
                        value=$(expr $prolong*$BRL/$license_type | bc )
                    else
                        value=$(expr $prolong/$license_type | bc )
                fi
			echo "Calculated renewal in USD: $value ">>${log_file}
        else
			# attempt to get reseller's real account price in case renewal price is 0 from sr_cust_accountvalue 
			echo "Renewal value is $value, checking the manually edited renewal value." >>${log_file}
						
			manual_renewal_price=`echo $fields | cut -d '|' -f6`
			echo "Manually edited renewal value in USD: $manual_renewal_price" >>${log_file}
			
			if [[ $manual_renewal_price -gt 0 ]]; then
				value=$manual_renewal_price 	
				echo "Calculated renewal in USD: $value ">>${log_file}
			else			
				echo "The price for the company renewal was not received properly. ">>${log_file}
				value=0
			fi
        fi

        # setting bug worth
        bug_worth=$((old_bug_value+value))        
        echo "Bug worth: $bug_worth" >>${log_file}

        #update bug file
        echo $affected >$bug_folder/$bug_id
        echo $bug_worth >>$bug_folder/$bug_id
        echo "Bug file $bug_id was updated with values - affected:$affected, bug price: $bug_worth " >>${log_file}

        # adding the query to update dev notes
		# if this is the first ticket, I replace the column value with the note; otherwise I add the note to existing notes.
		if [ $affected -gt 1 ];then
			echo "update service_req set sr_cust_existcust=concat(sr_cust_existcust,'Account: $lic_type pays $value USD annually, SR #$sr_id.\n') where id=$bug_id;" >> $sql_update
		else
			echo "update service_req set sr_cust_existcust=('Account: $lic_type pays $value USD annually, SR #$sr_id\n') where id=$bug_id;" >> $sql_update
		fi	
		
		# FIXME 
		# get account manager, create a folder with the same email, add info to the folder 
		# folder to keep account managers is $account_managers
		
		
		
    else
        echo "Bug $bug_id is no longer active and thus will not be evaluated." >> ${log_file}
		# add ticket to the list of "can be closed" if the bug has been fixed
		echo "$sr_id " >> ${sr_to_close}
    fi
   
done < $tickets

#output to console in case manual script run 
echo "Finished working on tickets. Going over the list of bugs and creating SQL file."

echo "Finished working on tickets. Going over the list of bugs and creating SQL file." >>${log_file}
echo ".......................................................................................">>${log_file}

cd $bug_folder
FILES=*
    for f in $FILES; do
		eval $(awk '{print "var"NR"="$1}' $f)
		if [[ $var2 -gt 0 ]];then
			echo "update service_req set sr_cust_srs_in_support = $var1, sr_cust_sup_bug_worth=$var2 where id=$f ;" >> $sql_update
		fi
    done
echo "SQL file created with $(wc -l < $sql_update) lines. " >> $sql_update


chown -R ec2-user:ec2-user /tmp/update_dev

# run the prepared SQL file to update dev db
mysql -A dev < /tmp/update_dev/sql_update.sql

# send the logfile to slava
echo "Update DEV log" | mutt -a "${log_file}" -a "${sr_to_close}" -s "Update DEV log ${current_time}" -- slava.safronov@sysaid.com

