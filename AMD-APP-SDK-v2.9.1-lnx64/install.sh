#!/bin/bash

# ****************************************************************************************************
# Copyright (c) 2014 Advanced Micro Devices, Inc. All rights reserved.

# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

# .   Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# .   Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or
 # other materials provided with the distribution.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 # WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
 # DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 # OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# **************************************************************************************************/

# source shflags
. ./shflags

#Define flags --silent or -s
#Define flags --acceptEULA or -a. This is applicable only for silent install.
DEFINE_boolean 'silent' false 'Install AMD APP SDK v2.9-1 silently with default options' 's'
DEFINE_string 'acceptEULA' '' 'Accept the AMD APP SDK EULA' 'a'

#Script level variables
EULA_FILE=`pwd`/APPSDK-EULA-linux.txt
INSTALL_ARCH="[SETUP_ARCHITECTURE]"
AMDAPPSDK_TEMP_DIR="${HOME}/AMDAPPSDK-2.9-1"
LOG_FILE="$AMDAPPSDK_TEMP_DIR/InstallLog_$(date +"%m-%d-%Y"T"%H-%M-%S").log"
INSTALL_DIR="/opt"
USERMODE_INSTALL=1	#A value of 1 indicates that the script will install 
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
#Function Name	:checkPrerequisites
#Comments	: gets the architecture details of the current installer which is been installed.
checkPrerequisites()
{
	if [ "$OS_ARCH" = "32" -a "$INSTALL_ARCH" = "amd64" ]; then
		log "The 64-bit AMD APP SDK v2.9-1 cannot be installed on a 32-bit Operating System. Please use the 32-bit AMD APP SDK v2.9-1. The installer will now exit." "$LINENO" 
		return 1
	else
		return 0
	fi
}
#Function Name	: getLoggedInUserDetails
#Comments	: gets the current logged-in user details and prints on the console.
getLoggedInUserDetails()
{
	CURRENT_USER=$(whoami)
	log "Logged in user: $CURRENT_USER" "$LINENO" "console"
}

askYN()
{
	while true;
	do
		read -p "$1 " yn
		case ${yn:-$2} in
			[Yy]* ) return 0;;
			[Nn]* ) return 1;;
			* ) echo "Please answer Yes(Y) or No(N).";;
		esac
	done
}

#Function Name	: showEULAAndWait
#Comments	: Shows the EULA on the console and waits for the user to provide the input.
		  #if the user enter 'Y' the installation continues and if the user enters 'N' then installer exists installation.
showEULAAndWait()
{
	log "---------------------------------------------------------------------------------" "$LINENO" "console"
	cat "$EULA_FILE" | more
	log "---------------------------------------------------------------------------------" "$LINENO" "console"
	
	while true;
	do
		read -p "Do you accept the licence (y/n)? " yn
		case ${yn} in
			[Yy]* ) return 0;;
			[Nn]* ) return 1;;
			* ) echo "Please answer Yes(Y) or No(N).";;
		esac
	done
}

#Function Name	: diskSpaceAvailable
#Comments       : This function checks space available for installing the APPSDK installer.
diskSpaceAvailable()
{
	#Get the size of the payload
	PayloadSize=$(du -shb)
	log "Payload size: $PayloadSize" "$LINENO" 
	log "Removing the . character" "$LINENO" 
	PayloadSize=${PayloadSize%?}
	log "Size after removing the . character: $PayloadSize" "$LINENO" 
	PayloadSize="${PayloadSize%%*( )}"
	log "Size after Trimming the . character: $PayloadSize" "$LINENO" 
}

