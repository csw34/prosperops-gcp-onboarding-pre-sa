#!/bin/bash
set -e

# ==============================================================================
# PROSPEROPS UPGRADE SCRIPT
# This script updates the existing Custom Role with additional permissions
# and adds the Consumer Procurement Order Admin role to the Billing Account.
# ==============================================================================

# --- 1. USER INPUTS ---
echo "----------------------------------------------------------------"
echo "UPGRADE CONFIGURATION"
echo "----------------------------------------------------------------"

echo "Enter your Organization ID (e.g., 1234567890):"
read ORG_ID

echo ""
echo "Enter your Billing Account ID (e.g., 012345-6789AB-CDEF01):"
read BILLING_ID

echo ""
echo "Enter the ProsperOps Service Account Email:"
read SERVICE_ACCOUNT_EMAIL

# Formatting variables
SA_MEMBER="serviceAccount:$SERVICE_ACCOUNT_EMAIL"
ROLE_ID="ProsperOps"
YAML_FILE="prosperOpsRole_v2.yaml"

echo ""
echo "----------------------------------------------------------------"
echo "Review Upgrade:"
echo "  Organization ID: $ORG_ID"
echo "  Billing ID:      $BILLING_ID"
echo "  Service Account: $SA_MEMBER"
echo "----------------------------------------------------------------"
echo "Proceed? (y/n):"
read CONFIRM
if [[ $CONFIRM != "y" ]]; then exit 1; fi

# --- 2. GENERATE UPDATED YAML DEFINITION ---
echo ""
echo "1. Generating Updated Custom Role Definition..."

# This list is the SUPERSET (Original Read Permissions + New Write Permissions)
cat <<EOF > $YAML_FILE
title: "$ROLE_ID"
description: "Used by ProsperOps - www.prosperops.com. Includes CUD management permissions."
stage: "GA"
includedPermissions:
  # --- Original Read Permissions ---
  - compute.commitments.get
  - compute.commitments.list
  - resourcemanager.folders.get
  - resourcemanager.folders.list
  - resourcemanager.organizations.get
  - resourcemanager.projects.get
  - resourcemanager.projects.list
  # --- New Management Permissions ---
  - cloudquotas.quotas.get
  - cloudquotas.quotas.update
  - compute.commitments.create
  - compute.commitments.update
  - compute.regionOperations.get
  - consumerprocurement.orders.place
  - monitoring.timeSeries.list
  - serviceusage.quotas.get
  - serviceusage.quotas.update
  - serviceusage.services.get
  - serviceusage.services.list
EOF

# --- 3. UPDATE CUSTOM ROLE ---
echo "2. Updating Custom Role ($ROLE_ID) permissions..."

# We use 'update' here because the role should already exist
gcloud iam roles update $ROLE_ID \
    --organization=$ORG_ID \
    --file=$YAML_FILE \
    --quiet

# --- 4. ASSIGN NEW BILLING ROLE ---
echo "3. Assigning Consumer Procurement Order Admin Role..."

# Using gcloud beta as requested for billing account policy bindings
gcloud beta billing accounts add-iam-policy-binding $BILLING_ID \
  --member="$SA_MEMBER" \
  --role="roles/consumerprocurement.orderAdmin" \
  --quiet > /dev/null

# --- 5. CLEANUP ---
rm $YAML_FILE
echo ""
echo "----------------------------------------------------------------"
echo "✅ Upgrade Complete!"
echo "----------------------------------------------------------------"
