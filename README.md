# mp4-transcribe

## Purpose
Command–line utility to create an AWS transcription job from a video file.

## Compatibility
This script has been tested on Mac OS 10.13 (High Sierra) with the following utilities installed. Here are the high-level system configuration steps:

1. Install the [Homebrew package manager](https://brew.sh).
2. Run `brew install ffmpeg`.
3. Run `brew install awscli`.

## How to install this script
The script uses an S3 bucket to store the extracted audio track from the video file. Create a bucket and update the configuration settings in the `mp4-transcribe.sh` script.

1. Sign up for the [AWS Transcribe Preview](https://pages.awscloud.com/amazon-transcribe-preview.html) program.
2. Create an S3 bucket to store to-be-transcribed audio files.
   1. Run `aws s3 mb s3://mybucket --region us-east-1`, where *mybucket* is an unique bucket name.
3. Create a local clone of this repository.
4. Review the **Transcribe API configuration** in the script.
   1. Open `mp4-transcribe.sh` in a text editor.
   2. Make sure that the `endpoint_uri` and `region_name` settings matches the [guidelines and limits](https://docs.aws.amazon.com/transcribe/latest/dg/limits-guidelines.html) in the API documentation.
   3. Confirm that `bucket_path` matches the name of your S3 bucket.

## How to use this script
1. Copy an MP4 video file into the same directory as this script.
2. Run `./mp4-transcribe.sh -i <video_file_name>`, where `video_file_name` is your source video file.
3. Open the AWS console to see the current progress of the transcription.

## License
Review the [license](LICENSE) before you clone this repository.
