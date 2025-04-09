#!/bin/bash

yum update -y
yum install -y git python3 pip amazon-cloudwatch-agent
pip3 install flask
git clone https://github.com/Pavlo-Ponomarenko/cloud-gallery.git
cd cloud-gallery
python3 -m flask --app App run --host=0.0.0.0 &
cd ..
cat <<EOF > cloudwatch-agent-config.json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/cloud-gallery/app.log",
            "log_group_name": "cloud-gallery-logs",
            "log_stream_name": "cloud-gallery-requests"
          }
        ]
      }
    }
  }
}
EOF
./opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/cloudwatch-agent-config.json \
  -s &