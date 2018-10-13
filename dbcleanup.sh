#!/bin/sh
# Title: 		cleanup database
# created by: 	Slava Safronov

# create work directory and subdirectories
        work_folder='/tmp/dbcleanup/'

        mkdir -p $work_folder
        chmod -R 0777 $work_folder

        #define log
        log_file="$work_folder/dbcleanup.log"
        > ${log_file}


# functions
	delete_tickets(){
    
	}



# main	
today=$(date)
echo "DBCleanup log: " > ${log_file}
echo "   Started at: $today" >> ${log_file}
echo " =======================================================" >> ${log_file}
