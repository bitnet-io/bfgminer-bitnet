#!/bin/bash

# ****************************************************************************************************
# Copyright© 2014 Advanced Micro Devices, Inc. All rights reserved.

# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

# •   Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# •   Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or
 # other materials provided with the distribution.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 # WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
 # DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 # OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# **************************************************************************************************/

#Script level variables
AMDAPPSDK_TEMP_DIR="/tmp/AMDAPPSDK-2.9-1"
LOG_FILE="$AMDAPPSDK_TEMP_DIR/UninstallLog_$(date +"%m-%d-%Y"T"%H-%M-%S").log"
#INSTALL_DIR="/opt"
USERMODE_INSTALL=1	#A value of 1 indicates that the script will uninstall 
			#AMD APP SDK for the currently logged in user only

#Function Name	: log
#Comments	:#The log function logs the messages in the specified log file
			 #By default info is not logged in the console
log()
{
	Message="[$(date +"%m-%d-%Y"T"%T")][$2]$1"
	if [ -e "$LOG_FILE" ]; then
		#First log statement to the file
		echo "$Message" >> "$LOG_FILE"
	else
		touch "$LOG_FILE"
		chmod 666 "$LOG_FILE"
		echo "$Message" >> "$LOG_FILE"
	fi
	if [ -n "$3" -a "$3" == "console" ]; then  
		#dump the message to the console as well
		echo "$1"
	fi
}
#Function Name	: getOSDetails
#Comments	: Get's the complete details of OS and prints it on the console.
getOSDetails()
{
	OS_ARCH=$(getconf LONG_BIT)
	if [ $? -ne 0 ]; then
		log "getconf LONG_BIT failed. Trying alternate method using uname to get the OS type." "$LINENO" "console"
		#alternate method of finding out the OS type
		OS_ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
	fi
	log "Detected OS Architecture: $OS_ARCH" "$LINENO" "console"	
	OS_DISTRO=$(lsb_release -si)
	if [ $? -ne 0 ]; then
		log "FAILURE: Could not detect the OS distribution. Please check for the presence of /etc/lsb_release." "$LINENO" "console"
	fi
	log "Detected OS Distribution: $OS_DISTRO" "$LINENO" "console"	
	OS_VERSION=$(lsb_release -sr)
	if [ $? -ne 0 ]; then
		log "FAILURE: Could not detect the OS distribution. Please check for the presence of /etc/lsb_release." "$LINENO" "console"
	fi
	log "Detected OS Version: $OS_VERSION" "$LINENO" "console"
}
#Function Name	: getLoggedInUserDetails
#Comments	: get's the current loged-in user details and prints on the console.
getLoggedInUserDetails()
{
	CURRENT_USER=$(whoami)
	log "Logged in user: $CURRENT_USER" "$LINENO" "console"
}
#Function Name	: getInstallationDirectory
#Comments	: #This function checks for the presence of ini file in /etc/AMD/ directory
			  #for root users, otherwise checks for the presence of ini in $HOME/etc/AMD/directory
			  #This ini file contains the INSTALL_DIR as a key-value pair.
			  #Note: Most likely the environment variable AMDAPPSDKROOT will also point to the same directory,
			  #however the environment variable is not the best way to locate the installation directory
			  
getInstallationDirectory()
{
	INIFILE="$HOME/etc/AMD/APPSDK-2.9-1.ini"
	if [ $UID -eq "0" ]; then
		#Root user
		INIFILE="/etc/AMD/APPSDK-2.9-1.ini"
	fi
	#Check whether the INIFILE exists or not
	#If it exists, then grab the value of the key INSTALL_DIR in it.
	log "Locating $INIFILE" "$LINENO" "console"
	if [ -e "$INIFILE" ]; then
		INSTALL_DIR=$(grep -r INSTALL_DIR $INIFILE | awk -F'=' '{print $2}')
		log "Detected AMD APP SDK-2.9-1 installed in: $INSTALL_DIR" "$LINENO" "console"
	else
		log "Failed to locate the ini file: $INIFILE" "$LINENO"
	fi
}
#Function Name	: deleteOpenCLSoftLink
#Returns	: returns zero if soft link is deleted, else returns non-zero.
#Comments	: deletes the soft-link file from $TARGET
deleteOpenCLSoftLink()
{
	Retval=1	
	DIR=$1
	NAME=$2
	PLATFORM=$3
	TARGET="$DIR/$NAME"
	#first check the soft-link exists or not, if exists delete it.	
	log "Check existence of soft-link $TARGET" "$LINENO" 
	if [ -e "$TARGET" ]; then
		log "Soft-link $TARGET exists, hence deleting the soft-link." "$LINENO" 
		if [ "$USERMODE_INSTALL" == "1" ]; then
			TARGET="$INSTALL_DIR/lib/$PLATFORM/$NAME"
		fi
		rm -vf "$TARGET" >> "$LOG_FILE" 2>&1
		Retval=$?
	else
		log "soft-link does not exists" "$LINENO"		
	fi
	return $Retval
}
#Function Name	: unhandleCatalyst
#Returns	: returns a value 0 if the soft link is deleted, else it returns a non-zero value.
#Comments	: This function handles the catalyst and deletes the soft link if catalyst driver is present.
		      #it checks for the catalyst file are present or not, if presents it deletes the soft link, else it skips the deletion of soft link.
