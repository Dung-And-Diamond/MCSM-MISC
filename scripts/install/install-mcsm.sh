#!/bin/bash

dir=/opt/mcsmanager
node_ver=14
node_install_dir=/snap/bin
mcs_manager_download="https://github.com/MCSManager/MCSManager/releases/latest/download"
mcsm_command_download="https://raw.githubusercontent.com/Dung-And-Diamond/MCSM-MISC/main/scripts/command/mscm-command.sh"
mcs_manager_filename="mcsmanager_linux_release.tar.gz"
service_user_name="mcsm"
service_user_group="minecraft"
user_shell_nologin_path="/usr/bin/nologin"

install_web=true
install_daemon=true

if [ "$(id -u)" -ne 0 ]; then
    echo -e "You need root permissions to execute this script. Please use sudo or switch to the root user."
    exit 1
fi

verify_dependant_tool() {
    #Preping variables
    local tool="${1,,}"
    local install_cmd=''
    case "$tool" in
    "node")
      if $2 &> /dev/null
      then
        # Prepping command for later use, variables should not be expanded here
        # shellcheck disable=SC2016
        install_cmd='snap install $tool --classic --channel=$2'
      else
        echo "Missing desired ${tool} version! skipping..."
      fi
    ;;
    "git" | "tar")
      # Prepping command for later use, variables should not be expanded here
      # shellcheck disable=SC2016
      install_cmd='apt install $tool'
    ;;
    *)
      echo "Tool not expected! Skipping..."
      ;;
    esac

    if test -z "$install_cmd"
    then
        echo "Verifying ${tool} installation..."

        if ! command -v "${tool}" &> /dev/null
        then
          echo "${tool} is missing. Installing ${tool} now..."
          $install_cmd
          if command -v git &> /dev/null
          then
            echo -e "Git could not be installed via apt, exiting...."
            exit 1
          fi
        fi
        echo
    fi
}

verify_service_user() {
  echo "Checking for service user..."
  if ! id -u $service_user_name &> /dev/null
    then
    echo "Service User missing, adding user now..."
    useradd $service_user_name -m --home "/home/$service_user_group" -r -g $service_user_group -s $user_shell_nologin_path
    if id -u $service_user_name &> /dev/null
    then
      echo -e "Service User missing could not be added, exiting...."
      exit 1
    fi
  fi
}

process_variables() {
  while [ $# -ne 0 ]
    do
    case "$1" in
      "--skipWeb" | "-w")
        install_web=false
      ;;
      "--skipDaemon" | "-d")
        install_daemon=false
      ;;
    esac
    shift
  done
}

wget $mcsm_command_download

verify_dependant_tool "node" $node_ver
verify_dependant_tool "git"
verify_dependant_tool "tar"

mkdir $dir

echo
echo
echo "+-------------------------------------------------------------------------+"
echo "| MCSManager Installer                                                    |"
echo "+-------------------------------------------------------------------------+"
echo "| Copyright © 2023 MCSManager.                                            |"
echo "+-------------------------------------------------------------------------+"
echo "| Contributors: Nuomiaa, CreeperKong, Unitwk, FunnyShadow                 |"
echo "|     Install script by KillerOfPie                                       |"
echo "+-------------------------------------------------------------------------+"
echo
echo


echo "[+] Install MCSManager..."

# Stop Service
systemctl stop mcsm-{web,daemon}

echo

# Delete Service
rm -rf /etc/systemd/system/mcsm-daemon.service
rm -rf /etc/systemd/system/mcsm-web.service

echo

systemctl daemon-reload

echo

cd $dir || exit

echo

wget $mcs_manager_download/$mcs_manager_filename

echo

tar -zxf $mcs_manager_filename
rm -rf $mcs_manager_filename

echo

daemon_inst_dir="${dir}/daemon"
web_inst_dir="${dir}/web"

