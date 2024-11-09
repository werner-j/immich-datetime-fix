#!/bin/bash

# Check if enough arguments are provided
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 srcfolder destfolder"
  exit 1
fi

# Assign arguments to variables
srcfolder=$1
destfolder=$2

# Check if srcfolder exists
if [ ! -d "$srcfolder" ]; then
  echo "Source folder does not exist"
  exit 1
fi

# Create destfolder if it doesn't exist
mkdir -p "$destfolder"

# Loop through all files in srcfolder and its subdirectories
find "$srcfolder" -type f | while read -r file; do
  # Use exiftool to check for the specified tags
  tags_exist=$(exiftool -s3 -SubSecDateTimeOriginal -DateTimeOriginal -SubSecCreateDate -CreationDate -CreateDate -SubSecMediaCreateDate -MediaCreateDate -DateTimeCreated "$file" 2>/dev/null | grep -v '^$')

  # If none of the desired tags are present
  if [ -z "$tags_exist" ]; then
    # Get FileInodeChangeDate
    inode_change_date=$(exiftool -s3 -FileInodeChangeDate "$file" 2>/dev/null)
  fi

  # Get the date and time from the metadata to generate the new filename
  datetime=$(exiftool -s3 -DateTimeCreated -DateTimeOriginal -CreateDate "$file" 2>/dev/null | head -n 1)

  # If datetime is empty, set it to default value "1970-01-01 00:00:01"
  if [ -z "$datetime" ]; then
    datetime="1970-01-01 00:00:01"
  fi

  # Format datetime to "YYYY-MM-DD_HH:mm:ss"
  formatted_datetime=$(echo "$datetime" | sed 's/ /_/g' | sed 's/:/-/g' | sed 's/_/:/3')

  # Get the current system time in milliseconds
  millis=$(date +%s%3N)

  # Generate the new filename based on the metadata date and time with milliseconds
  extension="${file##*.}"
  new_filename="${formatted_datetime}.${millis}.${extension}"

  # Copy the file to destfolder with the new name
  cp "$file" "$destfolder/$new_filename"

  # Add exif information to the copied file if inode_change_date is set
  if [ -z "$tags_exist" ]; then
    exiftool -overwrite_original -DateTimeCreated="$inode_change_date" "$destfolder/$new_filename"
  fi

  # Output original and new filename along with EXIF datetime information in one line
  echo "$(date '+%b %d %H:%M:%S') INFO: $file -> $new_filename, EXIF DateTime: $datetime"
done

echo "Processing completed. Files copied to $destfolder with updated timestamps if needed."
