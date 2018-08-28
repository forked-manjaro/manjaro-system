err() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    RED="${BOLD}\e[1;31m"
	local mesg=$1; shift
	printf "${RED}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    GREEN="${BOLD}\e[1;32m"
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

check_pkgs()
{
	local remove=""

    for pkg in ${packages} ; do
        for rmpkg in $(pacman -Qq | grep ${pkg}) ; do
            if [ "${pkg}" == "${rmpkg}" ] ; then
               removepkgs="${removepkgs} ${rmpkg}"
            fi
        done
    done

    packages="${removepkgs}"
}

detectDE()
{
    if [ x"$KDE_FULL_SESSION" = x"true" ]; then DE=kde;
    elif [ x"$GNOME_DESKTOP_SESSION_ID" != x"" ]; then DE=gnome;
    elif `dbus-send --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.GetNameOwner string:org.gnome.SessionManager > /dev/null 2>&1` ; then DE=gnome;
    elif xprop -root _DT_SAVE_MODE 2> /dev/null | grep ' = \"xfce4\"$' >/dev/null 2>&1; then DE=xfce;
    elif [ x"$DESKTOP_SESSION" = x"LXDE" ]; then DE=lxde;
    else DE=""
    fi
}

post_upgrade() {
	# Fix libutf8proc upgrading
	if [ "$(pacman -Qq libutf8proc)" == "libutf8proc" ]; then
		if [ "$(vercmp $(pacman -Q libutf8proc | cut -d' ' -f2) 2.1.1-3)" -le 0 ]; then
			if [ -e "/usr/lib/libutf8proc.so.2" ]; then
				msg "Fix libutf8proc upgrade ..."
				rm -f /usr/lib/libutf8proc.so.2
				rm /var/lib/pacman/db.lck &> /dev/null
				pacman --noconfirm -S libutf8proc
			fi
		fi
	fi

	# nvidia legacy changes (may 2018)
	if [ "$(pacman -Qq nvidia-utils)" == "nvidia-utils" ]; then
		if [ "$(pacman -Qq mhwd-nvidia-390xx)" != "mhwd-nvidia-390xx" ]; then
			msg "Updating mhwd database"
			rm /var/lib/pacman/db.lck &> /dev/null
			pacman --noconfirm -S mhwd-db
		fi
		if [[ -z "$(mhwd | grep " video-nvidia ")" && -n "$(mhwd-gpu | grep nvidia)" ]]; then
			msg "Maintaining video driver at version nvidia-390xx"
			rm /var/lib/pacman/db.lck &> /dev/null
			pacman --noconfirm -Rdd $(pacman -Qq | grep nvidia | grep -v mhwd | grep -v toolkit)
			pacman --noconfirm -S $($(pacman -Qq | grep nvidia | grep -v mhwd | grep -v toolkit) \
			| sed 's|nvidia|nvidia-390xx|g')
			rm -r /var/lib/mhwd/local/pci/video-nvidia/
			cp -a /var/lib/mhwd/db/pci/graphic_drivers/nvidia-390xx/ /var/lib/mhwd/local/pci/
		fi
	fi

	# Fix config issue in sddm.conf
	if [ "$(vercmp $2 20180513)" -eq 0 ] && \
		[ -e "/etc/sddm.conf" ]; then
		msg "Fix default path config issue in sddm.conf ..."
		cp /etc/sddm.conf /etc/sddm.conf.pacsave
		sed -i -e 's|^.*DefaultPath.*|DefaultPath=/usr/local/sbin:/usr/local/bin:/usr/bin|' /etc/sddm.conf
	fi

	# Fix js52 upgrading
	if [ "$(pacman -Qq js52)" == "js52" ]; then
		if [ "$(vercmp $(pacman -Q js52 | cut -d' ' -f2) 52.7.3-1)" -le 0 ]; then
			if [ -e "/usr/lib/libmozjs-52.so.0" ]; then
				msg "Fix js52 upgrade ..."
				rm -f /usr/lib/libmozjs-52.so.0
				rm /var/lib/pacman/db.lck &> /dev/null
				pacman --noconfirm -S js52
			fi
		fi
	fi

	# Fix Firefox upgrading
	if [ "$(pacman -Qq firefox)" == "firefox" ]; then
		if [ "$(vercmp $(pacman -Q firefox | cut -d' ' -f2) 59.0.1-0)" -le 0 ]; then
			if [ -e "/usr/lib/firefox/distribution/distribution.ini" ]; then
				msg "Fix firefox upgrade ..."
				rm -f /usr/lib/firefox/distribution/distribution.ini
			fi
		fi
	fi

	# Fix upgrading sddm version is 0.17.0-4 or less
	if [ "$(pacman -Qq sddm)" == "sddm" ]; then 
		if [ "$(vercmp $(pacman -Q sddm | cut -d' ' -f2) 0.17.0-4)" -le 0 ]; then
			msg "Fix sddm upgrade ..."
			rm /var/lib/pacman/db.lck &> /dev/null
			if [ -e "/etc/sddm.conf" ]; then
				mv /etc/sddm.conf /etc/sddm.backup
			fi
			pacman --noconfirm -S sddm
			if [ -e "/etc/sddm.conf" ]; then
				mv /etc/sddm.conf /etc/sddm.conf.pacnew
			fi
			if [ -e "/etc/sddm.backup" ]; then
				mv /etc/sddm.backup /etc/sddm.conf
			fi
		fi
	fi

	# fix upgrading ca-certificates-utils when version is 20160507-1 or less
	if [ "$(pacman -Qq ca-certificates-utils)" == "ca-certificates-utils" ]; then 
		if [ "$(vercmp $(pacman -Q ca-certificates-utils | cut -d' ' -f2) 20160507-1)" -le 0 ]; then
			msg "Fix ca-certificates-utils upgrade ..."
			rm /var/lib/pacman/db.lck &> /dev/null
			pacman --noconfirm -Syw ca-certificates-utils
			rm /etc/ssl/certs/ca-certificates.crt &> /dev/null
			pacman --noconfirm -S ca-certificates-utils
		fi
	fi

	# fix issue with xorg-server
	if [ -L "/usr/lib/xorg/modules/extensions/libglx.xorg" ]; then
		msg "Removing depreciated libglx.so symlink ..."
		rm /usr/lib/xorg/modules/extensions/libglx.so &> /dev/null
	fi

	# fix upgrading mesa when version is 17.0.1-1 or less
	if [ "$(pacman -Qq mesa)" == "mesa" ]; then 
		if [ "$(vercmp $(pacman -Q mesa | cut -d' ' -f2) 17.0.1-1)" -le 0 ]; then
			PKG_LIST="mhwd mesa libglvnd"
			if [ "$(pacman -Qq lib32-mesa)" == "lib32-mesa" ]; then
				if [ "$(vercmp $(pacman -Q lib32-mesa | cut -d' ' -f2) 17.0.1-1)" -le 0 ]; then
					PKG_LIST="${PKG_LIST} lib32-mesa lib32-libglvnd"
				fi
			fi
			msg "Fix mesa-stack ..."
			rm /var/lib/pacman/db.lck &> /dev/null
			pacman --noconfirm -S $PKG_LIST --force
		fi
	fi

	# avoid upgrading problems when lib32-libnm-glib46 is installed 
	# and lib32-libnm-glib is not, and we want to install lib32-libnm-glib.
	# ldconfig creates varous symlink in /usr/lib32/ from the lib32-libnm-glib46
	# packages but lib32-libnm-glib provides those files.
	if [ "$(pacman -Qq lib32-libnm-glib)" != "lib32-libnm-glib" ]; then
		if [ "$(pacman -Qq lib32-libnm-glib46)" == "lib32-libnm-glib46" ]; then
			rm /var/lib/pacman/db.lck &> /dev/null
			pacman --noconfirm --force -S lib32-libnm-glib
		fi
	fi

	# avoid upgrading problems when lib32-libcurl-{gnutls,compat} is
	# installed and lib32-curl is not, and we want to install lib32-curl.
	# ldconfig creates /usr/lib32/libcurl.so.4 from the lib32-libcurl-{gnutls,compat}
	# packages but lib32-curl provides that file.
	if [ "$(pacman -Qq lib32-curl)" != "lib32-curl" ]; then
		if [ "$(pacman -Qq lib32-libcurl-gnutls)" == "lib32-libcurl-gnutls" ]; then
			if [ "$(vercmp $(pacman -Q lib32-libcurl-gnutls | cut -d' ' -f2) 7.52.1-1)" -le 0 ]; then
				rm /var/lib/pacman/db.lck &> /dev/null
				pacman --noconfirm --force -S lib32-curl
			fi
		fi
		if [ "$(pacman -Qq lib32-libcurl-compat)" == "lib32-libcurl-compat" ]; then 
			if [ "$(vercmp $(pacman -Q lib32-libcurl-compat | cut -d' ' -f2) 7.52.1-1)" -le 0 ]; then
				rm /var/lib/pacman/db.lck &> /dev/null
				pacman --noconfirm --force -S lib32-curl
			fi
		fi
	fi

	# fix upgrading ttf-dejavu when version is 2.35-1 or less
	if [ "$(pacman -Qq ttf-dejavu)" == "ttf-dejavu" ]; then 
		if [ "$(vercmp $(pacman -Q ttf-dejavu | cut -d' ' -f2) 2.35-1)" -le 0 ]; then
			msg "Fix ttf-dejavu upgrade ..."
			rm /var/lib/pacman/db.lck &> /dev/null
			pacman --noconfirm --force -S ttf-dejavu
		fi
	fi
	
	# fix xfprogs version
	export LANG=C
	if [[ -n $(pacman -Qi xfsprogs | grep Version | grep 1:3) ]]; then
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm -S xfsprogs
	fi
}
