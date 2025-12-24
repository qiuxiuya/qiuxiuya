REGION=cn-hongkong

aliyun ecs DescribeInstances \
  --RegionId "$REGION" | grep -E '"InstanceId"|"Status"' | awk -F'"' '
/InstanceId/ {id=$4}
/Status/ {
  if ($4 != "Running") {
    print id, $4
  }
}
' | while read -r INSTANCE_ID STATUS; do
  echo "starting $INSTANCE_ID (current=$STATUS)"
  aliyun ecs StartInstance --RegionId "$REGION" --InstanceId "$INSTANCE_ID"
done