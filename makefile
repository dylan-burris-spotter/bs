#!make
include .env
include ../Makefile

.PHONY: dynamodb localdev localprod local-lambda requirements poetry-auth poetry-install

localdev:
	docker compose down
	docker compose up -d localstack
	docker compose up -d dbadmin
	$(MAKE) s3
	$(MAKE) dynamodb
	$(MAKE) db-add-transaction
	$(MAKE) db-add-metadata
	$(MAKE) sqs-create
	$(MAKE) sns-create
	docker compose up -d dbadmin
	@echo "Success! Run 'make sqs-video' to send a video message to the queue, or sqs-audio for audio downloads. Then run src/app.py to process the queue."

localprod:
	docker compose down
	docker compose up -d localstack
	docker compose up -d dbadmin
	$(MAKE) s3
	$(MAKE) db
	$(MAKE) sqs-create
	docker compose up -d dbadmin
	$(MAKE) poetry-auth
	$(MAKE) requirements
	docker compose up -d --build app
	@echo "Success! Run 'make sqs-video' to send a video message to the queue, or sqs-audio for audio downloads. Then run src/app.py to process the queue."

db-add-metadata:
	@awslocal dynamodb put-item \
		--table-name Video-Data \
		--item "{\"pk\": {\"S\": \"#$(VIDEO_ID)\"},\"sk\": {\"S\": \"#metadata#2023-10-13T00:33:09.760Z\"},\"channel_id\": {\"S\": \"UClQubH2NeMmGLTLgNdLBwXg\"},\"channel_title\": {\"S\": \"ZHC\"},\"content_details\": {\"M\": {\"caption\": {\"S\": \"true\"},\"contentRating\": {\"M\": {}},\"definition\": {\"S\": \"hd\"},\"dimension\": {\"S\": \"2d\"},\"duration\": {\"S\": \"PT9M4S\"},\"licensedContent\": {\"BOOL\": false},\"projection\": {\"S\": \"rectangular\"}}},\"data_key\": {\"S\": \"#videodata\"},\"date_created\": {\"S\": \"2023-10-13T00:33:09.760Z\"},\"date_key\": {\"S\": \"2023-10-13T00:33:09.760Z#96f711a7-c496-4edc-a2ab-e091d96416c1\"},\"default_audio_language\": {\"S\": \"en\"},\"description\": {\"S\": \"Sample Description\"},\"id\": {\"S\": \"0ux00hqFTNA\"},\"record_subtype\": {\"NULL\": true},\"record_type\": {\"S\": \"metadata\"},\"statistics\": {\"M\": {\"commentCount\": {\"N\": \"814\"},\"favoriteCount\": {\"N\": \"0\"},\"likeCount\": {\"N\": \"6233\"},\"viewCount\": {\"N\": \"226111\"}}},\"status\": {\"M\": {\"embeddable\": {\"BOOL\": true},\"license\": {\"S\": \"youtube\"},\"privacyStatus\": {\"S\": \"public\"},\"publicStatsViewable\": {\"BOOL\": true},\"uploadStatus\": {\"S\": \"processed\"}}},\"tags\": {\"L\": [{\"S\": \"zhcomicart\"}]},\"thumbnails\": {\"M\": {\"default\": {\"M\": {\"height\": {\"N\": \"90\"},\"url\": {\"S\": \"https:\/\/i.ytimg.com\/vi\/0ux00hqFTNA\/default.jpg\"},\"width\": {\"N\": \"120\"}}},\"high\": {\"M\": {\"height\": {\"N\": \"360\"},\"url\": {\"S\": \"https:\/\/i.ytimg.com\/vi\/0ux00hqFTNA\/hqdefault.jpg\"},\"width\": {\"N\": \"480\"}}},\"maxres\": {\"M\": {\"height\": {\"N\": \"720\"},\"url\": {\"S\": \"https:\/\/i.ytimg.com\/vi\/0ux00hqFTNA\/maxresdefault.jpg\"},\"width\": {\"N\": \"1280\"}}},\"medium\": {\"M\": {\"height\": {\"N\": \"180\"},\"url\": {\"S\": \"https:\/\/i.ytimg.com\/vi\/0ux00hqFTNA\/mqdefault.jpg\"},\"width\": {\"N\": \"320\"}}},\"standard\": {\"M\": {\"height\": {\"N\": \"480\"},\"url\": {\"S\": \"https:\/\/i.ytimg.com\/vi\/0ux00hqFTNA\/sddefault.jpg\"},\"width\": {\"N\": \"640\"}}}}},\"title\": {\"S\": \"DRAWING A FAN'S DRAWING (Venom Mashup Challenge Entry Review)\"},\"video_id\": {\"S\": \"0ux00hqFTNA\"},\"video_key\": {\"S\": \"#0ux00hqFTNA#metadata#2023-10-13T00:33:09.760Z\"}}" \
		--region $(AWS_REGION)

