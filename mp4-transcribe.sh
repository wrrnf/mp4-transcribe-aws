#!/bin/bash
#
# mp4-transcribe
# warrenf 2018-03-31 Added help, strip video with ffmpeg

# Script configuration
      version="$(basename "$0") v2018-03-31"
    timestamp=$(date -u +"%Y%m%dT%H%M%SZ")

# Transcribe API configuration
     job_name="mp4-transcribe-warrenf-$timestamp"
  region_name="us-east-1"
 endpoint_uri="https://transcribe.us-east-1.amazonaws.com"
language_code="en-us"
  sample_rate="16000"
 media_format="mp3"
  bucket_link="s3.amazonaws.com"
  bucket_path="mp4-transcribe-warrenf"

# Help usage text
usage="$(basename "$0") [-h] [-i input_video_file]

where:
    -h   show this help text
    -i   the name of the video file to be transcribed, in MP4 format"

# Initialize the names of the input parameters
     video_file=""
     audio_file=""
transcript_file=""

while getopts ":hi:o:" option; do
    case "$option" in
        h) echo "$usage"
           exit 0
           ;;
        i) video_file=$OPTARG
           ;;
        :) printf "missing argument for -%s\n" "$OPTARG" >&2
           echo "$usage" >&2
           exit 1
           ;;
       \?) printf "unknown option: -%s\n" "$OPTARG" >&2
           echo "$usage" >&2
           exit 1
           ;;
    esac
done
shift $((OPTIND-1))

# Keep prompting until the user enters valid parameters
while [ ! -f "$video_file" ]; do
    if [ "$video_file" != "" ]; then
        printf "\nerror: cannot find video file %s\n" "$video_file"
    fi
    read -p "Enter the video file name (e.g. video.mp4): " video_file
done

# Set filenames for the audio and transcription files
 base_file=${video_file%.*}
audio_file=$base_file.mp3
  job_name=$job_name-$base_file

echo $version
echo "Timestamp:                            $timestamp"
echo "Source video file:                    $video_file"

# Extract and convert audio from video source
ffmpeg -hide_banner -loglevel panic -i $video_file -vn -acodec $media_format $audio_file

if [ -f "$audio_file" ]; then
    printf "Extracted and converted audio track:  %s\n" "$audio_file"
else
    echo "error: cannot generate audio file"
    exit -1
fi

# Copy audio file to S3 bucket
aws s3 cp $audio_file s3://$bucket_path

count=`aws s3 ls s3://$bucket_path | grep $audio_file | wc -l`
if [ $count -gt 0 ]; then
    printf "Copied audio file to S3 bucket:       s3://%s\n" "$bucket_path"
else
    echo "error: audio file not uploaded to S3 bucket"
    exit -2
fi
rm $audio_file

# Create transcribe JSON request
transcription_request="{
    \"TranscriptionJobName\": \"$job_name\",
    \"LanguageCode\": \"$language_code\",
    \"MediaFormat\": \"$media_format\",
    \"Media\": {
        \"MediaFileUri\": \"https://$bucket_link/$bucket_path/$audio_file\"
    }
}"

echo $transcription_request > $job_name-request.json
printf "Start transcription job: \n\n"
cat $job_name-request.json | python -mjson.tool

# Start transcription job
aws transcribe start-transcription-job \
    --endpoint-url $endpoint_uri \
    --region $region_name \
    --cli-input-json file://$job_name-request.json
