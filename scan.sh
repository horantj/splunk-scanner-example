#!/bin/bash

OUTPUT_DIR=/var/neuvector
HEC_ENDPOINT="https://splunk:port//services/collector/event"
HEC_TOKEN="token"

# Pull new scanner if necessary

docker pull neuvector/scanner:latest >/dev/null 2>&1

# loop through csv. #### registry,repo/container,tag

while IFS="," read -ra line || [ -n "$line" ]
do
	echo "Scanning ${line[0]}/${line[1]}:${line[2]}"

	docker run --name neuvector.scanner --rm \
		-e SCANNER_ON_DEMAND=true \
		-e SCANNER_REGISTRY=${line[0]} \
		-e SCANNER_REPOSITORY=${line[1]} \
		-e SCANNER_TAG=${line[2]} \
		-e SCANNER_SCAN_LAYERS=true \
		-v ${OUTPUT_DIR}:/var/neuvector \
		neuvector/scanner >/dev/null 2>&1

if (test $? -ne 0)
then
	echo "scan script failed"
	exit 1
fi

#send results to splunk
echo "Sending results to splunk"
results=$(<${OUTPUT_DIR}/scan_result.json)

cat > ${OUTPUT_DIR}/hec.json <<EOF
{
    "event": ${results}
}
EOF

curl -sS -k -H "Authorization: Splunk ${HEC_TOKEN}" \
${HEC_ENDPOINT} \
-d @${OUTPUT_DIR}/hec.json -o /dev/null

if (test $? -ne 0)
then
        echo "curl failed"
        exit 1
fi

#clean up, clean up, everybody clean up
rm ${OUTPUT_DIR}/hec.json

done < images.csv
