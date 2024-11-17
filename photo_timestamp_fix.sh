#!/bin/bash

# Check if enough arguments are provided
main() {
  parse_arguments "$@"
  init_log
  check_folders
  initialize_statistics
  start_processing
  display_final_statistics
  log_final_statistics
  show_exit_prompt
}

parse_arguments() {
  exclude_patterns=()
  if [ "$#" -lt 2 ]; then
    echo -e "\e[31mUsage: $0 srcfolder destfolder [-l logfile.log] [-e exclude_pattern]... \e[0m"
    echo -e "\e[33mParameters:\e[0m"
    echo -e "  srcfolder          Source directory containing files to process."
    echo -e "  destfolder         Destination directory for processed files."
    echo -e "\e[33mOptions:\e[0m"
    echo -e "  -l logfile.log     Specify a log file to store processing information."
    echo -e "  -e exclude_pattern Exclude files or directories that match the pattern (can be used multiple times)."
    echo -e "\e[33mVariables:\e[0m"
    echo -e "  FIND_OPTS          Specify additional options for the find command (e.g., size limits, excluding specific directories) over the command line variable FIND_OPTS."
    exit 1
  fi

  srcfolder=$1
  destfolder=$2
  logfile=""

  shift 2
  while getopts "l:e:o:" opt; do
    case $opt in
      e)
        exclude_patterns+=($OPTARG)
        ;;
      l)
        logfile=$OPTARG
        ;;
      *)
        echo -e "\e[31mUsage: $0 srcfolder destfolder [-l logfile.log]\e[0m"
        exit 1
        ;;
    esac
  done
}

init_log() {
  if [ -n "$logfile" ]; then
    echo "=========================================" >> "$logfile"
    echo "Processing started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"
    echo "=========================================" >> "$logfile"
  fi
}

check_folders() {
  # Create subdirectories for processed files
  mkdir -p "$destfolder/with_tags"
  mkdir -p "$destfolder/without_tags"
  if [ ! -d "$srcfolder" ]; then
    echo -e "\e[31mSource folder does not exist\e[0m"
    exit 1
  fi
  mkdir -p "$destfolder"
}

initialize_statistics() {
  # Build exclude pattern arguments for find command
  exclude_args=()
  for pattern in "${exclude_patterns[@]}"; do
    exclude_args+=" -not -ipath \"*$pattern*\" "
  done

  files_with_tags=0
  files_without_tags=0
  find_command="find \"$srcfolder\" $FIND_OPTS -type f ${exclude_args[@]} -print"
  if [ -n "$logfile" ]; then
    echo "Find command used for discovering files: $find_command" >> "$logfile"
  fi
  total_files=$(eval $find_command | wc -l)
  if [ -n "$logfile" ]; then
    echo "Total files found: $total_files" >> "$logfile"
  fi
  current_file=0
  declare -gA tag_usage
  declare -gA filetype_count
  tmpfile=$(mktemp)
  trap "rm -f $tmpfile" EXIT

  # Colors for UI
  title_color="\e[33m"
  text_color="\e[37m"
  progress_color="\e[32m"
  box_color="\e[33m"
  header_color="\e[32m"
  reset_color="\e[0m"
}


frame() {
  clear
  echo -e "${box_color}####################################################${reset_color}"
  echo -e "${box_color}#                                                  #${reset_color}"
  echo -e "${header_color}#             Photo Timestamp Fixer                #${reset_color}"
  echo -e "${box_color}#                                                  #${reset_color}"
  echo -e "${box_color}####################################################${reset_color}"
}