unhandleCatalyst()
{
	Retval=1	
	if [ "$OS_ARCH" = "32" ]; then
		if [ -e "/usr/lib/libamdocl32.so" -o -e "/usr/lib/fglrx/libamdocl32.so" ]; then
			#Found files
			log "32-bit AMD Catalyst OpenCL Runtime is available hence deleting the soft link." "$LINENO" 	
			deleteOpenCLSoftLink /usr/lib libOpenCL.so.1 x86
			Retval=$?
			if [ $Retval -ne 0 ]; then
				log "[WARN]Could not delete soft-link,You may need to delete this soft-link manually." "$LINENO"l
			fi
		else
			#files not found			
			log "no catalyst driver is installed, hence skipping the deletion of soft-link." "$LINENO"
		fi
	elif [ "$OS_ARCH" = "64" ]; then
		if [ -e /usr/lib/libamdocl64.so -o -e /usr/lib64/libamdocl64.so -o -e /usr/lib/fglrx/libamdocl64.so -o -e /usr/lib/fglrx/libamdocl64.so ]; then
			#Found files
			log "64-bit AMD Catalyst OpenCL Runtime is available hence deleting the soft link." "$LINENO" 		
			#The below is for ubuntu and architectures that support the new multi-arch mechanisms
			if grep -q Ubuntu <<< $OS_DISTRO; then
				log "Ubuntu 64-bit system, deleting soft-links from /usr/lib/i386-linux-gnu and /usr/lib" "$LINENO"
				deleteOpenCLSoftLink /usr/lib/i386-linux-gnu libOpenCL.so.1 x86
				deleteOpenCLSoftLink /usr/lib libOpenCL.so.1 x86_64
				Retval=$?
				if [ $Retval -ne 0 ]; then
					log "[WARN]Could not delete soft-link,You may need to delete this soft-link manually." "$LINENO"
				fi
			else
				log "Not Ubuntu 64-bit system, deleting soft-links from /usr/lib and /usr/lib64" $LINENO
				deleteOpenCLSoftLink /usr/lib libOpenCL.so.1 x86
				deleteOpenCLSoftLink /usr/lib64 libOpenCL.so.1 x86_64
				Retval=$?
				if [ $Retval -ne 0 ]; then
					log "[WARN]Could not delete soft-link,You will may to delete this soft-link manually." "$LINENO"
				fi
			fi
		else
			#files not found
			log "no catalyst driver is installed, hence skipping the deletion of soft-link." "$LINENO"	
		fi
	else
		echo FAILURE: Found an incompatible OS Architecture: "$OS_ARCH". Please report the issue.
	fi
	return $Retval
}

