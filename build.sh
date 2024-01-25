#!/bin/bash
cd ~
export LC_ALL=C
wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip
unzip platform-tools-latest-linux.zip -d ~
echo '
# add Android SDK platform tools to path
if [ -d "$HOME/platform-tools" ] ; then
    PATH="$HOME/platform-tools:$PATH"
fi
' >> ~/.profile
source ~/.profile
sudo apt install bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick lib32readline-dev lib32z1-dev libelf-dev liblz4-tool libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev

# Get the ID of the current Linux distribution
DISTRO_ID=$(lsb_release -is)

# Check if the distribution is Ubuntu
if [[ $DISTRO_ID != "Ubuntu" ]]; then
    echo "This script is intended for Ubuntu distributions. Skipping..."
else
    # Get the version of Ubuntu
    UBUNTU_VERSION=$(lsb_release -rs)

    # Check the version and install accordingly
    if [[ $UBUNTU_VERSION == "23.10" ]]; then
        wget http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.4-2_amd64.deb && sudo dpkg -i libtinfo5_6.4-2_amd64.deb && rm -f libtinfo5_6.4-2_amd64.deb
        wget http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.4-2_amd64.deb && sudo dpkg -i libncurses5_6.4-2_amd64.deb && rm -f libncurses5_6.4-2_amd64.deb
    elif [[ $UBUNTU_VERSION < "23.10" ]]; then
        sudo apt-get install lib32ncurses5-dev libncurses5 libncurses5-dev
        if [[ $UBUNTU_VERSION < "20.04" ]]; then
            sudo apt-get install libwxgtk3.0-dev
        fi
        if [[ $UBUNTU_VERSION < "16.04" ]]; then
            sudo apt-get install libwxgtk2.8-dev
        fi
    else
        echo "Unsupported Ubuntu version"
    fi
fi

sudo apt install python-is-python3

mkdir -p ~/bin
mkdir -p ~/android/lineage

curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo

git config --global user.email "you@example.com"
git config --global user.name "Your Name"

git lfs install

git config --global trailer.changeid.key "Change-Id"

sudo apt-get install repo

cd ~/android/lineage
echo "y" | repo init -u https://github.com/LineageOS/android.git -b cm-14.1

source ~/.profile

# START THE DOWNLOAD
repo sync

source build/envsetup.sh
breakfast gtelwifiue

# Define the path to the LineageOS zip file
ZIP_FILE="lineage-*.zip"

# Function to determine the type of OTA update
determine_ota_type() {
    local zip_file=$1
    if zipinfo -1 $zip_file | grep -q "^system/$"; then
        echo "file-based"
    elif zipinfo -1 $zip_file | grep -q "^payload.bin$"; then
        echo "payload-based"
    else
        echo "block-based"
    fi
}

# Determine the type of OTA update
TYPE=$(determine_ota_type $ZIP_FILE)

# Create a temporary directory to extract the content of the zip and move there
mkdir ~/android/system_dump/
cd ~/android/system_dump/

# Depending on the type of OTA update, perform the appropriate extraction steps
case $TYPE in
 "block-based")
    mkdir ~/android/system_dump/
    cd ~/android/system_dump/
    unzip ~/android/lineage/lineage-*.zip system.transfer.list system.new.dat* 
    if [[ -e vendor.transfer.list ]] && [[ -e vendor.new.dat.br ]]; then
        unzip ~/android/lineage/lineage-*.zip vendor.transfer.list vendor.new.dat*
    fi
    if [[ -e system.new.dat.br ]]; then
        brotli --decompress --output=system.new.dat system.new.dat.br
    fi
    if [[ -e vendor.new.dat.br ]]; then
        brotli --decompress --output=vendor.new.dat vendor.new.dat.br
    fi
    python sdat2img/sdat2img.py system.transfer.list system.new.dat system.img
    if [[ -e vendor.new.dat ]]; then
        python sdat2img/sdat2img.py vendor.transfer.list vendor.new.dat vendor.img
    fi
    mkdir system/
    sudo mount system.img system/
    if [[ -e vendor.img ]]; then
        sudo rm system/vendor
        sudo mkdir system/vendor
        sudo mount vendor.img system/vendor/
    fi
    ;;
 "file-based")
    mkdir ~/android/system_dump/
    cd ~/android/system_dump/
    unzip ~/android/lineage/lineage-*.zip system/*
    ;;
 "payload-based")
    mkdir ~/android/system_dump/
    cd ~/android/system_dump/
    sudo apt-get install python3-protobuf
    git clone https://github.com/LineageOS/android_tools_extract-utils android/tools/extract-utils
    git clone https://github.com/LineageOS/android_system_update_engine android/system/update_engine
    python3 android/tools/extract-utils/extract_ota.py ~/android/lineage/lineage-*.zip
    mkdir system/
    sudo mount -o ro system.img system/
    sudo mount -o ro vendor.img system/vendor/
    sudo mount -o ro odm.img system/odm/
    sudo mount -o ro product.img system/product/
    sudo mount -o ro system_ext.img system/system_ext/
    ;;
esac


# After extraction, run extract-files.sh
./extract-files.sh ~/android/system_dump/

# Clean up after extraction
rm -rf ~/android/system_dump/

cd ~/android/lineage

croot
brunch gtelwifiue
