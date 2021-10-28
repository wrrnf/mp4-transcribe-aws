#!/bin/bash
set -e
#
# mp4-transcribe
# warrenf 2018-03-31 Added help, strip video with ffmpeg

# cdukes 2021-10-28:
# * Added wait for transcribe complete
# * After transcribe complete, download the file
# * Added command line options with defaults
# * Added check for prerequisite tools (jq, ffmpeg, aws cli)

command -v jq >/dev/null 2>&1 || { echo >&2 "'jq' is not installed, please install it first."; exit 1; }
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "'ffmpeg' is not installed, please install it first."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo >&2 "missing 'aws' cli, please install it first."; exit 1; }

# Script configuration
version="$(basename "$0") v2021-10-28"
timestamp=$(date -u +"%Y%m%dT%H%M%SZ")

usage() {
  echo -en "Usage:\n"
  echo -en "$(basename $0) [-h] [-i video_file] [-r region] [-l en-US] [-b mys3bucket]\n"
  echo -en "  -h   This help\n"
  echo -en "  -i   MP4 video file to use       Required\n"
  echo -en "  -b   Destination s3 bucket name  Required\n"
  echo -en "  -r   Region to use               Default: us-east-1\n"
  echo -en "  -l   Language code to use        Default: en-US\n"
  exit 0
}

while getopts ":hi:o:r:l:b:" option; do
  case "$option" in
    h) echo "$usage"
      exit 0
      ;;
    i) video_file=$OPTARG
      ;;
    r) region_name=$OPTARG
      ;;
    l) language_code=$OPTARG
      ;;
    b) bucket_path=$OPTARG
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

#check for required params:
required_vars=(video_file bucket_path)
missing_vars=()
for i in "${required_vars[@]}"
do
  test -n "${!i:+y}" || missing_vars+=("$i")
done
if [ ${#missing_vars[@]} -ne 0 ]
then
  echo
  echo -e "\033[0;31m"
  echo "Missing required command line variables:" >&2
  printf ' %q\n' "${missing_vars[@]}" >&2
  echo -e "\033[0m"
  usage
  exit 1
fi

# Transcribe API configuration
# use defaults if not set:
language_code="${language_code:=en-US}"
job_name="mp4-transcribe-${USER}-$timestamp"
region_name="${region_name:=us-east-1}"
endpoint_uri="https://transcribe.$region_name.amazonaws.com"
sample_rate="16000"
media_format="mp3"
bucket_link="s3.amazonaws.com"

[[ -f "$video_file" ]] || { echo "Video file $video_file not found"; exit 1; }

# Set filenames for the audio and transcription files
base_file=${video_file%.*}
audio_file=$base_file.mp3
job_name=$job_name-$(basename $base_file)

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

audio_path=$(dirname $audio_file)
audio_file=$(basename $audio_file)
count=`aws s3 ls s3://$bucket_path | grep $audio_file | wc -l`
if [ $count -gt 0 ]; then
  printf "Copied audio file to S3 bucket:       s3://%s\n" "$bucket_path"
else
  echo "error: audio file not uploaded to S3 bucket"
  exit -2
fi
rm $audio_path/$audio_file

# Create transcribe JSON request
transcription_request="{
\"TranscriptionJobName\": \"$job_name\",
\"LanguageCode\": \"$language_code\",
\"MediaFormat\": \"$media_format\",
\"Media\": {
\"MediaFileUri\": \"https://$bucket_link/$bucket_path/$audio_file\"
}
}"

echo "$transcription_request" > "$job_name-request.json"
echo "Starting transcription job:"
jq . $job_name-request.json

# Start transcription job
aws transcribe start-transcription-job \
  --endpoint-url $endpoint_uri \
  --region $region_name \
  --cli-input-json file://$job_name-request.json


getStatus () {
  status="$(aws transcribe get-transcription-job --transcription-job-name $job_name | jq -r '.TranscriptionJob.TranscriptionJobStatus')"
  while [ "$status" != "COMPLETED" ]; do
    echo "Waiting 30 seconds for transcription to complete"
    sleep 30
    status="$(aws transcribe get-transcription-job --transcription-job-name $job_name | jq -r '.TranscriptionJob.TranscriptionJobStatus')"
  done
}

getStatus

curl -s $(aws transcribe get-transcription-job --transcription-job-name $job_name | jq -r '.TranscriptionJob.Transcript.TranscriptFileUri') | jq '.results.transcripts[0].transcript' --raw-output > "$base_file.txt"

echo "File saved as $base_file.txt"
