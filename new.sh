#!/bin/sh
# ShadowHarvy's Auto Boostrapping Script (LABS)
# by ShadowHarvy
#Hugely borrowed from Luke Smith (plus uses his dwm and I3)
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

while getopts ":a:r:b:p:h" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
	b) repobranch=${OPTARG} ;;
	p) progsfile=${OPTARG} ;;
	a) aurhelper=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

#[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/lukesmithxyz/voidrice.git"
#[ -z "$dotfilesrepo2" ] && dotfilesrepo2="https://github.com/jimbob343/zsh.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/jimbob343/zsh/master/pro.csv"
[ -z "$aurhelper" ] && aurhelper="yay"
[ -z "$repobranch" ] && repobranch="master"

### FUNCTIONS ###

if type xbps-install >/dev/null 2>&1; then
	installpkg(){ xbps-install -y "$1" >/dev/null 2>&1 ;}
	grepseq="\"^[PGV]*,\""
elif type apt >/dev/null 2>&1; then
	installpkg(){ apt-get install -y "$1" >/dev/null 2>&1 ;}
	grepseq="\"^[PGU]*,\""
else
	distro="arch"
	installpkg(){ pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 ;}
	grepseq="\"^[PGA]*,\""
fi

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

welcomemsg() { \
	dialog --title "Welcome!" --msgbox "Welcome to ShadowHarvy's Auto-Bootstrapping Script!\\n\\nThis script will automatically install a fully-featured Linux desktop, which I use as my main machine.\\n\\n-ShadowHarvy" 10 60

	dialog --colors --title "Important Note!" --yes-label "All ready!" --no-label "Return..." --yesno "Be sure the computer you are using has current pacman updates and refreshed Arch keyrings.\\n\\nIf it does not, the installation of some programs might fail." 8 70
	}

selectdotfiles() { \
	edition="$(dialog --title "Select LABS version." --menu "Select which version of LABS you wish to have as default:" 10 70 2 dwm "The version of LABS using suckless's dwm." i3 "The classic version of LABS using i3." custom "If you are supplying commandline options for LABS." 3>&1 1>&2 2>&3 3>&1)" || error "User exited."
	}

getuserandpass() { \
	# Prompts user for new username an password.
	name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
	while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

usercheck() { \
	! (id -u "$name" >/dev/null) 2>&1 ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. LABS can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nLABS will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that LABS will change $name's password to the one you just gave." 14 70
	}

preinstallmsg() { \
	dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit; }
	}

adduserandpass() { \
	# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$name\"..." 4 50
	useradd -m -g wheel -s /bin/bash "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	repodir="/home/$name/.local/src"; mkdir -p "$repodir"; chown -R "$name":wheel $(dirname "$repodir")
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}

refreshkeys() { \
	dialog --infobox "Refreshing Arch Keyring..." 4 40
	pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
	}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#LABS/d" /etc/sudoers
	echo "$* #LABS" >> /etc/sudoers ;}

manualinstall() { # Installs $1 manually if not installed. Used only for AUR helper here.
	[ -f "/usr/bin/$1" ] || (
	dialog --infobox "Installing \"$1\", an AUR helper..." 4 50
	cd /tmp || exit
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$name" tar -xvf "$1".tar.gz >/dev/null 2>&1 &&
	cd "$1" &&
	sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1
	cd /tmp || return) ;}

maininstall() { # Installs all needed programs from main repo.
	dialog --title "LABS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	installpkg "$1"
	}

gitmakeinstall() {
	progname="$(basename "$1" .git)"
	dir="$repodir/$progname"
	dialog --title "LABS Installation" --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
	sudo -u "$name" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return ; sudo -u "$name" git pull --force origin master;}
	cd "$dir" || exit
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return ;}

aurinstall() { \
	dialog --title "LABS Installation" --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 5 70
	echo "$aurinstalled" | grep "^$1$" >/dev/null 2>&1 && return
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
	}

pipinstall() { \
	dialog --title "LABS Installation" --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 5 70
	command -v pip || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
	}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' | eval grep "$grepseq" > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"A") aurinstall "$program" "$comment" ;;
			"G") gitmakeinstall "$program" "$comment" ;;
			"P") pipinstall "$program" "$comment" ;;
			*) maininstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv ;}

