#!/usr/bin/bash

print_log() {
  echo "$(date +%s) $1" >> "$HOME/.cache/usb.log"
}

[ -f "$HOME/.cache/usb.log" ] || touch "$HOME/.cache/usb.log" &&
  echo "# DEVICE_NAME: EVENT: TARGET: FOUND_DEVICE:APPLYRULE USB_ID" >> "$HOME/.cache/usb.log"

reset_() {
  FOUND_DEVICE=0
  USB_ID=0
  DEVICE_NAME=""
  DEVICE_ID=""
  DEVICE_HASH=""
  DEVICE_SERIAL=""
  APPLY=0
  EVENT=""
  TARGET=""
}
reset_ 

# ask_for_permit $USB_ID $DEVICE_ID $DEVICE_SERIAL $DEVICE_NAME $DEVICE_HASH
ask_for_permit() {
ret_val=$(notify-send --action="opt1=Allow" --action="opt2=Remember" --action="opt3=Ignore" "USB Guard" "Need action for dew device detectd: $4")
case $ret_val in
    "opt1")
        usbguard allow-device "$1" &&
          print_log "ALLOWED DEVICE_NAME:$DEVICE_NAME DEVICE_HASH:$DEVICE_HASH"
        ;;
    "opt2")
        rule="allow id $2 serial \"$3\" name \"$4\" hash \"$5\""
        print_log "ACTION: usbguard append-rule '%s'" "$rule"
        usbguard append-rule "$rule"
        usbguard allow-device "$1" &&
          print_log "ALLOWED DEVICE_NAME:$DEVICE_NAME DEVICE_HASH:$DEVICE_HASH"
        ;;
    "opt3")
        print_log "DEVICE_NAME:$DEVICE_NAME Ignored"
        ;;
esac
}

usbguard watch | while read -r usb_data; do
  case "$usb_data" in
    \[device\]*)
      if echo "$usb_data" | grep "PresenceChanged" > /dev/null; then
        FOUND_DEVICE=1
        USB_ID=$(echo "$usb_data" | awk '{print $3}' | awk --field-separator='=' '{print $2}')
      elif [ $FOUND_DEVICE -gt 0 ] && echo "$usb_data" | grep "PolicyApplied" > /dev/null ; then
        DEVICE_ID_=$(echo "$usb_data" | awk '{print $3}' | awk --field-separator='=' '{print $2}')
        if [ "$USB_ID" -eq "$DEVICE_ID_" ]; then
          APPLY=1
        fi
      fi
      ;;
    event=*)
      if [ $FOUND_DEVICE -gt 0 ]; then
        EVENT=$(echo "$usb_data" | awk --field-separator='=' '{print $2}')
        if [ "$EVENT" == "Remove" ]; then
          reset_
        fi
      fi
      ;;
    target_new=*)
      if [ $FOUND_DEVICE -gt 0 ] && [ $APPLY -gt 0 ] && [ "$USB_ID" -gt 0 ]; then
        TARGET=$(echo "$usb_data" | awk --field-separator='=' '{print $2}')
      fi
      ;;
    device_rule=*)
      if [ $FOUND_DEVICE -gt 0 ] && [ $APPLY -gt 0 ] && [ "$USB_ID" -gt 0 ]; then
        DEVICE_NAME=$(echo "$usb_data" | grep -oP 'name "\K[^"]+')
        DEVICE_ID=$(echo "$usb_data" | grep -oP 'id \K[^ ]+')
        DEVICE_HASH=$(echo "$usb_data" | grep -oP ' hash "\K[^"]+')
        DEVICE_SERIAL=$(echo "$usb_data" | grep -oP 'serial "\K[^"]+')
        if [ "$TARGET" == "block" ]; then
          print_log "DEVICE_NAME:$DEVICE_NAME EVENT:$EVENT TARGET:$TARGET  $FOUND_DEVICE:$APPLY $USB_ID"
          ask_for_permit "$USB_ID" "$DEVICE_ID" "$DEVICE_SERIAL" "$DEVICE_NAME" "$DEVICE_HASH" &
        elif [ "$TARGET" == "allow" ]; then
          print_log "DEVICE_NAME:$DEVICE_NAME EVENT:$EVENT TARGET:$TARGET $FOUND_DEVICE:$APPLY $USB_ID"
          notify-send "USB Guard" "Allowed device connected: $DEVICE_NAME"
        fi
        reset_
      fi
      ;;
    *)
      ;;
  esac
done
