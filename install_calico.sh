#!/bin/bash

echo "Installing EKSCTL"
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
echo "EKSCTL installed in version"
eksctl version

echo "Installing Helm"
sudo yum install -y openssl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "Helm Installed"
helm version

output=$(aws eks update-kubeconfig --region us-east-1 --name Container-Security-InmersionDay)


# Extract the path from the output using string manipulation
kube_config="${output##* }"

export KUBECONFIG=$kube_config


echo "Installing calico ..."

helm repo add projectcalico https://docs.tigera.io/calico/charts
kubectl create namespace tigera-operator
helm install calico projectcalico/tigera-operator --version v3.25.1 --namespace tigera-operator
echo "calico installed"

sleep 20

# Function to check if all pods are in "Running" state
function check_pods_running() {
  local ready_pods=$(kubectl get pods -n calico-system | awk 'NR>1 {print $3}' | grep -c 'Running')
  local total_pods=$(kubectl get pods -n calico-system | awk 'NR>1' | wc -l)

  if [ "$ready_pods" -eq "$total_pods" ]; then
    return 0
  else
    return 1
  fi
}

# Main loop to watch the pods until they are all in "Running" state
while true; do
  watch_result=$(kubectl get pods -n calico-system)

  # Check if all pods are in "Running" state
  check_pods_running
  if [ $? -eq 0 ]; then
    break
  fi

  # Clear the watch output from the terminal
  clear
done

echo "All pods are in Running state!"


############# Check errors in calico ##############

sleep 5

# Get the output of "kubectl get all" command in the tigera-operator namespace
output=$(kubectl get all -n tigera-operator)

# Extract the values from the output using awk
desired=$(echo "$output" | awk 'NR==8 {print $2}')
ready=$(echo "$output" | awk 'NR==8 {print $4}')

# Check if the values match
if [ "$desired" = "$ready" ]; then
  echo $desired
  echo $ready
  echo "Values in DESIRED and READY columns match: $desired"
else
  echo $desired
  echo $ready
  echo "Values in DESIRED and READY columns do not match. DESIRED: $desired, READY: $ready"
  exit 1
fi


# Get the output of "kubectl get all" command in the calico-system namespace
output=$(kubectl get all -n calico-system)

# Extract the values for calico-node daemonset from the output using awk
desired_daemonset=$(echo "$output" | awk '/daemonset.apps\/calico-node/ {print $2}')
ready_daemonset=$(echo "$output" | awk '/daemonset.apps\/calico-node/ {print $3}')

# Extract the values for the two replicaset resources from the output using awk
desired_replicaset=$(echo "$output" | awk '/replicaset.apps\/calico-kube-controllers/ {print $2}')
ready_replicaset=$(echo "$output" | awk '/replicaset.apps\/calico-kube-controllers/ {print $3}')
desired_replicaset2=$(echo "$output" | awk '/replicaset.apps\/calico-typha/ {print $2}')
ready_replicaset2=$(echo "$output" | awk '/replicaset.apps\/calico-typha/ {print $3}')

# Function to check if desired and ready values match
function check_match() {
  if [ "$1" -eq "$2" ]; then
    echo "Match: $1/$2"
  else
    echo "No match: $1/$2"
    exit 1
  fi
}

# Check if desired and ready values for calico-node daemonset match
echo "Calico-node daemonset:"
check_match "$desired_daemonset" "$ready_daemonset"

# Check if desired and ready values for the two replicaset resources match
echo "Replicaset (calico-kube-controllers):"
check_match "$desired_replicaset" "$ready_replicaset"

echo "Replicaset (calico-typha-696bcd55cb):"
check_match "$desired_replicaset2" "$ready_replicaset2"



                                                         

sleep 10
output1=$(kubectl get pods --all-namespaces | grep tigera-operator)
# Use awk to extract the desired part
tigera=$(echo "$output1" | awk '{print $2}')
output2=$(kubectl get pods --all-namespaces | grep calico-node)
# Use awk to extract the desired part
cnode=$(echo "$output2" | awk '{print $2}')
output3=$(kubectl get pods --all-namespaces | grep calico-typha)
# Use awk to extract the desired part
typha=$(echo "$output3" | awk '{print $2}')

cnode1=$(echo "$cnode" | grep -o 'calico-node-[^[:space:]]*' | sed -n '1p')
cnode2=$(echo "$cnode" | grep -o 'calico-node-[^[:space:]]*' | sed -n '2p')

# Print the variables to verify their values
echo "First Pod: $cnode1"
echo "Second Pod: $cnode2"

commands=(
  "kubectl logs $tigera -n tigera-operator | grep ERROR"
  "kubectl logs $cnode1 -c calico-node -n calico-system | grep ERROR"=
  "kubectl logs $cnode2 -c calico-node -n calico-system | grep ERROR"
  "kubectl logs $typha -n calico-system | grep ERROR"
)

# Function to check logs for errors and print if found
function check_logs_for_errors() {
  local cmd=$1
  echo "Running: $cmd"
  local logs_output
  logs_output=$(eval "$cmd")
  if [ -n "$logs_output" ]; then
    echo "Error(s) found in logs:"
    echo "$logs_output"
    exit 1
  else
    echo "No errors found in logs."
  fi
}

# Loop through the commands and check logs for errors
for cmd in "${commands[@]}"; do
  check_logs_for_errors "$cmd"
done

################### Set Calico for EKS #####################

cat << EOF > append.yaml
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - patch
EOF

kubectl apply -f <(cat <(kubectl get clusterrole aws-node -o yaml) append.yaml)
kubectl set env daemonset aws-node -n kube-system ANNOTATE_POD_IP=true


sleep 5
# Save the output of the command in a variable using $()
output=$(kubectl get pods --all-namespaces | grep calico-kube-controllers)
# Use awk to extract the desired part
variable=$(echo "$output" | awk '{print $2}')
echo "$variable"
kubectl delete pod $variable -n calico-system

sleep 5

# Save the output of the command in a variable using $()
output=$(kubectl get pods --all-namespaces | grep calico-kube-controllers)

# Use awk to extract the desired part
variable=$(echo "$output" | awk '{print $2}')

kubectl describe pod $variable -n calico-system | grep vpc.amazonaws.com/pod-ips

sleep 10
# Save the output of the command in a variable using $()
output=$(kubectl get pods --all-namespaces | grep calico-kube-controllers)
# Use awk to extract the desired part
variable=$(echo "$output" | awk '{print $2}')
echo "$variable"
kubectl delete pod $variable -n calico-system

sleep5

# Save the output of the command in a variable using $()
output=$(kubectl get pods --all-namespaces | grep calico-kube-controllers)

# Use awk to extract the desired part
variable=$(echo "$output" | awk '{print $2}')

kubectl describe pod $variable -n calico-system | grep vpc.amazonaws.com/pod-ips