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

read -p "Enter your Organization ID (e.g., 1234567890): " ORG_ID
read -p "Enter your Billing Account ID (e.g., 012345-6789AB-CDEF01): " BILLING_ID
read -p "Enter the ProsperOps Service Account Email: " SERVICE_ACCOUNT_EMAIL
echo "Enter your BigQuery Dataset IDs involved in billing export (separated by spaces):"
read -p "Example: 'billing_dataset_1 billing_dataset_2': " -a DATASET_IDS

# Formatting variables
SA_MEMBER="serviceAccount:$SERVICE_ACCOUNT_EMAIL"
ROLE_ID="ProsperOps"
YAML_FILE="prosperOpsRole.yaml"

echo ""
echo "----------------------------------------------------------------"
echo "Review Configuration:"
echo "  Organization ID: $ORG_ID"
echo "  Billing ID:      $BILLING_ID"
echo "  Service Account: $SA_MEMBER"
echo "  Datasets:        ${DATASET_IDS[*]}"
echo "----------------------------------------------------------------"
read -p "Proceed? (y/n): " CONFIRM
if [[ $CONFIRM != "y" ]]; then exit 1; fi

# --- 2. GENERATE YAML DEFINITION ---
echo ""
echo "1. Generating Custom Role Definition ($YAML_FILE)..."

cat <<EOF > $YAML_FILE
title: "ProsperOpsTestSep25"
description: "Used by ProsperOps - www.prosperops.com. Must remain in place for ProsperOps to function correctly. Email help@prosperops.com for assistance."
stage: "GA"
includedPermissions:
  - compute.commitments.get
  - compute.commitments.list
  - resourcemanager.folders.get
  - resourcemanager.folders.list
  - resourcemanager.organizations.get
  - resourcemanager.projects.get
  - resourcemanager.projects.list
EOF

# --- 3. CREATE OR UPDATE CUSTOM ROLE ---
echo "2. Configuring Custom Role ($ROLE_ID) at Organization level..."

# Check if role exists to update, otherwise create
if gcloud iam roles describe $ROLE_ID --organization=$ORG_ID > /dev/null 2>&1; then
    echo "   Role exists. Updating..."
    gcloud iam roles update $ROLE_ID \
        --organization=$ORG_ID \
        --file=$YAML_FILE \
        --quiet
else
    echo "   Role does not exist. Creating..."
    gcloud iam roles create $ROLE_ID \
        --organization=$ORG_ID \
        --file=$YAML_FILE \
        --quiet
fi

# --- 4. ASSIGN ROLES ---
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

echo "5. Assigning BigQuery Data Viewer Role to Datasets..."
if [ ${#DATASET_IDS[@]} -eq 0 ]; then
    echo "   No datasets provided. Skipping."
else
    for DATASET in "${DATASET_IDS[@]}"; do
        echo "   Processing dataset: $DATASET"
        bq add-iam-policy-binding \
          --member="$SA_MEMBER" \
          --role=roles/bigquery.dataViewer \
          $DATASET > /dev/null
    done
fi

# --- 5. CLEANUP ---
rm $YAML_FILE
echo ""
echo "----------------------------------------------------------------"
echo "✅ Onboarding Complete!"
echo "----------------------------------------------------------------"
