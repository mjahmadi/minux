set -e
set +h

# COLORS
NORMAL="\e[39m"
WHITE="\e[37m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RED="\e[31m"

BOLD_TXT=$(tput bold)
NORMAL_TXT=$(tput sgr0)

# START EXECUTION TIME IN SEC
exec__start_time=$(date +%s)

if [[ -z $1 ]]; then
	echo -e "${RED}ERROR: Build descriptor file missing.${NORMAL}"
	exit -1
elif [[ ! -s $1 ]]; then
	echo -e "${RED}ERROR: Build descriptor file does not exist or access denied.${NORMAL}"
	exit -1
fi

XML_FILE=$1
XML_STRING=$(cat $XML_FILE)

# FUNCTION TO GET XML DATA
function xml_get_val
{
    echo "$XML_STRING" | xmlstarlet sel -t -v "$1" | xmlstarlet unesc
}

in_chroot=$(xml_get_val "/build/@in-chroot")
if [[ $in_chroot != "yes" && $(id -u) == 0 ]]; then
	echo -e "${RED}ERROR: Sorry, user root is not allowed to execute '$0'.${NORMAL}"
	exit -1
fi

export OLD_PATH=$PATH

envpath=$(xml_get_val "/build/@envpath")
if [[ -n $envpath ]]; then
	export PATH=$envpath
fi

export PROJECT__NAME=$(xml_get_val "/build/@name")
export PROJECT__TYPE=$(xml_get_val "/build/@type")
export PROJECT__ARCH=$(xml_get_val "/build/@arch")
export PROJECT__HOST_ARCH=$(uname -m)
export PROJECT__VERSION=$(xml_get_val "/build/@version")
export PROJECT__CODENAME=$(xml_get_val "/build/@codename")
export PROJECT__SUBJECT=$(xml_get_val "/build/@subject")
export PROJECT__TIMEZONE=$(xml_get_val "/build/@timezone")
export PROJECT__HOSTNAME=$PROJECT__NAME-$PROJECT__TYPE-$PROJECT__CODENAME

export PROJECT__VENDOR="Minux"
export PROJECT__AUTHOR_NAME="M.J.Ahmadi"
export PROJECT__AUTHOR_EMAIL="mohammad.j.ahmadi@gmail.com"
export PROJECT__WEBSITE="https://github.com/mjahmadi/minux"

export PROJECT__ISONAME="$PROJECT__NAME-$PROJECT__VERSION-$PROJECT__TYPE-$PROJECT__ARCH.iso"

if [[ $(xml_get_val "/build/@constructor") = 'yes' ]]; then
	export PROJECT__RFS=$(pwd)
	export PROJECT__BLD=$PROJECT__RFS/build
	export PROJECT__TOL=$PROJECT__RFS/tools
	export PROJECT__PKG=$PROJECT__RFS/packages
else
	export PROJECT__CUR=$(pwd)
	export PROJECT__DIR=$PROJECT__CUR/$PROJECT__TYPE-$PROJECT__ARCH
	export PROJECT__BLD=$PROJECT__DIR/build
	export PROJECT__RFS=$PROJECT__DIR/rootfs
	export PROJECT__TOL=$PROJECT__DIR/tools
	export PROJECT__PKG=$PROJECT__CUR/packages
fi

export PROJECT__TGT=$(uname -m)-$PROJECT__NAME-linux-gnu

if [[ -z $PROJECT__NAME || -z $PROJECT__TYPE || -z $PROJECT__SUBJECT || -z $PROJECT__ARCH || -z $PROJECT__VERSION ]]; then
	echo -e "${RED}ERROR: Project 'name/type/subject/arch/version' is missing.${NORMAL}"
	exit -1
fi

if [[ $PROJECT__ARCH != "x86" && $PROJECT__ARCH != $(uname -m) ]]; then
	echo -e "${RED}ERROR: Unsupported build arch.${NORMAL}"
	exit -1
fi

if [[ $(xml_get_val "/build/@sudo") == 'yes' ]]; then
	set +e
	echo -e "${BOLD_TXT}We ask for root credential because of your configurations.${NORMAL_TXT}\nroot's password: "
	read -rs HOST_ROOT_PASS
	sudo -k
	echo "$HOST_ROOT_PASS" | sudo -S echo "hello" &> /dev/null
	if ! [[ "$(sudo -n echo hello 2>&1)" == "hello" ]]; then
		echo -e "${RED}ERROR: Incorrect password was entered.${NORMAL}"
		exit -1
	else
		echo -e "${GREEN}OK!${NORMAL}"
	fi
	set -e
fi

echo -e "\n\n${BOLD_TXT}About to building '$PROJECT__NAME-$PROJECT__TYPE-$PROJECT__SUBJECT-$PROJECT__ARCH-$PROJECT__VERSION-->[$PROJECT__SUBJECT]'${NORMAL_TXT}\n"

mkdir -pv $PROJECT__PKG
mkdir -pv $PROJECT__BLD
mkdir -pv $PROJECT__TOL

if [[ -n $2 ]]; then
    phase_begin_from=$2
else
    phase_begin_from=1
fi

if [[ -n $3 ]]; then
    entry_begin_from=$3
else
    entry_begin_from=1
fi

if [[ -n $3 ]]; then
    action_begin_from=$4
else
    action_begin_from=1
fi

# MAXIMUM CONCURRENT MAKE JOBS
if [[ ! -z "/proc/cpuinfo " ]]; then
	export MAKEFLAGS="-j $(grep ^processor /proc/cpuinfo | wc -l)"
fi
export LC_ALL=POSIX

# BUILD >> PHASE
phase_count=$(xml_get_val "count(/build/phase)")
for phase in `seq $phase_begin_from $phase_count`; do
    
    phase_disabled=$(xml_get_val "/build/phase[$phase]/@disabled")
    if [[ $phase_disabled == 'yes' ]]; then
        echo -e "${BOLD_TXT}\nphase --> '$phase'"
    	echo -e "phase is disabled!\n${NORMAL_TXT}"
    	continue
    fi
    
    # BUILD >> PHASE >> ENTRY
    entry_count=$(xml_get_val "count(/build/phase[$phase]/entry)")
    for entry in `seq $entry_begin_from $entry_count`; do
    
    	entry_name=$(xml_get_val "/build/phase[$phase]/entry[$entry]/@name")
        entry_type=$(xml_get_val "/build/phase[$phase]/entry[$entry]/@type")
        
        entry_disabled=$(xml_get_val "/build/phase[$phase]/entry[$entry]/@disabled")
        if [[ $entry_disabled == 'yes' ]]; then
        	echo -e "${BOLD_TXT}\nentry '$entry' is disabled!\n${NORMAL_TXT}"
        	continue
        else
			echo -e "${BOLD_TXT}\nphase --> '$phase'"
		    echo -e "Entry --> '$entry'\n$entry_name[$entry_type]\n${NORMAL_TXT}"
			sleep 1
        fi
		
        # BUILD >> PHASE >> ENTRY >> ACTION [TYPE=BEFORE]
        entry_action_count=$(xml_get_val "count(/build/phase[$phase]/entry[$entry]/action[@when='before'])")
        for action in `seq 1 $entry_action_count`; do
		
			action_disabled=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/@disabled")
			if [[ $action_disabled == 'yes' ]]; then
				echo -e "${BOLD_TXT}\naction '$action' is disabled!\n${NORMAL_TXT}"
				continue
			else
				echo -e "${BOLD_TXT}\nphase --> '$phase'"
				echo -e "Entry --> '$entry'\n$entry_name[$entry_type]\nAction --> '$action'\n${NORMAL_TXT}"
				sleep 1
			fi
		
            # BUILD >> PHASE >> ENTRY >> ACTION [TYPE=BEFORE] >> LINE
        	entry_action_line_count=$(xml_get_val "count(/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line)")
        	for line in `seq $action_begin_from $entry_action_line_count`; do
        	
	        	line_disabled=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]/@disabled")
				if [[ $line_disabled == 'yes' ]]; then
					echo -e "${BOLD_TXT}action '$action' line '$line' is disabled!\n${NORMAL_TXT}"
					continue
				fi
				
		        sudo=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]/@sudo")
		        verbos=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]/@verbos")
				strap=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]/@strap")
				
		        command=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='before'][$action]/line[$line]")
				
		        if [[ $verbos == 'yes' ]]; then
		            echo -e "$command"
		        fi
		        
				if [[ $sudo == 'yes' && -n $HOST_ROOT_PASS ]]; then
					eval "echo $HOST_ROOT_PASS | sudo -k -S $command"
				else
					eval "$command"
				fi
        	done
        done
        
		# BUILD >> PHASE >> ENTRY
		cdto=$(xml_get_val "/build/phase[$phase]/entry[$entry]/@cdto")
		download=$(xml_get_val "/build/phase[$phase]/entry[$entry]/@download")
		extract=$(xml_get_val "/build/phase[$phase]/entry[$entry]/@extract")
		link=$(xml_get_val "/build/phase[$phase]/entry[$entry]/link")
		filename=$(xml_get_val "/build/phase[$phase]/entry[$entry]/filename")
		directory=$(xml_get_val "/build/phase[$phase]/entry[$entry]/directory")
		directory_base=$(xml_get_val "/build/phase[$phase]/entry[$entry]/directory/@base")
		checksum=$(xml_get_val "/build/phase[$phase]/entry[$entry]/checksum")
		checksum_type=$(xml_get_val "/build/phase[$phase]/entry[$entry]/checksum/@type")
        
        if [[ $download == 'yes' ]]; then
            echo -e "\nDownloading '$filename'"
            wget --continue $link --directory-prefix="$PROJECT__PKG"
        fi
        
		if [[ $entry_type == 'package/src' ]]; then
		
			if [[ ! -s "$PROJECT__PKG/$filename" ]]; then
				echo -e "${RED}ERROR: The package file does not exist or access denied.${NORMAL}"
				exit -1
			fi
			
			chk_algo="${checksum_type}sum"
			checksum2=($($chk_algo $PROJECT__PKG/$filename))
			
			if [[ -n $checksum && $checksum != $checksum2 ]]; then
				echo -e "${RED}ERROR: Checksum[$checksum_type] validation failed.\n  '$checksum' != '$checksum2'${NORMAL}"
				exit -1
			fi

		    if [[ $entry_type == 'package/src' ]]; then
				if [[ $extract == 'yes' ]]; then
				
					des_dir=$(tar -tf $PROJECT__PKG/$filename | head -n 1 | cut -f1)
					des_dir=$(IFS='/' read -r -a array <<< $des_dir && echo ${array[0]})
					des_dir=$(read -r -a array <<< $des_dir && echo ${array[0]})
					
					echo -e "\nExtracting '$filename'"
					
					if [[ -n $directory ]]; then
					
						if [[ $directory_base = 'yes' ]]; then
							eval tmp_dir=$directory/$des_dir
						else
							eval tmp_dir=$directory
						fi
						
						rm -rf $tmp_dir
						mkdir -v -p $tmp_dir
						
						tar -xf $PROJECT__PKG/$filename -C $tmp_dir
					else
						rm -rf $PROJECT__BLD/$des_dir
						tar -xf $PROJECT__PKG/$filename -C $PROJECT__BLD
					fi
				fi
			fi
		fi
		
		if [[ $cdto == 'yes' ]]; then
		
			if [[ ! -s $tmp_dir && ! -s $PROJECT__BLD/$des_dir ]]; then
				echo -e "${RED}ERROR: The directory does not exist or access denied.${NORMAL}"
				exit -1
			fi
			
			if [[ -n $tmp_dir ]]; then
				cd $tmp_dir/$des_dir
			else
				cd $PROJECT__BLD/$des_dir
			fi
			
		fi
        
        # BUILD >> PHASE >> ENTRY >> ACTION [TYPE=AFTER]
        entry_action_count=$(xml_get_val "count(/build/phase[$phase]/entry[$entry]/action[@when='after'])")
        for action in `seq $action_begin_from $entry_action_count`; do
        
			action_disabled=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/@disabled")
			if [[ $action_disabled == 'yes' ]]; then
				echo -e "${BOLD_TXT}\naction '$action' is disabled!\n${NORMAL_TXT}"
				continue
			else
				echo -e "${BOLD_TXT}action --> '$action'\n${NORMAL_TXT}"
				sleep 1
			fi
        
            # BUILD >> PHASE >> ENTRY >> ACTION [TYPE=BEFORE] >> LINE
        	entry_action_line_count=$(xml_get_val "count(/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line)")
        	for line in `seq 1 $entry_action_line_count`; do
        	
				line_disabled=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]/@disabled")
				if [[ $line_disabled == 'yes' ]]; then
					echo -e "${BOLD_TXT}\nline '$line' is disabled!\n${NORMAL_TXT}"
					continue
				fi
			
		        sudo=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]/@sudo")
		        verbos=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]/@verbos")
	        	
		        command=$(xml_get_val "/build/phase[$phase]/entry[$entry]/action[@when='after'][$action]/line[$line]")
		        
		        if [[ $verbos == 'yes' ]]; then
		            echo -e "$command"
		        fi
		        
				if [[ $sudo == 'yes' && -n $HOST_ROOT_PASS ]]; then
					eval "echo $HOST_ROOT_PASS | sudo -k -S $command"
				else
					eval "$command"
				fi
        	done
        done
        
    done
    
    # RESET ENTRY INDEX FOR EACH PHASE
    entry_begin_from=1
    action_begin_from=1
    
done

# CALCULATE THE EXECUTION TIME
exec__elapsed_time=$(echo "$(date +%s) - $exec__start_time" | bc)
echo -e "${GREEN}\nExecution time:\n   $(($exec__elapsed_time / 60)) minute(s) and $(($exec__elapsed_time % 60)) second(s). ${NORMAL}\n"
