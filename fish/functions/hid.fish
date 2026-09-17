function hid --wraps='sudo chmod 666 /dev/hidraw*' --description 'alias hid=sudo chmod 666 /dev/hidraw*'
    sudo chmod 666 /dev/hidraw* $argv
end
