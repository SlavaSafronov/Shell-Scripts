# The logic behind the calculated score is the following:

# if the client is within 90 days towards renewal -         +5 points
# if the agreement is gold or gold vip -                    +10 point
# if the agreement is silver -                              +5 points
# priority 1 -                                              +10 points
# priority 2 -                                              +5 points
# if the customer complained (set by PS) -                  +5 points
# if the SR is new -                                        +5 points
# days since last contact with the client -                 # of days




# additional functions to calculate the date difference
# -----------------------------------------------------
date2stamp () {
    date --utc --date "$1" +%s
}
# -----------------------------------------------------

# define log file
log_file="/root/scripts/sorting/sorting.log"

# create folder if it does not exist
mkdir -p /tmp/results
chmod 777 /tmp/results

# clear temp files
> /root/scripts/sorting/update_sorting.sql
rm -rf /tmp/results/*
> /root/scripts/sorting/sorting.log

# get the array of tickets
ids=$(mysql support -BNe "select distinct r.id from service_req r where r.parent_link=0 and r.sr_sub_type=50 and r.sr_type=1 and r.problem_type='Support Request' and r.status in (1,2,12,15) and r.assigned_group in ('Support Tier 1','Support Tier 2','Support Tier 3','Support Supervisors','SupTeamLeaders','SysAid Australia','Cloud Infrastructure Team') and r.agreement > 0 order by r.id;")

# for each ticket
for id in $ids; do

    # clean variables and temp file
    sortvalue=0
    agreement=0
    priority=0
    complained=0
    mstatus=0
    lastcontactdate=0
    expiring=0
    dayspassed=0

    filename="$id.txt"
    #touch /tmp/sorting/results/$filename

    # running the query and writing the result into txt file
    echo ""  >> $log_file
    echo ""  >> $log_file
    echo "_____________________Checking SR:  $id ___________________ " >> $log_file

    mysql support -BNe "SELECT r.agreement,r.priority,r.sr_cust_custcomplain,r.status,datediff(c.expiration_time,now()) from service_req r join sysaid_user u on r.request_user=u.user_name join company c on u.company=c.company_id where id = $id into outfile '/tmp/results/$filename' FIELDS TERMINATED BY ',';"


    IFS=","
        while read f1 f2 f3 f4 f5; do

         # check agreement
            agreement=$f1
            echo "Agreement is  $agreement " >> $log_file
            if [ $agreement -eq 3 ]; then
                sortvalue=$((sortvalue+10))
            elif [ $agreement -eq 6 ]; then
                sortvalue=$((sortvalue+11))
            elif [ $agreement -eq 2 ]; then
                sortvalue=$((sortvalue+5))
            fi
            echo "Sorting columns after agreement check is  $sortvalue " >> $log_file

         # check priority
            priority=$f2
            echo "Priority is  $priority " >> $log_file
            if [ $priority -eq 1 ]; then
                sortvalue=$((sortvalue+10))
            elif [ $priority -eq 2 ]; then
                sortvalue=$((sortvalue+5))
            elif [ $priority -ge 4 ]; then
                sortvalue=$((sortvalue-1))
            fi
            echo "Sorting columns after priority check is  $sortvalue" >> $log_file

         # check if the customer complained
            complained=$f3
            echo "Complained is  $complained " >> $log_file
            if [ $complained = 1 ]; then
                sortvalue=$((sortvalue+5))
            fi
            echo "Sorting columns after complained check is  $sortvalue" >> $log_file

         # check if SR is new
            mstatus=$f4
            echo "Status is  $mstatus " >> $log_file
            if [ $mstatus -eq 1 ]; then
                sortvalue=$((sortvalue+5))
            fi
            echo "Sorting columns after status check is  $sortvalue " >> $log_file

         # check how many days passed since last contact
            now="$(TZ=Israel date +'%Y-%m-%d')"
            lastcontactdate=$(mysql support -BNe "select msg_time +INTERVAL 7 HOUR from service_req_msg where id=$id and from_user like '%@sysaid.com' and from_user!='helpdesk@sysaid.com' order by msgid desc limit 1;")
            echo "Lastcontacted  is  $lastcontactdate" >> $log_file
            dte1=$(date2stamp $lastcontactdate)
            dte2=$(date2stamp $now)
            dayspassed=$(((dte2-dte1) / 86400))
            echo "Days Passed: $dayspassed" >> ${log_file}
            sortvalue=$((sortvalue+dayspassed))
            echo "Sorting columns after lastcontact check is  $sortvalue" >> $log_file


         # check if the client is expiring within 90 days
            expiring=$f5
            echo "Expiring  is in $expiring days" >> $log_file
            if [[ "$expiring" -ge "1" ]] && [[ "$expiring" -le "90" ]]; then
                sortvalue=$((sortvalue+5))
            fi
            echo "Sorting columns after expiring check is  $sortvalue" >> $log_file

         # add zeroes for sorting as text
            if [ $sortvalue -ge 0 -a $sortvalue -le 9 ]; then
                sortvalue="00$sortvalue"
            elif [ $sortvalue -ge 10 -a $sortvalue -le 99 ]; then
                sortvalue="0$sortvalue"
            fi

         #create a query to update the SR and add the query to the temp sql file
         echo "update service_req set sr_cust_eu_class='$sortvalue' where id = $id;" >> /root/scripts/sorting/update_sorting.sql
      done < /tmp/results/$filename
done

