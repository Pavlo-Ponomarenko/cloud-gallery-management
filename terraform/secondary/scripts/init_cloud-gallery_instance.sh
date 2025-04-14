#!/bin/bash

yum update -y
yum install -y git python3 pip amazon-cloudwatch-agent amazon-efs-utils cronie
pip3 install flask boto3
sudo systemctl start crond
sudo systemctl enable crond

git clone https://github.com/Pavlo-Ponomarenko/cloud-gallery.git
cd cloud-gallery

mkdir logs
sudo mount -t efs -o tls ${efs_id}:/ logs

export IMAGES_SOURCE=s3
python3 -m flask --app App run --host=0.0.0.0 &

cat <<"EOF" > /backup_logs.sh
BASE_DIR="/cloud-gallery"
LOGS_DIR="$BASE_DIR/logs"
file=$(find "$LOGS_DIR" -maxdepth 1 -type f -name 'latest*' | head -n 1)
if [[ -n "$file" ]]; then
  base_name=$(basename "$file")
  new_name="archived${base_name#latest}"
  mv "$file" "${LOGS_DIR}/${new_name}"
fi
timestamp="$(date "+%Y-%m-%d_%H:%M:%S")"
cp "$BASE_DIR/app.log" "${LOGS_DIR}/latest_${timestamp}.log"
echo "" > "$BASE_DIR/app.log"
EOF
chmod +x /backup_logs.sh
echo '* * * * * /backup_logs.sh' | crontab -

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