putgitrepo() { # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	dialog --infobox "Downloading and installing config files..." 4 60
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown -R "$name":wheel "$dir" "$2"
	sudo -u "$name" git clone --recursive -b "$branch" --depth 1 "$1" "$dir" >/dev/null 2>&1
	sudo -u "$name" cp -rfT "$dir" "$2"
	}

systembeepoff() { dialog --infobox "Getting rid of that retarded error beep sound..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}

finalize(){ \
	dialog --infobox "Preparing welcome message..." 4 50
	echo "exec_always --no-startup-id notify-send -i ~/.local/share/LABS/LABS.png 'Welcome to LABS:' 'Press Super+F1 for the manual.' -t 10000"  >> "/home/$name/.config/i3/config"
	dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t ShadowHarvy" 12 80
	}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install dialog.
installpkg dialog || error "Are you sure you're running this as the root user and have an internet connection?"

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."
selectdotfiles || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

adduserandpass || error "Error adding username and/or password."

# Refresh Arch keyrings.
refreshkeys || error "Error automatically refreshing Arch keyring. Consider doing so manually."

dialog --title "LABS Installation" --infobox "Installing \`basedevel\` and \`git\` for installing other software required for the installation of other programs." 5 70
installpkg curl
installpkg base-devel
installpkg git
installpkg ntp

dialog --title "LABS Installation" --infobox "Synchronizing system time to ensure successful and secure installation of software..." 4 70
ntpdate 0.us.pool.ntp.org >/dev/null 2>&1

[ "$distro" = arch ] && { \
	[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

	# Allow user to run sudo without password. Since AUR programs must be installed
	# in a fakeroot environment, this is required for all builds with AUR.
	newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

	# Make pacman and yay colorful and adds eye candy on the progress bar because why not.
	grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color$/Color/" /etc/pacman.conf
	grep "ILoveCandy" /etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
  grep "SigLevel    = Never" /etc/pacman.conf >/dev/null || sed -i "/SigLevel    = Required DatabaseOptional" /etc/pacman.conf

	# Use all cores for compilation.
	sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

	manualinstall $aurhelper || error "Failed to install AUR helper."
	}

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

dialog --title "LABS Installation" --infobox "Finally, installing \`libxft-bgra\` to enable color emoji in suckless software without crashes." 5 70
yes | sudo -u "$name" $aurhelper -S libxft-bgra >/dev/null 2>&1

# Install the dotfiles in the user's home directory


putgitrepo "$dotfilesrepo" "/home/$name" "$repobranch"
putgitrepo "$dotfilesrepo2" "/home/$name" "$repobranch"
rm -f "/home/$name/README.md" "/home/$name/LICENSE" "/home/$name/FUNDING.yml"
# make git ignore deleted LICENSE & README.md files
git update-index --assume-unchanged "/home/$name/README.md"
git update-index --assume-unchanged "/home/$name/LICENSE"

# Most important command! Get rid of the beep!
systembeepoff

# Make zsh the default shell for the user.
chsh -s /bin/zsh $name >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

# dbus UUID must be generated for Artix runit.
dbus-uuidgen > /var/lib/dbus/machine-id

# Block Brave autoupdates just in case. (I don't know if these even exist on Linux, but whatever.)
grep -q "laptop-updates.brave.com" /etc/hosts || echo "0.0.0.0 laptop-updates.brave.com" >> /etc/hosts

# If user chose i3, start i3 on startx by default.
[ "$edition" = "i3" ] && sed -i "s/^ssh-agent dwm/# ssh-agent dwm/;s/^#\s*ssh-agent i3/ssh-agent i3/;s/#\s*export STATUSBAR=\"\?i3blocks\"\?/export STATUSBAR=\"i3blocks\"/" "/home/$name/.xinitrc"

# Start/restart PulseAudio.
killall pulseaudio; sudo -u "$name" pulseaudio --start

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
[ "$distro" = arch ] && newperms "%wheel ALL=(ALL) ALL #LABS
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay,/usr/bin/pacman -Syyuw --noconfirm"

# Last message! Install complete!
finalize
clear