peek:
	curl -H "Accept: application/json" "http://localhost:4566/_aws/sqs/messages?QueueUrl=http://localhost:4566/000000000000/video-download-spotter-local"

sns-create:
	awslocal sns create-topic --name video-download-spotter-local --region $(AWS_REGION)

sqs-create:
	@awslocal sqs create-queue --queue-name video-download-spotter-local --region $(AWS_REGION)

sqs-video:
	awslocal sqs send-message --queue-url http://localhost:4566/000000000000/video-download-spotter-local --message-body "{ \"video_id\": \"$(VIDEO_ID)\", \"transaction_id\": \"#$(VIDEO_ID)\", \"channel_id\": \"asdfasdf\" , \"job\": {  \"id\": \"242945d6-e26a-47dc-9f34-a3f019a7705d\",  \"limit\": 0,  \"video_download\": { \"acquire\": true, \"update\": false, \"yt_transcript\": false  } }}" --region $(AWS_REGION)

sqs-audio:
	awslocal sqs send-message --queue-url http://localhost:4566/000000000000/video-download-spotter-local --message-body "{ \"video_id\": \"$(VIDEO_ID)\", \"transaction_id\": \"#$(VIDEO_ID)\", \"channel_id\": \"asdfasdf\" , \"job\": {  \"id\": \"242945d6-e26a-47dc-9f34-a3f019a7705d\",  \"limit\": 0,  \"video_download\": { \"acquire\": false, \"acquire_audio\": true, \"update\": false, \"yt_transcript\": false  } }}" --region $(AWS_REGION)

sqs-catalog:
	awslocal sqs send-message --queue-url http://localhost:4566/000000000000/video-download-spotter-local --message-body "{ \"video_id\": \"$(VIDEO_ID)\", \"transaction_id\": \"#$(VIDEO_ID)\", \"channel_id\": \"asdfasdf\" , \"job\": {  \"id\": \"242945d6-e26a-47dc-9f34-a3f019a7705d\",  \"limit\": 0,  \"video_download\": { \"acquire\": false, \"acquire_audio\": false, \"update\": false, \"yt_transcript\": false, \"acquire_language_catalog\": true } }}" --region $(AWS_REGION)

sqs-transcript:
	awslocal sqs send-message --queue-url http://localhost:4566/000000000000/video-download-spotter-local --message-body "{ \"video_id\": \"$(VIDEO_ID)\", \"transaction_id\": \"#$(VIDEO_ID)\", \"channel_id\": \"asdfasdf\" , \"job\": {  \"id\": \"242945d6-e26a-47dc-9f34-a3f019a7705d\",  \"limit\": 0,  \"video_download\": { \"acquire\": false, \"acquire_audio\": false, \"update\": false, \"yt_transcript\": true, \"acquire_language_catalog\": false } }}" --region $(AWS_REGION)

sqs-peek:
	curl -H "Accept: application/json" "http://localhost:4566/_aws/sqs/messages/us-east-1/000000000000/video-download-spotter-local"

cf-validate:
	aws cloudformation validate-template --template-body file://stack.yml

# Core pipeline must be deployed first. See core project in this repo.
cf-deploy:
	aws cloudformation deploy \
	  --profile $(PROFILE) \
	  --region $(AWS_REGION) \
      --stack-name BrandSafety-Downloader \
      --template-file stack.yml \
      --capabilities CAPABILITY_NAMED_IAM \
      --parameter-overrides ImageExists=true


ecr-deploy-base:
	@echo "Deploying to ECR Base"
	$(eval AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --profile $(PROFILE) --query Account --output text))
	@echo $(AWS_ACCOUNT_ID)
	docker build -t spotterlocal/brandsafety-downloader-base -f Dockerfile.base .
	docker tag spotterlocal/brandsafety-downloader-base:latest $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/brandsafety-downloader-base:latest
	aws ecr get-login-password --region $(AWS_REGION) --profile $(PROFILE) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/brandsafety-downloader-base:latest

ecr-deploy:
	@echo "Deploying to ECR"
	$(eval AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --profile $(PROFILE) --query Account --output text))
	@echo $(AWS_ACCOUNT_ID)
	docker build -t spotterlocal/brandsafety-downloader .
	docker tag spotterlocal/brandsafety-downloader:latest $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/brandsafety-downloader:latest
	aws ecr get-login-password --region $(AWS_REGION) --profile $(PROFILE) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/brandsafety-downloader:latest

lambda-tail:
	awslocal logs tail --follow /aws/lambda/brand-safety-metadata --region $(AWS_REGION)
