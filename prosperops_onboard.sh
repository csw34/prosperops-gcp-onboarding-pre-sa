#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

# ==============================================================================
# PROSPEROPS ONBOARDING SCRIPT
# This script automates the creation of the Custom Role and assignment of permissions
# required for ProsperOps to optimize your environment.
# ==============================================================================

# --- 1. USER INPUTS ---
echo "----------------------------------------------------------------"
echo "Please provide the following configuration details:"
echo "----------------------------------------------------------------"

echo "Enter your Organization ID (e.g., 1234567890):"
read ORG_ID

echo ""
echo "Enter your Billing Account ID (e.g., 012345-6789AB-CDEF01):"
read BILLING_ID

echo ""
echo "Enter the Project.Dataset containing the DETAILED USAGE export:"
echo "Format: project-id.dataset_name"
read DETAILED_DATASET_ID

echo ""
echo "Enter the Project.Dataset containing the PRICING export:"
echo "Format: project-id.dataset_name"
read PRICING_DATASET_ID

echo ""
echo "Enter the Project.Dataset containing the CUD METADATA export:"
echo "Format: project-id.dataset_name"
read CUD_METADATA_DATASET_ID

echo ""
echo "Enter the ProsperOps Service Account Email:"
read SERVICE_ACCOUNT_EMAIL
# --- 2. PREPARE VARIABLES ---

# Function to ensure Project:Dataset format (replaces first dot with colon if colon is missing)
fix_dataset_format() {
    local input=$1
    if [[ "$input" != *":"* ]]; then
        # Replace only the first dot with a colon
        echo "${input/./:}"
    else
        echo "$input"
    fi
}

# Apply fixes
DETAILED_DATASET_ID=$(fix_dataset_format "$DETAILED_DATASET_ID")
PRICING_DATASET_ID=$(fix_dataset_format "$PRICING_DATASET_ID")
CUD_METADATA_DATASET_ID=$(fix_dataset_format "$CUD_METADATA_DATASET_ID") # <-- NEW
BILLING_ID_UNDERSCORES=${BILLING_ID//-/_}

# 2. Construct Full Table Paths (Project:Dataset.Table)
TABLE_DETAILED="${DETAILED_DATASET_ID}.gcp_billing_export_resource_v1_${BILLING_ID_UNDERSCORES}"
TABLE_PRICING="${PRICING_DATASET_ID}.cloud_pricing_export"
TABLE_CUD_METADATA="${CUD_METADATA_DATASET_ID}.committed_use_discount_metadata" # <-- NEW

# 3. Standard Variables
SA_MEMBER="serviceAccount:$SERVICE_ACCOUNT_EMAIL"
ROLE_ID="ProsperOps"
YAML_FILE="prosperOpsRole.yaml"

echo ""
echo "----------------------------------------------------------------"
echo "Review Configuration:"
echo "  Organization ID: $ORG_ID"
echo "  Billing ID:      $BILLING_ID"
echo "  Service Account: $SA_MEMBER"
echo "  Target Tables:"
echo "    1. $TABLE_DETAILED"
echo "    2. $TABLE_PRICING"
echo "    3. $TABLE_CUD_METADATA" # <-- NEW
echo "----------------------------------------------------------------"
echo "Proceed? (y/n):"
read CONFIRM
if [[ $CONFIRM != "y" ]]; then exit 1; fi

# --- 3. GENERATE YAML DEFINITION ---
echo ""
echo "1. Generating Custom Role Definition ($YAML_FILE)..."

# Note: Included the full permission list from previous requirements to ensure functionality
cat <<EOF > $YAML_FILE
title: "$ROLE_ID"
description: "Used by ProsperOps - www.prosperops.com. Must remain in place for ProsperOps to function correctly. Email help@prosperops.com for assistance."
stage: "GA"
includedPermissions:
  - compute.commitments.get
  - compute.commitments.list
  - compute.instances.list
  - resourcemanager.folders.get
  - resourcemanager.folders.list
  - resourcemanager.organizations.get
  - resourcemanager.projects.get
  - resourcemanager.projects.list
EOF

# --- 4. CREATE OR UPDATE CUSTOM ROLE ---
echo "2. Configuring Custom Role ($ROLE_ID) at Organization level..."

# Check if role exists to update, otherwise create
if gcloud iam roles describe $ROLE_ID --organization=$ORG_ID > /dev/null 2>&1; then
    echo "   Role exists. Updating..."
    gcloud iam roles update $ROLE_ID \
        --organization=$ORG_ID \
        --file=$YAML_FILE \
        --quiet
else
    echo "   Role does not exist. Creating..."
    gcloud iam roles create $ROLE_ID \
        --organization=$ORG_ID \
        --file=$YAML_FILE \
        --quiet
fi

# --- 5. ASSIGN ROLES ---
echo "3. Assigning Custom Role to Organization..."
gcloud organizations add-iam-policy-binding $ORG_ID \
  --member="$SA_MEMBER" \
  --role="organizations/$ORG_ID/roles/$ROLE_ID" \
  --condition=None \
  --quiet > /dev/null

echo "4. Assigning Billing Account Viewer Role..."
gcloud billing accounts add-iam-policy-binding $BILLING_ID \
  --member="$SA_MEMBER" \
  --role="roles/billing.viewer" \
  --quiet > /dev/null

echo "5. Assigning BigQuery Data Viewer Role to Tables..."

# Array of tables to loop through
TABLES_TO_BIND=(
    "$TABLE_DETAILED"
    "$TABLE_PRICING"
    "$TABLE_CUD_METADATA" # <-- NEW: CUD Metadata table
)

for TABLE in "${TABLES_TO_BIND[@]}"; do
    echo "   Processing Table: $TABLE"
    bq add-iam-policy-binding \
      --member="$SA_MEMBER" \
      --role=roles/bigquery.dataViewer \
      $TABLE > /dev/null
done

# --- 6. CLEANUP ---
rm $YAML_FILE
echo ""
echo "----------------------------------------------------------------"
echo "✅ Onboarding Complete!"
echo "----------------------------------------------------------------"
