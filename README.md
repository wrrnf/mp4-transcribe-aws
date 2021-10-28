# mp4-transcribe

## Purpose
Command–line utility to create an AWS transcription job from a video file.

## Compatibility
This script has been tested on Mac OS 11.5.1 (Big Sur) with the following utilities installed. Here are the high-level system configuration steps:

1. Install the [Homebrew package manager](https://brew.sh).
2. Run `brew install ffmpeg`.
3. Run `brew install awscli`.
4. Run `brew install jq`.

## How to install this script
The script uses an S3 bucket to store the extracted audio track from the video file. Create a bucket and update the configuration settings in the `mp4-transcribe.sh` script.

1. Sign up for the [AWS Transcribe Preview](https://pages.awscloud.com/amazon-transcribe-preview.html) program.
2. Create an S3 bucket to store to-be-transcribed audio files.
   1. Run `aws s3 mb s3://mybucket --region us-east-1`, where **mybucket** is an unique bucket name.
3. Create a local clone of this repository (or just download the script)

## How to use this script
1. Run `./mp4-transcribe.sh -i <video_file_name> -b <bucket_name>`, where `video_file_name` is your source video file and `<bucket_name>` is the name of the bucket you created above.
2. Open the AWS console to see the current progress of the transcription.

```
Usage:
mp4-transcribe.sh [-h] [-i video_file] [-r region] [-l en-US] [-b mys3bucket]
  -h   This help
  -i   MP4 video file to use       Required
  -b   Destination s3 bucket name  Required
  -r   Region to use               Default: us-east-1
  -l   Language code to use        Default: en-US
```

## License
Review the [license](LICENSE) before you clone this repository.
