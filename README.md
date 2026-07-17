terraform init \
  -backend-config="access_key=$ACCESS_KEY" \
  -backend-config="secret_key=$SECRET_KEY" \
  -backend-config="yc_cloud_id=$YC_CLOUD_ID" \
  -backend-config="yc_folder_id=$YC_FOLDER_ID"