#Function Name	: uninstallCLINFO
#Returns	: returns zero if clinfo file has been deleted, if not returns non-zero value.
#Comments	: Depending upon the user logged-in, deletes the CLINFO file from $INSTALL_DIR
uninstallCLINFO()
{
	Retval=1
	if [ $UID -eq "0" ]; then
		#root user
		log "Deleting soft-link from the appropriate $INSTALL_DIR/bin/*/clinfo from /usr/bin" "$LINENO" 
		if [ ! -e "/usr/bin/clinfo" ]; then
			#clinfo does not exists, hence no soft-link is present
			log "clinfo file does not exist in /usr/bin directory." "$LINENO"
		else
			#the clinfo file exist so deleting the soft-link
			rm -vf "/usr/bin/clinfo" >> "$LOG_FILE" 2>&1
			Retval=$?
		fi
	else
		#non-root user
		log "Non root user, deleting soft link in the users $HOME/bin directory." "$LINENO" 
		if [ ! -e "$HOME/bin/clinfo" ] ; then
			#clinfo file does not exist,so soft link does not exists
			log "clinfo file does not exist in $HOME/bin directory." "$LINENO"			
		else
			#clinfo file exist so deleting the soft-link
			rm -vf "$HOME/bin/clinfo" >> "$LOG_FILE" 2>&1
			Retval=$?
		fi
	fi
	return $Retval
}
#Function Name	: removeEnvironmentVariable
#Returns	: returns zero if the EnvironmentVariablehas been deleted, if not returns non-zero value.
#Comments	: #this function checks whether the EnvironmentVariable is present or not,through Grep command.
		  #If present, it deletes the EnvironmentVariable, if not present-it skips the deletion.
