# Photo Timestamp Fix Script

This repository contains a Bash script designed to help prepare media files for importing into the [Immich](https://github.com/alextran1502/immich) photo management app. The script addresses issues where image files do not have proper EXIF date and time information, which can prevent Immich from importing them correctly. This workaround uses the file's inode change date to populate the missing EXIF tags and ensures that every image has an appropriate timestamp.

## Features

- **Adds Missing EXIF Date Information**: If an image lacks key date and time metadata (such as `DateTimeOriginal` or `CreateDate`), the script uses the file's inode change date (`FileInodeChangeDate`) to set the `DateTimeCreated` EXIF tag.
- **Non-destructive Operation**: The original files are not modified. Instead, they are copied to a specified destination folder with corrected EXIF information.
- **Renames Files with Timestamp**: Each copied file is renamed based on its EXIF date information in the format `YYYY-MM-DD_HH:mm:ss.millis.ext`. This helps ensure unique filenames even for images with identical timestamps.

## Why Use This Script?

This script addresses the issue discussed in the Immich community: [Missing DateTime EXIF data causing import problems](https://github.com/immich-app/immich/discussions/7654).

Immich has trouble handling image files that do not include the correct date and time in their EXIF metadata. This script provides a solution by ensuring that every file has a valid `DateTimeCreated` tag, using the inode change date as a fallback. Additionally, it keeps the original files untouched and prepares a set of copies that are ready for importing into Immich.

## Usage

```bash
./photo_timestamp_fix.sh srcfolder destfolder [ -l logfile ] [ -e exclude ]
```

- `srcfolder`: The source directory containing the image files to be processed.
- `destfolder`: The destination directory where the processed image files will be copied.
- `logfile`: Specify the name of a logfile, where the conversion report shall be stored.
- `exclude`: Exclude a specific pattern (case insensitive), can be used multiple times.

### Example

```bash
./photo_timestamp_fix.sh /path/to/source /path/to/destination  -l datefix.log -e thumbnail -e eaDir
```

This command will:
- Search the `srcfolder` directory and all subdirectories for files.
- Use `exiftool` to check for existing date tags. If none are found, it will use the inode change date (`FileInodeChangeDate`) to create a `DateTimeCreated` tag.
- Copy each file to the `destfolder` with the new name format `YYYY-MM-DD_HH:mm:ss.millis.ext`.

## Dependencies

- **exiftool**: The script requires `exiftool` to read and modify the metadata of image files. You can install `exiftool` using:
  - Debian/Ubuntu: `sudo apt-get install libimage-exiftool-perl`
  - macOS (using Homebrew): `brew install exiftool`

## Notes

- The script only processes files that are missing specific date metadata tags (`SubSecDateTimeOriginal`, `DateTimeOriginal`, `CreateDate`, etc.). If a file already has these tags, it will not modify the EXIF data.
- The `SubSecCreateDate` tag is added to the copied version of the image in the `destfolder`, leaving the original file untouched.
- The output will show each processed file in the format: `original filename -> new filename`, along with EXIF date information.

## License

This project is licensed under the GPL v3 License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Special thanks to the Immich community for providing inspiration for this workaround to improve import accuracy and maintain a better-organized photo library.
