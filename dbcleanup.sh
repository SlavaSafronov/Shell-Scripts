#!/bin/sh
# Title: 	cleanup database
# created by: 	Slava Safronov

# create work directory and subdirectories
        work_folder='/tmp/dbcleanup/'
        mkdir -p $work_folder
        chmod -R 0777 $work_folder

        #define log
        log_file="$work_folder/dbcleanup.log"
        > ${log_file}

# define API connection credentials
	URL='https://testent18.sysaidit.com'
	API_ACCOUNT_ID='testent18'
	API_USER=''
	API_PASS=''
	
	API_LOGIN_URL=${URL}/api/v1/login -d '{"user_name":"$API_USER","account_id":"$API_ACCOUNT_ID","password":"$API_PASS"}'
	
	
	

# functions
	delete_tickets(){
    
	}



# main	
today=$(date)
echo "DBCleanup log: " > ${log_file}
echo "   Started at: $today" >> ${log_file}
echo " =======================================================" >> ${log_file}