removeEnvironmentVariable()
{
	FILE="$1"
	ENVIRONMENT_VARIABLE_NAME="$2"
	#First check whether the entry exists, if it does then delete, else skip the deletion.
	log "Checking for the presence of $ENVIRONMENT_VARIABLE_NAME in the file: $FILE using grep" "$LINENO"
	grep "$ENVIRONMENT_VARIABLE_NAME" "$FILE" >> "$LOG_FILE" 2>&1
	Retval=$?
	if [ $Retval -eq 0 ]; then
		#found an entry, which needs to be deleted
		log "Found an entry for $ENVIRONMENT_VARIABLE_NAME in file: $FILE. Deleted it." "$LINENO" 
		sed -i.bak "/$ENVIRONMENT_VARIABLE_NAME/d" "$FILE" >> "$LOG_FILE" 2>&1	
		#Confirm whether the command did its job in removing the file.
		grep "$ENVIRONMENT_VARIABLE_NAME" "$FILE" >> "$LOG_FILE" 2>&1
		Retval=$?
		if [ $Retval -ne 0 ]; then
			log "Entry for $ENVIRONMENT_VARIABLE_NAME removed." "$LINENO"
			Retval=0
		else
			log "FAILURE: Could not delete entry for $ENVIRONMENT_VARIABLE_NAME removed." "$LINENO"
			Retval=$?
		fi
	else
		log "No Entry for $ENVIRONMENT_VARIABLE_NAME in file: $FILE. hence skipping the deletion." "$LINENO"
	fi
	return $Retval
}
#Function Name	: addEnvironmentVariable
#Comments	: #this function adds back the environment variables, after updating the environment variables.
addEnvironmentVariable()
{
	FILE="$1"
	ENVIRONMENT_VARIABLE_NAME="$2"
	ENVIRONMENT_VARIABLE_VALUE="$3"
	#Adding the environment variable back
	log "echo export \"$ENVIRONMENT_VARIABLE_NAME=\"$ENVIRONMENT_VARIABLE_VALUE\"\" >> \"$FILE\"" "$LINENO" 
	echo "export $ENVIRONMENT_VARIABLE_NAME=\"$ENVIRONMENT_VARIABLE_VALUE\"" >> "$FILE"	
}
#Function Name	: updateEnvironmentVariables
#Returns	: returns zero if the EnvironmentVariablehas been updated, if not returns non-zero value.
#Comments	: #this function updates and also unset the EnvironmentVariables which have been updated during installation.
updateEnvironmentVariables()
{
	#This function updates and also unset an environment variable 
	AMDAPPSDKROOT="$INSTALL_DIR"
	AMDAPP_CONF_32="/etc/ld.so.conf.d/amdapp_x86.conf"
	Retval=1
	if [ $UID -eq "0" ]; then
		#Installed as root user
		AMDAPPSDK_PROFILE="/etc/profile.d/AMDAPPSDK.sh"
		#Update the AMDAPPSDKROOT environment variable in /etc/profile.d directory as root user
		if [ "$OS_ARCH" == "32" ]; then
			#deleting AMDAPPSDK_conf file 
			rm -vf $AMDAPP_CONF_32 >> "$LOG_FILE" 2>&1
			Retval=$?
			if [ $Retval -eq 1 ]; then
				#The configuration files are not deleted, you may have to delete it manually.
				log "[WARN]: Could not delete the configuration file, You will need to delete the file manually." "$LINENO" "console"
			else
				log "The configuration file for AMDAPPSDK has been deleted." "$LINENO" "console"
			fi
		else
			#deleting AMDAPPSDK_conf files 
			rm -vf $AMDAPP_CONF_32 >> "$LOG_FILE" 2>&1
			rm -vf $AMDAPP_CONF_64 >> "$LOG_FILE" 2>&1
			Retval=$?
			if [ $Retval -eq 1 ]; then
				#the config files are not deleted, you may have to delete it manually.
				log "[WARN]: Could not delete the configuration files, You will need to delete them manually." "$LINENO" "console"
			else
				log "The configuration files for AMDAPPSDK has been deleted." "$LINENO" "console"
			fi
		fi
		removeEnvironmentVariable "$AMDAPPSDK_PROFILE" "OPENCL_VENDOR_PATH" 
		removeEnvironmentVariable "$AMDAPPSDK_PROFILE" "AMDAPPSDKROOT"
		Retval=$?
		if [ $Retval -eq 1 ]; then
				#Environment variables are not deleted, you may have to delete it manually.
				log "[WARN]: Could not delete the Environment variables from the $AMDAPPSDK_PROFILE file , You will need to delete them manually." "$LINENO" "console"
		else
				log "The Environment variables for AMDAPPSDK has been deleted the $AMDAPPSDK_PROFILE file." "$LINENO" "console"
		fi
	else
		#non root user
		if [ -e "$HOME/.bashrc" ]; then
			AMDAPPSDK_PROFILE="$HOME/.bashrc"
		else
			log "Could not locate $HOME/.bashrc. Unable to update environment variables" "$LINENO" 
		fi	
		#Delete the AMDAPPSDKROOT environment variable
		removeEnvironmentVariable "$AMDAPPSDK_PROFILE" "OPENCL_VENDOR_PATH" 
		removeEnvironmentVariable "$AMDAPPSDK_PROFILE" "AMDAPPSDKROOT"
		Retval=$?
		if [ $Retval -eq 1 ]; then
				#Environment variables files are not deleted, you may have to delete it manually.
				log "[WARN]: Could not delete the Environment variables from the $AMDAPPSDK_PROFILE file , You will need to delete them manually." "$LINENO" "console"
		else
				log "The Environment variables for AMDAPPSDK has been deleted the $AMDAPPSDK_PROFILE file." "$LINENO" "console"
		fi
	fi
	#special updation of $LD_LIBRARY_PATH.
	#first checks whether the $LD_LIBRARY_PATH exists or not.
	#if exists, again it checks whether it is terminated with semicolon or not.
	#in-turn it checks whether LD_LIBRARY_PATH contains the updated path, if found it will delete only the value which has 		#been updated during installation.
	#if its not found it just logs the case and skips deletion of $LD_LIBRARY_PATH.
	#after updation of LD_LIBRARY_PATH, it writes back the updated value to the system
	#Deleting the values of the LD_LIBRARY_PATH
	if [ -n "$LD_LIBRARY_PATH" ]; then
		#LD_LIBRARY_PATH exists
		log "LD_LIBRARY_PATH exists. Existing Value: $LD_LIBRARY_PATH" "$LINENO" 
		
		#Check for the updated LD_LIBRARY_PATH while installing.	
		#Remove the trailing : character, if any. The below bash shell code will do that.
		LD_LIBRARY_PATH="${LD_LIBRARY_PATH%:}"	#System's LD_LIBRARY_PATH
		
		#Create the Path that the installer would have added for APP SDK
		LD_LIBRARY_PATH32="${INSTALL_DIR}/lib/x86/"
		if [ "$OS_ARCH" == "64" ]; then
			LD_LIBRARY_PATH64="${INSTALL_DIR}/lib/x86_64/"
		fi

		#checking whether $LD_LIBRARY_PATH contains $LD_LIBRARY_PATH32, if found we need to delete only the value which is appended during installing.
		# if not found just logs the case and skips deletion.
		if [[ $LD_LIBRARY_PATH =~ "$LD_LIBRARY_PATH32" ]] ; then
			  	#$LD_LIBRARY_PATH32 path is found in LD_LIBRARY_PATH, hence deleting the trailing part of it.
				log "$LD_LIBRARY_PATH32 path is found in LD_LIBRARY_PATH, hence deleting the $LD_LIBRARY_PATH32 part from $LD_LIBRARY_PATH " "$LINENO"
				#Deleting duplicate values if any exists, without sorting the order of values.				
				export LD_LIBRARY_PATH="`echo "$LD_LIBRARY_PATH" |awk 'BEGIN{RS=":";}{sub(sprintf("%c$",10),"");if(A[$0]){}else{A[$0]=1;printf(((NR==1)?"":":")$0)}}'`";								
				#Deleting $LD_LIBRARY_PATH64 part from $LD_LIBRARY_PATH
				LD_LIBRARY_PATH=$( echo $LD_LIBRARY_PATH | sed -e 's!'$LD_LIBRARY_PATH32'!!' -e 's/::/' )
				log "The new LD_LIBRARY_PATH value is: $LD_LIBRARY_PATH" "$LINENO"
				addEnvironmentVariable "$AMDAPPSDK_PROFILE" "LD_LIBRARY_PATH" "$LD_LIBRARY_PATH"
		else
		  	log "$LD_LIBRARY_PATH32 does not exists." "$LINENO" 
		fi
		#checking whether $LD_LIBRARY_PATH contains $LD_LIBRARY_PATH64, if found we need to delete only the value which is appended during installing.
		# if not found just log the case and skip deletion.
		if [[ $LD_LIBRARY_PATH =~ "$LD_LIBRARY_PATH64" ]] ; then
				#$LD_LIBRARY_PATH64 path is found in LD_LIBRARY_PATH, hence deleting the trailing part of it.
				log "$LD_LIBRARY_PATH64 path is found in LD_LIBRARY_PATH, hence deleting the $LD_LIBRARY_PATH64 part from $LD_LIBRARY_PATH " "$LINENO"
				#Deleting duplicate values if any exists, without sorting the order of values.				
				export LD_LIBRARY_PATH="`echo "$LD_LIBRARY_PATH" |awk 'BEGIN{RS=":";}{sub(sprintf("%c$",10),"");if(A[$0]){}else{A[$0]=1;printf(((NR==1)?"":":")$0)}}'`";									
				#Deleting $LD_LIBRARY_PATH64 part from $LD_LIBRARY_PATH
				LD_LIBRARY_PATH=$( echo $LD_LIBRARY_PATH | sed -e 's!'$LD_LIBRARY_PATH64'!!' -e 's/::/' )
				log "The new LD_LIBRARY_PATH value is $LD_LIBRARY_PATH" "$LINENO"
				addEnvironmentVariable "$AMDAPPSDK_PROFILE" "LD_LIBRARY_PATH" "$LD_LIBRARY_PATH"		
		else
		  	log "$LD_LIBRARY_PATH64 does not exists." "$LINENO" 
		fi
		if [ -z "$LD_LIBRARY_PATH" ]; then
			if [ $UID -ne "0" ]; then
				#Non-Root user				
				removeEnvironmentVariable "$AMDAPPSDK_PROFILE" "LD_LIBRARY_PATH"
				Retval=$?
				if [ $Retval -eq 1 ]; then
					#The LD_LIBRARY_PATH is not deleted.
					log "[WARN]: The LD_LIBRARY_PATH is not deleted, You may need to delete the variable manually." "$LINENO"
				else
					log "The LD_LIBRARY_PATH is deleted" "$LINENO"
				fi				
			fi			
		fi
	else
		# LD_LIBRARY_PATH does not exists, hence skipping the deletion.
		log "LD_LIBRARY_PATH does not exists." "$LINENO" 
	fi

	log "Done updating Environment variables for $USER" "$LINENO" "console"
}
#Function Name	: unregisterOpenCLICD
#Returns	: returns zero if the $VENDOR_DIR is deleted, if not returns non-zero value.
#Comments	: Depending upon the user and catalyst driver installed, this function deletes the $VENDOR_DIR.
unregisterOpenCLICD()
{
	Retval=1
	
	VENDORS_DIR="/etc/OpenCL/vendors"
	DeleteFolder=0
			
	if [ $UID -eq "0" ]; then
		#root user
		#If catalyst is present, then the VENDORS_DIR would have been created by the catalyst,
		#In such a scenario the SDK Un-Installer should not do anything.
		#else DeleteFolder=1
		if [ "$OS_ARCH" = "32" ]; then
			if [ -e "/usr/lib/libamdocl32.so" -o -e "/usr/lib/fglrx/libamdocl32.so" ]; then
				#Found files
				log "32-bit AMD Catalyst OpenCL Runtime is available hence skipping deletion of vendors directory." "$LINENO"
			else
				DeleteFolder=1		
			fi
		elif [ "$OS_ARCH" = "64" ]; then
			if [ -e /usr/lib/libamdocl64.so -o -e /usr/lib64/libamdocl64.so -o -e /usr/lib/fglrx/libamdocl64.so -o -e /usr/lib/fglrx/libamdocl64.so ]; then
				#Found files
				log "64-bit AMD Catalyst OpenCL Runtime is available hence skipping deletion of vendors directory." "$LINENO"
			else
				DeleteFolder=1
			fi
		else
			log "Found an incompatible OS Architecture: "$OS_ARCH". Please report the issue" "$LINENO"
		fi
	else
		#non root user
		log "Pre-pending the directory: $INSTALL_DIR" "$LINENO"
		VENDORS_DIR="${INSTALL_DIR}${VENDORS_DIR}"
		DeleteFolder=1
	fi
	if [ "$DeleteFolder" == "1" ]; then
		log "deleting Vendors directory containing ICD registration files: $VENDORS_DIR" "$LINENO" 
		if [ ! -d "$VENDORS_DIR" ]; then
			log "Unable to locate/find the vendor directory: $VENDORS_DIR" "$LINENO"
			Retval=0
		else
			rm -rvf "$VENDORS_DIR" >> "$LOG_FILE" 2>&1
			Retval=$?
		fi
	else
		Retval=0
	fi
	return $Retval
}
#Function Name	: removePayload
#Returns	: returns zero if $INSTALL_DIR is deleted, else returns non-zero.
#Comments	: This function deletes the installation directory: $INSTALL_DIR
removePayload()
{
	Retval=1
	if [ -d "$INSTALL_DIR" ]; then
		rm -rvf "$INSTALL_DIR" >> "$LOG_FILE" 2>&1
		Retval=$?
	else
		log "$INSTALL_DIR not found!!" "$LINENO" "console"
	fi
	return $Retval
}
#Function Name	: removeAPPSDKIni
#Returns	: returns zero if the $AMDAPPSDK_DIR is deleted,else returns non-zero.
#Comments	: #Deleting the $AMDAPPSDK_DIR, which is been created while installing.
removeAPPSDKIni()
{
	Retval=1
	#Deleting the $AMDAPPSDK_DIR, which is been created while installing.
	AMDAPPSDK_DIR=/etc/AMD
	if [ "$UID" -ne 0 ]; then
		#Non-root
		AMDAPPSDK_DIR=${HOME}${AMDAPPSDK_DIR}
	fi
	if [ -d "$AMDAPPSDK_DIR" ]; then
		rm -rvf "$AMDAPPSDK_DIR" >> "$LOG_FILE" 2>&1
		Retval=$?
	else
		log "$AMDAPPSDK_DIR not found!!" "$LINENO" "console"
	fi
	return $Retval
}
#Function Name	: main
#Returns	: returns zero if all the functions gets executed else if any function gets failed it will return non-zero.
#Comments	: this function executes all the functions called in it and creates the log files for all the functions irrespective of the results.
main()
{
	Retval=1
	if [ ! -d "$AMDAPPSDK_TEMP_DIR" ]; then
		#create the tmp directory for storing logs with 777 permissions.
		#this directory hierarchy will be owned by the logged in user.
		mkdir --parents --mode 777 "$AMDAPPSDK_TEMP_DIR"
	fi
	log "Starting un-installation of AMD APP SDK2.9-1" "$LINENO" "console"
	log "Retrieving Operating System details..." "$LINENO" "console"

	getOSDetails
	getLoggedInUserDetails
	getInstallationDirectory
	unhandleCatalyst
	uninstallCLINFO
	updateEnvironmentVariables	
	unregisterOpenCLICD
	removePayload
	removeAPPSDKIni
	Retval=$?
	log "Un-installation of AMD APP SDK-2.9-1 completed." "$LINENO" "console"
	log "You may need to re-login to your console for updates to environment variable to take affect." "$LINENO" "console"

	return $Retval
}

main
exit $?