if [ "$install_daemon" == true ]
then
  cd daemon || exit

  echo
  echo "Install MCSManager-Daemon dependencies..."
  npm install --registry=https://registry.npmmirror.com --production > npm_install_log
else
  daemon_inst_dir="-- Skipped --"
  echo "Daemon installation disabled, skipping..."
fi

echo


if [ "$install_web" == true ]
then
  cd ../web || exit

  echo
  echo "Install MCSManager-Web dependencies..."
  npm install --registry=https://registry.npmmirror.com --production > npm_install_log
else
  web_inst_dir="-- Skipped --"
  echo "Web installation disabled, skipping..."
fi
echo

echo
echo "================ MCSManager ==============="
echo "Daemon: ${daemon_inst_dir}"
echo "Web: ${web_inst_dir}"
echo "================ MCSManager ==============="
echo

sleep 3

echo "[+] Creating Services..."
echo

sys_ctl_daemon="enable"
sys_ctl_web="enable"

if [ "$install_daemon" == true ]
then
  echo "Creating MCSManager Daemon service..."
  echo "
  [Unit]
  Description=MCSManager Daemon

  [Service]
  WorkingDirectory=/opt/mcsmanager/daemon
  ExecStart=${node_install_dir}/node app.js
  User=${service_user_name}
  Group=${service_user_group}
  ExecReload=/bin/kill -s QUIT $MAINPID
  ExecStop=/bin/kill -s QUIT $MAINPID
  Environment=\"PATH=${PATH}\"

  [Install]
  WantedBy=multi-user.target
  " > /etc/systemd/system/mcsm-daemon.service
else
  sys_ctl_daemon="disable"
  echo "Daemon installation disabled, skipping..."
fi
  
echo

if [ "$install_web" == true ]
then
  echo "Creating MCSManager Web service..."
  echo "
  [Unit]
  Description=MCSManager Web

  [Service]
  WorkingDirectory=/opt/mcsmanager/web
  ExecStart=${node_install_dir}/node app.js
  User=${service_user_name}
  Group=${service_user_group}
  ExecReload=/bin/kill -s QUIT $MAINPID
  ExecStop=/bin/kill -s QUIT $MAINPID
  Environment=\"PATH=${PATH}\"

  [Install]
  WantedBy=multi-user.target
  " > /etc/systemd/system/mcsm-web.service
else
  sys_ctl_web="disable"
  echo "Web installation disabled, skipping..."
fi

echo

systemctl daemon-reload
systemctl ${sys_ctl_daemon} mcsm-daemon.service --now
systemctl ${sys_ctl_web} mcsm-web.service --now

#Create command scripts for common commands
script_dir="/usr/local/bin/mcsmanager"
script_file="${script_dir}/mcsm"
script_link="/usr/local/bin/mcsm"

cd "$(dirname "$0")" || exit

mkdir "${script_dir}"
rm -f $script_file
cp -f mcsm-command.sh $script_file

if [ -s $script_file ]; then
        # The file is not-empty.
        echo "Command script installed!"
else
        # The file is empty.
        echo "Command script installation failed!"
fi

chown -R $service_user_name:$service_user_group $dir
chmod -R ug=rwx ${dir}

chmod +x ${script_file}

if ! test -f ${script_link}; then
 echo "Sym-Link doesn't exist, creating..."
  ln -s ${script_file} ${script_link}
else
  echo "Sym-Link already exists skipping creation."
fi

sleep 3

echo "=================================================================="
echo "The installation is complete! Welcome to use the MCSManager panel!"
echo " "
echo "Control panel address: "
echo "http://server.ip:23333"
echo "You must open ports 23333 (Panel) and 24444 (Daemon). The control panel requires these two ports to work properly."
echo " "
echo "The following are some commonly used commands:"
echo "mcsm panel start"
echo "mcsm panel stop"
echo "mcsm panel restart"
echo "mcsm panel status"
echo "mcsm panel update"
echo " "
echo "Official documentation (must read): https://docs.mcsmanager.com/"
echo "=================================================================="