#Function Name	: dumpPayload
#Comments       : This function dumps/copies all the files and folders to $INSTALL_DIR. 
dumpPayload()
{
	#$1 contains the directory where the payload has to be moved.
	log "Installing to $INSTALL_DIR." "$LINENO" "console"
	
	mkdir -pv --mode 755 "$INSTALL_DIR" >> "$LOG_FILE" 2>&1
	Retval=$?
	if [ $Retval -ne 0 ]; then
		log "Failed to create the $INSTALL_DIR. The installation cannot continue." "$LINENO" "console"
	else
		#Install Directory created successfully, now copy over the contents to the directory
		cp -rvu ./* "$INSTALL_DIR" >> "$LOG_FILE" 2>&1
		Retval=$?
		if [ $Retval -ne 0 ]; then
			log "Failed to install files in the $INSTALL_DIR directory." "$LINENO" "console"
		else
			log "Payload copied to $INSTALL_DIR" "$LINENO" 
			#Change the permission of clinfo
			if [ "$OS_ARCH" == "32" ]; then
				chmod -v 755 "$INSTALL_DIR/bin/x86/clinfo" >> "$LOG_FILE" 2>&1
			else
				#Changing mode for both 32-bit and 64-bit clinfo.
				chmod -v 755 "$INSTALL_DIR/bin/x86/clinfo" >> "$LOG_FILE" 2>&1
				chmod -v 755 "$INSTALL_DIR/bin/x86_64/clinfo" >> "$LOG_FILE" 2>&1
			fi
			
			#In case of root, give execute permissions to all users for samples
			if [ "$USERMODE_INSTALL" == "0" ]; then
				#Change the permission of the directory
				#If the logged in user is root, then give others and groups rw permissions
				chmod -Rv 755 "$INSTALL_DIR/bin" >> "$LOG_FILE" 2>&1
				chmod -Rv 755 "$INSTALL_DIR/lib" >> "$LOG_FILE" 2>&1
				chmod -Rv 755 "$INSTALL_DIR/include" >> "$LOG_FILE" 2>&1
				chmod -Rv 755 "$INSTALL_DIR/samples" >> "$LOG_FILE" 2>&1
				chmod -v 755 "$INSTALL_DIR/docs" >> "$LOG_FILE" 2>&1
				pushd "$INSTALL_DIR/docs" >> "$LOG_FILE" 2>&1
					chmod -v 644 * >> "$LOG_FILE" 2>&1
				popd >> "$LOG_FILE" 2>&1
			fi
		fi
	fi
	
	return $Retval
}

askDirectory()
{
	while true;
	do
		Directory="$2"
		read -e -p "$1: [$2]" Directory
		if [ -z "$Directory" ]; then
			Directory="$2"
		fi

		#remove trailing directory separator if present
		Directory="${Directory%/}"
		Directory=${Directory}/AMDAPPSDK-2.9-1
		log "You have chosen to install AMD APP SDK v2.9-1 in directory: $Directory" "$LINENO", "console"
		break;
	done
}

#Function Name	: registerOpenCLICD
#Comments       : this function checks for $VENDORS_DIR, if exists just logs, else creates the $VENDORS_DIR
				  #After creation of $VENDORS_DIR, it checks for the vendors directory, and registers the ICD's.
registerOpenCLICD()
{
	VENDORS_DIR="/etc/OpenCL"
		
	if [ "$USERMODE_INSTALL" == "0" ]; then
		log "Creating $VENDORS_DIR for root user." "$LINENO"
		
		#Root mode installation
		if [ ! -d "$VENDORS_DIR" ]; then
			#VENDORS_DIR does not exist, so create it.
			mkdir -v --mode 755 "$VENDORS_DIR" >> "$LOG_FILE" 2>&1
			Retval=$?
			if [ $Retval -ne 0 ]; then
				log "Failed to create the ICD registrations directory: $VENDORS_DIR" "$LINENO" 
				return $Retval
			fi
		else
			log "$VENDORS_DIR for $USER already exists." "$LINENO"
		fi
		
		#VENDORS_DIR exists or has now been created
		#Check for the existence of $VENDORS_DIR/vendors
		VENDORS_DIR="$VENDORS_DIR/vendors"
		if [ ! -d "$VENDORS_DIR" ]; then
			#Create it if not exists
			mkdir -v --mode 755 "$VENDORS_DIR" >> "$LOG_FILE" 2>&1
			Retval=$?
			if [ $Retval -ne 0 ]; then
				log "Failed to create the ICD registrations directory: $VENDORS_DIR" "$LINENO" 
				return $Retval
			fi
		else
			log "$VENDORS_DIR for $USER already exists." "$LINENO"
		fi
	else
		#User mode installation
		VENDORS_DIR="$INSTALL_DIR/$VENDORS_DIR/vendors"	

		#Check if VENDORS_DIR exists
		if [ ! -d "$VENDORS_DIR" ]; then
			#Create it if not exists
			log "Creating $VENDORS_DIR for $USER." "$LINENO"
			mkdir -pv --mode 755 "$VENDORS_DIR" >> "$LOG_FILE" 2>&1
			Retval=$?
			if [ $Retval -ne 0 ]; then
				log "Failed to create the ICD registrations directory: $VENDORS_DIR" "$LINENO" 
				return $Retval
			fi
		else
			log "$VENDORS_DIR for $USER already exists." "$LINENO"
		fi
	fi
	
	log "Creating ICD registration files under $VENDORS_DIR" "$LINENO" 

	log "echo libamdocl32.so > \"\$VENDORS_DIR/amdocl32.icd\"" "$LINENO"
	echo libamdocl32.so > "$VENDORS_DIR/amdocl32.icd"
	Retval=$?
	if [ $Retval -ne 0 ]; then
		log "FAILURE: Could not create file: $VENDORS_DIR/amdocl32.icd. Could not register AMD as a 32-bit OpenCL vendor." "$LINENO" 
		return $Retval
	else
		chmod 666 "$VENDORS_DIR/amdocl32.icd" >> "$LOG_FILE" 2>&1
	fi
	
	if [ "$OS_ARCH" == "64" ]; then
		log "echo libamdocl64.so > \"\$VENDORS_DIR/amdoc64.icd\"" "$LINENO"
		echo libamdocl64.so > "$VENDORS_DIR/amdocl64.icd"
		Retval=$?
		if [ $Retval -ne 0 ]; then
			log "FAILURE: Could not create file: $VENDORS_DIR/amdocl64.icd. Could not register AMD as a 64-bit OpenCL vendor." "$LINENO" 
			return $Retval
		else
			chmod 666 "$VENDORS_DIR/amdocl64.icd" >> "$LOG_FILE" 2>&1
		fi
	fi
}

#Function Name	: addEnvironmentVariable
#Comments       : This function first checks whether the Environment variable is present or not.
		  #If present it deletes the environment variable and then add back the variable with the new value.
		  #if not found it just add the variable.
addEnvironmentVariable()
{
	FILE="$1"
	ENVIRONMENT_VARIABLE_NAME="$2"
	ENVIRONMENT_VARIABLE_VALUE="$3"
	
	#First check whether the entry already exists, if it does then delete and recreate
	log "Checking for the presence of $ENVIRONMENT_VARIABLE_NAME in the file: $FILE using grep" "$LINENO"

	grep "$ENVIRONMENT_VARIABLE_NAME" "$FILE" >> "$LOG_FILE" 2>&1
	Retval=$?
	if [ $Retval -eq 0 ]; then
		#found an existing entry, which needs to be deleted
		log "Found an entry for $ENVIRONMENT_VARIABLE_NAME in file: $FILE. Deleted it." "$LINENO" 
		sed -i.bak "/$ENVIRONMENT_VARIABLE_NAME/d" "$FILE" >> "$LOG_FILE" 2>&1
		
		#Confirm whether the command did its job in removing the file.
		grep "$ENVIRONMENT_VARIABLE_NAME" "$FILE" >> "$LOG_FILE" 2>&1
		Retval=$?
		if [ $Retval -ne 0 ]; then
			log "Entry for $ENVIRONMENT_VARIABLE_NAME removed." "$LINENO"
			Retval=0
			#Add the entry back
			log "echo export \"$ENVIRONMENT_VARIABLE_NAME=\"$ENVIRONMENT_VARIABLE_VALUE\"\" >> \"$FILE\"" "$LINENO" 
			echo "export $ENVIRONMENT_VARIABLE_NAME=\"$ENVIRONMENT_VARIABLE_VALUE\"" >> "$FILE"
		else
			log "FAILURE: Could not delete entry for $ENVIRONMENT_VARIABLE_NAME removed." "$LINENO"
			log "[WARN]: Could not update $FILE with the latest value for the environment variable: $ENVIRONMENT_VARIABLE_NAME=$ENVIRONMENT_VARIABLE_VALUE. You will need to update the file with the correct value." "$LINENO" "console"
			return 1
		fi
	else
		log "No Entry for $ENVIRONMENT_VARIABLE_NAME in file: $FILE. Adding it."
		#Add the entry back
		log "echo export \"$ENVIRONMENT_VARIABLE_NAME=\"$ENVIRONMENT_VARIABLE_VALUE\"\" >> \"$FILE\"" "$LINENO" 
		echo "export $ENVIRONMENT_VARIABLE_NAME=\"$ENVIRONMENT_VARIABLE_VALUE\"" >> "$FILE"
	fi
	
	#If the control comes here this means that the variable was added back
	#Now check.
	grep "$ENVIRONMENT_VARIABLE_NAME" "$FILE" >> "$LOG_FILE" 2>&1
	Retval=$?
	if [ $Retval -eq 1 ]; then
		#echo ENVIRONMENT_VARIABLE_NAME not found. i.e., the command failed to add the environment variable in the file
		log "[WARN]: Could not add the entry $ENVIRONMENT_VARIABLE_NAME=$ENVIRONMENT_VARIABLE_VALUE in the file: $FILE. You will need to update the file manually." "$LINENO" "console"
	else
		log "Exported $ENVIRONMENT_VARIABLE_NAME=$ENVIRONMENT_VARIABLE_VALUE via $FILE." "$LINENO" "console"
	fi
	
	return $Retval
}

#Function Name	: updateEnvironmentVariables
#Comments       : This function updates the environment variables, depending upon the user logged-in.
		  # if it's a non-root user, this function updates the variables in $HOME/.bashrc file.
		  # if it's a root user, this function updates the values in /etc/profile.d/AMDAPPSDK.sh.
updateEnvironmentVariables()
{
	#This also needs to be set as an environment variable 
	AMDAPPSDKROOT="$INSTALL_DIR"
	AMDAPP_CONF_32="/etc/ld.so.conf.d/amdapp_x86.conf"
	
	if [ "$OS_ARCH" == "64" ]; then
		AMDAPP_CONF_64="/etc/ld.so.conf.d/amdapp_x86_64.conf"
	fi
	
	#Create the values of the LD_LIBRARY_PATH
	if [ -n "$LD_LIBRARY_PATH" ]; then
		#LD_LIBRARY_PATH exists
		log "LD_LIBRARY_PATH exists. Existing Value: $LD_LIBRARY_PATH" "$LINENO" 
		
		#Check if it is terminated with a : character
		LD_LIBRARY_PATH="${LD_LIBRARY_PATH%:}"
		LD_LIBRARY_PATH32="${LD_LIBRARY_PATH}:${INSTALL_DIR}/lib/x86/"
		if [ "$OS_ARCH" == "64" ]; then
			LD_LIBRARY_PATH64="${LD_LIBRARY_PATH}:${INSTALL_DIR}/lib/x86_64/:${INSTALL_DIR}/lib/x86/"
		fi
	else
		log "LD_LIBRARY_PATH does not exists." "$LINENO" 
		LD_LIBRARY_PATH32="${INSTALL_DIR}/lib/x86/"
		if [ "$OS_ARCH" == "64" ]; then
			LD_LIBRARY_PATH64="${INSTALL_DIR}/lib/x86_64/"
		fi
	fi
	
	log "LD_LIBRARY_PATH32: $LD_LIBRARY_PATH32" "$LINENO"
	log "LD_LIBRARY_PATH64: $LD_LIBRARY_PATH64" "$LINENO"
	
	if [ "$USERMODE_INSTALL" == "0" ]; then
		#Installing as root user
		AMDAPPSDK_PROFILE="/etc/profile.d/AMDAPPSDK.sh"
		#Update the AMDAPPSDKROOT environment variable in /etc/profile.d directory as root user
		echo export AMDAPPSDKROOT="$AMDAPPSDKROOT" > "$AMDAPPSDK_PROFILE"
		chmod -v 644 "$AMDAPPSDK_PROFILE" >> "$LOG_FILE" 2>&1
		
		if [ "$OS_ARCH" == "32" ]; then
			#echo export LD_LIBRARY_PATH="$LD_LIBRARY_PATH32" >> "$AMDAPPSDK_PROFILE" 
			echo "$AMDAPPSDKROOT/lib/x86" > "$AMDAPP_CONF_32"
			chmod 644 "$AMDAPP_CONF_32" >> "$LOG_FILE" 2>&1
		else
			#echo export LD_LIBRARY_PATH="$LD_LIBRARY_PATH64" >> "$AMDAPPSDK_PROFILE" 
			echo "$AMDAPPSDKROOT/lib/x86" > "$AMDAPP_CONF_32"
			chmod 644 "$AMDAPP_CONF_32" >> "$LOG_FILE" 2>&1
			
			echo "$AMDAPPSDKROOT/lib/x86_64" > "$AMDAPP_CONF_64"
			chmod 644 "$AMDAPP_CONF_64" >> "$LOG_FILE" 2>&1
		fi
		
		log "Rebuilding linker cache..." "$LINENO" "console"
		ldconfig -v >> "$LOG_FILE" 2>&1
	else
		#non root user
		if [ -e "$HOME/.bashrc" ]; then
			AMDAPPSDK_PROFILE="$HOME/.bashrc"
		else
			log "Could not locate $HOME/.bashrc. Unable to setup environment variables" "$LINENO" 
		fi
		
		#Add the AMDAPPSDKROOT environment variable
		addEnvironmentVariable "$AMDAPPSDK_PROFILE" "AMDAPPSDKROOT" "$AMDAPPSDKROOT"
		addEnvironmentVariable "$AMDAPPSDK_PROFILE" "OPENCL_VENDOR_PATH" "$INSTALL_DIR/etc/OpenCL/vendors/"
	fi
	
	if [ "$OS_ARCH" == "32" ]; then
		addEnvironmentVariable "$AMDAPPSDK_PROFILE" "LD_LIBRARY_PATH" "$LD_LIBRARY_PATH32"
	else
		addEnvironmentVariable "$AMDAPPSDK_PROFILE" "LD_LIBRARY_PATH" "$LD_LIBRARY_PATH64"
	fi
	
	log "Done updating Environment variables for $USER" "$LINE" "console"
}

#Function Name	: installCLINFO
#Comments       : This function creates the soft-link to appropriate $INSTALL_DIR/bin/*/clinfo, depending on the user
installCLINFO()
{
	if [ "$USERMODE_INSTALL" == "0" ]; then
		#root user
		log "Creating soft-link to the appropriate $INSTALL_DIR/bin/*/clinfo in /usr/bin" "$LINENO" 
		if [ "$OS_ARCH" = "32" ]; then
			ln -svf "$INSTALL_DIR/bin/x86/clinfo" "/usr/bin/clinfo" >> "$LOG_FILE" 2>&1
		else
			ln -svf "$INSTALL_DIR/bin/x86_64/clinfo" "/usr/bin/clinfo" >> "$LOG_FILE" 2>&1
		fi
	else
		#non-root user
		log "Non root user, creating soft link in the users $HOME/bin directory." "$LINENO" 
		if [ ! -d "$HOME/bin" ] ; then
			#bin directory does not exist, so create it
			log "$HOME/bin directory does not exist, so creating it." "$LINENO" 
			mkdir -v "$HOME/bin"  >> "$LOG_FILE" 2>&1
		fi
		
		#the directory exist so create a soft-link
		log "Creating soft-link to the appropriate $INSTALL_DIR/bin/*/clinfo in $HOME/bin" "$LINENO" 
		if [ "$OS_ARCH" = "32" ]; then
			ln -svf "$INSTALL_DIR/bin/x86/clinfo" "$HOME/bin/clinfo" >> "$LOG_FILE" 2>&1
		else
			ln -svf "$INSTALL_DIR/bin/x86_64/clinfo" "$HOME/bin/clinfo" >> "$LOG_FILE" 2>&1
		fi
	fi
}

#Function Name	: reportMetrics
#Comments       : This function reports to metrics.amd.com
reportMetrics()
{
	WGET=$(which wget)
	Retval=$?
	if [ $Retval -eq 0 ]; then
		log "Reporting to metrics.amd.com" "$LINENO"
		if [ "$OS_ARCH" == "32" ]; then
			$WGET --tries=2 -O "$AMDAPPSDK_TEMP_DIR/Linux_fullInstall_$USER.gif" -U "DEV/SDK Mozilla (X11; Linux x86; rv:25.0) Gecko/20100101 Firefox/25.0" "http://metrics.amd.com/b/ss/amdvdev/1/H.23.3/s84357590374752?AQB=1&ndh=1&t=23%2F7%2F2013%2012%3A00%3A01%203%20240&ce=UTF-8&ns=amd&pageName=%2Fdeveloper.amd.com%2Fsdk&g=http%3A%2F%2Fdeveloper.amd.com%2Fsdk%3Faction%3Dinstalled%26file%3DFull_L2.9-1&cc=USD&ch=%2Fdeveloper.amd.com%2Fsdk%2F&server=developer.amd.com&events=event8%2Cevent62&c1=developer.amd.com&c2=developer.amd.com%2Fsdk&c3=developer.amd.com%2Fsdk&c4=developer.amd.com%2Fsdk&v8=http%3A%2F%2Fdeveloper.amd.com%2Fsdk%3Faction%3Dinstalled%26file%3DFull_L2.9-1&c13=SDK%7Cinstalled%7CFull_L2.9-1&c15=SDK%20Downloader&c17=index.aspx%3Faction%3Dinstalled%26file%3DFull_L2.9-1&c25=amdvdev&c51=SDK%7Cinstalled%7CFull_L2.9-1&s=1280x1024&c=32&j=1.5&v=Y&k=Y&bw=1280&bh=1024&ct=lan&hp=N&AQE=1" >> "$LOG_FILE" 2>&1
		else
			$WGET --tries=2 -O "$AMDAPPSDK_TEMP_DIR/Linux_fullInstall_$USER.gif" -U "DEV/SDK Mozilla (X11; Linux x86_64; rv:25.0) Gecko/20100101 Firefox/25.0" "http://metrics.amd.com/b/ss/amdvdev/1/H.23.3/s84357590374752?AQB=1&ndh=1&t=23%2F7%2F2013%2012%3A00%3A01%203%20240&ce=UTF-8&ns=amd&pageName=%2Fdeveloper.amd.com%2Fsdk&g=http%3A%2F%2Fdeveloper.amd.com%2Fsdk%3Faction%3Dinstalled%26file%3DFull_L2.9-1&cc=USD&ch=%2Fdeveloper.amd.com%2Fsdk%2F&server=developer.amd.com&events=event8%2Cevent62&c1=developer.amd.com&c2=developer.amd.com%2Fsdk&c3=developer.amd.com%2Fsdk&c4=developer.amd.com%2Fsdk&v8=http%3A%2F%2Fdeveloper.amd.com%2Fsdk%3Faction%3Dinstalled%26file%3DFull_L2.9-1&c13=SDK%7Cinstalled%7CFull_L2.9-1&c15=SDK%20Downloader&c17=index.aspx%3Faction%3Dinstalled%26file%3DFull_L2.9-1&c25=amdvdev&c51=SDK%7Cinstalled%7CFull_L2.9-1&s=1280x1024&c=32&j=1.5&v=Y&k=Y&bw=1280&bh=1024&ct=lan&hp=N&AQE=1" >> "$LOG_FILE" 2>&1
		fi
	else
		log "Failed to locate wget command. Skipping metrics reporting." "$LINENO"
	fi
	
	return $?
}

#Function Name	: reportStats
#Comments       :# We first check whether internet connection is available.
		 # Ping metrics.amd.com first, if successfull go ahead and report metrics
		 # If ping fails (port blocked or genuine failure) try downloading verison.txt from developer.amd.com (try this only once)
		 # If the download succeeds then report metrics, otherwise skip reporting metrics.
reportStats()
{
	log "Checking Internet connectivity. Please wait..." "$LINENO" "console"
	
	# We first check whether internet connection is available.
	# Ping metrics.amd.com first, if successfull go ahead and report metrics
	# If ping fails (port blocked or genuine failure) try downloading verison.txt from developer.amd.com (try this only once)
	# If the download succeeds then report metrics, otherwise skip reporting metrics.
	
	PING=$(which ping)
	Retval=$?
	if [ $Retval -ne 0 ]; then
		log "Failed to locate ping command" "$LINENO"
		return $Retval
	fi
	
	log "PING Command: ${PING}" "$LINENO"
	$PING -c 4 metrics.amd.com >> "$LOG_FILE" 2>&1
	Retval=$?
	if [ $Retval -eq 0 ]; then
		# Has internet access
		reportMetrics
		return $?
	fi
	
	#Ping failed, ping may be blocked or some other reason
	#Try downloading the default from metrics.amd.com
	WGET=$(which wget)
	Retval=$?
	if [ $Retval -ne 0 ]; then
		log "Failed to locate wget command. Skipping metrics reporting." "$LINENO"
		return $Retval
	fi
	
	#If the code has come here this means that ping has failed
	#So we try downloading from metrics.amd.com
	$WGET -v --tries=1 -O "$AMDAPPSDK_TEMP_DIR/metrics-amd-com.html" -U "DEV/SDK Mozilla (X11; Linux x86; rv:25.0) Gecko/20100101 Firefox/25.0" "http://metrics.amd.com"  >> "$LOG_FILE" 2>&1
	Retval=$?
	if [ $Retval -eq 0 ]; then
		#Looks like metrics.amd.com is accessible, ping might have been blocked.
		reportMetrics
		Retval=$?
	fi
	
	return $Retval
}

#Function Name	: createAPPSDKIni
#Comments       : This function creates the INI file in the appropriate folder, for root user it creates in /etc/AMD folder,  		  	  #for non-root it creates the file in $HOME/etc/AMD
		  #The Ini file consists the value of $INSTALL_DIR, which can be used to check whether APP SDK is already installed 			  #for the logged in user.
		  #The $INSTALL_DIR value can be used while repairing the APP SDK or even while uninstalling the APP SDK.
createAPPSDKIni()
{
	AMDAPPSDK_DIR=/etc/AMD
	if [ "$UID" -ne 0 ]; then
		#Non-root
		AMDAPPSDK_DIR=${HOME}${AMDAPPSDK_DIR}
	fi
	
	AMDAPPSDK_INIFILE=${AMDAPPSDK_DIR}/APPSDK-2.9-1.ini
	Retval=1

	#AS of now if the file exists, we log it and then re-create the file.
	if [ -e $AMDAPPSDK_INIFILE ]; then
		#log that the INI file pre-exists and the file is been re-created with the new value.
		log "The $AMDAPPSDK_INIFILE pre-exists" "$LINENO."
	fi
	
	#create the ini file with the INSTALL_DIR value.
	mkdir -pv "$AMDAPPSDK_DIR" --mode 755 "$INSTALL_DIR" >> "$LOG_FILE" 2>&1		
	Retval=$?
	if [ $Retval -eq 0 ] ; then
		echo [GENERAL] > $AMDAPPSDK_INIFILE
		echo INSTALL_DIR=$INSTALL_DIR >> $AMDAPPSDK_INIFILE
	else
		log "Failed to create the directory for $AMDAPPSDK_INIFILE." "$LINENO"
	fi
	
	return $Retval
}

#Function Name	: createOpenCLSoftLink
#Comments       : This function checks whether soft link exists or not.
		  #If exist, it removes the soft-link and creates a new soft-link with new files.
		  #If soft-link does not exists, it creates the soft-link to the appropriate files.
createOpenCLSoftLink()
{
	DIR=$1				#The directory containing the file to which the soft-link has to be created
	NAME=$2				#The name of the file.
	PLATFORM=$3			#The directory under which i.e. $INSTALL_DIR/lib/x86 or $INSTALL_DIR/lib/x86_64 the soft-link will be created.
	Retval=1
	SOURCE="$DIR/${NAME}.1"	#/usr/lib/libOpenCL.so.1
	
	#First check whether the source exists or nit
	if [ -e "$SOURCE" ]; then
		log "$SOURCE exist. Proceeding with creation of soft-link to it." $LINENO
		
		TARGET="$INSTALL_DIR/lib/$PLATFORM/$NAME"
		
		#Now check whether the soft-link already exists
		if [ -e "$TARGET" ]; then
			#Soft-link already exists, delete it
			rm -rvf "$TARGET"  >> "$LOG_FILE" 2>&1
		fi
		
		#Soft-link does not exist, or has been removed
		#now create the soft-link
		ln -sv "$SOURCE" "$TARGET" >> "$LOG_FILE" 2>&1
		Retval=$?
		if [ $Retval -eq 0 ]; then
			log "SUCCESS: Soft-link $TARGET to $SOURCE created." "$LINENO"
		else
			log "FAILURE: Could not create Soft-link $TARGET to $SOURCE created." "$LINENO"
		fi
	else
		log "$SOURCE does not exist. Skipping creation of soft-link to it."
		Retval=0
	fi
	
	return $Retval
}

deleteFile()
{
	Retval=1
	
	log "Removing the file: $1" "$LINENO"
	if [ -e "$1" ]; then
		rm -vf "$1" >> "$LOG_FILE" 2>&1
		Retval=$?
	else
		#Since the file does not exist, hence do not count it as an error.
		log "File $1 does not exist" "$LINENO"
		Retval=0
	fi
	
	return $Retval
}

#Function Name	: handleCatalyst
#Comments       :This function removes the libOpenCL.so and the libamdocl32/64.so if catalyst is installed.
				 #It also creates the libOpenCL.so soft-link to the appropriate libOpenCL.so.1
handleCatalyst()
{
	Retval=1
	if [ "$OS_ARCH" = "32" ]; then
		if [ -e "/usr/lib/libamdocl32.so" -o -e "/usr/lib/fglrx/libamdocl32.so" ]; then
			#Found files
			log "32-bit AMD Catalyst OpenCL Runtime is available hence skipping 32-bit AMD OpenCL CPU Runtime Installation." "$LINENO" 
			
			if [ -e /usr/lib/libamdocl32.so ]; then
				log "/usr/lib/libamdocl32.so found" "$LINENO"
			fi
			
			if [ -e /usr/lib/fglrx/libamdocl32.so ]; then
				log "/usr/lib/fglrx/libamdocl32.so found" "$LINENO"
			fi

			deleteFile "$INSTALL_DIR/lib/x86/libamdocl32.so"
			deleteFile "$INSTALL_DIR/lib/x86/libOpenCL.so"
			
			#File removed or not present. Now create the soft-link to the appropriate libOpenCL.so.1
			#Note: /usr/lib/libOpenCL.so.1 will be of the same architecture as the OS. So if it is a 32-bit OS, then this libOpenCL.so.1 will be a 32-bit file
			createOpenCLSoftLink /usr/lib libOpenCL.so x86
			Retval=$?
			if [ $Retval -ne 0 ]; then
				log "[WARN]Could not create soft-link $INSTALL_DIR/lib/x86/libOpenCL.so to /usr/lib/libOpenCL.so.1. You will need to create this soft-link manually." "$LINENO" "console"
			fi
		fi
	elif [ "$OS_ARCH" = "64" ]; then
		#Now on Ubuntu 64-bit machines, the catalyst will dump the libOpenCL.so.1 in the /usr/lib and the /usr/lib/i386-linux-gnu directory for 64-bit and 32-bit versions respectively.
		#So we need to remove the libamdocl32.so, libamdocl64.so and libOpenCL.so from the appsdk lib directory
		if [ -e /usr/lib/libamdocl64.so -o -e /usr/lib64/libamdocl64.so -o -e /usr/lib/fglrx/libamdocl64.so -o -e /usr/lib/fglrx/libamdocl64.so ]; then
			#Found files
			log "64-bit AMD Catalyst OpenCL Runtime is available hence skipping OpenCL CPU Runtime Installation." "$LINENO" 
			if [ -e /usr/lib/libamdocl64.so ]; then
				log "/usr/lib/libamdocl64.so found" "$LINENO"
			fi
			
			if [ -e /usr/lib64/libamdocl64.so ]; then
				log "/usr/lib64/libamdocl64.so found" "$LINENO"
			fi
			
			if [ -e /usr/lib/fglrx/libamdocl64.so ]; then
				log "/usr/lib/fglrx/libamdocl64.so found" "$LINENO"
			fi
			
			if [ -e /usr/lib/fglrx/libamdocl64.so ]; then
				log "/usr/lib/fglrx/libamdocl64.so found" "$LINENO"
			fi
			
			log "Removing the 32-bit and 64-bit libOpenCL files from $INSTALL_DIR" "$LINENO"
			
			deleteFile "$INSTALL_DIR/lib/x86/libamdocl32.so"
			deleteFile "$INSTALL_DIR/lib/x86_64/libamdocl32.so" 
			deleteFile "$INSTALL_DIR/lib/x86_64/libamdocl64.so"
			deleteFile "$INSTALL_DIR/lib/x86/libOpenCL.so"
			deleteFile "$INSTALL_DIR/lib/x86_64/libOpenCL.so"
			
			#The below is for ubuntu and architectures that support the new multi-arch mechanisms
			if grep -q Ubuntu <<< $OS_DISTRO; then
				log "Ubuntu 64-bit system, creating soft-links to /usr/lib/i386-linux-gnu and /usr/lib" $LINENO
				createOpenCLSoftLink /usr/lib/i386-linux-gnu libOpenCL.so x86
				createOpenCLSoftLink /usr/lib libOpenCL.so x86_64
			else
				log "Not Ubuntu 64-bit system, creating soft-links to /usr/lib and /usr/lib64" $LINENO
				createOpenCLSoftLink /usr/lib libOpenCL.so x86
				createOpenCLSoftLink /usr/lib64 libOpenCL.so x86_64
			fi
		fi
	else
		log "FAILURE: Found an incompatible OS Architecture: $OS_ARCH. Please report the issue." "$LINENO" "console"
	fi
}

#Function Name	: main
#Comments	: this function executes all the functions called in it and creates the log files for all the functions irrespective of the results.
main()
{
	Retval=1
	if [ ! -d "$AMDAPPSDK_TEMP_DIR" ]; then
		#create the tmp directory for storing logs with 777 permissions.
		#this directory hierarchy will be owned by the logged in user.
		mkdir --parents --mode 777 "$AMDAPPSDK_TEMP_DIR"
	fi
	
	log "Starting installation of AMD APP SDK v2.9-1" "$LINENO" "console"
	log "Retrieving Operating System details..." "$LINENO" "console"
	
	getOSDetails
	getLoggedInUserDetails
	checkPrerequisites
	Retval=$?
	if [ $Retval -ne 0 ] ; then
		log "The 64-bit AMD APP SDK v2.9-1 cannot be installed on a 32-bit Operating System. Please use the 32-bit AMD APP SDK v2.9-1." "$LINENO" "console"
		exit $Retval
	fi
	#Show the EULA and ask for continuation
	if [ ${FLAGS_silent} -eq ${FLAGS_TRUE} ]; then
		ACCEPTEULA=`echo ${FLAGS_acceptEULA} | tr '[:upper:]' '[:lower:]'`
		
		echo ACCEPTEULA: $ACCEPTEULA, FLAGS: $FLAGS_acceptEULA
		#If silent mode, then check whether the --acceptEULA flag is specified with the value=y or yes or true, or TRUE or 1.
		if [ "${ACCEPTEULA}" == "1" -o "${ACCEPTEULA}" == "y" -o "${ACCEPTEULA}" == "yes" ]; then
			log "EULA accepted, proceeding with silent installation", "$LINENO"
		else
			log "You will need to read and accept the EULA to install AMD APP SDK." "$LINENO" "console"
			exit 1
		fi
	else
		#not silent mode, show the EULA and wait for acceptance
		if showEULAAndWait; then
			log "EULA accepted, proceeding with console mode installation", "$LINENO"
		else
			log "You will need to read and accept the EULA to install AMD APP SDK." "$LINENO" "console"
			exit 1
		fi
	fi
	
	#If the user is a non-root user, ask whether the software needs to be installed for all users (root) or only
	#for the logged in user?
	
	#If only for logged in user, then the software will be installed in the home directory,
	#otherwise in the /opt/AMDAPPSDK/2.9-1 directory.
	if [ "$UID" -eq 0 ]; then
		log "AMD APP SDK v2.9-1 will be installed for all users." "$LINENO" "console"
		USERMODE_INSTALL=0
	else
		if [ ${FLAGS_silent} -eq ${FLAGS_TRUE} ]; then
			#silent mode, dump the message and proceed with installation
			log "Proceeding with non root silent mode installation." "$LINENO" "console"
			USERMODE_INSTALL=1
			INSTALL_DIR="$HOME"
		else
			log "Non root user, asking the user for continuation of installation." "$LINENO" "console"
			if askYN "AMD APP SDK v2.9-1 will be installed for $USER only if you choose to continue. If you want to install for all users, then you need to restart the installer with root credentials. Do you wish to continue [Y/N]?"; then
				#user wants to get ahead with a non-root installation
				USERMODE_INSTALL=1
				INSTALL_DIR="$HOME"
			else
				log "Please restart the installer with root credentials to install for all users. The installer will now quit." "$LINENO" "console"
				exit 0
			fi
		fi
	fi
	
	log "USERMODE_INSTALL: $USERMODE_INSTALL. (0: root user; 1: non-root user " "$LINENO" 
	
	#Now we know whether to perform a user-mode or a root-mode installation
	#Now ask for the install directory, default will be $INSTALL_DIR
	if [ ${FLAGS_silent} -ne ${FLAGS_TRUE} ]; then
		log "Prompting user for selecting the Installation Directory. Default is $INSTALL_DIR" "$LINENO"
		askDirectory "Enter the Installation directory. Press ENTER for choosing the default directory" "$INSTALL_DIR"
		INSTALL_DIR="$Directory"
	else
		INSTALL_DIR=${INSTALL_DIR}/AMDAPPSDK-2.9-1
	fi
	
	#Now we need to copy the payload to the $INSTALL_DIR
	#The various use cases are:
	#	1. Fresh install
	#	2. The directory exists
	#	3. If it is a root mode install, then other users need to have rwx permissions
	#	4. If non-root mode install, then other users should not have any permissions.

	dumpPayload
	Retval=$?
	if [ $Retval -ne 0 ] ; then
		log "Failed to install AMD APP SDK v2.9-1 to $INSTALL_DIR. The installation cannot continue." "$LINENO" "console"
		exit $Retval
	fi
	
	registerOpenCLICD
	Retval=$?
	if [ $Retval -ne 0 ] ; then
		log "Failed to install AMD APP SDK v2.9-1 to $INSTALL_DIR. The installation cannot continue." "$LINENO" "console"
		exit $Retval
	fi
	
	updateEnvironmentVariables
	Retval=$?
	if [ $Retval -ne 0 ] ; then
		log "Failed to update environment variables AMDAPPSDKROOT and/or LD_LIBRARY_PATH. The installation might still work, however you will need to create/update these environment variables manually. Consult the documentation for the same." "$LINENO" "console" 
	fi
	
	installCLINFO
	Retval=$?
	if [ $Retval -ne 0 ] ; then
		log "[WARN]Failed to install clinfo." "$LINENO" "console"
	fi

	handleCatalyst
	Retval=$?
	if [ $Retval -ne 0 ] ; then
		log "[WARN]Failed to update files to use existing catalyst drivers." "$LINENO" "console"
	fi
	
	reportStats
	Retval=$?
	if [ $Retval -ne 0 ] ; then
		log "Failed to report statistics to metrics.amd.com." "$LINENO"
	fi
	
	createAPPSDKIni
	Retval=$?
	if [ $Retval -ne 0 ] ; then
		log "Failed to create the INI file for AMD APP SDK-2.9-1." "$LINENO"
		return $Retval
	fi
	
	log "Installation Log file: $LOG_FILE" "$LINENO" "console"
	log "You will need to log back in/open another terminal for the environment variable updates to take effect." "$LINENO" "console"
	
	return $Retval
}

# parse the command-line
FLAGS "$@" || exit $?
eval set -- "${FLAGS_ARGV}"

main "$@"
exit $?

