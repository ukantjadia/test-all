#!/bin/bash  
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

echoerr() { echo "Error: $1" >&2; }

ghost_blog_install() {

# Check operating system
os_type="$(lsb_release -si 2>/dev/null)"
os_vers="$(lsb_release -sr 2>/dev/null)"
if [ -z "$os_type" ]; then
  [ -f /etc/os-release  ] && os_type="$(. /etc/os-release  && printf '%s' "$ID")"
  [ -f /etc/os-release  ] && os_vers="$(. /etc/os-release  && printf '%s' "$VERSION_ID")"
  [ -f /etc/lsb-release ] && os_type="$(. /etc/lsb-release && printf '%s' "$DISTRIB_ID")"
  [ -f /etc/lsb-release ] && os_vers="$(. /etc/lsb-release && printf '%s' "$DISTRIB_RELEASE")"
  [ "$os_type" = "debian" ] && os_type=Debian
  [ "$os_type" = "ubuntu" ] && os_type=Ubuntu
fi
if [ "$os_type" = "Ubuntu" ]; then
  if [ "$os_vers" != "16.04" ] && [ "$os_vers" != "14.04" ]; then
    echoerr "This script only supports Ubuntu 16.04 and 14.04."
    exit 1
  fi
elif [ "$os_type" = "Debian" ]; then
  os_vers="$(sed 's/\..*//' /etc/debian_version 2>/dev/null)"
  if [ "$os_vers" != "8" ] && [ "$os_vers" != "9" ]; then
    echoerr "This script only supports Debian 9 and 8."
    exit 1
  fi
else
  if [ ! -f /etc/redhat-release ]; then
    echoerr "This script only supports Ubuntu, Debian and CentOS."
    exit 1
  elif ! grep -qs -e "release 6" -e "release 7" /etc/redhat-release; then
    echoerr "This script only supports CentOS 7 and 6."
    exit 1
  fi
  os_type="CentOS"
fi

# Check for root permission
if [ "$(id -u)" != 0 ]; then
  echoerr "Script must be run as root. Try 'sudo bash $0'"
  exit 1
fi
}



read -r -p "Confirm and proceed with the install? [y/N] " response
case $response in
  [yY][eE][sS]|[yY])
    echo
    echo "Please be patient. Setup is continuing..."
    echo
    ;;
  *)
    echo "Aborting."
    exit 1
    ;;
esac

BLOG_FQDN=$1

# Create and change to working dir
mkdir -p /opt/nginx
cd /opt/nginx || exit 1

if [ "$os_type" = "CentOS" ]; then

  # Add the EPEL repository
  yum -y install epel-release || { echoerr "Cannot add EPEL repo."; exit 1; }

  # We need some more software
  yum --enablerepo=epel -y install unzip gcc gcc-c++ make openssl-devel \
    wget curl sudo libtool autoconf || { echoerr "'yum install' failed."; exit 1; }
else

  # Update package index
  export DEBIAN_FRONTEND=noninteractive
  apt-get -yq update || { echoerr "'apt-get update' failed."; exit 1; }

  # We need some more software
  apt-get -yq install unzip  \
    build-essential apache2-dev libxml2-dev wget curl sudo \
    libcurl4-openssl-dev libssl-dev  \
    libtool autoconf || { echoerr "'apt-get install' failed."; exit 1; }

fi

# Insert required IPTables rules
if ! iptables -C INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null; then
  iptables -I INPUT -p tcp --dport 80 -j ACCEPT
fi
if ! iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null; then
  iptables -I INPUT -p tcp --dport 443 -j ACCEPT
fi

# Next, we need to install Node.js.
# Ref: https://github.com/nodesource/distributions
if [ "$ghost_num" = "1" ] || [ ! -f /usr/bin/node ]; then
  if [ "$os_type" = "CentOS" ]; then
    curl -sL https://rpm.nodesource.com/setup_6.x | bash -
    sed -i '/gpgkey/a exclude=nodejs' /etc/yum.repos.d/epel.repo
    yum -y --disablerepo=epel install nodejs || { echoerr "Failed to install 'nodejs'."; exit 1; }
  else
    curl -sL https://deb.nodesource.com/setup_6.x | bash -
    apt-get -yq install nodejs || { echoerr "Failed to install 'nodejs'."; exit 1; }
  fi
fi

# To keep your Ghost blog running, install "forever".
npm install forever -g

# Create a user to run Ghost:
mkdir -p /var/www
useradd -d "/var/www/$BLOG_FQDN" -m -s /bin/false "$ghost_user"

# Stop running Ghost blog processes, if any.
su - "$ghost_user" -s /bin/bash -c "forever stopall"

# Create temporary swap file to prevent out of memory errors during install
# Do not create if OpenVZ VPS
swap_tmp="/tmp/swapfile_temp.tmp"
if [ ! -f /proc/user_beancounters ]; then
  echo
  echo "Creating temporary swap file, please wait ..."
  echo
  dd if=/dev/zero of="$swap_tmp" bs=1M count=512 2>/dev/null || /bin/rm -f "$swap_tmp"
  chmod 600 "$swap_tmp" && mkswap "$swap_tmp" &>/dev/null && swapon "$swap_tmp"
fi

# Switch to Ghost blog user. We use a "here document" to run multiple commands as this user.