show_progress() {
  frame
  echo -e "${progress_color}Processing files... ($current_file/$total_files)${reset_color}"
  progress_percent=$(( (current_file * 100) / total_files ))
  progress_bar=$(printf "[%-50s]" $(eval "printf '='%.0s {1..$(( progress_percent / 2 ))}"))
  echo -e "${progress_color}Progress: ${progress_bar} ${progress_percent}%${reset_color}"

  # Multi-column layout for statistics
  echo -e "${box_color}----------------------------------------------------${reset_color}"
  echo -e "${header_color}Statistics:${reset_color}"
  echo -e "${text_color}Files with tags     : $files_with_tags${reset_color}"
  echo -e "${text_color}Files without tags  : $files_without_tags${reset_color}"
  echo -e "${box_color}----------------------------------------------------${reset_color}"

  # Tag statistics
  if [ ${#tag_usage[@]} -gt 0 ]; then
    echo -e "${header_color}Most used tags:${reset_color}"
    for tag in "${!tag_usage[@]}"; do
      echo -e "${text_color}$tag: ${tag_usage[$tag]}${reset_color}"
    done
  else
    echo -e "${text_color}No tags were found.${reset_color}"
  fi
  echo -e "${box_color}----------------------------------------------------${reset_color}"

  # File types processed
  if [ ${#filetype_count[@]} -gt 0 ]; then
    echo -e "${header_color}File types processed:${reset_color}"
    for ext in "${!filetype_count[@]}"; do
      echo -e "${text_color}$ext: ${filetype_count[$ext]}${reset_color}"
    done
  else
    echo -e "${text_color}No files were processed.${reset_color}"
  fi
  echo -e "${box_color}----------------------------------------------------${reset_color}"

  # Last processed files
  echo -e "${header_color}Last processed files:${reset_color}"
  tail -n 10 "$tmpfile"
  echo -e "${box_color}----------------------------------------------------${reset_color}"
}

start_processing() {
  # Build exclude pattern arguments for find command
  exclude_args=()
  for pattern in "${exclude_patterns[@]}"; do
    exclude_args+=" -not -ipath \"*$pattern*\" "
  done

  find_command="find \"$srcfolder\" $FIND_OPTS -type f ! -iname ".*" ${exclude_args[@]} -print"
  if [ -n "$logfile" ]; then
    echo "Find command used for discovering files: $find_command" >> "$logfile"
  fi
  total_files=$(eval $find_command | wc -l)

  while IFS= read -r file; do
    ((current_file++))

    process_file "$file"
    show_progress
  done < <(eval $find_command)
}


process_file() {
  local file=$1

  extension="${file##*.}"
  ((filetype_count[${extension,,}]++))

  tag_names=$(exiftool -s -SubSecDateTimeOriginal -DateTimeOriginal -SubSecCreateDate -CreationDate -CreateDate -SubSecMediaCreateDate -MediaCreateDate "$file" 2>/dev/null | grep -v '^$' | cut -d':' -f1)

  tag_status=""
  datetime=""
  used_tag="original"
  if [ -z "$tag_names" ]; then
    inode_change_date=$(exiftool -s3 -GPSDateTime "$file" 2>/dev/null)
    used_tag="GPSDateTime"
    if [ -z "$inode_change_date" ]; then
      inode_change_date=$(exiftool -s3 -ModifyDate "$file" 2>/dev/null)
      used_tag="ModifyDate"
    fi
    if [ -z "$inode_change_date" ]; then
      inode_change_date=$(exiftool -s3 -SubSecModifyDate "$file" 2>/dev/null)
      used_tag="SubSecModifyDate"
    fi
    if [ -z "$inode_change_date" ]; then
      inode_change_date=$(exiftool -s3 -GPSDateStamp "$file" 2>/dev/null)
      used_tag="GPSDateStamp"
    fi
    if [ -z "$inode_change_date" ]; then
      inode_change_date=$(exiftool -s3 -FileModifyDate "$file" 2>/dev/null)
      used_tag="FileModifyDate"
    fi

    if [ -n "$inode_change_date" ]; then
      ((files_without_tags++))
      tag_status="Tag added"
      datetime="$inode_change_date"
    else
      tag_status="Tag added"
      datetime="1970-01-01 00:00:01"
    fi
  else
    tag_status="Tag present"
    datetime=$(exiftool -s3 -DateTimeCreated -DateTimeOriginal -CreateDate "$file" 2>/dev/null | head -n 1)
    if [ -n "$datetime" ]; then
      ((files_with_tags++))
      for tag in $tag_names; do
        ((tag_usage[$tag]++))
      done
    fi
  fi

  formatted_datetime=$(echo "$datetime" | sed 's/ /_/g' | sed 's/:/-/g' | sed 's/_/:/3')
  millis=$(date +%s%3N)
  new_filename="${formatted_datetime}.${millis}.${extension}"
  dest_subfolder="$destfolder/with_tags"
  if [ "$tag_status" == "Tag added" ]; then
    dest_subfolder="$destfolder/without_tags"
  fi

  cp "$file" "$dest_subfolder/$new_filename"

  if [ "$tag_status" == "Tag added" ]; then
    exiftool -overwrite_original -SubSecCreateDate="$datetime" -P "$dest_subfolder/$new_filename"
  fi

  output_line="$(date '+%b %d %H:%M:%S') INFO: $file -> $dest_subfolder/$new_filename, EXIF DateTime: $datetime, Status: $tag_status, Used Tag: $used_tag"
  echo "$output_line" >> "$tmpfile"
  if [ -n "$logfile" ]; then
    echo "$output_line" >> "$logfile"
  fi
}

display_final_statistics() {
  frame
  echo -e "${progress_color}Processing completed. Files copied to $destfolder with updated timestamps if needed.${reset_color}"
  echo -e "${text_color}Files with proper tags: $files_with_tags${reset_color}"
  echo -e "${text_color}Files without tags: $files_without_tags${reset_color}"

  # Display most used tags and file types
  echo -e "${box_color}----------------------------------------------------${reset_color}"
  if [ ${#tag_usage[@]} -gt 0 ]; then
    echo -e "${header_color}Most used tags:${reset_color}"
    for tag in "${!tag_usage[@]}"; do
      echo -e "${text_color}$tag: ${tag_usage[$tag]}${reset_color}"
    done
  else
    echo -e "${text_color}No tags were found.${reset_color}"
  fi
  echo -e "${box_color}----------------------------------------------------${reset_color}"

  if [ ${#filetype_count[@]} -gt 0 ]; then
    echo -e "${header_color}File types processed:${reset_color}"
    for ext in "${!filetype_count[@]}"; do
      echo -e "${text_color}$ext: ${filetype_count[$ext]}${reset_color}"
    done
  else
    echo -e "${text_color}No files were processed.${reset_color}"
  fi
  echo -e "${box_color}----------------------------------------------------${reset_color}"
}

show_exit_prompt() {
  # Check if tput is available
  if command -v tput > /dev/null 2>&1; then
    # Centered overlay exit prompt using tput
    cols=$(tput cols)
    rows=$(tput lines)
    msg="Press any key to exit..."
    msg_length=${#msg}
    x=$(( (cols - 38) / 2 ))
    y=$(( (rows / 2) - 1 ))

    # Move cursor to the calculated position and display the box
    tput cup $y $x
    echo -e "${box_color}####################################${reset_color}"
    tput cup $((y + 1)) $x
    echo -e "${box_color}#${reset_color}            ${text_color}${msg}${reset_color}           ${box_color}#${reset_color}"
    tput cup $((y + 2)) $x
    echo -e "${box_color}####################################${reset_color}"
    tput cup $((y + 4)) 0
  else
    # Simple exit prompt if tput is not available
    echo -e "${box_color}####################################${reset_color}"
    echo -e "${box_color}#${reset_color} ${text_color}Press any key to exit...${reset_color} ${box_color}#${reset_color}"
    echo -e "${box_color}####################################${reset_color}"
  fi
  read -n 1 -s
}

log_final_statistics() {
  if [ -n "$logfile" ]; then
    echo "=========================================" >> "$logfile"
    echo "Processing completed. Files copied to $destfolder with updated timestamps if needed." >> "$logfile"
    echo "=========================================" >> "$logfile"
    echo "Processing ended: $(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"
    echo "=========================================" >> "$logfile"
    echo "Files with proper tags: $files_with_tags" >> "$logfile"
    echo "Files without tags: $files_without_tags" >> "$logfile"
    echo "Most used tags:" >> "$logfile"
    for tag in "${!tag_usage[@]}"; do
      echo "$tag: ${tag_usage[$tag]}" >> "$logfile"
    done
    echo "File types processed:" >> "$logfile"
    for ext in "${!filetype_count[@]}"; do
      echo "$ext: ${filetype_count[$ext]}" >> "$logfile"
    done
  fi
}

# Run the main function
main "$@"
